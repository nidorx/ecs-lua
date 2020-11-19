local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

-- precision
local EPSILON = 0.000000001

local function floatEQ(n0, n1)
   if n0 == n1 then
      return true
   end

   return math.abs(n1 - n0) < EPSILON
end


local function vectorEQ(v0, v1)
   if v0 == v1 then
      return true
   end

   if not floatEQ(v0.X, v1.X) or not floatEQ(v0.Y, v1.Y) or not floatEQ(v0.Z, v1.Z) then
      return false
   else
      return true
   end
end

----------------------------------------------------------------------------------------------------------------------
-- UTILITY COMPONENTS & SYSTEMS
----------------------------------------------------------------------------------------------------------------------

local ECSUtil = {}


-- A component that facilitates access to BasePart
ECSUtil.BasePartComponent = ECS.Component.register('BasePart', function(object)
   if object == nil or object['IsA'] == nil or object:IsA('BasePart') == false then
      error("This component only works with BasePart objects")
   end

   return object
end)

-- Tag, indicates that the entity must be synchronized with the data from the BasePart (workspace)
ECSUtil.BasePartToEntitySyncComponent = ECS.Component.register('BasePartToEntitySync', nil, true)

-- Tag, indicates that the BasePart (workspace) must be synchronized with the existing data in the Entity (ECS)
ECSUtil.EntityToBasePartSyncComponent = ECS.Component.register('EntityToBasePartSync', nil, true)

-- Component that works with a position Vector3
ECSUtil.PositionComponent = ECS.Component.register('Position', function(position)
   if position ~= nil and typeof(position) ~= 'Vector3' then
      error("This component only works with Vector3 objects")
   end

   if position == nil then
      position = Vector3.new(0, 0, 0)
   end

   return position
end)

-- Allows to register two last positions (Vector3) to allow interpolation
ECSUtil.PositionInterpolationComponent = ECS.Component.register('PositionInterpolation', function(position)
   if position ~= nil and typeof(position) ~= 'Vector3' then
      error("This component only works with Vector3 objects")
   end

   if position == nil then
      position = Vector3.new(0, 0, 0)
   end

   return {position, position}
end)

-- {avgDelta, lastUpdate, position, rightVector, upVector, lookVector}
ECSUtil.InterpolationCustomComponent = ECS.Component.register('InterpolationCustom', function(avgDelta, lastUpdate, lastPosition, lastRightVector, lastUpVector, lastLookVector)
   if avgDelta == nil then
      return nil
   end
   return {avgDelta, lastUpdate, lastPosition, lastRightVector, lastUpVector, lastLookVector}
end)

local VEC3_R = Vector3.new(1, 0, 0)
local VEC3_U = Vector3.new(0, 1, 0)
local VEC3_F = Vector3.new(0, 0, 1)

--[[
   Rotational vectors that represents the object in the 3d world.
   To transform into a CFrame use CFrame.fromMatrix(pos, rot[1], rot[2], rot[3] * -1)

   Params
      lookVector  {Vector3}   @See CFrame.LookVector
      rightVector {Vector3}   @See CFrame.RightVector
      upVector    {Vector3}   @See CFrame.UpVector

   @See
      https://devforum.roblox.com/t/understanding-cframe-frommatrix-the-replacement-for-cframe-new/593742
      https://devforum.roblox.com/t/handling-the-edge-cases-of-cframe-frommatrix/632465
]]
ECSUtil.RotationComponent = ECS.Component.register('Rotation', function(rightVector, upVector, lookVector)

   if rightVector ~= nil and typeof(rightVector) ~= 'Vector3' then
      error("This component only works with Vector3 objects [param=rightVector]")
   end

   if upVector ~= nil and typeof(upVector) ~= 'Vector3' then
      error("This component only works with Vector3 objects [param=upVector]")
   end

   if lookVector ~= nil and typeof(lookVector) ~= 'Vector3' then
      error("This component only works with Vector3 objects [param=lookVector]")
   end

   if rightVector == nil then
      rightVector = VEC3_R
   end

   if upVector == nil then
      upVector = VEC3_U
   end

   if lookVector == nil then
      lookVector = VEC3_F
   end

   return {rightVector, upVector, lookVector}
end)

-- Allows to record two last rotations (rightVector, upVector, lookVector) to allow interpolation
ECSUtil.RotationInterpolationComponent = ECS.Component.register('RotationInterpolation', function(rightVector, upVector, lookVector)

   if rightVector ~= nil and typeof(rightVector) ~= 'Vector3' then
      error("This component only works with Vector3 objects [param=rightVector]")
   end

   if upVector ~= nil and typeof(upVector) ~= 'Vector3' then
      error("This component only works with Vector3 objects [param=upVector]")
   end

   if lookVector ~= nil and typeof(lookVector) ~= 'Vector3' then
      error("This component only works with Vector3 objects [param=lookVector]")
   end

   if rightVector == nil then
      rightVector = VEC3_R
   end

   if upVector == nil then
      upVector = VEC3_U
   end

   if lookVector == nil then
      lookVector = VEC3_F
   end

   return {{rightVector, upVector, lookVector}, {rightVector, upVector, lookVector}}
end)

-- Tag, indicates that the forward movement system must act on this entity
ECSUtil.MoveForwardComponent = ECS.Component.register('MoveForward', nil, true)

-- Allows you to define a movement speed for specialized handling systems
ECSUtil.MoveSpeedComponent = ECS.Component.register('MoveSpeed', function(speed)
   if speed == nil or typeof(speed) ~= 'number' then
      error("This component only works with number value")
   end

   return speed
end)

------------------------------------------
--[[
   Utility system that copies the direction and position of a Roblox BasePart to the ECS entity

   Executed in two moments: At the beginning of the "process" step and at the beginning of the "transform" step
]]
---------------------------------------->>
local function BasePartToEntityUpdate(time, world, dirty, entity, index, parts, positions, rotations)

   local changed = false
   local part = parts[index]

   if part ~= nil then

      local position = positions[index]
      local basePos = part.CFrame.Position
      if position == nil or not vectorEQ(basePos, position) then
         positions[index] = basePos
         changed = true
      end

      local rotation    = rotations[index]
      local rightVector =  part.CFrame.RightVector
      local upVector    =  part.CFrame.UpVector
      local lookVector  =  part.CFrame.LookVector
      if rotation == nil or not vectorEQ(rightVector, rotation[1]) or not vectorEQ(upVector, rotation[2]) or not vectorEQ(lookVector, rotation[3]) then
         rotations[index] = {rightVector, upVector, lookVector}
         changed = true
      end
   end

   return changed
end

-- copia dados de basepart para entidade no inicio do processamento, ignora entidades marcadas com Interpolation
ECSUtil.BasePartToEntityProcessInSystem = ECS.System.register({
   name  = 'BasePartToEntityProcessIn',
   step  = 'processIn',
   order = 10,
   requireAll = {
      ECSUtil.BasePartComponent,
      ECSUtil.PositionComponent,
      ECSUtil.RotationComponent,
      ECSUtil.BasePartToEntitySyncComponent
   },
   rejectAny = {
      ECSUtil.PositionInterpolationComponent,
      ECSUtil.RotationInterpolationComponent
   },
   update = BasePartToEntityUpdate
})

-- copia dados de um BasePart para entidade no inicio do passo transform
ECSUtil.BasePartToEntityTransformSystem = ECS.System.register({
   name  = 'BasePartToEntityTransform',
   step  = 'transform',
   order = 10,
   requireAll = {
      ECSUtil.BasePartComponent,
      ECSUtil.PositionComponent,
      ECSUtil.RotationComponent,
      ECSUtil.BasePartToEntitySyncComponent
   },
   rejectAny = {
      ECSUtil.PositionInterpolationComponent,
      ECSUtil.RotationInterpolationComponent
   },
   update = BasePartToEntityUpdate
})
----------------------------------------<<

------------------------------------------
--[[
   Utility system that copies the direction and position from ECS entity to a Roblox BasePart

   Executed in two moments: At the end of the "process" step and at the end of the "transform" step
]]
---------------------------------------->>

local function EntityToBasePartUpdate(time, world, dirty, entity, index, parts, positions, rotations)

   if not dirty then
      return false
   end

   local changed  = false
   local part     = parts[index]
   local position = positions[index]
   local rotation = rotations[index]
   if part ~= nil then
      local basePos     = part.CFrame.Position
      local rightVector = part.CFrame.RightVector
      local upVector    = part.CFrame.UpVector
      local lookVector  = part.CFrame.LookVector

      -- goal cframe, allow interpolation
      local cframe = part.CFrame

      if position ~= nil and not vectorEQ(basePos, position) then
         cframe = CFrame.fromMatrix(position, rightVector, upVector, lookVector * -1)
         changed = true
      end

      if rotation ~= nil then
         if not vectorEQ(rightVector, rotation[1]) or not vectorEQ(upVector, rotation[2]) or not vectorEQ(lookVector, rotation[3]) then
            cframe = CFrame.fromMatrix(cframe.Position, rotation[1], rotation[2], rotation[3] * -1)
            changed = true
         end
      end

      if changed then
         part.CFrame = cframe
      end
   end

   return changed
end

-- copia dados da entidade para um BaseParte no fim do processamento
ECSUtil.EntityToBasePartProcessOutSystem = ECS.System.register({
   name  = 'EntityToBasePartProcess',
   step  = 'processOut',
   order = 100,
   requireAll = {
      ECSUtil.BasePartComponent,
      ECSUtil.PositionComponent,
      ECSUtil.RotationComponent,
      ECSUtil.EntityToBasePartSyncComponent
   },
   update = EntityToBasePartUpdate
})

-- copia dados de uma entidade para um BsePart no passo de transformação, ignora entidades com interpolação
ECSUtil.EntityToBasePartTransformSystem = ECS.System.register({
   name  = 'EntityToBasePartTransform',
   step  = 'transform',
   order = 100,
   requireAll = {
      ECSUtil.BasePartComponent,
      ECSUtil.PositionComponent,
      ECSUtil.RotationComponent,
      ECSUtil.EntityToBasePartSyncComponent
   },
   rejectAny = {
      ECSUtil.PositionInterpolationComponent,
      ECSUtil.RotationInterpolationComponent
   },
   update = EntityToBasePartUpdate
})

-- Interpolates the position and rotation of a BasePart in the transform step.
-- Allows the process step to be performed at low frequency and with smooth rendering
local interpolationFactor = 1
ECSUtil.EntityToBasePartInterpolationTransformSystem = ECS.System.register({
   name  = 'EntityToBasePartInterpolationTransform',
   step  = 'transform',
   order = 100,
   requireAll = {
      ECSUtil.BasePartComponent,
      ECSUtil.PositionComponent,
      ECSUtil.RotationComponent,
      ECSUtil.PositionInterpolationComponent,
      ECSUtil.RotationInterpolationComponent,
      ECSUtil.EntityToBasePartSyncComponent
   },
   rejectAny ={
      ECSUtil.InterpolationCustomComponent
   },
   beforeUpdate = function(time, interpolation, world, system)
      interpolationFactor = interpolation
   end,
   update = function(time, world, dirty, entity, index, parts, positions, rotations, positionsInt, rotationsInt)

      local part     = parts[index]
      local position = positions[index]
      local rotation = rotations[index]

      if part ~= nil then
         -- goal cframe, allow interpolation
         local cframe = part.CFrame

         -- swap old and new position, if changed
         if position ~= nil then
            local rightVector = part.CFrame.RightVector
            local upVector    = part.CFrame.UpVector
            local lookVector  = part.CFrame.LookVector

            if not vectorEQ(positionsInt[index][1], position) then
               positionsInt[index][2] = positionsInt[index][1]
               positionsInt[index][1] = position
            end

            local oldPosition = positionsInt[index][2]
            cframe = CFrame.fromMatrix(oldPosition:Lerp(position, interpolationFactor), rightVector, upVector, lookVector * -1)
         end

         -- swap old and new rotation, if changed
         if rotation ~= nil then
            if not vectorEQ(rotationsInt[index][1][1], rotation[1])
               or not vectorEQ(rotationsInt[index][1][2], rotation[2])
               or not vectorEQ(rotationsInt[index][1][3], rotation[3])
            then
               rotationsInt[index][2] = rotationsInt[index][1]
               rotationsInt[index][1] = rotation
            end

            local oldRotation = rotationsInt[index][2]
            cframe = CFrame.fromMatrix(
               cframe.Position,
               oldRotation[1]:Lerp(rotation[1], interpolationFactor),
               oldRotation[2]:Lerp(rotation[2], interpolationFactor),
               (oldRotation[3] * -1):Lerp((rotation[3] * -1), interpolationFactor)
            )
         end

         part.CFrame = cframe
      end

      -- readonly
      return false
   end
})

-- Customized interpolation, the developer is responsible for indicating the necessary parameters for calculating the interpolation 
ECSUtil.EntityToBasePartInterpolationCustomTransformSystem = ECS.System.register({
   name  = 'EntityToBasePartInterpolationCustomTransform',
   step  = 'transform',
   order = 100,
   requireAll = {
      ECSUtil.BasePartComponent,
      ECSUtil.PositionComponent,
      ECSUtil.RotationComponent,
      ECSUtil.InterpolationCustomComponent,
      ECSUtil.EntityToBasePartSyncComponent
   },
   update = function(time, world, dirty, entity, index, parts, positions, rotations, interpolations)

      local part     = parts[index]
      local position = positions[index]
      local rotation = rotations[index]
      -- {avgDelta, lastUpdate, position, rightVector, upVector, lookVector}
      local interp = interpolations[index]

      if part ~= nil and position ~= nil and rotation ~= nil and interp ~= nil then
         local avgDelta    = interp[1]
         local lastUpdate  = interp[2]
         local alpha = (time.frame-lastUpdate)/avgDelta
         local cframe = CFrame.fromMatrix(interp[3], interp[4], interp[5], interp[6] * -1)
         part.CFrame = cframe:Lerp ( CFrame.fromMatrix(position, rotation[1], rotation[2], rotation[3] * -1), alpha )
      end

      -- readonly
      return false
   end
})
----------------------------------------<<

-- Simple forward movement system (position = position + speed * lookVector)
local moveForwardSpeedFactor = 1
ECSUtil.MoveForwardSystem = ECS.System.register({
   name = 'MoveForward',
   step = 'process',
   requireAll = {
      ECSUtil.MoveSpeedComponent,
      ECSUtil.PositionComponent,
      ECSUtil.RotationComponent,
      ECSUtil.MoveForwardComponent,
   },
   beforeUpdate = function(time, interpolation, world, system)
      moveForwardSpeedFactor = world.frequency/60
   end,
   update = function (time, world, dirty, entity, index, speeds, positions, rotations, forwards)

      local position = positions[index]
      if position ~= nil then

         local rotation = rotations[index]
         if rotation ~= nil then

            local speed = speeds[index]
            if speed ~= nil then
               -- speed/2 = 1 studs per second (120 = frequency)
               positions[index] = position + speed/moveForwardSpeedFactor  * rotation[3]
               return true
            end
         end
      end

      return false
   end
})

-- Creates an entity related to a BasePart
function ECSUtil.NewBasePartEntity(world, part, syncBasePartToEntity, syncEntityToBasePart, interpolate)
   local entityID = world.create()

   world.set(entityID, ECSUtil.BasePartComponent, part)
   world.set(entityID, ECSUtil.PositionComponent, part.CFrame.Position)
   world.set(entityID, ECSUtil.RotationComponent, part.CFrame.RightVector, part.CFrame.UpVector, part.CFrame.LookVector)

   if syncBasePartToEntity then
      world.set(entityID, ECSUtil.BasePartToEntitySyncComponent)
   end

   if syncEntityToBasePart then
      world.set(entityID, ECSUtil.EntityToBasePartSyncComponent)
   end

   if interpolate then
      world.set(entityID, ECSUtil.PositionInterpolationComponent, part.CFrame.Position)
      world.set(entityID, ECSUtil.RotationInterpolationComponent, part.CFrame.RightVector, part.CFrame.UpVector, part.CFrame.LookVector)
   end

   return entityID
end

-- add default systems
function  ECSUtil.AddDefaultSystems(world)
   -- processIn
   world.addSystem(ECSUtil.BasePartToEntityProcessInSystem)

   -- process
   world.addSystem(ECSUtil.MoveForwardSystem)

   -- processOut
   world.addSystem(ECSUtil.EntityToBasePartProcessOutSystem)

   -- transform
   world.addSystem(ECSUtil.BasePartToEntityTransformSystem)
   world.addSystem(ECSUtil.EntityToBasePartTransformSystem)
   world.addSystem(ECSUtil.EntityToBasePartInterpolationTransformSystem)
   world.addSystem(ECSUtil.EntityToBasePartInterpolationCustomTransformSystem)   
end

-- export ECS lib
return ECSUtil
