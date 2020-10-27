<div align="center">   
    <img src="https://github.com/nidorx/ecs-lib/raw/master/logo.jpg" width="882" />
</div>

**roblox-ecs-lib** is a tiny and easy to use [ECS _(Entity Component System)_](https://en.wikipedia.org/wiki/Entity_component_system) library for game programming on the Roblox platform (It is written in Lua easy to adapt to other platforms)


## Table of contents
   * [Documentation](#documentation)
      * [World](#world)
      * [Component](#component)
         * [Raw data access](#raw-data-access)
         * [Secondary attributes](#secondary-attributes)
      * [Entity](#entity)
         * [Adding and removing from the world](#adding-and-removing-from-the-world)
         * [Adding and removing components](#adding-and-removing-components)
         * [Subscribing to changes](#subscribing-to-changes)
         * [Accessing components](#accessing-components)
      * [System](#system)
         * [Adding and removing from the world](#adding-and-removing-from-the-world-1)
         * [Limiting frequency (FPS)](#limiting-frequency-fps)
         * [Time Scaling - Slow motion effect](#time-scaling---slow-motion-effect)
             * [Pausing](#pausing)
         * [Global systems - all entities](#global-systems---all-entities)
         * [Before and After update](#before-and-after-update)
         * [Enter - When adding new entities](#enter---when-adding-new-entities)
         * [Change - When you add or remove components](#change---when-you-add-or-remove-components)
         * [Exit - When removing entities](#exit---when-removing-entities)
   * [API](#api)
      * [ECS](#ecs)
      * [Component](#component-1)
         * [Component&lt;T&gt;](#componentt)
      * [Entity](#entity-1)
      * [System](#system-1)
   * [Feedback, Requests and Roadmap](#feedback-requests-and-roadmap)
   * [Contributing](#contributing)
      * [Translating and documenting](#translating-and-documenting)
      * [Reporting Issues](#reporting-issues)
      * [Fixing defects and adding improvements](#fixing-defects-and-adding-improvements)
   * [License](#license)


## Documentation

Entity-Component-System (ECS) is a distributed and compositional architectural design pattern that is mostly used in game development. It enables flexible decoupling of domain-specific behaviour, which overcomes many of the drawbacks of traditional object-oriented inheritance.

For further details:

- [Entity Systems Wiki](http://entity-systems.wikidot.com/)
- [Evolve Your Hierarchy](http://cowboyprogramming.com/2007/01/05/evolve-your-heirachy/)
- [ECS on Wikipedia](https://en.wikipedia.org/wiki/Entity_component_system)
- [Entity Component Systems in Elixir](https://yos.io/2016/09/17/entity-component-systems/)

## Roblox Pipeline

Before going into the details, let's review some important concepts about how the Roblox game engine works.

Most likely you have seen the illustration below, made by zeuxcg and enriched by Fractality_alt. It describes the roblox rendering pipeline. Let's redraw it so that it is clearer what happens in each frame of a game in roblox

[![](docs/pipeline_old.png)](https://devforum.roblox.com/t/runservice-heartbeat-switching-to-variable-frequency/23509/7)

Ready: In the new image, we have a clear separation (gap between CPU1 and CPU2) of the roblox rendering process, which occurs in parallel with the simulation and processing (game logic) of the next screen.

The green arrows indicate the start of processing of the new frame and the return of execution after the completion of the two processes that are being executed in parallel (rendering of the previous screen and processing of the current frame).

The complete information on the order of execution can be seen at https://developer.roblox.com/en-us/articles/task-scheduler

[![](docs/pipeline.png)](https://developer.roblox.com/en-us/articles/task-scheduler)

Based on this model, roblox-ecs-lib organizes the execution of the systems in the following events. We call them steps

![](docs/pipeline_ecs_resume.png)

![](docs/pipeline_ecs_steps.png)

### processIn
Executed once per frame.

This is the first step to be executed in a frame. Use this step to run systems that translate the user's input or the current state of the workspace to entity components, which can be processed by specialized systems in the next steps

Eg. Use the UserInputService to register the player's inputs in the current frame in a pool of inputs, and, in the PROCESS_IN step, translate these commands to the player's components. Realize that the same logic can be used to receive entries from the server and update local entities that represent other players

```lua

-- InputHandlerUtils.lua
local UserInputService = game:GetService("UserInputService")

local pool = {
   FIRE = false
}

-- clear frame inputs
function pool.clear()
   pool = {
      FIRE = false
   }
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		pool.FIRE = true
	end
end)

return pool

---------------------------------------------------------------------------------------

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

### process
Executed 0 or more times per frame

This step allows the execution of systems for game logic independent of Frame-Rate, obtaining determinism in the simulation of the rules of the game

Independent Frame-Rate games are games that run at the same speed, no matter the frame rate. For example, a game can run at 30 FPS (frames per second) on a slow computer and 60 FPS on a fast one. A game independent of the frame rate progresses at the same speed on both computers (the objects appear to move at the same speed). On the other hand, a frame rate-dependent game advances at half the speed of the slow computer, in a kind of slow motion effect (read more at https://gafferongames.com/post/fix_your_timestep/).

Making frame rate independent games is important to ensure that your game is enjoyable and playable for everyone, no matter what type of computer they have. Games that slow down when the frame rate drops can seriously affect gameplay, making players frustrated and giving up! In addition, some systems have screens with different refresh rates, such as 120 Hz, so independence of the frame rate is important to ensure that the game does not accelerate and is impossibly fast on these devices.

This step can also be used to perform some physical simulations that are not met (or should not be performed) by the roblox internal physics engine.

The standard frequency for executing this step in a world is 30Hz, which can be configured when creating a world.

In the tutorial topic there is a demonstration of the use of interpolation for smooth rendering display even when updating the simulation in just 10Hz

### processOut
Executed once for the frame

Use this step when your systems make changes to the components and these changes imply the behavior of the roblox internal physics simulations, therefore, the workspace needs to receive the update for the correct physics engine simulation

### transform
Executed once per frame.

Use this step for systems that react to changes made by the roblox physics engine or to perform transformations on game objects based on entity components (ECS to Workspace).

Ex. In a soccer game, after running the physics engine, check if the ball touched the net, scoring a point

Ex2. In a game that is not based on the roblox physics engine, perform the interpolation of objects based on the positions calculated by the specialized systems that were executed in the PROCESS step

### render
Executed once per frame.

Use this step to run systems that perform updates on things related to the camera and user interface.

IMPORTANT! Only run light systems here, as the screen design and the processing of the next frame will only happen after the completion of this step. If it is necessary to make transformations on world objects (interpolations, complex calculations), use the TRANSFORM step



## roblox-ecs-lib

### World

A ECS instance is used to describe you game world or **Entity System** if you will. The World is a container for Entities, Components, and Systems. You can optionally enter the list of systems you already want to add in the world, as well as change some settings in this world

```lua
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

local world = ECS.newWorld({SystemA, SystemB}, { frequence = 30, disableDefaultSystems = false, disableAutoUpdate = false})
```

### Component

Represents the different facets of an entity, such as position, velocity, geometry, physics, and hit points for example. Components store only raw data for one aspect of the object, and how it interacts with the world.

In other words, the component labels the entity as having this particular aspect.


```lua
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

return ECS.Component.register('Box')
```

The register method generates a new component type, which is a unique identifier. 

#### Constructor

If desired, you can pass a constructor to the component. The constructor will be invoked whenever the component is added to an entity

```lua
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

return ECS.Component.register('Box', function( width, height, depth)
   -- validations 
   if width == nil then width = 1 end

   return {width, height, depth}
end)
```

#### Tag component

The tag component or "zero size component" is a special case where a component does not contain any data.

Example: EnemyComponent can indicate that an entity is an enemy, with no data, just a marker

```lua
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

return ECS.Component.register('Enemy', nil, true)
```

### Entity

The entity is a general purpose object. An entity is what you use to describe an object in your game. e.g. a player, a gun, etc. It consists only of a unique ID and the list of components that make up this entity.

```lua
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

local world = ECS.newWorld()

-- create a entity
local cubeEntity = world.create()

```

#### Adding and removing components 

At any point in the entity's life cycle, you can add or remove components, using `set` and `remove` methods.

```lua

local ColorComponent = require(game.ReplicatedStorage:WaitForChild("ColorComponent"))
local BoxComponent = require(game.ReplicatedStorage:WaitForChild("BoxComponent"))

-- add components to entity
world.set(cubeEntity, ColorComponent, Color3.new(1, 0, 0))
world.set(cubeEntity, BoxComponent, 10, 10, 10)


-- remove component
world.remove(cubeEntity, BoxComponent)
```

#### Accessing components data

To gain access to the components data of an entity, simply use the `get` method of the `world`.

```lua
local color = world.get(cubeEntity, ColorComponent)
```

#### Check if it is

To find out if an entity has a specific component, use the `has` method of the `world`

```lua
if world.has(cubeEntity, ColorComponent) then
   -- ...
end
```
#### Remove an entity

To remove an entity, use the "remove" method from the world, this time without informing the component.

```lua
world.remove(cubeEntity)
```

**IMPORTANT!** The removal of the entity is only carried out at the end of the execution of the current step, when invoking the `remove` method, the engine cleans the data of that entity and marks it as removed. To check if an entity is marked for removal, use the `alive` method of the world.

```lua
if not world.alive(cubeEntity) then
   -- ...
end
```


### System

Represents the logic that transforms component data of an entity from its current state to its next state. A system runs on entities that have a specific set of component types.

In **ecs-lib**, a system has a strong connection with component types. You must define which components this system works on in the `System` registry.

If the `update` method is implemented, it will be invoked respecting the order parameter within the configured step. Whenever an entity with the characteristics expected by this system is added on world, the system is informed via the `enter` method.

```lua
local UserInputService = game:GetService("UserInputService")
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

-- Components
local Components = game.ReplicatedStorage:WaitForChild("Components")
local FiringComponent = require(Components:WaitForChild("FiringComponent"))
local WeaponComponent = require(Components:WaitForChild("WeaponComponent"))

return ECS.System.register({
   name = 'PlayerShooting',
   step = 'processIn',
   requireAll = {
      WeaponComponent
   },
   rejectAny = {
      FiringComponent
   },
   enter = function(time, world, entity, index, weapons)
      -- on new entity
      print('New entity added ', entity)
      return false
   end,
   beforeUpdate = function(time, interpolation, world, system)
      -- called before update
      print(system.config.customConfig)
   end,
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
```

#### UPDATE method

The update method has the following signature:

```lua
update = function (time, world, dirty, entity, index, [component_A_data, component_N_data...])

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
- **component_N_data** : The component arrays that are processed by this system. The ordering of the parameters follows the order defined in the `requireAll` or `requireAny` attributes of the system. As in this architecture you have direct access to the data of the components, it is necessary to inform on the return of the function if any changes were made to this data.


#### Adding to the world

To add a system to the world, simply use the `addSystem` method. You can optionally change the order of execution and pass any configuration parameters that are expected by your system

```lua
local PlayerShootingSystem = require(game.ReplicatedStorage:WaitForChild("PlayerShootingSystem"))


world.addSystem(PlayerShootingSystem, newOrder, { customConfig = 'Hello' })
```

## Feedback, Requests and Roadmap

Please use [GitHub issues] for feedback, questions or comments.

If you have specific feature requests or would like to vote on what others are recommending, please go to the [GitHub issues] section as well. I would love to see what you are thinking.

## Contributing

You can contribute in many ways to this project.

### Translating and documenting

I'm not a native speaker of the English language, so you may have noticed a lot of grammar errors in this documentation.

You can FORK this project and suggest improvements to this document (https://github.com/nidorx/ecs-lib/edit/master/README.md).

If you find it more convenient, report a issue with the details on [GitHub issues].

### Reporting Issues

If you have encountered a problem with this component please file a defect on [GitHub issues].

Describe as much detail as possible to get the problem reproduced and eventually corrected.

### Fixing defects and adding improvements

1. Fork it (<https://github.com/nidorx/ecs-lib/fork>)
2. Commit your changes (`git commit -am 'Add some fooBar'`)
3. Push to your master branch (`git push`)
4. Create a new Pull Request

## License

This code is distributed under the terms and conditions of the [MIT license](LICENSE).


[GitHub issues]: https://github.com/nidorx/ecs-lib/issues
