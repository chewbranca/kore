-- TODO: move defaults to centralized location
local DEFAULT_SPEED = 200 -- duplicated from player.lua
local DEFAULT_PJT_SPEED = DEFAULT_SPEED * math.pi

local Projectile = {}
Projectile.__index = Projectile


local function init(_self, p)
    assert(p.spell_name)
    assert(p.cdir)
    assert(p.x)
    assert(p.y)
    assert(p.dx)
    assert(p.dy)
    assert(p.puid)

    local spell = lfg.get_spell(p.spell_name)
    local am = spell.ams[p.cdir].power
    local spacing = p.spacing or 10.0
    local uuid = p.uuid or lume.uuid()
    local speed = p.speed or spell.speed or DEFAULT_PJT_SPEED

    local self = {
        am = am,
        spell = spell,
        x = p.x + p.dx * spacing,
        y = p.y + p.dy * spacing,
        dx = p.dx,
        dy = p.dy,
        cdir = p.cdir,
        w = p.w or spell.w or 64,
        h = p.h or spell.h or 64,
        ox = p.ox or spell.ox or 0,
        oy = p.oy or spell.oy or 0,
        age = p.age or 0,
        max_age = p.max_age or 5.0,
        puid = p.puid,
        uuid = uuid,
        speed = speed,
        type = "projectile",
        collision = nil,
    }
    setmetatable(self, Projectile)

    return self
end
setmetatable(Projectile, {__call = init})


function Projectile:update(dt)
    self.age = self.age + dt

    self.am:update(dt)
end


function Projectile:draw()
    self.am:draw(self.spell.sprite, self.x, self.y, 0, 1, 1, self.ox, self.oy)
end


function Projectile:serialized()
    return {
        spell_name = self.spell.name,
        x = self.x,
        y = self.y,
        dx = self.dx,
        dy = self.dy,
        cdir = self.cdir,
        w = self.w,
        h = self.h,
        ox = self.ox,
        oy = self.oy,
        age = self.age,
        max_age = self.max_age,
        puid = self.puid,
        uuid = self.uuid,
        collision = self.collision,
    }
end


function Projectile:is_expired()
    return self.age >= self.max_age
end


function Projectile:tick(dt)
    self.age = self.age + dt
    local x = self.x + dt *self.dx * self.speed
    local y = self.y + dt *self.dy * self.speed
    return {x=x, y=y}
end


function Projectile:update_projectile(p)
    self.x = p.x
    self.y = p.y
    if p.collision then self.collision = p.collision end
end


return Projectile
