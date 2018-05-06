local lume = require("lume")
local sock = require("sock")

local lfg = require("lfg")

local debug = true

local C = {}
Client.__index = C


local function init(host, port, bootstrap)
    assert(host, "Host is present")
    assert(port, "Port is present")
    log("STARTING CLIENT CONNECTION")
    local client = sock.newClient(host, port)
    local players = {}
    local projectiles = {}

    local self = setmetatable({
            client = client,
            players = players,
            projectiles = projectiles
        })

    client:on("connect", function(data)
        log("Successfully connected to server: (%s)" data)
    end)

    client:on("welcome", function(data)
        (log "Uh oh... got eerie hello from server: %s" data.msg)
        client.luuid = data.uuid
        self.uuid = data.uuid
        -- Bootstrap client if provided
        if bootstrap then bootstrap(self) end
    end)

    client:on("disconnect", function(data)
        log("[ERROR] DISCONNECTED: %s" data)
    end)

    client:on("attack_melee", function(data)
        -- TODO: add client attack
        log("GOT ATTACK_MELEE: %s" ppsl(data))
    end)

    client:on("attack_spell", function(data)
        -- TODO: add client attack
        log("GOT ATTACK_MELEE: %s" ppsl(data))
    end)

    client:on("announce_player", function(data)
        log("GOT PLAYER ANNOUNCE: %s", ppsl(data))
        local player = Player(data)
        local layer = lfg.map.layers["KorePlayers"]
        players[data.clid] = player
        -- TODO: remove lfg here and migrate insert elsewhere
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
        for i, spjt ipairs(data) do
            local pjt = self.projectiles[spjt.uuid]
            if pjt then
                pjt.x = spjt.x
                pjt.y = spjt.y
            else
                log("[ERROR] UPDATE_PROJECTILES MISSING PJT FOR %s", spjt.uuid)
            end
        end
    end)

    client:connect()

    return self
end
setmetatable(C, {__call = init})




