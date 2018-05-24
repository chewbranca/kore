-- -*- lua -*-
color = false
-- don't warn when unused arguments start with _
-- don't warn for shadowed upvalues; the compiler emits these no matter what
ignore = {"21/_.*", "431"}
max_line_length = false

-- better to use luacheck's version of this, but it isn't up to date with
-- the latest love2d API
new_globals = {"love"}

stds.main = {globals ={"lume", "pp", "ppsl", "ppl", "log", "lfg", "GKORE"}}

-- run with luacheck --std luajit+love+main *lua
