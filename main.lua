-- Thanks to: https://gitlab.com/technomancy/fennel-tiled-tech-demo/blob/master/main.lua
-- A shim to bridge fennel and love2d
fennel = require("fennel")

pps = function(x)
   return require("serpent").block(x, {maxlevel=8,maxnum=64,
                                       nocode=true,comment=false})
end
pp = function(x) print(pps(x)) end

fennel.dofile("main.fnl")
