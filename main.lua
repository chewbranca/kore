
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

local client, layer, map, player, server

local is_user_bootstrapped = false


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

    local player_layer = lfg.map:addCustomLayer("KorePlayers", #lfg.map.layers + 1)
    player_layer.players = {}
    player_layer.update = function(self, dt)
        for _i, p in ipairs(self.players) do p:update(dt) end
    end
    player_layer.draw = function(self)
        for _i, p in ipairs(self.players) do p:draw() end
    end

    local pjt_layer = lfg.map:addCustomLayer("KoreProjectiles", #lfg.map.layers + 1)
    pjt_layer.players = {}
    pjt_layer.update = function(self, dt)
        for i, pjt in ipairs(self.players) do
            pjt:update(dt)
        end
    end
    pjt_layer.draw = function(self)
        for i, pjt in ipairs(self.players) do
            pjt:draw()
        end
    end

    if pargs.server then server = GameServer(pargs.port) end
    if pargs.client then
        client = GameClient(pargs.host, pargs.port)
        if pargs.user then
            local payload = {
                character = pargs.character,
                spell = pargs.spell,
                name = pargs.name
            }
            user = GameUser(payload)
        end
    end
end


local ready_for_user = false
function love.update(dt)
    if server then server:update(dt) end
    if client then client:update(dt) end
    if user then
        if not is_user_bootstrapped then
            -- FIXME: DIRTY HACKS
            -- need a full {client,server}:update(dt) cycle before this works
            -- otherwise the create_player message gets lost
            -- TODO: fix this or make this not terrible
            if ready_for_user then
                is_user_bootstrapped = user:bootstrap(client)
            else
                ready_for_user = true
            end
        else
            user:update(dt)
        end
    end

    map:update(dt)
end


function love.draw()
    local px = player and player.x or 0
    local py = player and player.y or 0
    local tx = math.max(0, math.floor(px - love.graphics.getWidth() / 2))
    local ty = math.max(0, math.floor(py - love.graphics.getHeight() / 2))

    love.graphics.push()
    do
        lfg.map:draw(-tx, -ty)
        -- TODO: why is this still drawing on a rectangle grid?
        --lfg.map:bump_draw(lfg.world, -tx, -ty)
        love.graphics.translate(-tx, -ty)
        if (lfg.player) then
            love.graphics.points(math.floor(px), math.floor(py))
            love.graphics.rectangle("line", lfg.player.x - lfg.player.ox, lfg.player.y - lfg.player.oy, 128, 128)
        end
    end
    love.graphics.pop()

    -- TODO: move debug stats to User module
    love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)
    --if lfg.player then
    --if user then
    --    local tl_x, tl_y = lfg.map:convertPixelToTile(lfg.player.x, lfg.player.y)
    --    love.graphics.print(string.format("Current Pos: (%.2f, %.2f) <%.2f, %.2f>", lfg.player.x, lfg.player.y, tl_x, tl_y), 10, 30)
    --    love.graphics.print(string.format("Mouse Pos:   (%.2f, %.2f)", lfg.mouse.x, lfg.mouse.y), 10, 50)
    --    local deg = (math.deg(lfg.mouse.angle) + 360) % 360
    --    love.graphics.print(string.format("Angle[%.2f]: %.2f {%.2f} {[%i]}", lfg.mouse.distance, lfg.mouse.angle, math.deg(lfg.mouse.angle), deg), 10, 70)
    --end
end

