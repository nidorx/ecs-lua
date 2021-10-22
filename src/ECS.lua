--[[
   ECS Lua v2.2.0

   ECS Lua is a fast and easy to use ECS (Entity Component System) engine for game development.

   https://github.com/nidorx/ecs-lua

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

local Query = require("Query")
local World = require("World")
local System = require("System")
local Archetype = require("Archetype")
local Component = require("Component")

local function setLoopManager(manager)
   World.LoopManager = manager
end

pcall(function()
   if (game and game.ClassName == "DataModel") then
      -- is roblox
      setLoopManager(require("RobloxLoopManager")())
   end
end)

--[[
  @TODO
   - Server entities
   - Client - Server sincronization (snapshot, delta, spatial index, grid manhatham distance)
   - Table pool (avoid GC)
   - System readonly? Paralel execution
   - Debugging?
   - Benchmark (Local Script vs ECS implementation)
   - Basic physics (managed)
   - SharedComponent?
   - Serializaton
      - world:Serialize()
      - world:Serialize(entity)
      - entity:Serialize()
      - component:Serialize()
]]
local ECS = {
   Query = Query,
   World = World.New,
   System = System.Create,
   Archetype = Archetype,
   Component = Component.Create,
   SetLoopManager = setLoopManager
}

if _G.ECS == nil then
   _G.ECS = ECS
else
   local warn = _G.warn or print
   warn("ECS Lua was not registered in the global variables, there is already another object registered.")
end

return ECS
