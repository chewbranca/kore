local lume = require("lume")

local STATES = {
    run = "run",
    stand = "stance",
    swing = "swing",
    cast = "cast",
}

local DEFAULT_DIR         = "D_S"
local DEFAULT_SPEED       = 200
local DEFAULT_SPELL_NAME  = "Fireball"
local DEFAULT_STATE       = STATES.stand

local Player = {}
Player.__index = Player

local function init(args)
    --assert(args.client)
    assert(args.character)

    --local clid = client.luuid
    local name = args.name or string.format("FOO: %s", clid)
    local char = lfg.get_character(args.character)
    local spell_name = args.spell or DEFAULT_SPELL_NAME
    local spell = lfg.get_spell(spell_name)
    local uuid = lume.uuid()
    local cdir = args.cdir or DEFAULT_DIR
    local state = args.state or DEFAULT_STATE

    local self = {
        name = name,
        char = char,
        spell = spell,
        --map_inputs = args.map_inputs or true,
        x = args.x or 25,
        y = args.y or 25,
        vx = args.vx or 200,
        vy = args.vy or 200,
        age = 0,
        --clid = clid,
        uuid = uuid,
        state = state,
        cdir = cdir,
    }
    setmetatable(self, Server)

    self:switch_animation(cdir, state)

    return self
end
setmetatable(Player, {__call = init})


function self:switch_animation(dir, state)
    state = state or  DEFAULT_STATE
    self.am = self.char.ams[dir][state]
end


function Player:update_player(p)
    if p.x  then self.x  = self.x end
    if p.y  then self.y  = self.y end
    if p.vx then self.vx = self.vx end
    if p.vy then self.vy = self.vy end

    -- TODO: better handle compound state/dir updates
    -- also do proper transitions, where animations can be delayed
    if p.state then self.state = p.state end
    if p.cdir and p.cdir ~= self.cdir then
        self:switch_animation(p.cdir)
        self.cdir = p.cdir
    end
end


function Player:update(dt)
    self.age = self.age + dt

    self.am:update(dt)
end

function Player:draw()
end

