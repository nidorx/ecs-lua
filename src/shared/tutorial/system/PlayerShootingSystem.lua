
local UserInputService = game:GetService("UserInputService")


local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

-- Components
local Components = game.ReplicatedStorage:WaitForChild("tutorial"):WaitForChild("component")
local FiringComponent = require(Components:WaitForChild("FiringComponent"))
local WeaponComponent = require(Components:WaitForChild("WeaponComponent"))

--[[
   Responsible for notifying the FiringSystem when it's time to create bullets for the player,
   It will do this by monitoring input and adding a special tag component to the player's weapon entity whenever the fire button is pressed

   ECS only grab entities that have WeaponComponent (and dont have FiringComponent yet)
]]
return ECS.System.register({
   name = 'PlayerShooting',
   step = 'render',
   requireAll = {
      WeaponComponent
   },
   rejectAny = {
      FiringComponent
   },
   --[[
      Waits for player input to fire a shot (mark the entity with FiringComponent)
   ]]
   update = function (time, delta, world, dirty, entity, index, weapons)

      local isFiring = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)

      if isFiring  then
         -- Add a firing component to all entities when mouse button is pressed
         world.set(entity, FiringComponent, { FiredAt = time })
         return true
      end

      return false
   end
})