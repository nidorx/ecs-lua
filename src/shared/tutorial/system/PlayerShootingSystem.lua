
local UserInputService = game:GetService("UserInputService")
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

-- Components
local Components = game.ReplicatedStorage:WaitForChild("tutorial"):WaitForChild("component")
local FiringComponent = require(Components:WaitForChild("FiringComponent"))
local WeaponComponent = require(Components:WaitForChild("WeaponComponent"))

return ECS.System.register({
   name = 'PlayerShooting',
   step = 'processIn',
   order = 1,
   requireAll = {
      WeaponComponent
   },
   rejectAny = {
      FiringComponent
   },
   update = function (time, world, dirty, entity, index, weapons)

      local isFiring = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)

      if isFiring  then
         world.set(entity, FiringComponent, time.frame)
         return true
      end

      return false
   end
})

--[[
   
local UserInputService = game:GetService("UserInputService")
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

-- Components
local Components = game.ReplicatedStorage:WaitForChild("tutorial"):WaitForChild("component")
local FiringComponent = require(Components:WaitForChild("FiringComponent"))
local WeaponComponent = require(Components:WaitForChild("WeaponComponent"))


return ECS.System.register({
   name = 'PlayerShooting',
   step = 'processIn',
   order = 1,
   requireAll = {
      WeaponComponent
   },
   rejectAny = {
      FiringComponent
   },
   update = function (time, world, dirty, entity, index, weapons)

      local isFiring = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)

      if isFiring  then
         -- Add a firing component to all entities when mouse button is pressed
         world.set(entity, FiringComponent, { FiredAt = time.frame })
         return true
      end

      return false
   end
})
]]