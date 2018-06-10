
local argparse = require("lib.argparse")
local repl = require("lib.repl")

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
local Powerup = require("powerup")

local client, map, server, world

local is_user_bootstrapped = false

-- HACK: set global Kore table for use from repl
GKORE = {}


local function parse_args()
    local parser = argparse("kore", "Kore - The Rise of Persephone")
    parser:argument("dir", "App dir")
    parser:flag("--server", "Host a server")
    parser:flag("--no-client", "Do not connect to host?")
    parser:flag("--no-user", "Are you not a user?")
    parser:flag("--no-kur", "Scared of Kur?")
    parser:flag("--headless", "Headless mode")
    parser:option("--host", "Server host to connect to", nil)
    parser:option("--port", "Server port to connect to", GameServer.PORT)
    parser:option("--character", "What character to use; one of [Minotaur, Zombie, Skeleton, Goblin, Antlion", nil)
    parser:option("--spell", "What spell to use; one of [Fireball, Lightning, Channel, Icicle", nil)
    parser:option("--name", "Are you really a user?", string.format("FOO{%s}", lume.uuid()))
    parser:option("--map", "Map file to use", "map_arena3.lua")

    return parser:parse()
end

local user

function love.load()
    log("LOADING KORE")

    local pargs = parse_args()
    log("GOT PARSED ARGS: %s", ppsl(pargs))
    local host = (pargs.host or (pargs.server and "localhost") or
            "kore.chewbranca.com")

    assert(lfg.init({map_file=pargs.map}, pargs))
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
        for _i, pjt in ipairs(self.projectiles) do pjt:update(dt) end
    end
    pjt_layer.draw = function(self)
        for _uuid, pjt in pairs(self.projectiles) do pjt:draw() end
    end

    local pup_layer = lfg.map:addCustomLayer("KorePowerups", #lfg.map.layers + 1)
    pup_layer.powerups = {}
    pup_layer.update = function(self, dt)
        for _i, pup in pairs(self.powerups) do pup:update(dt) end
    end
    pup_layer.draw = function(self)
        for _uuid, pup in pairs(self.powerups) do pup:draw() end
    end

    if pargs.server and lfg.map.layers["health-pots"] then
        for _, obj in pairs(lfg.map.layers["health-pots"].objects) do
            local tl_x, tl_y = obj.x / 32, obj.y / 32
            local x, y = lfg.map:convertTileToPixel(tl_x, tl_y)
            local pup_type = Powerup.health_pot_name
            local pup = Powerup({x=x, y=y, powerup_type=pup_type})
            pup_layer.powerups[pup.uuid] = pup
        end
    end

    if pargs.server then
        repl.start()
        server = GameServer({
            port = pargs.port,
            map = map,
            world = world,
            kur = not pargs.no_kur,
        })
        GKORE.server = server
    end
    if not pargs.no_client then
        client = GameClient(host, pargs.port)
        if not pargs.no_user then
            local payload = {
                character = pargs.character,
                spell_name = pargs.spell,
                name = pargs.name
            }
            user = GameUser(payload)
        end
        GKORE.client = client
        GKORE.user = user
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

            if (user and user.debug) then
                love.graphics.setColor(255, 0, 0)
                map:bump_draw(world, -tx, -ty, 1, 1)
                love.graphics.setColor(255, 255, 255)
            end

            love.graphics.translate(-tx, -ty)
            if (user and user.debug) then
                love.graphics.points(math.floor(px), math.floor(py))
                love.graphics.rectangle("line", user:x() - user:ox(), user:y() - user:oy(), 128, 128)
            end
            client:draw()
        end
        love.graphics.pop()

        love.graphics.setColor(255, 255, 255)
        user:draw()

        -- TODO: remove need for client:draw hackery
        --client:draw()
    end
end


function love.mousepressed(...)
  if user then user:mousepressed(...) end
end


function love.keypressed(...)
    if user then user:keypressed(...) end
end

function love.textinput(...)
   if user then user:textinput(...) end
end
