local lume = require("lib.lume")

local STATES = {
    run = "run",
    stand = "stance",
    swing = "swing",
    cast = "cast",
    dead = "die",
    hit = "hit",
}

local DEFAULT_DIR         = "D_S"
local DEFAULT_SPEED       = 400
local DEFAULT_SPELL_NAME  = "Fireball"
local DEFAULT_STATE       = STATES.stand

local RESPAWN_TIMER       = 7.0
local DEFAULT_HP          = 5

local Player = {}
Player.__index = Player

Player.STATES = STATES


local function init(_self, args)
    assert(args.character)
    assert(args.x)
    assert(args.y)

    local char = lfg.get_character(args.character)
    local spell_name = args.spell_name or DEFAULT_SPELL_NAME
    local spell = lfg.get_spell(spell_name)
    local uuid = args.uuid or lume.uuid()
    local name = args.name or string.format("FOO: %s", uuid)
    local cdir = args.cdir or DEFAULT_DIR
    local state = args.state or DEFAULT_STATE
    local speed = args.speed or DEFAULT_SPEED

    local self = {
        name = name,
        char = char,
        spell = spell,
        hp = args.hp or args.starting_hp or DEFAULT_HP,
        starting_hp = args.starting_hp or DEFAULT_HP,
        x = args.x,
        y = args.y,
        ox = args.ox or spell.as.ox or 0,
        oy = args.oy or spell.as.oy or 0,
        sx = args.sx or 1,
        sy = args.sy or 1,
        -- TODO: rectify width/height once dual worlds dichotomy resolved
        --w = args.w or char.as.w or 64,
        --h = args.h or char.as.h or 32,
        -- set player box to 64x32
        w = args.w or 64,
        h = args.h or 32,
        vx = args.vx or 200,
        vy = args.vy or 200,
        age = 0,
        uuid = uuid,
        state = state,
        cdir = cdir,
        user_id = args.user_id,
        speed = speed,
        am_timer = 0.0,
        respawn_timer = 0.0,
        respawn_loc = nil,
        type = "player",
    }
    setmetatable(self, Player)
    self.last_x, self.last_y = self.x, self.y

    self:switch_animation(cdir, state)

    return self
end
setmetatable(Player, {__call = init})


function Player:switch_animation(dir, state)
    state = state or self.state
    self.am = self.char.ams[dir][state]
end


function Player:is_dead() return self.hp <= 0 end


function Player:hit()
    self.hp = self.hp - 1
    if self:is_dead() then
        self.state = STATES.dead
        self:switch_animation(self.cdir, self.state)
    else
        self.state = STATES.hit
        self:switch_animation(self.cdir, self.state)
    end
    return {
        hp = self.hp,
        state = self.state,
        type = "hit",
    }
end


function Player:kill(respawn_loc)
    self.hp = 0
    self.state = STATES.dead
    self.respawn_loc = assert(respawn_loc)
    assert(self:is_dead())
    return {
        hp = self.hp,
        state = self.state,
        type = "hit",
        respawn_loc = respawn_loc,
    }
end


function Player:get_hit(action)
    assert(action.type == "hit")
    if action.hp then self.hp = action.hp end
    if action.state then
        self.state = action.state
        self:switch_animation(self.cdir, self.state)
    end
    if self:is_dead() and action.respawn_loc then
        self.respawn_loc = action.respawn_loc
    end
end


function Player:update_player(p, _tick)
    if p.x  then self.x  = p.x end
    if p.y  then self.y  = p.y end
    if p.vx then self.vx = p.vx end
    if p.vy then self.vy = p.vy end

    -- TODO: better handle compound state/dir updates
    -- also do proper transitions, where animations can be delayed
    if p.state then
        self.state = p.state
    elseif not p.state and not (p.x or p.y) then
        if self.state ~= STATES.stand then
            self.state = STATES.stand
            self:switch_animation(self.cdir, self.state)
        end
    end

    if p.cdir and p.cdir ~= self.cdir then
        self:switch_animation(p.cdir)
        self.cdir = p.cdir
    end
end


function Player:update(dt)
    if self:is_dead() then
        if self.state ~= STATES.dead then
            self.state = STATES.dead
            self:switch_animation(self.cdir, self.state)
        end

        self.respawn_timer = self.respawn_timer + dt
        if self.respawn_timer > RESPAWN_TIMER then
            self:respawn()
        end

        -- TODO: why is onLoop not doing this for us?
        --self.am:update(dt)
        self.am:pauseAtEnd()
    else
        -- TODO: replace timer with event based approach
        local AM_TIMEOUT = 0.5
        self.am_timer = self.am_timer + dt
        if self.am_timer > AM_TIMEOUT then
            self.am_timer = self.am_timer - AM_TIMEOUT
            if self.x == self.last_x and self.y == self.last_y then
                if self.state ~= STATES.stand then
                    self.state = STATES.stand
                    self:switch_animation(self.cdir, self.state)
                end
            else
                self.last_x, self.last_y = self.x, self.y
            end
        end

        self.age = self.age + dt

        self.am:update(dt)
    end
end


function Player:draw()
    love.graphics.push()
    do
        local max_bar_width = 100
        local bar_width = (self.hp / self.starting_hp) * max_bar_width
        love.graphics.setColor(255, 0, 0)
        love.graphics.rectangle("fill", self.x, self.y - 45, bar_width, 10)
        love.graphics.print(self.name, self.x + 10, self.y - 60)
    end
    love.graphics.pop()
    love.graphics.setColor(255, 255, 255)
    self.am:draw(self.char.sprite, self.x, self.y, 0, self.sx, self.sy, self.ox, self.oy)
end


function Player:serialized()
    return {
        character = self.char.name,
        spell_name = self.spell.name,
        name = self.name,
        x = self.x,
        y = self.y,
        sx = self.sx,
        sy = self.sy,
        vx = self.vx,
        vy = self.vy,
        clid = self.clid,
        uuid = self.uuid,
        age = self.age,
        state = self.state,
        cdir = self.cdir,
        hp = self.hp,
        starting_hp = self.starting_hp,
        respawn_loc = self.respawn_loc,
    }
end


function Player:respawn()
    self.hp = self.starting_hp
    if self.respawn_loc then
        self.x = assert(self.respawn_loc.x)
        self.y = assert(self.respawn_loc.y)
        self.respawn_loc = nil
    end
    self.respawn_timer = 0
    self.state = STATES.stand
    self:switch_animation(self.cdir, self.state)
end


function Player:full_name()
    if self.type == "Kur" then
        return "Kur"
    else
        return string.format("%s<%s>", self.name, self.uuid)
    end
end


return Player

