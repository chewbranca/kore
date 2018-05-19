require("love.event")

local serpent = require("lib.serpent")
local serpent_opts = {maxlevel=8,maxnum=64,nocode=true}
local event, channel = ...

if channel then
   local function prompt()
      io.write("> ")
      io.flush()
      return io.read("*l")
   end
   local function looper(input)
      if input then
         love.event.push(event, input)
         print(channel:demand())
         return looper(prompt())
      end
   end
   return looper(prompt())
end

local function start_repl()
   local code = love.filesystem.read("lib/repl.lua")
   local thread = love.thread.newThread(code)
   local io_channel = love.thread.newChannel()

   thread:start("eval", io_channel)
   love.handlers.eval = function (input)
      local chunk, err = loadstring("return " .. input)
      if(err and not chunk) then -- maybe it's a statement, not an expression
         chunk, err = loadstring(input)
         if(not chunk) then
            io_channel:push("! Compilation error: " .. (err or "Unknown error"))
            return false
         end
      end
      local trace
      local result = {xpcall(chunk, function(e)
                                trace = debug.traceback()
                                err = e end)}
      if(result[1]) then
         local output, i = serpent.block(result[2], serpent_opts), 3
         -- pretty-print out the values it returned.
         while i <= #result do
            output = output .. ', ' .. serpent.block(result[i], serpent_opts)
            i = i + 1
         end
         io_channel:push(output)
      else
         -- display the error and stack trace.
         io_channel:push('! Evaluation error: ' .. (err or "Unknown"))
         print('! Evaluation error: ' .. (err or "Unknown"))
         print(trace)
      end
   end
end

return ({start = start_repl})
