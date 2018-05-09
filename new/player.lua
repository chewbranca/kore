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


local function init(self, args)
    assert(args.character)

    --local clid = client.luuid
    local name = args.name or string.format("FOO: %s", clid)
    local char = lfg.get_character(args.character)
    local spell_name = args.spell or DEFAULT_SPELL_NAME
    local spell = lfg.get_spell(spell_name)
    local uuid = args.uuid or lume.uuid()
    local cdir = args.cdir or DEFAULT_DIR
    local state = args.state or DEFAULT_STATE
    local speed = args.speed or DEFAULT_SPEED

    local self = {
        name = name,
        char = char,
        spell = spell,
        --map_inputs = args.map_inputs or true,
        x = args.x or 250,
        y = args.y or 250,
        ox = args.ox or char.as.ox or 0,
        oy = args.oy or char.as.oy or 0,
        -- TODO: rectify width/height once dual worlds dichotomy resolved
        w = args.w or 1.0,
        h = args.h or 1.0,
        vx = args.vx or 200,
        vy = args.vy or 200,
        age = 0,
        --clid = clid,
        uuid = uuid,
        state = state,
        cdir = cdir,
        user_id = args.user_id,
        speed = speed,
    }
    setmetatable(self, Player)

    self:switch_animation(cdir, state)

    return self
end
setmetatable(Player, {__call = init})


function Player:switch_animation(dir, state)
    state = state or  DEFAULT_STATE
    self.am = self.char.ams[dir][state]
end


function Player:update_player(p, tick)
    if p.x  then self.x  = p.x end
    if p.y  then self.y  = p.y end
    if p.vx then self.vx = p.vx end
    if p.vy then self.vy = p.vy end

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
    self.am:draw(self.char.sprite, self.x, self.y, 0, 1, 1, self.ox, self.oy)
end


function Player:serialized()
    return {
        character = self.char.name,
        spell = self.spell.name,
        name = self.name,
        x = self.x,
        y = self.y,
        vx = self.vx,
        vy = self.vy,
        clid = self.clid,
        uuid = self.uuid,
        age = self.age,
        state = self.state,
        cdir = self.cdir,
    }
end


return Player

