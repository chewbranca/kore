local User = {}
User.__index = User

function init(client, payload)
    local m_x, m_y = love.mouse.getPosition()
    local uuid = lume.uuid()

    local self = {
        m_x = m_x,
        m_y = m_y,
        uuid = uuid,
        is_bootstrapped = false,
        client = nil,
        payload = payload,
        player = nil
    }
    setmetatable(self, User)

    return self
end
setmetatable(User, {__call = init})


function User:update(dt)
    local updates = {}
    local updated = false
    local dir = lfg.get_key_dir() -- FIXME: migrate logic to this module
    local m0_x, m0_y = self.m_x, self.m_y
    local m_x, m_y = love.mouse.getPosition()

    if dir and dir ~= self.cdir then
        updated = true
        self.cdir = cdir
        updates.cdir = lfg.ndirs[dir]
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
        self.m_x = m_x
        self.m_y = m_y
    end

    self.updates = updates
    if updated then self.client:send_player_update(self, updates) end
end


function User:draw()
    -- TODO: draw game UI
    -- TODO: enable FPS and stats logic:
    -- TODO: add toggle button for displaying these stats
    --love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)
    --if lfg.player then
    --    local tl_x, tl_y = lfg.map:convertPixelToTile(lfg.player.x, lfg.player.y)
    --    love.graphics.print(string.format("Current Pos: (%.2f, %.2f) <%.2f, %.2f>", lfg.player.x, lfg.player.y, tl_x, tl_y), 10, 30)
    --    love.graphics.print(string.format("Mouse Pos:   (%.2f, %.2f)", lfg.mouse.x, lfg.mouse.y), 10, 50)
    --    local deg = (math.deg(lfg.mouse.angle) + 360) % 360
    --    love.graphics.print(string.format("Angle[%.2f]: %.2f {%.2f} {[%i]}", lfg.mouse.distance, lfg.mouse.angle, math.deg(lfg.mouse.angle), deg), 10, 70)
    --end
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


function User:x() return self.player.x end
function User:y() return self.player.y end
function User:w() return self.player.w end
function User:h() return self.player.h end


return User

