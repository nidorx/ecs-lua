
local ECS      = require(game.ReplicatedStorage:WaitForChild("ECS"))
local ECSUtil  = require(game.ReplicatedStorage:WaitForChild("ECSUtil"))

-- Components
local Components = game.ReplicatedStorage:WaitForChild("tutorial"):WaitForChild("component")
local FiringComponent = require(Components:WaitForChild("FiringComponent"))

return ECS.RegisterSystem({
   Name = 'Firing',
   Step = 'process0',
   RequireAll = {
      ECSUtil.PositionComponent,
      ECSUtil.RotationComponent,
      FiringComponent
   },
   OnEnter = function(time, world, entity, index,  positions, rotations, firings)

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

         local bulletEntity = ECSUtil.NewBasePartEntity(world, bulletPart, false, true, true)
         world.Set(bulletEntity, ECSUtil.MoveForwardComponent)
         world.Set(bulletEntity, ECSUtil.MoveSpeedComponent, 1.0)
      end

      return false
   end
})
