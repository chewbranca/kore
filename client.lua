local lume = require("lib.lume")
local sock = require("lib.sock")

local lfg = require("lfg")

local GamePlayer = require("player")
local Projectile = require("projectile")

local Client = {}
Client.__index = Client


local function init(_Client, host, port)
    assert(host, "Host is present")
    assert(port, "Port is present")
    log("STARTING CLIENT CONNECTION.")
    local client = sock.newClient(host, port)
    local players = {}
    local projectiles = {}
    local projectile_ams = {}
    local reqs = {}

    local pjt_col = assert(lfg.get_effect("Blast"))
    local pjt_col_type = "fire"
    local pjt_col_am = assert(pjt_col.ams[pjt_col_type]["power"])

    local self = setmetatable({
            client = client,
            players = players,
            projectiles = projectiles,
            projectile_ams = projectile_ams,
            pjt_col = pjt_col,
            pjt_col_type = pjt_col_type,
            pjt_col_am = pjt_col_am,
            reqs = reqs,
            last_tick = 0,
            curr_updates = {},
            user = nil,
        }, Client)

    client:on("connect", function(data)
        log("Successfully connected to server: (%s)", data)
    end)

    client:on("welcome", function(data)
        log("Uh oh... got eerie hello from server: %s", data.msg)
        client.clid = data.uuid
        self.uuid = data.uuid
    end)

    client:on("disconnect", function(data)
        log("[ERROR] DISCONNECTED: %s", data)
    end)

    client:on("announce_player", function(data)
        log("GOT PLAYER ANNOUNCE: %s", ppsl(data))
        local player = GamePlayer(data)
        -- TODO: remove lfg here and migrate insert elsewhere
        local layer = lfg.map.layers["KorePlayers"]
        players[data.clid] = player
        table.insert(layer.players, player)
    end)

    client:on("player_update", function(data)
        local player = self.players[data.clid]
        -- TODO: better handle case of local player
        -- issue being the local player isn't in players
        if (player) then
            player.x = data.x
            player.y = data.y
        end
    end)

    client:on("created_projectile", function(data)
        assert(data.uuid)
        local pjt = Projectile(data)

        local layer = lfg.map.layers["KoreProjectiles"]
        self.projectiles[data.uuid] = pjt
        layer.projectiles[data.uuid] = pjt
    end)

    client:on("create_player_nack", function(data)
        error(data.error)
    end)

    client:on("create_player_ack", function(data)
        log("GOT CREATE_PLAYER_ACK: %s -- %s", ppsl(data), ppsl(data.player))
        local req = reqs[data.req_id]
        if req then
            -- TODO: dedupe this logic with annouce_player
            local player = GamePlayer(data.player)
            req.user:bootstrap_player(player)
            -- TODO: remove lfg here and migrate insert elsewhere
            local layer = lfg.map.layers["KorePlayers"]
            self.players[self.uuid] = player
            self.players[player.uuid] = player
            table.insert(layer.players, player)
        else
            log("ERROR[client_player_ack]: UNKNOWN REQ: %s", ppsl(data))
        end
    end)

    client:on("server_tick", function(data)
        --log("GOT SERVER_TICK[%i]: %s", data.tick, ppsl(data))
        self.last_tick = data.tick
        self.curr_updates = data.updates
        -- TODO: better handle bootsrapping. We can see a tick before player announce
        -- which can result in none of the players existing
        for puid, update in pairs(data.updates) do
            if self.players[puid] then
                local player = assert(self.players[puid])
                player:update_player(update, data.tick)
            end
        end

        for uuid, spjt in pairs(data.pjt_data.projectiles) do
            local pjt = self.projectiles[uuid]
            if pjt then
                pjt:update_projectile(spjt)
            else
                pjt = self:created_projectile(spjt)
            end
        end
        local layer = lfg.map.layers["KoreProjectiles"]
        for uuid, _spjt in pairs(data.pjt_data.expired) do
            local pjt = self.projectiles[uuid]
            if pjt.collision == "projectile" then
                -- TODO: use animation's duration
                local am_uuid = lume.uuid()
                local payload = {
                    am = self.pjt_col_am:clone(),
                    am_uuid = am_uuid,
                    duration = 0.6,
                    x = pjt:screen_x(),
                    y = pjt:screen_y(),
                }
                self.projectile_ams[am_uuid] = payload
            end
            self.projectiles[uuid] = nil
            layer.projectiles[uuid] = nil
        end

        for puid, hit in pairs(data.hits) do
            if self.players[puid] then
                local player = assert(self.players[puid])
                player:get_hit(hit)
            end
        end
        for puid, _tval in pairs(data.disconnects) do
            if self.players[puid] then
                local layer = lfg.map.layers["KorePlayers"]
                -- TODO: switch player layer.players to use puid as key
                local index
                for i, player in ipairs(layer.players) do
                    if player.uuid == puid then index = i end
                end
                assert(index)
                table.remove(layer.players, index)
                self.players[puid] = nil
            -- else: disconnected player in last frame, never announced
            end
        end
        if self.user then
            local scores = {}
            for puid, score in pairs(data.scores) do
                local player = self.players[puid]
                if player then
                    table.insert(scores,
                        {puid=puid, score=score, name=player.name})
                end
            end
            table.sort(scores, function(a, b) return a.score > b.score end)
            self.user:update_scores(scores, data.tick)
            for _i, msg_data in pairs(data.messages) do
                self.user:print(msg_data.msg)
            end
        end
    end)

    client:on("announce_players", function(data)
        for puid, pobj in pairs(data.players) do
            local player = self.players[puid]
            if not player then
                player = GamePlayer(pobj)
                self.players[puid] = player
                -- TODO: remove lfg here and migrate insert elsewhere
                local layer = lfg.map.layers["KorePlayers"]
                table.insert(layer.players, player)
            end
            player:update_player(pobj, data.tick)
        end
    end)

    log("CONNECTING TO SERVER")
    client:connect()
    log("FINISHED CONNECTING TO SERVER")

    return self
end
setmetatable(Client, {__call = init})


function Client:update(dt)
    self.client:update(dt)
    local to_remove = {}
    for uuid, pjt_am in pairs(self.projectile_ams) do
        pjt_am.duration = pjt_am.duration - dt
        if pjt_am.duration < 0.0 then
            table.insert(to_remove, uuid)
        end
        pjt_am.am:update(dt)
    end
    for _i, uuid in ipairs(to_remove) do
        self.projectile_ams[uuid] = nil
    end
end


-- TODO: client draw hack for projectile collision effects
-- need a better place for the temporary animation objects to be stored
function Client:draw()
    for uuid, pjt_am in pairs(self.projectile_ams) do
        pjt_am.am:draw(self.pjt_col.sprite, pjt_am.x, pjt_am.y, 0, 0.5, 0.5, 0, 0)
    end
end


function Client:create_player(user, payload)
    -- TODO: find a better place to set this
    self.user = user

    --log("CREATING PLAYER: %s", ppsl(payload))
    local req_id = lume.uuid()
    local req = {
        action  = "create_player",
        req_id  = req_id,
        user_id = user.uuid,
        payload = payload,
    }
    self.client:send(req.action, req)
    self.reqs[req_id] = {user=user, req=req}
end


function Client:send_player_update(_user, updates)
    self.client:send("player_update", updates)
end


function Client:send_player_respawn(user)
    local payload = {
        user_id = user.uuid,
        puid = user:puid(),
        action = "respawn",
    }
    self.client:send("player_respawn_request", payload)
end


function Client:create_projectile(m_info)
    self.client:send("create_projectile", m_info)
end


function Client:send_msg(msg)
    local payload = {msg=msg, clid=self.client.clid}
    self.client:send("send_msg", payload)
end


function Client:created_projectile(data, skip_world)
    assert(data.uuid)
    local pjt = Projectile(data)

    if not skip_world then
        local layer = lfg.map.layers["KoreProjectiles"]
        self.projectiles[data.uuid] = pjt
        layer.projectiles[data.uuid] = pjt

        self.projectiles[pjt.uuid] = pjt
    end

    return pjt
end


return Client

