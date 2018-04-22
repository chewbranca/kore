-- Thanks to: https://gitlab.com/technomancy/fennel-tiled-tech-demo/blob/master/main.lua
-- A shim to bridge fennel and love2d
fennel = require("fennel")
lume = require("lume")

lfg = require("lfg")

table[("insert")](package[("loaders")], fennel[("searcher")])
pps = function(x)
   return require("serpent").block(x, {maxlevel=8,maxnum=64,
                                       nocode=true,comment=false})
end
ppsl = function(x) return require("serpent").line(x) end
pp = function(x) print(pps(x)) end
ppl = function(x) print(ppsl(x)) end
log = function(...) print(string.format(...)) end

fennel.dofile("main.fnl")
