local User = {}
User.__index = User

function init(self, payload)
    local m0_x, m0_y = 0, 0
    local m_x, m_y = love.mouse.getPosition()
    local angle = lume.angle(m0_x, m0_y, m_x, m_y)
    local distance = lume.distance(m0_x, m0_y, m_x, m_y)
    local dx, dy = lume.vector(angle, distance)

    local uuid = lume.uuid()

    local d_width, d_height = love.window.getDesktopDimensions()
    local w_width, w_height = love.graphics.getDimensions()

    local self = {
        debug = false,
        fullscreen = false,
        m_x = m_x,
        m_y = m_y,
        m_dx = dx,
        m_dy = dy,
        m_angle = angle,
        m_distance = distance,
        uuid = uuid,
        is_bootstrapped = false,
        client = nil,
        payload = payload,
        player = nil,
        d_width = d_width,
        d_height = d_height,
        w_width = w_width,
        w_height = w_height,
    }
    setmetatable(self, User)

    return self
end
setmetatable(User, {__call = init})


function User:update(dt)
    if self.player:is_dead() then return false end

    local updates = {}
    local dir = lfg.get_key_dir() -- FIXME: migrate logic to this module
    local m0_x, m0_y = self.m_x, self.m_y
    local m_x, m_y = love.mouse.getPosition()

    if dir and dir ~= self.cdir then
        self.cdir = cdir
        updates.cdir = lfg.ndirs[dir]
        -- TODO: guarantee self.player is set
        updates.state = self.player.STATES.run
    end

    if m0_x ~= m_x or m0_y ~= m_y then
        local angle = lume.angle(m0_x, m0_y, m_x, m_y)
        local distance = lume.distance(m0_x, m0_y, m_x, m_y)
        local dx, dy = lume.vector(angle, distance)
        -- TODO: should we send mouse movement to server?
        -- at the very least need to use mouse dir to send dir player facing
        --updated = true
        --updates.m_x, updates.m_y = m_x, m_y
        --updates.m_dx, updates.m_dy = dx, dy
        -- TODO: move this into self.mouse = {...} ?
        self.m_x = m_x
        self.m_y = m_y
        self.m_dx = dx
        self.m_dy = dy
        self.m_angle = angle
        self.m_distance = distance
    end

    -- send player movement
    if next(updates) ~= nil then
        self.client:send_player_update(self, updates)
    end

    -- send projectiles
    if self.mouse_updates then
        for button, m_info in pairs(self.mouse_updates) do
            -- TODO: reenable melee attacks
            -- however, one button mouse works well for trackpads
            if false and button == "1" then
                self.client:melee_attack(button, m_info)
            elseif button == "1" or button == "2" then
                m_info.spell_name = self.player.spell.name
                self.client:create_projectile(m_info)
            end
        end
        self.mouse_updates = {}
    end
end


function User:draw()
    -- TODO: draw game UI
    -- TODO: enable FPS and stats logic:
    -- TODO: add bandwith numbers
    -- TODO: add ping time
    -- TODO: add server tps
    -- TODO: add object stats for players/projectiles/collidables/etc
    -- TODO: add toggle button for displaying these stats
    if self.debug then
        love.graphics.print("Current FPS: "..tostring(love.timer.getFPS()), 10, 10)
        local tl_x, tl_y = lfg.map:convertPixelToTile(self:x(), self:y())
        love.graphics.print(string.format("Current Pos: (%.2f, %.2f) <%.2f, %.2f>", self:x(), self:y(), tl_x, tl_y), 10, 30)
        love.graphics.print(string.format("Mouse Pos:   (%.2f, %.2f)", self.m_x, self.m_y), 10, 50)
        local deg = (math.deg(self.m_angle) + 360) % 360
        love.graphics.print(string.format("Angle[%.2f]: %.2f {%.2f} {[%i]}", self.m_distance, self.m_angle, math.deg(self.m_angle), deg), 10, 70)
    end

    if self.player:is_dead() then
        -- TODO: properly fetch the respawn value timer
        love.graphics.print(string.format("YOU HAVE DIED!!! Respawning in %i...", 7 - self.player.respawn_timer), 500, 500)
    end
end


function User:bootstrap_player(player)
    assert(player)
    self.player = player
    self.is_bootstrapped = true
end


function User:bootstrap(client)
    log("BOOTSTRAPPING USER[%s]{%s}: %s", self.uuid, self.client, self.is_bootstrapped)
    if not self.client then
        self.client = client
        client:create_player(self, self.payload)
    end

    return self.is_bootstrapped
end


function User:mousepressed(m_x, m_y, button)
    button = tostring(button)
    if not self.mouse_updates then self.mouse_updates = {} end

    local w_x = math.floor(love.graphics.getWidth() / 2)
    local w_y = math.floor(love.graphics.getHeight() / 2)
    local angle = lume.angle(w_x, w_y, m_x, m_y)
    local distance = lume.distance(w_x, w_y, m_x, m_y)
    local dx, dy = lume.vector(angle, distance)
    local n_dx = dx / distance
    local n_dy = dy / distance
    local dir = lfg.ndirs[lfg.angle_to_dir(angle)]

    -- last update wins
    self.mouse_updates[button] = {
        x = self:x(),
        y = self:y(),
        dx = n_dx,
        dy = n_dy,
        w_x = w_x,
        w_y = w_y,
        angle = angle,
        distance = distance,
        cdir = dir,
        puid = self:puid(),
    }
end


function User:keypressed(key, scancode, isrepeat)
    if isrepeat then return false end

    if scancode == "f1" then self.debug = not self.debug end

    if scancode == "f2" then
        self.fullscreen = not self.fullscreen
        local fst = {fullscreen=self.fullscreen, fullscreentype="desktop"}
        --love.window.setFullscreen(self.fullscreen, "desktop")
        if self.fullscreen then
            love.window.setMode(self.d_width, self.d_height, fst)
        else
            love.window.setMode(self.w_width, self.w_height, fst)
        end
    end
end


function User:x() return self.player.x end
function User:y() return self.player.y end
function User:ox() return self.player.ox end
function User:oy() return self.player.oy end
function User:w() return self.player.w end
function User:h() return self.player.h end
function User:cdir() return self.player.cdir end
function User:puid() return self.player.uuid end


return User

