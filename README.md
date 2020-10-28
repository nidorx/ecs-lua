![](repository-open-graph.png)

**Roblox-ECS** is a tiny and easy to use [ECS _(Entity Component System)_](https://en.wikipedia.org/wiki/Entity_component_system) engine for game development on the Roblox platform


**TLDR;** There is a very cool tutorial below in the content that shows you in practice how to create a small shooting system

Entity-Component-System (ECS) is a distributed and compositional architectural design pattern that is mostly used in game development. It enables flexible decoupling of domain-specific behaviour, which overcomes many of the drawbacks of traditional object-oriented inheritance

For further details:

- [Entity Systems Wiki](http://entity-systems.wikidot.com/)
- [Evolve Your Hierarchy](http://cowboyprogramming.com/2007/01/05/evolve-your-heirachy/)
- [ECS on Wikipedia](https://en.wikipedia.org/wiki/Entity_component_system)
- [Entity Component Systems in Elixir](https://yos.io/2016/09/17/entity-component-systems/)
- [2017 GDC - Overwatch Gameplay Architecture and Netcode](https://www.youtube.com/watch?v=W3aieHjyNvw&ab_channel=GDC)

## Roblox Pipeline

Before going into the details, let's review some important concepts about how the Roblox game engine works

Most likely you have seen the illustration below, made by zeuxcg and enriched by Fractality_alt. It describes the roblox rendering pipeline. Let's redraw it so that it is clearer what happens in each frame of a game in roblox

[![](docs/pipeline_old.png)](https://devforum.roblox.com/t/runservice-heartbeat-switching-to-variable-frequency/23509/7)

In the new image, we have a clear separation (gap between CPU1 and CPU2) of the roblox rendering process, which occurs in parallel with the simulation and processing (game logic) of the next screen

The green arrows indicate the start of processing of the new frame and the return of execution after the completion of the two processes that are being executed in parallel (rendering of the previous screen and processing of the current frame)

The complete information on the order of execution can be seen at https://developer.roblox.com/en-us/articles/task-scheduler

> **note** the distance between the initialization of the two processes in the image is just to facilitate understanding, in Roblox both threads are started at the same time

[![](docs/pipeline.png)](https://developer.roblox.com/en-us/articles/task-scheduler)

Based on this model, Roblox-ECS organizes the execution of the systems in the following events. We call them **steps**

![](docs/pipeline_ecs_resume.png)

## Roblox-ECS steps

Roblox-ECS allows you to configure your systems to perform in the steps defined below.

In addition to defining the execution step, you can also define the execution order within that step. By default, the order of execution of a system is 50. When two or more systems have the same order of execution, they will be executed following the order of insertion in the world

![](docs/pipeline_ecs_steps.png)

- **processIn** - Executed once per frame

   This is the first step to be executed in a frame. Use this step to run systems that translate the user's input or the current state of the workspace to entity components, which can be processed by specialized systems in the next steps

   Eg. Use the UserInputService to register the player's inputs in the current frame in a pool of inputs, and, in the PROCESS_IN step, translate these commands to the player's components. Realize that the same logic can be used to receive entries from the server and update local entities that represent other players

   ```lua
   -- InputHandlerUtils.lua
   local UserInputService = game:GetService("UserInputService")

   local pool = { FIRE = false }

   UserInputService.InputBegan:Connect(function(input, gameProcessed)
      if input.UserInputType == Enum.UserInputType.MouseButton1 then
         pool.FIRE = true
      end
   end)

   return pool

   --------------------------------

   -- InputMapSystem.lua
   local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))
   local FiringComponent = require(game.ReplicatedStorage:WaitForChild("FiringComponent"))

   local pool = require(game.ReplicatedStorage:WaitForChild("InputHandlerUtils"))

   return ECS.System.register({
      name = 'InputMap',
      step = 'processIn',
      order = 5,
      requireAll = {
         PlayerComponent
      },
      update = function (time, world, dirty, entity, index, players)
         local changed = false

         if pool.FIRE then
            world.set(entity, FiringComponent, { FiredAt = time.frame })
            changed = true
         end

         pool.clear()

         return changed
      end
   })
   ```
- **process** - Executed 0 or more times per frame

   This step allows the execution of systems for game logic independent of Frame-Rate, obtaining determinism in the simulation of the rules of the game

   Independent Frame-Rate games are games that run at the same speed, no matter the frame rate. For example, a game can run at 30 FPS (frames per second) on a slow computer and 60 FPS on a fast one. A game independent of the frame rate progresses at the same speed on both computers (the objects appear to move at the same speed). On the other hand, a frame rate-dependent game advances at half the speed of the slow computer, in a kind of slow motion effect

   Making frame rate independent games is important to ensure that your game is enjoyable and playable for everyone, no matter what type of computer they have. Games that slow down when the frame rate drops can seriously affect gameplay, making players frustrated and giving up! In addition, some systems have screens with different refresh rates, such as 120 Hz, so independence of the frame rate is important to ensure that the game does not accelerate and is impossibly fast on these devices

   This step can also be used to perform some physical simulations that are not met (or should not be performed) by the roblox internal physics engine.

   The standard frequency for executing this step in a world is 30Hz, which can be configured when creating a world

   In the tutorial topic there is a demonstration of the use of interpolation for smooth rendering display even when updating the simulation in just 10Hz

   Read more 
   - [Game Networking (1) - Interval and ticks](https://medium.com/@timonpost/game-networking-1-interval-and-ticks-b39bb51ccca9)
   - [Fix Your Timestep](https://gafferongames.com/post/fix_your_timestep/)
   - [Netcode 101 - What You Need To Know](https://www.youtube.com/watch?v=hiHP0N-jMx8&ab_channel=Battle%28non%29sense)

- **processOut** - Executed once per frame

   Use this step when your systems make changes to the components and these changes imply the behavior of the roblox internal physics simulations, therefore, the workspace needs to receive the update for the correct physics engine simulation

- **transform** - Executed once per frame

   Use this step for systems that react to changes made by the roblox physics engine or to perform transformations on game objects based on entity components (ECS to Workspace)

   Ex. In a soccer game, after running the physics engine, check if the ball touched the net, scoring a point

   Ex2. In a game that is not based on the roblox physics engine, perform the interpolation of objects based on the positions calculated by the specialized systems that were executed in the PROCESS step

- **render** - Executed once per frame

   Use this step to run systems that perform updates on things related to the camera and user interface.

   **IMPORTANT!** Only run light systems here, as the screen design and the processing of the next frame will only happen after the completion of this step. If it is necessary to make transformations on world objects (interpolations, complex calculations), use the TRANSFORM step

### Cleaning phase

At the end of each step, as long as there is dirt, Roblox-ECS sanitizes the environment.

In order to increase performance and maintain the determinism of the simulation, changes that modify the organization of the environment (change in chunks) are applied only in this phase.

At this stage, the following procedures are performed, in that order

1. **Removing entities**
   - If during the execution of the step your system requests the removal of an entity from the world, Roblox-ECS clears the data of that entity in memory but does not immediately remove the entity from Chunk, it only marks the entity for removal, which happens at the moment current (cleaning phase)
2. **Changing the entity's archetype**
   - Entities are grouped in chunk based on their archetype (types of existing components). When you add or remove components from an entity you are modifying its archetype, which should modify the chunk of that entity. When this happens, Roblox-ECS starts to work internally with a copy of that entity, without removing it from the original chunk. This chunk change only occurs during this cleaning phase
3. **Creation of new entities**
   - When a new entity is added to the world by its systems, Roblox-ECS houses that entity in specific chunks of new entities, and only at that moment these entities are copied to their definitive chunk
4. **Invocation of the systems "onEnter" method**
   - After cleaning the environment, Roblox-ECS invokes the `onEnter` method for each entity that has been added (or that has undergone component changes and now matches the signature expected by some system)


## Roblox-ECS

We will now know how to create Worlds, Components, Entities and Systems in Roblox-ECS

### World

The World is a container for Entities, Components, and Systems.

To create a new world, use the Roblox-ECS `newWorld` method.

```lua
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

local world = ECS.newWorld(

   -- [Optional] systems
   {SystemA, SystemB}, 

   -- [Optional] config
   { 
      frequence = 30, 
      disableDefaultSystems = false, 
      disableAutoUpdate = false
   }
)
```

### Component

Represents the different facets of an entity, such as position, velocity, geometry, physics, and hit points for example. Components store only raw data for one aspect of the object, and how it interacts with the world

In other words, the component labels the entity as having this particular aspect


```lua
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

return ECS.Component.register(
   -- name
   'Box',

   -- [Optional] constructor
   function( width, height, depth)
      if width == nil then width = 1 end

      return {width, height, depth}
   end,

   -- [Optional] is tag? Defaults false
   false
)
```

The register method generates a new component type, which is a unique identifier

- **constructor** - you can pass a constructor to the component register. The constructor will be invoked whenever the component is added to an entity
- **Tag component** - The tag component or "zero size component" is a special case where a component does not contain any data. (Eg: **EnemyComponent** can indicate that an entity is an enemy, with no data, just a marker)


### Entity

The entity is a general purpose object. An entity is what you use to describe an object in your game. e.g. a player, a gun, etc. It consists only of a unique ID and the list of components that make up this entity

```lua
local cubeEntity = world.create()
```

#### Adding and removing components 

At any point in the entity's life cycle, you can add or remove components, using `set` and `remove` methods

```lua
local BoxComponent = require(path.to.BoxComponent)
local ColorComponent = require(path.to.ColorComponent)

-- add components to entity
world.set(cubeEntity, BoxComponent, 10, 10, 10)
world.set(cubeEntity, ColorComponent, Color3.new(1, 0, 0))


-- remove component
world.remove(cubeEntity, BoxComponent)
```

#### Accessing components data

To gain access to the components data of an entity, simply use the `get` method of the `world`

```lua
local color = world.get(cubeEntity, ColorComponent)
```

#### Check if it is

To find out if an entity has a specific component, use the `has` method of the `world`

```lua
if world.has(cubeEntity, ColorComponent) then
   -- your code
end
```
#### Remove an entity

To remove an entity, use the "remove" method from the `world`, this time without informing the component.

```lua
world.remove(cubeEntity)
```

**IMPORTANT!** The removal of the entity is only carried out at the end of the execution of the current step, when invoking the `remove` method, the engine cleans the data of that entity and marks it as removed. To check if an entity is marked for removal, use the `alive` method of the world.

```lua
if not world.alive(cubeEntity) then
   -- your code
end
```

### System

Represents the logic that transforms component data of an entity from its current state to its next state. A system runs on entities that have a specific set of component types.

In **Roblox-ECS**, a system has a strong connection with component types. You must define which components this system works on in the `System` registry.

If the `update` method is implemented, it will be invoked respecting the order parameter within the configured step. Whenever an entity with the characteristics expected by this system is added on world, the system is informed via the `onEnter` method.

```lua
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

-- Components
local FiringComponent = require(path.to.FiringComponent)
local WeaponComponent = require(path.to.WeaponComponent)

return ECS.System.register({
   name = 'PlayerShooting',

   -- [Optional] defaults to transform
   step = 'processIn',

   -- [Optional] Order of execution within that step. defaults to 50
   order = 10,

   -- requireAll or requireAny
   requireAll = {
      WeaponComponent
   },

   --  [Optional] rejectAll or rejectAny
   rejectAny = {
      FiringComponent
   },

   --  [Optional] Invoked when an entity with these characteristics appears
   onEnter = function(time, world, entity, index, weapons)
      -- on new entity
      print('New entity added ', entity)
      return false
   end,

   --  [Optional] Invoked before executing the update method
   beforeUpdate = function(time, interpolation, world, system)
      -- called before update
      print(system.config.customConfig)
   end,

   -- [Optional] Invoked for each entity that has the characteristics 
   -- expected by this system
   update = function (time, world, dirty, entity, index, weapons)

      local isFiring = UserInputService:IsMouseButtonPressed(
         Enum.UserInputType.MouseButton1
      )

      if isFiring  then
         -- Add a firing component to all entities when mouse button is pressed
         world.set(entity, FiringComponent, { FiredAt = time.frame })
         return true
      end

      return false
   end
})
```

#### update

The `update` method has the following signature:

```lua
update = function (time, world, dirty, entity, index, [component_N_data...])

   local changed = false

   return changed
end
```

- **time** : Object containing the time that the last execution of the `process` step occurred; the time at the beginning of the execution of the current `frame` (processIn); the `delta` time, in seconds passed between the previous and the current frame
   - `{ process = number, frame = number, delta = number }`
- **world**: Reference to the world in which the system is running
- **dirty** : Informs that the chunk (see performance topic) currently being processed has entities that have been modified since the last execution of this system
- **entity** : Entity ID being processed
- **index** : Index, in the chunk being processed, that has the data of the current entity.
- **component_N_data** : The component arrays that are processed by this system. The ordering of the parameters follows the order defined in the `requireAll` or `requireAny` attributes of the system.

As in this architecture you have direct access to the data of the components, it is necessary to inform on the return of the function if any changes were made to this data.

##### Performance TIP, dirty version

As with Unity ECS, Roblox-ECS systems are processed in batch.

Component data is saved in chunks, which allows queries by entities with the expected characteristics to be made more quickly.

In the `update` method, your system is able to know if this chunk being processed at the moment has entities that have changed, through the `dirty` parameter. Using this parameter you can skip the execution of your system when there has been no change since the last execution of your system for this specific chunk

See that this parameter says only if there are any entities modified in this chunk, but it does not say exactly which entity is

For more details, see the links [The Chunk data structure in Unity](https://gametorrahod.com/the-chunk-data-structure/) and [Designing an efficient system with version numbers](https://gametorrahod.com/designing-an-efficient-system-with-version-numbers/)


#### Adding to the world

To add a system to the world, simply use the `addSystem` method. You can optionally change the order of execution and pass any configuration parameters that are expected by your system

```lua
local PlayerShootingSystem = require(path.to.PlayerShootingSystem)

world.addSystem(PlayerShootingSystem, newOrder, { customConfig = 'Hello' })
```
## Utility Systems and Components

Roblox-ECS provides (and already starts the world) with some basic systems and components, described below

### Components
- _ECS.Util._**BasePartComponent**
   - A component that facilitates access to BasePart
- _ECS.Util._**PositionComponent**
   - Component that works with a position `Vector3`
- _ECS.Util._**RotationComponent**
   - Rotational vectors _(right, up, look)_ that represents the object in the 3d world. To transform into a CFrame use `CFrame.fromMatrix(pos, rot[1], rot[2], rot[3] * -1)`
- _ECS.Util._**PositionInterpolationComponent**
   - Allows to register two last positions (`Vector3`) to allow interpolation
- _ECS.Util._**RotationInterpolationComponent**
   - Allows to record two last rotations (`rightVector`, `upVector`, `lookVector`) to allow interpolation
- _ECS.Util._**BasePartToEntitySyncComponent**
   - Tag, indicates that the `Entity` _(ECS)_ must be synchronized with the data from the `BasePart` _(workspace)_
- _ECS.Util._**EntityToBasePartSyncComponent**
   - Tag, indicates that the `BasePart` _(workspace)_ must be synchronized with the existing data in the `Entity` _(ECS)_
- _ECS.Util._**MoveForwardComponent**
   - Tag, indicates that the forward movement system must act on this entity
- _ECS.Util._**MoveSpeedComponent**
   - Allows you to define a movement speed for specialized handling systems


### Systems
- _ECS.Util._**BasePartToEntityProcessInSystem**
   - Synchronizes the `Entity` _(ECS)_ with the data of a `BasePart` _(workspace)_ at the beginning of the `processIn` step
   -  ```lua
      step  = 'processIn',
      order = 10,
      requireAll = {
         ECS.Util.BasePartComponent,
         ECS.Util.PositionComponent,
         ECS.Util.RotationComponent,
         ECS.Util.BasePartToEntitySyncComponent
      },
      rejectAny = {
         ECS.Util.PositionInterpolationComponent,
         ECS.Util.RotationInterpolationComponent
      }
      ```
- _ECS.Util._**BasePartToEntityTransformSystem**
   - Synchronizes the `Entity` _(ECS)_ with the data of a `BasePart` _(workspace)_ at the beginning of the `transform` step _(After running the Roblox physics engine)_
   -  ```lua
      step  = 'transform',
      order = 10,
      requireAll = {
         ECS.Util.BasePartComponent,
         ECS.Util.PositionComponent,
         ECS.Util.RotationComponent,
         ECS.Util.BasePartToEntitySyncComponent
      },
      rejectAny = {
         ECS.Util.PositionInterpolationComponent,
         ECS.Util.RotationInterpolationComponent
      }
      ```
- _ECS.Util._**EntityToBasePartProcessOutSystem**
   - Synchronizes the `BasePart` _(workspace)_ with the `Entity` _(ECS)_ data at the end of the `processOut` step _(before Roblox's physics engine runs)_
   -  ```lua
      step  = 'processOut',
      order = 100,
      requireAll = {
         ECS.Util.BasePartComponent,
         ECS.Util.PositionComponent,
         ECS.Util.RotationComponent,
         ECS.Util.EntityToBasePartSyncComponent
      }
      ```
- _ECS.Util._**EntityToBasePartTransformSystem**
   - Synchronizes the `BasePart` _(workspace)_ with the `Entity` _(ECS)_ data at the end of the `transform` step _(last step of the current frame in multi-thread execution)_
   -  ```lua
      step  = 'transform',
      order = 100,
      requireAll = {
         ECS.Util.BasePartComponent,
         ECS.Util.PositionComponent,
         ECS.Util.RotationComponent,
         ECS.Util.EntityToBasePartSyncComponent
      },
      rejectAny = {
         ECS.Util.PositionInterpolationComponent,
         ECS.Util.RotationInterpolationComponent
      }
      ```
- _ECS.Util._**EntityToBasePartInterpolationTransformSystem**
   - Interpolates the position and rotation of a BasePart in the `transform` step. Allows the `process` step to be performed at low frequency with smooth rendering
   -  ```lua
      step  = 'transform',
      order = 100,
      requireAll = {
         ECS.Util.BasePartComponent,
         ECS.Util.PositionComponent,
         ECS.Util.RotationComponent,
         ECS.Util.PositionInterpolationComponent,
         ECS.Util.RotationInterpolationComponent,
         ECS.Util.EntityToBasePartSyncComponent
      }
      ```
- _ECS.Util._**MoveForwardSystem**
   - Simple forward movement system (position = position + speed * lookVector)
   -  ```lua
      step = 'process',
      requireAll = {
         ECS.Util.MoveSpeedComponent,
         ECS.Util.PositionComponent,
         ECS.Util.RotationComponent,
         ECS.Util.MoveForwardComponent,
      }
      ```

## Tutorial - Shooting Game

In this topic, we will see how to implement a simple shooting game, inspired by the [Unity ECS Tutorial - Player Shooting](https://www.youtube.com/watch?v=OQgmIHKXAdg&ab_channel=InfallibleCode)

The first step in using Roblox-ECS is to install the script. In roblox studio, in the Toolbox search field, type "Roblox-ECS". Install the script in `ReplicatedStorage> ECS`.

Now, let's give our character a gun, let's do it via code. Create a `LocalScript` named `tutorial` in `StarterPlayer > StarterCharacterScripts` and add the code below.

 ```lua
repeat wait() until game.Players.LocalPlayer.Character

local Players 	   = game:GetService("Players")
local Player 	   = Players.LocalPlayer
local Character	= Player.Character

local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

-- Our weapon
local rightHand = Character:WaitForChild("RightHand")
local weapon = Instance.new("Part", Character)
weapon.CanCollide = false
weapon.CastShadow = false
weapon.Size       = Vector3.new(0.2, 0.2, 2)
weapon.CFrame     = rightHand.CFrame + Vector3.new(0, 0, -1)
weapon.Color      = Color3.fromRGB(255, 0, 255)

local weldWeapon = Instance.new("WeldConstraint", weapon)
weldWeapon.Part0 = weapon
weldWeapon.Part1 = rightHand

-- weapon bullet spawn
local BulletSpawnPart   = Instance.new("Part", weapon)
BulletSpawnPart.CanCollide = false
BulletSpawnPart.CastShadow = false
BulletSpawnPart.Color      = Color3.fromRGB(255, 255, 0)
BulletSpawnPart.Size       = Vector3.new(0.6, 0.6, 0.6)
BulletSpawnPart.Shape      = Enum.PartType.Ball
BulletSpawnPart.CFrame     = weapon.CFrame + Vector3.new(0, 0, -1)

local weldBulletSpawn = Instance.new("WeldConstraint", BulletSpawnPart)
weldBulletSpawn.Part0 = BulletSpawnPart
weldBulletSpawn.Part1 = weapon
```

In the code above we are just adding a weapon _(a cube)_ in the character's hands. We make the connection using a `WeldConstraint`, we also add a reference point to use as the initial position of the projectiles (`BulletSpawnPart`) and adjust the CFrame of the same to be on the correct side of the weapon (front).

If you run the code now you will see something like the image below.

![](docs/tut_01.gif)

All ok, now, to have access to the position of `BulletSpawnPart` within an ECS world, we need to obtain the Position and Rotation of the object from the Workspace and save it as a component of an entity in the ECS world

Roblox-ECS already offers a generic method, some components and systems that already do this synchronization, so let's use it to create our `bulletEntity`

In the script above, before the creation of our weapon, we will define our ECS world, and below, at the end of the script, we will use the Roblox-ECS utility components to synchronize the `BulletSpawnPart` position and rotation

 ```lua
local world = ECS.newWorld()


local bulletSpawnEntity = ECS.Util.NewBasePartEntity(world, BulletSpawnPart, true, false)
```

The `ECS.Util.NewBasePartEntity` method is a facilitator that adds the `ECS.Util.BasePartComponent`, `ECS.Util.PositionComponent`, `ECS.Util.RotationComponent` components and can also add interpolation and sync tags, it has the following signature: `function ECS.Util.NewBasePartEntity(world, part, syncBasePartToEntity, syncEntityToBasePart, interpolate)`.

In our case, we only want it to sync the data from `BasePart` _(workspace)_ to our `Entity` _(ECS)_.

If you run the project now, you won't see any visual changes, because the systems that are running in this instance of the world don't have any logic that changes the behavior of our game yet.

Now let's create our first component. Thinking about a solution that can be used both on the client and on the server, we will create our components and systems in the `ReplicatedStorage > tutorial` directory. Within this directory we can create two folders, `component` and` system`.

In `ReplicatedStorage > tutorial > component`, create a `ModuleScript` with the name `WeaponComponent` and the contents below

 ```lua
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

return ECS.Component.register('Weapon')
```
 
That’s it, there’s no logic, no data typing

> **Note** Roblox-ECS does not validate the data handled by the systems, it is the responsibility of the developer to pay attention to the validations

Now, in our `tutorial` script, we will add this feature to our entity. Change the script by adding the code snippets below.

```lua
local Components = game.ReplicatedStorage:WaitForChild("tutorial"):WaitForChild("component")
local WeaponComponent = require(Components:WaitForChild("WeaponComponent"))


world.set(bulletSpawnEntity, WeaponComponent)
```

Ok. We created the world, we created an entity, we added features but nothing happened on the screen yet. This is because we only add features (components) to our entity, we have not yet defined any behavior that must be performed for those features

With our components and entity defined, it's time to create our first system, let's call it `PlayerShootingSystem`

For a better separation of responsibilities, we will divide our weapon system into two distinct systems, the first, `FiringSystem` will be responsible only for creating new projectiles in the workpace whenever necessary. The `PlayerShootingSystem`, which we are creating now, will be the responsible for notifying the `FiringSystem` when it is time to create new projectiles. It does this by monitoring user input and whenever the mouse button is clicked, it adds a tag component to our entity, indicating that a projectile must be created

Before moving on, let's create this component now. Create a `ModuleScript` in` ReplicatedStorage > tutorial > component` with the name `FiringComponent` and add the content below

 ```lua
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

return ECS.Component.register('Firing', nil, true)
```

Now, going back to our system, create a `ModuleScript` in `ReplicatedStorage > tutorial > system` with the name `PlayerShootingSystem` and the content below. This system is responsible for adding the `FiringComponent` tag to the entity that has the `WeaponComponent` component whenever the mouse button is pressed. Realize that when we make changes to the data currently being processed (entity or data array), it is necessary that our `update` method returns `true`, so that Roblox-ECS can inform other systems that this chunk has been changed, using dirty parameter

 ```lua
local UserInputService = game:GetService("UserInputService")
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

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
   update = function (time, world, dirty, entity, index, weapons)

      local isFiring = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)

      if isFiring  then
         world.set(entity, FiringComponent)
         return true
      end

      return false
   end
})
```

Continuing, we will now create the system responsible for creating the projectiles whenever our entity receives the tag `FiringComponent`, this will be the `FiringSystem`

Create a `ModuleScript` in `ReplicatedStorage > tutorial > system` with the name `FiringSystem` and the contents below. This system is responsible only for creating 3D objects in the scene that represent our projectiles. Realize that this system does not have the `update` method, as it is only interested in knowing when an entity with the expected characteristics appears in the world.

To correctly position our projectiles, this system uses data from the `ECS.Util.PositionComponent` and `ECS.Util.RotationComponent` components, which were added up there by the `ECS.Util.NewBasePartEntity` method during the creation of our entity. In order for our projectile to move, we added the `ECS.Util.MoveForwardComponent` and `ECS.Util.MoveSpeedComponent` components that are used by the `ECS.Util.MoveForwardSystem` system (Automatically added when creating the world)

Also note that our system has not made any changes to the current `chunk` or even the entity, so it always returns `false`

```lua

local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

local Components = game.ReplicatedStorage:WaitForChild("tutorial"):WaitForChild("component")
local FiringComponent = require(Components:WaitForChild("FiringComponent"))

return ECS.System.register({
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

         local bulletEntity = ECS.Util.NewBasePartEntity(world, bulletPart, false, true)
         world.set(bulletEntity, ECS.Util.MoveForwardComponent)
         world.set(bulletEntity, ECS.Util.MoveSpeedComponent, 0.1)
      end

      return false
   end
})
```

Now, let's add our systems to the world. Change the `tutorial` script by adding the codes below.

```lua
local Systems = game.ReplicatedStorage:WaitForChild("tutorial"):WaitForChild("system")
local FiringSystem         = require(Systems:WaitForChild("FiringSystem"))
local PlayerShootingSystem = require(Systems:WaitForChild("PlayerShootingSystem"))

world.addSystem(FiringSystem)
world.addSystem(PlayerShootingSystem)
```

Okay, let's test our game.

![](docs/tut_01a.gif)

Perfect, everything went completely well, except for one thing. We can only shoot once. Let's understand what's wrong:

Our `FiringSystem` is carrying out the expected behavior, creating projectiles whenever an entity with those characteristics appears in the world, `PlayerShootingSystem` is also carrying out what we expect, whenever we use the mouse click it defines that our entity has the `FiringComponent`, however, this `FiringComponent` feature never ceases to exist, it is being added only once, so the `onEnter` method of `FiringSystem` is only invoked once. Therefore, we need to remove the entity's `FiringComponent` after some time so that the `onEnter` method can be triggered more often.

To do this we will create a new system, its name will be `CleanupFiringSystem`, it will be responsible for removing the `FiringComponent` component from our entity after a period of time. In order for `CleanupFiringSystem` to do its job we need to change `FiringComponent`. It will stop being a component tag and start saving the moment of its creation, so that `CleanupFiringSystem` can validate this time and decide if it will remove it from the entity or not

Let's change the `ReplicatedStorage > tutorial > component > FiringComponent.lua` script to the content below. Our component now has a constructor, used to validate the input data and is no longer a tag component

```lua
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

return ECS.Component.register('Firing', function(firedAt)
   if firedAt == nil then
      error("firedAt is required")
   end

   return firedAt
end)
```

If you run the code now and try to shoot, you will see the following error in Roblox Studio's output:

```log
21:21:39.043 - ReplicatedStorage.tutorial.component.FiringComponent:5: firedAt is required
21:21:39.044 - Stack Begin
21:21:39.044 - Script 'ReplicatedStorage.tutorial.component.FiringComponent', Line 5
21:21:39.045 - Script 'ReplicatedStorage.ECS', Line 1349
21:21:39.045 - Script 'ReplicatedStorage.tutorial.system.PlayerShootingSystem', Line 22
21:21:39.045 - Script 'ReplicatedStorage.ECS', Line 1096
21:21:39.046 - Script 'ReplicatedStorage.ECS', Line 1635
21:21:39.047 - Script 'ReplicatedStorage.ECS', Line 1787
21:21:39.047 - Stack End
```

Note that `PlayerShootingSystem` is trying to add a `FiringComponent` to our entity, but the constructor method performed the validation and prevented the creation of the entity

We will update the `ReplicatedStorage > tutorial > system > PlayerShootingSystem.lua` script with the change below, when adding the component, we will pass to the constructor the current frame instant (`time.frame`)

```lua
if isFiring  then
   world.set(entity, FiringComponent, time.frame)
   return true
end
```

Ok, now that we are correctly starting `FiringComponent` with a moment for validation, we will create `CleanupFiringSystem`

Create a `ModuleScript` in `ReplicatedStorage > tutorial > system` with the name `CleanupFiringSystem` and the contents below. This system is responsible for removing the `FiringComponent` component after some time. This will allow the `FiringSystem` `onEnter` method to be invoked more often. In our implementation, we define that after `0.5` seconds the information that the shot was taken is removed from our entity, allowing it to be fired again in the sequence

```lua
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

local Components = game.ReplicatedStorage:WaitForChild("tutorial"):WaitForChild("component")
local FiringComponent = require(Components:WaitForChild("FiringComponent"))

return ECS.System.register({
   name = 'CleanupFiring',
   step = 'process',
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
```

We will also change the `tutorial` script to add the new system to the world

```lua
local CleanupFiringSystem  = require(Systems:WaitForChild("CleanupFiringSystem"))


world.addSystem(CleanupFiringSystem)
```

OK, now we can shoot more than once, however, we still have another problem. Realize that by pressing and holding the mouse button, our weapon does not fire anymore, it is only firing if I click, wait `0.5` seconds and click again

This is happening because the `update` method of `PlayerShootingSystem` is being invoked with each new frame, updating the time of the `FiringComponent` of our entity in each update (`world.set(entity, FiringComponent, time.frame)`) , this means that the logic of `CleanupFiringSystem` is not validated, since the elapsed time (`firedAt`) never exceeds 0.5 seconds. We need to filter this behavior.

Let's change the `PlayerShootingSystem` to obtain the desired behavior. We want him to add the `FiringComponent` to any entity that does not yet have this component, so he will never make changes to the data for that component.

Let's change the script `ReplicatedStorage > tutorial > system > PlayerShootingSystem.lua` with the code snippet below, applying a component filter, which at the moment only has `requireAll`, we will also add the `rejectAny` field, so that the method `Update` ignore entities that already have this component.

```lua
requireAll = {
   WeaponComponent
},
rejectAny = {
   FiringComponent
}
```

Okay, now we have the expected behavior, when pressing and holding the left mouse button, our weapon fires several projectiles respecting the interval defined in `CleanupFiringSystem`

![](docs/tut_02.gif)

However, you noticed one thing: The animation of our projectile is terrible, the projectiles are teleporting from one point to another, the animation of the movement is not smooth as expected

This happens due to **Fixed Timestep Jitter**, we will understand in the next topic


### Fixed Timestep Jitter

In our project, the system responsible for the movement of our projectiles is `ECS.Util.MoveForwardSystem`. The `update` method of this system is invoked 30 times per second, which is the standard update frequency for the `process` step of Roblox-ECS. Therefore, even though our game is being rendered at more than 60FPS, the simulation performed by this system is limited, causing this unwanted effect in the animation

To work around the problem we have two solutions:

**1 - Increase the frequency of our simulation**

At first glance, this seems to be the most suitable solution, just increase the frequency of our simulation to 60, 90 or 120Hz and our animation will be smooth

From a technical point of view this is true, our animation will run smoothly, but in return we will be spending a lot more computational resources to run all the systems that are programmed to update in the `process` step, and that is not a good thing

In addition to spending unnecessary processing resources, this will increase the battery consumption of mobile devices and, if the player's device (whether computer or cell phone) does not have enough processing power the heavy simulation will cause the FPS to drop in rendering

Another problem is if you increase the frequency of the simulation on your server, which in addition to having limited processing power needs to process data from all players simultaneously, decreasing the overall quality of your game

Just for the sake of experimentation, we will increase the frequency of execution of our world. Change the `tutorial` script to the following world boot configuration:

```lua
local world = ECS.newWorld(nil, { frequence = 60 })
```

![](docs/tut_03.gif)

Okay, you already noticed that the animation of our projectiles were smooth, but this at an expensive computational cost (and unnecessary in our case). This change causes the `process` step of the world to be performed at a frequency of 60Hz (60 times per second)

This is not the best solution, let's use something more efficient

**2 - Do Interpolation**

Interpolation is a technique that allows, from two values ​​(A and B), to calculate a third value (C) that represents a ratio between A and B.

Example:
   - If `A = 0` and `B = 10`, for the ratio of `0.5` the value of `C = 5` _(C is between A and B exactly 0.5)_
   - If our ratio were `0.95`, the `C` value would be `9.5`

In game development, we use interpolation to calculate a spatial position _(`Vector3`)_, or a rotation that is between two previously calculated values ​​_(position of the previous frame and position of the last simulation)_ using the elapsed time as a factor _(if the simulation takes 0.24 seconds and 0.12 seconds has passed since the last simulation, the factor is ~ 0.5)_

With that, we can reduce the frequency of the simulation _(heavy calculation)_, save the last two positions/rotations and apply the interpolation as we render the screen, in our case, doing this in the `transform` step _(which is running at a higher frequency, 60FPS for example)_

Roblox-ECS already offers the interpolation factor _(interpolationAlpha)_ to be used in systems that wish to apply the interpolation. It also already provides a data synchronization system between the position and rotation of the entity to update the `BasePart` through this interpolation.

We will then make the changes to verify the use of interpolation and decrease the cost of processing our game.

In the `tutorial` script, we will decrease the execution frequency of the world, say for 10Hz

```lua
local world = ECS.newWorld(nil, { frequence = 10 })
```

![](docs/tut_04.gif)

If you run the game now you will see that the animation is horrible, we will now inform you that we want to use interpolation in the entities of our projectiles.

Change the `ReplicatedStorage > tutorial > system > FiringSystem.lua` script, in the line where our bulletEntity is initializing, using the utility method, modify it

```lua
local bulletEntity = ECS.Util.NewBasePartEntity(world, bulletPart, false, true)
```

to

```lua
local bulletEntity = ECS.Util.NewBasePartEntity(world, bulletPart, false, true, true)
```

Informing that we want an entity that receives the tags and components used by the system if interpolated synchronization.

The result, as expected, is a totally smooth animation and using minimal CPU resources in the `process` step (only 10 times per second)

![](docs/tut_05.gif)

And we come to the end of the tutorial, for more information on these concepts, see
- [Game Loop by Robert Nystrom](http://gameprogrammingpatterns.com/game-loop.html)
- [Fix Your Timestep! by Glenn Fiedler](https://gafferongames.com/post/fix_your_timestep/)
- [The Game Loop By Gilles Bellot](https://bell0bytes.eu/the-game-loop/)

## Feedback, Requests and Roadmap

Please use [GitHub issues] for feedback, questions or comments.

If you have specific feature requests or would like to vote on what others are recommending, please go to the [GitHub issues] section as well. I would love to see what you are thinking.

## Contributing

You can contribute in many ways to this project.

### Translating and documenting

I'm not a native speaker of the English language, so you may have noticed a lot of grammar errors in this documentation.

You can FORK this project and suggest improvements to this document (https://github.com/nidorx/roblox-ecs/edit/master/README.md).

If you find it more convenient, report a issue with the details on [GitHub issues].

### Reporting Issues

If you have encountered a problem with this component please file a defect on [GitHub issues].

Describe as much detail as possible to get the problem reproduced and eventually corrected.

### Fixing defects and adding improvements

1. Fork it (<https://github.com/nidorx/roblox-ecs/fork>)
2. Commit your changes (`git commit -am 'Add some fooBar'`)
3. Push to your master branch (`git push`)
4. Create a new Pull Request

## License

This code is distributed under the terms and conditions of the [MIT license](LICENSE).


[GitHub issues]: https://github.com/nidorx/roblox-ecs/issues