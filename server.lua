local bump = require("lib.bump")
local lume = require("lib.lume")
local sock = require("lib.sock")

local lfg = require("lfg")

local GamePlayer = require("player")

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


local function init(_Server, port)
    port = port or Server.PORT
    log("OPENING SERVER ON PORT: %s", ppsl(port))
    local server = sock.newServer("*", port)
    local world = bump.newWorld(1)

    local self = setmetatable({
            clients = {},
            players = {},
            projectiles = {},
            updates = {},
            server = server,
            world = world,
            tick_rate = 1.0 / 40.0,
            tick_tock = 0,
            ticks = 0,
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

    --server.on("attack_melee", function(data, client)
    --    lfg.log("MELEE ATTACK FROM CLIENT[%s]: %s", client.clid, ppsl(data))
    --    self:broadcast_event("attack_melee" data)
    --end)

    --server.on("attack_spell", function(data, client)
    --    lfg.log("SPELL ATTACK FROM CLIENT[%s]: %s", client.clid, ppsl(data))
    --    self:broadcast_event("attack_melee" data)
    --end)

    server:on("create_player", function(data, client)
        log("GOT CREATE PLAYER: %s", ppsl(data))
        local player = GamePlayer({
            name = data.payload.name,
            character = data.payload.character,
            spell = data.payload.spell,
            user_id = data.user_id,
        })
        self.players[player.uuid] = player
        self.players[client.clid] = player
        self.players[data.user_id] = player
        self.world:add(client.clid, player.x, player.y, player.w, player.h)
        client:send("create_player_ack", {req_id=data.req_id,
            player=player:serialized()})
    end)

    server:on("announce_self", function(data, client)
        local ent = Entity(data)
        local layer = lfg.map.layers["KoreEntitie"]
        self.players[client.clid] = ent
        self.world:add(ent.clid, ent.x, ent.y, ent.w, ent.h)
        self:announce_player(client, data)
        self:announce_players(client)
    end)

    server:on("player_update", function(data, client)
        local player = assert(self.players[client.clid])
        -- TODO: switch to world:move(...)
        self.updates[player.uuid] = data
        -- TODO: add update ack or track frame id and send frame ack
    end)

    server:on("new_projectile", function(data, client)
        local pjt = Projectile(data)
        self.projectiles[pjt.uuid] = pjt
        lfg.log("CREATING NEW PROJECTILE WITH: %s", ppsl(data))
        world:add(pjt.uuid, pjt.x, pjt.y, pjt.w, pjt.h)
        self:broadcast_event("new_projectile", pjt:serialized())
    end)

    return self
end
setmetatable(Server, {__call = init})


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


function Server:announce_players(client)
    for uuid, player in pairs(self.players) do
        client:send("announce_player", player:serialized())
    end
end


function Server:broadcast_projectiles(dt)
    -- TODO: what to do about serializeAll()? Where to put it?
    --local serialized = self.projectiles:serialize_all()
    local serialized = {}
    if #serialized > 0 then
        for uuid, client in pairs(self.clients) do
            client:send("update_projectiles", serialized)
        end
    end
end


-- TODO: switch to prioritize update hierarchy
function Server:broadcast_updates(dt)
    local payload = {tick = self.ticks, updates = self.updates}
    self.server:sendToAll("server_tick", payload)
end


function Server:update(dt)
    self.server:update(dt)
    self:process_updates(dt)
    -- self.update_projectiles()
    self:tick(dt)
end


function Server:tick(dt)
    self.tick_tock = self.tick_tock + dt

    if self.tick_tock > self.tick_rate then
        self.ticks = self.ticks + 1
        self.tick_tock = self.tick_tock - self.tick_rate
        self:broadcast_updates(dt)
        self:clear_updates(dt)
        --self:broadcast_projectiles(dt)
    end
end


function Server:clear_updates(dt)
    self.updates = {}
end


function Server:process_updates(dt)
    for puid, update in pairs(self.updates) do
        local player = assert(self.players[puid])
        if update.cdir then
            local cdir = assert(lfg.ndirs[update.cdir])
            local x = player.x + cdir.x * player.speed * dt
            local y = player.y + cdir.y * player.speed * dt
            player.x, player.y = x, y
            update.x, update.y = x, y
        end
    end
end


return Server
