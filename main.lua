
local argparse = require("lib.argparse")
local serpent = require("lib.serpent")

lume = require("lib.lume")

-- TODO: find a good spot for this
-- require "strict"

local pps = function(x)
   return require("lib.serpent").block(x, {maxlevel=8,maxnum=64,
                                       nocode=true,comment=false})
end

ppsl = function(x) return require("lib.serpent").line(x) end
pp = function(x) print(pps(x)) end
ppl = function(x) print(ppsl(x)) end
log = function(...) print(string.format(...)) end

lfg = require("lfg")

local GameClient = require("client")
local GameServer = require("server")
local GameUser = require("user")

local client, layer, map, player, server, world

local is_user_bootstrapped = false
local dev_mode = false


local function parse_args()
    local parser = argparse("kore", "Kore - The Rise of Persephone")
    parser:argument("dir", "App dir")
    parser:flag("--server", "Host a server")
    parser:flag("--client", "Connect to host")
    parser:flag("--user", "Are you a user?")
    parser:option("--host", "Server host to connect to", "localhost")
    parser:option("--port", "Server port to connect to", GameServer.PORT)
    parser:option("--character", "What character to use; one of [Minotaur, Zombie, Skeleton", "Minotaur")
    parser:option("--spell", "What spell to use; one of [Fireball, Lightning, Channel", "Fireball")
    parser:option("--name", "Are you really a user?", string.format("FOO{%s}", lume.uuid()))

    return parser:parse()
end


function love.load(args)
    log("LOADING KORE")

    local pargs = parse_args()
    log("GOT PARSED ARGS: %s", ppsl(pargs))

    assert(lfg.init({map_file="map_lfg_demo.lua"}, pargs))
    map = lfg.map
    world = lfg.world

    local player_layer = lfg.map:addCustomLayer("KorePlayers", #lfg.map.layers + 1)
    player_layer.players = {}
    player_layer.update = function(self, dt)
        for _i, p in ipairs(self.players) do p:update(dt) end
    end
    player_layer.draw = function(self)
        for _i, p in ipairs(self.players) do p:draw() end
    end

    local pjt_layer = lfg.map:addCustomLayer("KoreProjectiles", #lfg.map.layers + 1)
    pjt_layer.projectiles = {}
    pjt_layer.update = function(self, dt)
        for i, pjt in ipairs(self.projectiles) do pjt:update(dt) end
    end
    pjt_layer.draw = function(self)
        for uuid, pjt in pairs(self.projectiles) do pjt:draw() end
    end

    if pargs.server then server = GameServer(pargs.port, map, world) end
    if pargs.client then
        client = GameClient(pargs.host, pargs.port)
        if pargs.user then
            local payload = {
                character = pargs.character,
                spell_name = pargs.spell,
                name = pargs.name
            }
            user = GameUser(payload)
        end
    end
end


local connect_delay = 3.0
function love.update(dt)
    if server then server:update(dt) end
    if client then client:update(dt) end
    if user then
        if not is_user_bootstrapped then
            -- FIXME: DIRTY HACKS
            -- need a full {client,server}:update(dt) cycle before this works
            -- otherwise the create_player message gets lost
            -- TODO: fix this or make this not terrible
            if connect_delay <= 0.0 then
                is_user_bootstrapped = user:bootstrap(client)
            else
                connect_delay = connect_delay - dt
            end
        else
            user:update(dt)
        end
    end

    map:update(dt)
end


function love.draw()
    if user and is_user_bootstrapped then
        local px = user and user:x() or 0
        local py = user and user:y() or 0
        local tx = math.max(0, math.floor(px - love.graphics.getWidth() / 2))
        local ty = math.max(0, math.floor(py - love.graphics.getHeight() / 2))

        love.graphics.push()
        do
            love.graphics.setColor(255, 255, 255)
            map:draw(-tx, -ty)
            --love.graphics.setColor(255, 0, 0)
            --map:bump_draw(world, -tx, -ty, 1, 1)
            love.graphics.translate(-tx, -ty)
            if (user and dev_mode) then
                love.graphics.points(math.floor(px), math.floor(py))
                love.graphics.rectangle("line", user:x() - user:ox(), user:y() - user:oy(), 128, 128)
            end
        end
        love.graphics.pop()

        love.graphics.push()
        do
            -- TODO: why is this still drawing on a rectangle grid?
            -- TODO: where should this go? why not in the upper block?
            love.graphics.setColor(255, 0, 0)
            map:bump_draw(world, -tx, -ty, 1, 1)
        end
        love.graphics.pop()

        love.graphics.setColor(255, 255, 255)
        user:draw()
    end
end


function love.mousepressed(...)
  if user then user:mousepressed(...) end
end

