
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

-- Components
local Components = game.ReplicatedStorage:WaitForChild("tutorial"):WaitForChild("component")
local FiringComponent = require(Components:WaitForChild("FiringComponent"))

--[[
   Responsible for removing the Firing Component from entities after a certain period of time. 
   This will result in behavior that, in effect, will emulate rate of fire
]]
return ECS.System.register({
   name = 'CleanupFiring',
   step = 'logic',
   requireAll = {
      FiringComponent
   },
   update = function (time, delta, world, dirty, entity, index, firings)

      local data = firings[index]
      if data ~= nil then
         if time - data.FiredAt < 500 then
            return false
         end

         world.remove(entity, FiringComponent)

         return true
      end

      return false
   end
})