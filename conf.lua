local k = function(x) return function() return x end end

local headless = function(t)
   package.loaded["lib.anim8"] = {newGrid = k(k()),
                                  newAnimation = k({pauseAtEnd=k(),
                                                    update=k()})}
   love.graphics = {newImage = k({getHeight=k(), getWidth=k(),
                                  setFilter = k()}),
                    newQuad = k(), getWidth = k(), getHeight = k(),
                    newSpriteBatch = k({add=k()}),
                    newCanvas = k({setFilter = k()}),
                    isActive = k(false),}
   t.window, t.modules.window, t.modules.graphics = false, false, false
end

function love.conf(t)
   t.title = "Kore - The Rise of Persephone"
   t.window.width = 1400
   t.window.height = 800
   t.console = true
   local client = false
   for _, a in ipairs(arg) do
      if(a == "--headless") then headless(t) end
      if(a == "--client") then client = true end
   end
   if(not client) then headless(t) end
end
