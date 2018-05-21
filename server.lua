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


local function init(_Server, args)
    assert(args.map)
    assert(args.world)
    local map = args.map
    local world = args.world
    local port = args.port or Server.PORT
    log("OPENING SERVER ON PORT: %s", ppsl(port))
    local server = sock.newServer("*", port)
    --local world = bump.newWorld(1)
    --local world = map.world

    local self = setmetatable({
            noclip = false,
            map = map,
            clients = {},
            dead_players = {},
            disconnected_players = {},
            players = {},
            projectiles = {},
            player_hits = {},
            scores = {},
            updates = {},
            server = server,
            world = world,
            tick_rate = 1.0 / 40.0,
            tick_tock = 0,
            ticks = 0,
            age = 0,
            uuid = lume.uuid(),
        }, Server)

    if args.kur then
        local kur = self:make_kur()
        self:store_player(kur, self.uuid)
        self.kur = kur
        self.kur_target = nil
        self.kur_target_timer = 0.0
        self.kur_target_max_timer = 5.0
        self.kur_fireball_timer = 0.0
        self.kur_fireball_delay = 1.0
    end

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
        local x, y = self:rand_xy()
        local player = GamePlayer({
            name = data.payload.name,
            character = data.payload.character,
            spell_name = data.payload.spell_name,
            user_id = data.user_id,
            x = x,
            y = y,
        })
        log("CREATING PLAYER: %s", ppsl(player:serialized()))
        self:store_player(player, client.clid)
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
    self.scores[player.uuid] = nil
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
        scores = self.scores,
    }
    self.server:sendToAll("server_tick", payload)
end


function Server:update(dt)
    self.server:update(dt)
    self:process_updates(dt)
    self:update_projectiles(dt)
    if self.kur then self:update_kur(dt) end
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

            if self.noclip or (self.kur and puid == self.kur.uuid) then
                self.world:update(puid, x, y)
                player.x, player.y = x, y
                update.x, update.y = x, y
            else
                local actual_x, actual_y, cols, len = self.world:move(puid, x, y)
                -- TODO: switch these updates to action model like with pjt's
                -- then update by way of player:update_player(action)
                player.x, player.y = actual_x, actual_y
                update.x, update.y = actual_x, actual_y
            end
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
                                self.scores[pjt.puid] = self.scores[pjt.puid] + 1
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


function Server:rand_xy()
    local width = self.map.width * self.map.tilewidth
    local height = self.map.height * self.map.tileheight
    local x = math.random(width * 0.30, width * 0.70)
    local y = math.random(height * 0.30, height * 0.70)
    return x, y
end


function Server:store_player(player, clid)
    self.players[player.uuid] = player
    self.players[clid] = player
    self.world:add(player.uuid, player.x, player.y, player.w, player.h)
    self.scores[player.uuid] = 0
end


function Server:make_kur()
    local x, y = self:rand_xy()
    local args = {
        x = x,
        y = y,
        sx = 2,
        sy = 2,
        name = "Kur",
        hp = 10000,
        character = "Wyvern Adult",
        spell = "Fireball",
        user_id = "ENEMY",
        speed = 70,
        w = 256,
        h = 256,
    }
    log("CREATING KUR WITH: %s", ppsl(args))
    return GamePlayer(args)
end


function Server:update_kur(dt)
    local kur = self.kur

    self.kur_target_timer = self.kur_target_timer - dt
    if self.kur_target_timer < 0 then
        --log("LOOKING FOR NEW KUR TARGET[%s]...", kur.uuid)
        self.kur_target_timer = self.kur_target_max_timer + self.kur_target_timer

        -- find new target
        local player_vectors = {}
        local k_x, k_y = kur.x, kur.y
        for puid, player in pairs(self.players) do
            if player.uuid ~= kur.uuid then
                local p_x, p_y = player.x, player.y
                local angle = lume.angle(k_x, k_y, p_x, p_y)
                local distance = lume.distance(k_x, k_y, p_x, p_y)
                local dx, dy = lume.vector(angle, distance)
                local n_dx = dx / distance
                local n_dy = dy / distance
                local dir = lfg.ndirs[lfg.angle_to_dir(angle)]
                table.insert(player_vectors, {
                    distance = distance,
                    puid = player.uuid,
                    player = player,
                    x = p_x,
                    y = p_y,
                    dx = n_dx,
                    dy = n_dy,
                    dir = dir,
                    angle = angle,
                })
            end
        end
        if next(player_vectors) ~= nil then
            table.sort(player_vectors, function(a, b) return a.distance < b.distance end)
            local p_t = player_vectors[1]
            --log("KUR FOUND NEW TARGET[%s]: %s", kur.uuid, player_vectors[1].player.uuid)
            self.kur_target = player_vectors[1]
        else
            self.kur_target = nil
        end
    end

    if self.kur_target then
        --log("KUR[%s] IS TARGETING: %s [%s]", kur.uuid, self.kur_target.puid, self.kur_target.player.uuid)
        local k_x, k_y = kur.x, kur.y
        local t_x, t_y = self.kur_target.player.x, self.kur_target.player.y
        --log("<%.2f, %.2f> --> {%.2f, %.2f}", k_x, k_y, t_x, t_y)
        local angle = lume.angle(k_x, k_y, t_x, t_y)
        local distance = lume.distance(k_x, k_y, t_x, t_y)
        local dx, dy = lume.vector(angle, distance)
        local n_dx = dx / distance
        local n_dy = dy / distance
        local dir = lfg.ndirs[lfg.angle_to_dir(angle)]
        local cdir = lfg.ndirs[dir]
        kur.x = kur.x + cdir.x * kur.speed * dt
        kur.y = kur.y + cdir.y * kur.speed * dt
        if kur.cdir ~= dir then
            kur.cdir = dir
            kur:switch_animation(kur.cdir, kur.state)
        end
        self.world:update(kur.uuid, kur.x, kur.y)
        self.updates[kur.uuid] = kur:serialized()

        -- maybe shoot fireballs
        self.kur_fireball_timer = self.kur_fireball_timer + dt
        if self.kur_fireball_timer > self.kur_fireball_delay then
            self.kur_fireball_timer = self.kur_fireball_timer - self.kur_fireball_delay - math.random()
            local args = {
                spell_name = "Fireball",
                x = k_x,
                y = k_y,
                dx = n_dx,
                dy = n_dy,
                puid = kur.uuid,
                cdir = dir,
                spacing = 300,
            }
            local pjt = Projectile(args)
            self.projectiles[pjt.uuid] = pjt
            self.world:add(pjt.uuid, pjt.x, pjt.y, pjt.w, pjt.h)
            self:broadcast_event("created_projectile", pjt:serialized())

            -- fire second fireball
            local angle2 = angle + math.pi / 4
            local dx2, dy2 = lume.vector(angle2, distance)
            local n_dx2 = dx2 / distance
            local n_dy2 = dy2 / distance
            args.dx = n_dx2
            args.dy = n_dy2

            local pjt2 = Projectile(args)
            self.projectiles[pjt2.uuid] = pjt2
            self.world:add(pjt2.uuid, pjt2.x, pjt2.y, pjt2.w, pjt2.h)
            self:broadcast_event("created_projectile", pjt2:serialized())

            -- fire third fireball
            local angle3 = angle - math.pi / 4
            local dx3, dy3 = lume.vector(angle3, distance)
            local n_dx3 = dx3 / distance
            local n_dy3 = dy3 / distance
            args.dx = n_dx3
            args.dy = n_dy3

            local pjt3 = Projectile(args)
            self.projectiles[pjt3.uuid] = pjt3
            self.world:add(pjt3.uuid, pjt3.x, pjt3.y, pjt3.w, pjt3.h)
            self:broadcast_event("created_projectile", pjt3:serialized())
        end
    else
        -- pick random vector to use?
        -- or should we just stand still?
    end
end


return Server
