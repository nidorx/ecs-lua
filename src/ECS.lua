--[[
   ECS-Lua v2.0.0 [2021-10-02 17:25]

   Roblox-ECS is a tiny and easy to use ECS (Entity Component System) engine for
   game development on the Roblox platform

   https://github.com/nidorx/roblox-ecs

   Discussions about this script are at https://devforum.roblox.com/t/841175

   ------------------------------------------------------------------------------

   MIT License

   Copyright (c) 2020 Alex Rodin

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in all
   copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE.
]]

local isRoblox, err = pcall(function()
   if game and game.ClassName == 'DataModel' then
      return true
   end
   error('Not Roblox')
end)

local Query = require("Query")
local World = require("World")
local System = require("System")
local Archetype = require("Archetype")
local Component = require("Component")

local function setHost(host)
   World.Host = host
end

if isRoblox then
   setHost(require("HostRoblox"))
else
   setHost(require("HostDummy"))
end

--[[
  @TODO
      - Serialize componentes
      - Server entities
      - Client - Server sincronization (snapshot, delta, spatial index, grid manhatham distance)
      - Table pool (avoid GC)
      - System readonly? Paralel execution
      - Debugging?
      - Benchmark (Local Script vs ECS implementation)
      - Basic physics (managed)
      - SharedComponent?
]]
return {
   Query = Query.Create,
   World = World.Create
   System = System.Create,
   Archetype = Archetype,
   Component = Component.Create,
   SetHost = setHost
}