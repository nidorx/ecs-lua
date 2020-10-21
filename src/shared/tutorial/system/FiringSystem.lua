
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

-- Components
local Components = game.ReplicatedStorage:WaitForChild("tutorial"):WaitForChild("component")
local FiringComponent = require(Components:WaitForChild("FiringComponent"))

--[[
   Responsible soleley for creating bullets
]]
return ECS.System.register({
   name = 'Firing',
   requireAll = {
      FiringComponent,
      ECS.Util.PositionComponent,
      ECS.Util.DirectionComponent
   },
   --[[
      Waits for player input to fire a shot (mark the entity with FiringComponent)
   ]]
   onEnter = function(world, entity, index, firings, positions, directions)

      -- weapon firing position and rotation
      local position = positions[index]
      local direction = directions[index]
      
      if position ~= nil and direction ~= nil then
         -- can be made in a utility script, or clone a preexistece model
         local bulletPart = Instance.new("Part")
         bulletPart.Anchored     = true
         bulletPart.CanCollide   = false
         bulletPart.Position = position
         bulletPart.CFrame = CFrame.new(position, position + direction)

         local bulletEntity = ECS.Util.newBasePartEntity(world, bulletPart)
         world.set(bulletEntity, ECS.Util.MoveForwardComponent)
         world.set(bulletEntity, ECS.Util.MoveSpeedComponent, 0.01)

         -- bullet current position and rotation components (from newBasePartEntity)
         --world.set(bulletEntity, ECS.Util.PositionComponent, position)
         --world.set(bulletEntity, ECS.Util.DirectionComponent, direction)

         bulletPart.Parent = game.Workspace
      end

      return false
   end
})