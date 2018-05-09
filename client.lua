local lume = require("lib.lume")
local sock = require("lib.sock")

local lfg = require("lfg")

local GamePlayer = require("player")

local debug = true

local Client = {}
Client.__index = Client


local function init(_Client, host, port)
    assert(host, "Host is present")
    assert(port, "Port is present")
    log("STARTING CLIENT CONNECTION.")
    local client = sock.newClient(host, port)
    local players = {}
    local projectiles = {}
    local reqs = {}

    local self = setmetatable({
            client = client,
            players = players,
            projectiles = projectiles,
            reqs = reqs,
            last_tick = 0,
            curr_updates = {},
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

    client:on("attack_melee", function(data)
        -- TODO: add client attack
        log("GOT ATTACK_MELEE: %s", ppsl(data))
    end)

    client:on("attack_spell", function(data)
        -- TODO: add client attack
        log("GOT ATTACK_MELEE: %s", ppsl(data))
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

    client:on("new_projectile", function(data)
        local pjt = Projectile(data)
        local layer = lfg.map.layers["KoreProjectiles"]
        players[data.uuid] = pjt
        Projectile.add_projectile(layer, pjt, true)
    end)

    client:on("update_projectiles", function(data)
        for i, spjt in ipairs(data) do
            local pjt = self.projectiles[spjt.uuid]
            if pjt then
                pjt.x = spjt.x
                pjt.y = spjt.y
            else
                log("[ERROR] UPDATE_PROJECTILES MISSING PJT FOR %s", spjt.uuid)
            end
        end
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
        for puid, update in pairs(data.updates) do
            local player = assert(self.players[puid])
            player:update_player(update, tick)
        end
    end)

    log("CONNECTING TO SERVER")
    client:connect()
    log("FINISHED CONNECTING TO SERVER")

    return self
end
setmetatable(Client, {__call = init})


function Client:update(dt)
    self.client:update()
end


function Client:create_player(user, payload)
    log("CREATING PLAYER: %s", ppsl(payload))
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


function Client:send_player_update(user, updates)
    self.client:send("player_update", updates)
end


return Client

