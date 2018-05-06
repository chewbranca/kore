local bump = require("bump")
local lume = require("lume")
local sock = require("sock")

local lfg = require("lfg")

local debug = true

local Server = {}
Server.__index = Server

Server.PORT = 34227

local function log_client_connected(uuid, data, client)
    if debug then
        lfg.log("\n***CLIENT CONNECTED[%s]:\n\tDATA: %s\n\tCLIENT: %s\n\t",
            uuid, lfg.ppsl(data), lfg.ppsl(client))
    end
end


local function init(port)
    port = port or Server.PORT
    local server = sock.newServer("*", port)
    local world = bump.newWorld(1)

    local self = setmetatable({
            clients = {},
            players = {},
            projectiles = {},
            server = server,
            world = world
        }, Server)

    sever.on("connect", function(data, client)
        local uuid = lume.uuid()
        local msg = "welcome to your doom"

        client["luuid"] = uuid
        clients[uuid] = client
        logClientConnected(uuid, data, client)

        client:send("welcome", {msg=msg, uuid=uuid})
    end)

    --server.on("attack_melee", function(data, client)
    --    lfg.log("MELEE ATTACK FROM CLIENT[%s]: %s", client.luuid, ppsl(data))
    --    self:broadcast_event("attack_melee" data)
    --end)

    --server.on("attack_spell", function(data, client)
    --    lfg.log("SPELL ATTACK FROM CLIENT[%s]: %s", client.luuid, ppsl(data))
    --    self:broadcast_event("attack_melee" data)
    --end)

    server.on("announce_self", function(data, client)
        local ent = Entity(data)
        local layer = lfg.map.layers["KoreEntitie"]
        self.players[client.luuid] = ent
        self.world:add(ent.clid, ent.x, ent.y, ent.w, ent.h)
        self:announce_player(client, data)
        self:announce_players(client)
    end)

    server:on("send_player_state", function(data, client)
        local player = self.players[client.luuid]
        -- TODO: switch to world:move(...)
        player.x = data.x
        player.y = data.y
        self:broadcast_event("player_update", player:serialize())
    end)

    server:on("new_projectile", function(data, client)
        local pjt = Projectile(data)
        self.projectiles[pjt.uuid] = pjt
        lfg.log("CREATING NEW PROJECTILE WITH: %s", ppsl(data))
        world:add(pjt.uuid, pjt.x, pjt.y, pjt.w, pjt.h)
        self:broadcast_event("new_projectile", pjt:serialize())
    end)

    return self
end
setmetatable(Server, {__call = init})


function Server:broadcast_event(clients, etype, data)
    for uuid, client in pairs(clients) do
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
        client:send("announce_player", player:serialize())
    end
end


function Server:broastcast_projectiles()
    -- TODO: what to do about serializeAll()? Where to put it?
    local serialized = self.projectiles:serializeAll()
    if #serialized > 0 then
        for uuid, client in pairs(self.clients) do
            client:send("update_projectiles", serialized)
        end
    end
end

return Server
