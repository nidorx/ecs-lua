
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

-- Components
local Components = game.ReplicatedStorage:WaitForChild("tutorial"):WaitForChild("component")
local FiringComponent = require(Components:WaitForChild("FiringComponent"))

return ECS.System.register({
   name = 'CleanupFiring',
   step = 'transform',
   requireAll = {
      FiringComponent
   },
   update = function (time, world, dirty, entity, index, firings)

      local firedAt = firings[index]
      if firedAt ~= nil then
         if time.frame - firedAt < 0.5 then
            return false
         end

         world.remove(entity, FiringComponent)

         return true
      end

      return false
   end
})