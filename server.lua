local bump = require("lib.bump")
local lume = require("lib.lume")
local sock = require("lib.sock")

local lfg = require("lfg")

local GamePlayer = require("player")
local Projectile = require("projectile")

local debug = true

local Server = {}
Server.__index = Server

Server.PORT = 34227

local function log_client_connected(uuid, data, client)
    if debug then
        log("\n***CLIENT CONNECTED[%s]:\n\tDATA: %s\n\tCLIENT: %s\n\t",
            uuid, ppsl(data), ppsl(client))
    end
end


local function init(_Server, port, map, world)
    assert(map)
    port = port or Server.PORT
    log("OPENING SERVER ON PORT: %s", ppsl(port))
    local server = sock.newServer("*", port)
    --local world = bump.newWorld(1)
    --local world = map.world

    local self = setmetatable({
            map = map,
            clients = {},
            dead_players = {},
            disconnected_players = {},
            players = {},
            projectiles = {},
            player_hits = {},
            updates = {},
            server = server,
            world = world,
            tick_rate = 1.0 / 40.0,
            tick_tock = 0,
            ticks = 0,
            age = 0,
        }, Server)

    server:on("connect", function(data, client)
        local uuid = lume.uuid()
        local msg = "welcome to your doom"

        -- TODO: do we still need this? ugly to update client object
        client.clid = uuid

        self.clients[uuid] = client
        log_client_connected(uuid, data, client)

        client:send("welcome", {msg=msg, uuid=uuid})
    end)

    server:on("create_player", function(data, client)
        log("GOT CREATE PLAYER: %s", ppsl(data))
        local player = GamePlayer({
            name = data.payload.name,
            character = data.payload.character,
            spell_name = data.payload.spell_name,
            user_id = data.user_id,
        })
        log("CREATING PLAYER: %s", ppsl(player:serialized()))
        self.players[player.uuid] = player
        self.players[client.clid] = player
        self.world:add(player.uuid, player.x, player.y, player.w, player.h)
        client:send("create_player_ack", {req_id=data.req_id,
            player=player:serialized()})
        self:announce_players()
    end)

    server:on("player_update", function(data, client)
        local player = assert(self.players[client.clid])
        -- TODO: switch to world:move(...)
        self.updates[player.uuid] = data
        -- TODO: add update ack or track frame id and send frame ack
    end)

    server:on("create_projectile", function(data, client)
        --log("CREATING NEW PROJECTILE WITH: %s", ppsl(data))
        local pjt = Projectile(data)
        self.projectiles[pjt.uuid] = pjt
        world:add(pjt.uuid, pjt.x, pjt.y, pjt.w, pjt.h)
        self:broadcast_event("created_projectile", pjt:serialized())
    end)

    server:on("disconnect", function(data, client)
        log("SERVER GOT DISCONNECT FROM CLIENT: %s", client.clid)
        if self.players[client.clid] then
            local player = assert(self.players[client.clid])
            self.disconnected_players[player.uuid] = true
            self:remove_player(player, client)
        -- else: client did not fully connect
        end
    end)

    return self
end
setmetatable(Server, {__call = init})


function Server:remove_player(player, client)
    local puid = player.uuid
    self.world:remove(puid)
    self.players[puid] = nil
    self.dead_players[puid] = nil
    self.player_hits[puid] = nil
    self.players[client.clid] = nil
end


function Server:broadcast_event(etype, data)
    for uuid, client in pairs(self.clients) do
        if uuid ~= data.clid then
            client:send(etype, data)
        end
    end
end


function Server:announce_player(aclient, data)
    local atype = "announce_player"
    data["atype"] = atype
    for uuid, client in pairs(self.clients) do
        client:send(atype, data)
    end
end


function Server:announce_players()
    local payload = {tick=self.ticks, players={}}
    for _, player in pairs(self.players) do
        if not payload.players[player.uuid] then
            payload.players[player.uuid] = player:serialized()
        end
    end
    --log("ANNOUNCE_PLAYERS PAYLOAD: %s", ppsl(payload))
    self.server:sendToAll("announce_players", payload)
end


function Server:broadcast_projectiles(dt)
    local serialized = {projectiles={}, expired={}}
    local updated = false
    if next(self.projectiles) ~= nil then
        updated = true
        for uuid, pjt in pairs(self.projectiles) do
            serialized.projectiles[uuid] = pjt:serialized()
        end
    end
    if next(self.expired) ~= nil then
        updated = true
        for uuid, pjt in pairs(self.expired) do
            self.world:remove(uuid)
            serialized.expired[uuid] = pjt:serialized()
        end
    end
    if updated then
        self.server:sendToAll("updated_projectiles", serialized)
    end
end


-- TODO: switch to prioritize update hierarchy
function Server:broadcast_updates(dt)
    local payload = {
        tick = self.ticks,
        updates = self.updates,
        hits = self.player_hits,
        disconnects = self.disconnected_players,
    }
    self.server:sendToAll("server_tick", payload)
end


function Server:update(dt)
    self.server:update(dt)
    self:process_updates(dt)
    self:update_projectiles(dt)
    self:tick(dt)
end


function Server:tick(dt)
    self.tick_tock = self.tick_tock + dt
    self.age = self.age + dt

    if self.tick_tock > self.tick_rate then
        self.ticks = self.ticks + 1
        self.tick_tock = self.tick_tock - self.tick_rate
        self:broadcast_updates(dt)
        self:clear_updates(dt)
        self:broadcast_projectiles(dt)
        self:clear_projectiles(dt)
    end
end


function Server:clear_updates(dt)
    self.updates = {}
    self.player_hits = {}
    self.disconnected_players = {}
end


function Server:clear_projectiles(dt)
    for uuid, pjt in pairs(self.expired) do
        self.projectiles[uuid] = nil
    end
    self.expired = {}
end


function Server:process_updates(dt)
    for puid, update in pairs(self.updates) do
        local player = assert(self.players[puid])
        -- don't handle updates for dead players
        if not self.dead_players[puid] and update.cdir then
            local cdir = assert(lfg.ndirs[update.cdir])
            local x = player.x + cdir.x * player.speed * dt
            local y = player.y + cdir.y * player.speed * dt

            local actual_x, actual_y, cols, len = self.world:move(puid, x, y)
            -- TODO: switch these updates to action model like with pjt's
            -- then update by way of player:update_player(action)
            player.x, player.y = actual_x, actual_y
            update.x, update.y = actual_x, actual_y
        end
    end

    local alive = {}
    for puid, val in pairs(self.dead_players) do
        local player = assert(self.players[puid])
        player:update(dt)
        if not player:is_dead() then alive[puid] = true end
    end

    for puid, val in pairs(alive) do self.dead_players[puid] = nil end
end


local function skip_collisions(item, other)
    -- TODO: skip projectile collisions on dead players
    -- need access to self.players
    if item.type == "projectile" and item.type == other.type then
        return false
    else
        return "slide"
    end
end

function Server:update_projectiles(dt)
    if not self.expired then self.expired = {} end

    for uuid, pjt in pairs(self.projectiles) do
        if not self.expired[uuid] then
            pjt:update(dt)

            if pjt:is_expired() then
                self.expired[uuid] = pjt
            else
                local pact = pjt:tick(dt)
                local actual_x, actual_y, cols, len = self.world:move(
                    pjt.uuid, pact.x, pact.y, skip_collisions)

                if len > 0 then
                    self.expired[uuid] = pjt
                    for i, col in ipairs(cols) do
                        --log("{%i}{{%.2f}}COL IS[%i]: %s -- PJT.UUID: %s -- COL OTHER: %s", self.ticks, self.age, i, col.item, pjt.uuid, col.other)
                        assert(uuid == col.item)
                        local player = self.players[col.other]
                        if player and pjt.puid ~= player.uuid  and not self.dead_players[player.uuid] then
                            local action = player:hit(col)
                            if player:is_dead() then
                                self.dead_players[player.uuid] = true
                            end
                            self.player_hits[player.uuid] = action
                        end
                    end
                end

                pact.x, pact.y = actual_x, actual_y
                pact.cols, pact.cols_len = cols, len
                pjt:update_projectile(pact)
            end
        end
    end
end


return Server
