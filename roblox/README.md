# Roblox-ECS

LINK: https://github.com/nidorx/ecs-lua/blob/master/src/shared/ECSUtil.lua

## Utility Systems and Components

ECSUtil provides some basic systems and components, described below

### Components
- _ECSUtil._**BasePartComponent**
   - A component that facilitates access to BasePart
- _ECSUtil._**PositionComponent**
   - Component that works with a position `Vector3`
- _ECSUtil._**RotationComponent**
   - Rotational vectors _(right, up, look)_ that represents the object in the 3d world. To transform into a CFrame use `CFrame.fromMatrix(pos, rot[1], rot[2], rot[3] * -1)`
- _ECSUtil._**PositionInterpolationComponent**
   - Allows to register two last positions (`Vector3`) to allow interpolation
- _ECSUtil._**RotationInterpolationComponent**
   - Allows to record two last rotations (`rightVector`, `upVector`, `lookVector`) to allow interpolation
- _ECSUtil._**BasePartToEntitySyncComponent**
   - Tag, indicates that the `Entity` _(ECS)_ must be synchronized with the data from the `BasePart` _(workspace)_
- _ECSUtil._**EntityToBasePartSyncComponent**
   - Tag, indicates that the `BasePart` _(workspace)_ must be synchronized with the existing data in the `Entity` _(ECS)_
- _ECSUtil._**MoveForwardComponent**
   - Tag, indicates that the forward movement system must act on this entity
- _ECSUtil._**MoveSpeedComponent**
   - Allows you to define a movement speed for specialized handling systems


### Systems
- _ECSUtil._**BasePartToEntityProcessInSystem**
   - Synchronizes the `Entity` _(ECS)_ with the data of a `BasePart` _(workspace)_ at the beginning of the `process` step
   -  ```lua
      step  = 'process',
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
      }
      ```
- _ECSUtil._**BasePartToEntityTransformSystem**
   - Synchronizes the `Entity` _(ECS)_ with the data of a `BasePart` _(workspace)_ at the beginning of the `transform` step _(After running the Roblox physics engine)_
   -  ```lua
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
      }
      ```
- _ECSUtil._**EntityToBasePartProcessOutSystem**
   - Synchronizes the `BasePart` _(workspace)_ with the `Entity` _(ECS)_ data at the end of the `processOut` step _(before Roblox's physics engine runs)_
   -  ```lua
      step  = 'process',
      order = 100,
      requireAll = {
         ECSUtil.BasePartComponent,
         ECSUtil.PositionComponent,
         ECSUtil.RotationComponent,
         ECSUtil.EntityToBasePartSyncComponent
      }
      ```
- _ECSUtil._**EntityToBasePartTransformSystem**
   - Synchronizes the `BasePart` _(workspace)_ with the `Entity` _(ECS)_ data at the end of the `transform` step _(last step of the current frame in multi-thread execution)_
   -  ```lua
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
      }
      ```
- _ECSUtil._**EntityToBasePartInterpolationTransformSystem**
   - Interpolates the position and rotation of a BasePart in the `transform` step. Allows the `process` step to be performed at low frequency with smooth rendering
   -  ```lua
      step  = 'transform',
      order = 100,
      requireAll = {
         ECSUtil.BasePartComponent,
         ECSUtil.PositionComponent,
         ECSUtil.RotationComponent,
         ECSUtil.PositionInterpolationComponent,
         ECSUtil.RotationInterpolationComponent,
         ECSUtil.EntityToBasePartSyncComponent
      }
      ```
- _ECSUtil._**MoveForwardSystem**
   - Simple forward movement system (position = position + speed * lookVector)
   -  ```lua
      step = 'process',
      requireAll = {
         ECSUtil.MoveSpeedComponent,
         ECSUtil.PositionComponent,
         ECSUtil.RotationComponent,
         ECSUtil.MoveForwardComponent,
      }
      ```
