
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

-- Components
local Components = game.ReplicatedStorage:WaitForChild("tutorial"):WaitForChild("component")
local FiringComponent = require(Components:WaitForChild("FiringComponent"))

return ECS.RegisterSystem({
   name = 'Firing',
   step = 'processIn',
   requireAll = {
      ECS.Util.PositionComponent,
      ECS.Util.RotationComponent,
      FiringComponent
   },
   onEnter = function(time, world, entity, index,  positions, rotations, firings)

      local position = positions[index]
      local rotation = rotations[index]
      
      if position ~= nil and rotation ~= nil then

         -- can be made in a utility script, or clone a preexistece model
         local bulletPart = Instance.new("Part")
         bulletPart.Anchored     = true
         bulletPart.CanCollide   = false
         bulletPart.Position     = position
         bulletPart.CastShadow   = false
         bulletPart.Shape        = Enum.PartType.Ball
         bulletPart.Size         = Vector3.new(0.6, 0.6, 0.6)
         bulletPart.CFrame       = CFrame.fromMatrix(position, rotation[1], rotation[2], rotation[3] * -1)
         bulletPart.Parent       = game.Workspace

         local bulletEntity = ECS.Util.NewBasePartEntity(world, bulletPart, false, true, true)
         world.Set(bulletEntity, ECS.Util.MoveForwardComponent)
         world.Set(bulletEntity, ECS.Util.MoveSpeedComponent, 1.0)
      end

      return false
   end
})