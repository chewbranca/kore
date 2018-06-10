local Powerup = {}
Powerup.__index = Powerup
Powerup.health_pot = {}
Powerup.health_pot_name = "Health Pot"


Powerup.pup_types = {
    ["Health Pot"] = Powerup.health_pot,
}


local function init(_self, args)
    local pup_type = args.powerup_type

    assert(pup_type)
    assert(Powerup.pup_types[pup_type])
    assert(args.x)
    assert(args.y)

    local powerup = assert(lfg.get_powerup(pup_type))

    local self = {
        type = "powerup",
        alive = args.alive or false,
        pup_type = args.powerup_type,
        powerup = powerup,
        am = assert(powerup.ams["uno"]["power"]),
        x = args.x,
        y = args.y,
        ox = args.ox or powerup.as.ox or 0,
        oy = args.oy or powerup.as.oy or 0,
        sx = args.sx or 1.3,
        sy = args.sy or 1.3,
        w = args.w or 96,
        h = args.h or 96,
        uuid = args.uuid or lume.uuid(),
    }
    setmetatable(self, Powerup)
    return self
end
setmetatable(Powerup, {__call = init})


function Powerup:is_alive()
    return self.alive
end


function Powerup:make_alive() self.alive = true end
function Powerup:make_dead()  self.alive = false end


function Powerup:acquire(player)
    if self:is_alive() then
        self:make_dead()
        player:inc_hp(self)
        return true
    else
        return false
    end
end


function Powerup:update(dt)
    if self:is_alive() then
        -- TODO: how to change animation duration so we can use real dt?
        self.am:update(dt/7)
    end
end


function Powerup:update_powerup(p, _tick)
    if p.alive ~= nil then self.alive = p.alive end
end


function Powerup:draw()
    if self:is_alive() then
        self.am:draw(self.powerup.sprite, self.x, self.y, 0, self.sx, self.sy, self.ox, self.oy)
    end
end


function Powerup:serialized()
    return {
        type = self.type,
        alive = self.alive,
        powerup_type = self.pup_type,
        x = self.x,
        y = self.y,
        ox = self.ox,
        oy = self.oy,
        sx = self.sx,
        sy = self.sy,
        w = self.w,
        h = self.h,
        uuid = self.uuid,
    }
end


return Powerup

