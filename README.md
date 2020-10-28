![](repository-open-graph.png)

**Roblox-ECS** is a tiny and easy to use [ECS _(Entity Component System)_](https://en.wikipedia.org/wiki/Entity_component_system) engine for game development on the Roblox platform

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
4. **Invocation of the systems "enter" method**
   - After cleaning the environment, Roblox-ECS invokes the enter method for each entity that has been added (or that has undergone component changes and now matches the signature expected by some system)


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

If the `update` method is implemented, it will be invoked respecting the order parameter within the configured step. Whenever an entity with the characteristics expected by this system is added on world, the system is informed via the `enter` method.

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
   enter = function(time, world, entity, index, weapons)
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


O primeiro passo para utilizar o Roblox-ECS é fazer a instalação do script. No roblox studio, no campo de busca do Toolbox digite "Roblox-ECS". Faça a instalação do script em `ReplicatedStorage > ECS`.

Agora, vamos dar uma arma para o nosso personagem, vamos fazer isso via código. Crie um `LocalScript` com nome `tutorial` em `StarterPlayer > StarterCharacterScripts` e adicione o código abaixo. 

 ```lua
repeat wait() until game.Players.LocalPlayer.Character

local Players 	   = game:GetService("Players")
local Player 	   = Players.LocalPlayer
local Character	= Player.Character

   
-- services
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

-- weapone bullet spawn
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

No código acima estamos apenas adicionando uma arma (um cubo) nas mãos do personagem. Fazemos a ligação usando um `WeldConstraint`, adicionamos também um ponto de referencia para usarmos como posição inicial dos projéteis (`BulletSpawnPart`) e ajustamos o CFrame do mesmo para ficar no lado correto da arma (frente). 

Se executar o código agora você verá algo parecido com a imagem abaixo.

![](docs/tut_01.gif)

Tudo ok, agora, para termos acesso à posição do `BulletSpawnPart` dentro de um mundo ECS, precisamos obter a Posição e Rotação do objeto a partir do Workspace e salvar como componente de uma entidade no mundo ECS. 

o Roblox-ECS já disponibiliza um método genérico e alguns sistemas e componentes que já faz essa sincronização para nós, vamos então usar para criar o nosso `bulletEntity`. 

No script acima, antes da criação da nossa arma, vamos definir o nosso mundo ECS, e abaixo, no final do script, vamos utilizar os componentes utilitários do Roblox-ECS para sincronizar a posição e rotação do `BulletSpawnPart`

 ```lua
 --- requires ...

-- Our world
local world = ECS.newWorld()


-- Our weapon
---local rightHand = Ch...


-- Create our entity
local bulletSpawnEntity = ECS.Util.NewBasePartEntity(world, BulletSpawnPart, true, false)
```

O método `ECS.Util.NewBasePartEntity` é um facilitador que adiciona os componentes BasePart, Position, Rotation e também pode adicionar as tag de interpolação e sincronia, ele tem a seguinte assinatura: `function ECS.Util.NewBasePartEntity(world, part, syncBasePartToEntity, syncEntityToBasePart, interpolate)`. 

No nosso caso, nós só desejamos que ele realize a sincronia dos dados do BasePart (workspace) para a nossa Entidade (ECS).

Se executar o projeto agora, você não verá nenhuma mudança visual, pois os sistemas que estão executando nessa instancia do mundo não tem nenhuma logica que modifica o comportamento do nosso jogo ainda.

**WeaponComponent**

Agora vamos criar o nosso primeiro componente. Pensando em uma solução que pode ser usada tanto no cliente como no servidor, vamos criar nosssos componentes e sistemas no diretório `ReplicatedStorage > tutorial`. Dentro deste diretório, podemos criar duas pastas `component` e `system`.

Em `ReplicatedStorage > tutorial > component`, cria um `ModuleScript` com nome `WeaponComponent` e o conteúdo abaixo.

 ```lua
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

return ECS.Component.register('Weapon')
```
 
Só isso, não existe lógica, nem tipagem de dados, o Roblox-ECS não faz validação dos dados manipulados pelos sistemas, é de responsabilidade do desenvolvedor se atentar para as validações de tipo.

Agora, no nossso script `tutorial`, vamos adicionar essa caracteristíca na nossa entidade. Altere o script adicionando os trechos abaixo.

```lua
-- Components
local Components = game.ReplicatedStorage:WaitForChild("tutorial"):WaitForChild("component")
local WeaponComponent = require(Components:WaitForChild("WeaponComponent"))


-- Mark as weapon
world.set(bulletSpawnEntity, WeaponComponent)
```

Ok. Nós criamos o mundo, criamos uma entidade, adicionamos características mas nada aconteceu na tela ainda. Isso porque nós só adicionamos características (componentes) em nossa entidade, nós ainda não definimos nenhum comportamento que deve ser executado para essas características.

Com nossos componentes e entidade definida, é hora de criar o nosso primeiro sistema, vamos chama-lo `PlayerShootingSystem`.

Para melhor separação das responsabilidades, vamos dividir o nosso sistema de arma em dois sistemas distintos, o primeiro, `FiringSystem` será responsável apenas por criar novos projéteis no workpace sempre que necessário, já o `PlayerShootingSystem`, que estamos criando agora,  será o responsável por notificar o `FiringSystem` quando for o tempo de criar novos projéteis. Ele faz isso monitorando as entradas do usuário e sempre que o botão do mouse for acionado, adiciona um Tag Component na nossa entidade, indicando que um projétil deve ser criado.

Antes de seguir em frente, vamos criar este componente agora. Crie um `ModuleScript` em `ReplicatedStorage > tutorial > component` com nome `FiringComponent` e adicione o conteúdo abaixo

 ```lua
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

return ECS.Component.register('Firing', nil, true)
```

Agora, voltando para o nosso sistema, crie um `ModuleScript` em `ReplicatedStorage > tutorial > system` com nome `PlayerShootingSystem` e o conteúdo abaixo. Este sistema é responsável por adicionar a tag `FiringComponent` na entidade que possui o componente `WeaponComponent` sempre que o botão do mouse é pressionado. Perceba que quando nós realizamos alteração nos dados sendo processados no momento (entidade ou array de dados), é necessário que nosso método `update` retorne `true`, para que o Roblox-ECS possa informar aos outros sistemas que este chunk sofreu alteração por meio do parametro `dirty`.

 ```lua
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

Dando continuidade, vamos agora criar o sistema responsável por criar os projéteis sempre que a nossa entidade receber a tag `FiringComponent`, este será o `FiringSystem`

Crie um `ModuleScript` em `ReplicatedStorage > tutorial > system` com nome `FiringSystem` e o conteúdo abaixo. Este sistema é responsáel apenas por criar objetos 3D na cena que representam os nosso projéteis. Perceba que esse sistema não possui o método `update`, pois ele só está interessando em saber quando uma entidade com as características esperadas surgir no mundo.

Para posicionar corretamente os nosso projéteis, este sistema utiliza os dados provenientes dos componente `ECS.Util.PositionComponent` e `ECS.Util.RotationComponent`, que foram adicionados lá encima pelo método utilitário `ECS.Util.NewBasePartEntity` durante a criação da nossa entidade. Para que o nosso projétil possa movimentar-se, nós adicionamos nele os componentes `ECS.Util.MoveForwardComponent` e `ECS.Util.MoveSpeedComponent` que são usados pelo sistema `ECS.Util.MoveForwardSystem` (adicionado automaticamente na construção do mundo). 

Perceba também que o nosso sistema não fez nenhuma modificação no `chunk` atual nem mesmo na entidade, portanto sempre retorna `false`

```lua

local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

-- Components
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

         local bulletEntity = ECS.Util.NewBasePartEntity(world, bulletPart, false, true, true)
         world.set(bulletEntity, ECS.Util.MoveForwardComponent)
         world.set(bulletEntity, ECS.Util.MoveSpeedComponent, 0.1)
      end

      return false
   end
})
```

Agora, vamos adicionar nossos sistemas no mundo. Altere o script `tutorial` adicionando os trechos abaixo.

```lua
-- Systems
local Systems = game.ReplicatedStorage:WaitForChild("tutorial"):WaitForChild("system")
local FiringSystem         = require(Systems:WaitForChild("FiringSystem"))
local PlayerShootingSystem = require(Systems:WaitForChild("PlayerShootingSystem"))

-- ...

world.addSystem(FiringSystem)
world.addSystem(PlayerShootingSystem)
```

Ok, vamos testar o nosso jogo.


Perfeito, tudo correu completamente bem, exceto por uma coisa. Nós só consguimos atirar uma única vez. Vamos entender o que há de errado:

O nosso `FiringSystem` está realizando o comportamento esperado, criando projéteis sempre que uma entidade com aquelas características aparece no mundo, o `PlayerShootingSystem` também está realizando o que esperamos, sempre que usamos o clique do mouse ele define que a nossa entidade possui o `FiringComponent`, porém, essa caracteristica `FiringComponent`, nunca deixa de existir, está sendo adicionada somente uma única vez, portanto o método `enter` do `FiringSystem`  só é invocado uma única vez. Portanto, precisamos remover o `FiringComponent` da entidade após algum período de tempo para que o método `enter` possa ser acionado mais vezes.

Vamos fazer isso, vamos criar um novo sistema, o nome dele será `CleanupFiringSystem`, ele será responsáel por remover o componente `FiringComponent` da nossa entidade após um período de tempo. Para que o novo `CleanupFiringSystem` possa realizar seu trabalho, nós precisamos alterar o `FiringComponent`, ele deixará de ser um Tag Componente e passará a salvar o instante de sua criação, para que o `CleanupFiringSystem` possa validar essa data e decidir se vai remove-lo da entidade ou não. 

Vamos alterar o script  `ReplicatedStorage > tutorial > component > FiringComponent.lua` para o conteúdo abaixo. O nosso componente agora tem um construtor, usado para validar os dados de entrada e deixou de ser um Tag Component.

```lua
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

return ECS.Component.register('Firing', function(firedAt)
   if firedAt == nil then
      error("firedAt is required")
   end

   return firedAt
end)
```

Se você executar o código agora e tentar atirar, verá o seguinte erro na saída do Roblox Studio:

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

Veja que o `PlayerShootingSystem` está tentando adicionar um `FiringComponent` na nossa entidade mas o construtor realizou a validação e impediu a criação da entidade. 

Vamos atualizar o script `ReplicatedStorage > tutorial > system > PlayerShootingSystem.lua` com a alteração abaixo, ao adicionar o componente, vamos passar para o construtor o instant do frame atual (`time.frame`)

```lua
if isFiring  then
   world.set(entity, FiringComponent, time.frame)
   return true
end
```

Ok, agora que estamos iniciando corretamente nosso componente com um instante para validação, vamos criar o nosso `CleanupFiringSystem`

Crie um `ModuleScript` em `ReplicatedStorage > tutorial > system` com nome `CleanupFiringSystem` e o conteúdo abaixo. Este sistema é responsáel por remover o componente `FiringComponent` após algum intervalo de tempo. Isso permitirá que o método `enter` do `FiringSystem` seja invocado mais vezes. Na nossa implementação, definimos que após `0.5` segundos a informação de que o disparo foi realizado é removido da nossa entidade, permitindo que seja disparado novamente na sequencia.


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

Vamos alterar também script `tutorial` para adicionar o novo sistema no mundo.

```lua
-- Systems
local CleanupFiringSystem  = require(Systems:WaitForChild("CleanupFiringSystem"))

-- ...

world.addSystem(CleanupFiringSystem)
```

Ok, agora nós conseguimos atirar mais de uma vez, porém, temos ainda outro problema. Perceba que ao pressionar e ficar segurado o botão do mouse a nossa arma não realiza mais disparos, ela só está disparando se eu clicar, esperar `0.5` segundos e clicar novamente. 

Isso está acontecendo pois o método `update` do `PlayerShootingSystem` está sendo invocado a cada novo frame, atualizando a data do `FiringComponent` da nossa entidade a todo instante (`world.set(entity, FiringComponent, time.frame)`), isso faz com que a lógica do `CleanupFiringSystem` não seja validada, visto que o tempo transcorrido (`firedAt`) nunca seja superior a 0.5 segundos. Nós precisamos filtrar esse comportamento.

Vamos alterar o `PlayerShootingSystem` para obtermos o comportamento desejado. Queremos que ele adicione o `FiringComponent` em qualquer entidade que ainda não possua esse componente, desse modo, ele nunca fará a alteraçao nos dados desse componente. 

Vamos alterar o script  `ReplicatedStorage > tutorial > system > PlayerShootingSystem.lua` com o trecho de código abaixo, aplicando um filtro de componentes, que no momento só possui `requireAll`, vamos adicionar tambem o campo `rejectAny`, para que o método `update` ignore entidades que já possuam este componente.

```lua
-- ... register
requireAll = {
   WeaponComponent
},
rejectAny = {
   FiringComponent
}
```
Pronto, agora temos o comportamento esperado, ao pressionar e segurar o botão esquerdo do mouse a nossa arma dispara diversos projéteis respeitando o intervalo definido no `CleanupFiringSystem`. 

![](docs/tut_02.gif)

Porém, você percebeu uma coisa: A animação do nosso projétil está péssima, os projéteis estão teleportando de um ponto para outro, a animação do movimento não está suave como esperado.

Isso acontece devido ao **Fixed Timestep Jitter**, vamos entender no proximo tópico


### Fixed Timestep Jitter

No nosso projeto, o sistema resposável pelo movimento dos nossos projéteis é o `ECS.Util.MoveForwardSystem`. O método `update` desse sistema é invocado 30 vezes por segundo, que é a frequencia padrão de atualização para o passo `process` do Roblox-ECS. Portanto, apesar de o nosso jogo estar sendo renderizado a mais de 60 FPS, a simulação realizada por esse sistema está limitado, causando esse efeito indesejado na animação.

Para contornar o problema nós temos duas soluções:

**1 - Aumentar a frequencia da nossa simulação**

À primeira vista, esse parece ser a solução mais adequada, basta aumentar a frequencia da nossa simulação para 60, 90 ou 120Hz e nossa animação ficará suave. 

Do ponto de vista técnico isso é verdade, a nossa animação correrá suave, mas em contrapartida nós estaremos gastando muito mais recurso computacional para executar todos os sistemas que são programados para atualizar no passo `process`, e isso não é bom. 

Além de gastar recurso de processamento desnecessário, isso aumentará o consumo de bateria de dispositivos móveis e, se o dispositivo (seja computador ou celular) do jogador não tiver poder de processamento suficiente a simulação pesada irá causar a queda de FPS na renderização.

Outro ponto de problema é se você aumentar muito a frequencia da simulação no seu servidor, que além de tem poder de processamento limitado precisa processar dados de todos os jogadores simultaneamente, diminuindo a qualidade geral do seu jogo.

Apenas para fins de experimentação, vamos aumentar a frequencia de execução do nosso mundo. Altere o scrip `tutorial` para a seguinte configuração de inicialização do mundo:

```lua
local world = ECS.newWorld(nil, { frequence = 60 })
```

![](docs/tut_03.gif)

Pronto, você já percebeu que a animação dos nossos projéteis ficaram suaves, mas isso à um custo computacional caro (e desnecessário no nosso caso). Essa alteração faz com que o passo `process` do mundo seja executado a frequencia de 60Hz (60 vezes por segundo)

Essa não é a melhor solução, vamos usar algo mais eficiente

**2 - Realizar Interpolação**

Interpolação é uma técnica que permite, a partir de dois valores (A e B), calcular um terceiro valor (C) que represente uma razão entre A e B.

Exemplo: 
   - Se A = 0 e B = 10, para a razão de 0.5 o valor de C = 5 (C está entre A e B exatamente 0.5) 
   - Se a nossa razão fosse 0.95, o valor de C seria 9.5

No desenvolvimento de jogos, usamos a interpolação para calcular uma posição espacial (Vector3), ou uma rotação que esteja entre dois valores calculados anteriormente (posição do frame anterior e posição da última simulação) usando o tempo transcorrido como fator (se a simulação demora 0.24 segundos e já transcorreu 0.12 segundos desde a ultima simulação, o fator é ~0.5).

Com isso, nós podemos reduzir a frequencia da simulação (cálculo pesado), salvar as duas últimas posições/rotações e aplicar a interpolação a medida que vamos renderizar a tela (que está rodando em uma frequencia maior, 60FPS por exemplo) 

O Roblox-ECS já disponibiliza o fator para interpolação (interpolationAlpha) para ser usado nos sistemas que desejam aplicar a interpolação. Ele também já disponibiliza um sistema de sincronização de dados entre a posição e rotação da entidade para atualizar o `BasePart` por meio dessa interpolação.

Vamos então fazer as alterações para verificar o uso da interpolação e diminuir o custo de processamento do nosso jogo.

No script `tutorial`, vamos dimiuir a frequencia de execução do mundo, digamos que para 10Hz

```lua
local world = ECS.newWorld(nil, { frequence = 10 })
```

![](docs/tut_04.gif)

Se você executar o jogo agora verá que a animação está horrível, vamos agora informar que desejamos utilizar a interpolação nas entidades dos nossos projéteis.

Altere o script  `ReplicatedStorage > tutorial > system > FiringSystem.lua`, na linha onde está inicializando o nosso bulletEntity, com uso do método utilitário, modifique de 

```lua
local bulletEntity = ECS.Util.NewBasePartEntity(world, bulletPart, false, true)
```

para

```lua
local bulletEntity = ECS.Util.NewBasePartEntity(world, bulletPart, false, true, true)
```

Informando que desejamos uma entidade que recebe as tags e componentes usadas pelos sistema se sincronização interpolada.

O resultado, como esperado, é uma animação totalmente lisa e utilizando o mínimo de recursos da CPU no passo `transform` (apenas 10 vezes por segundo)

![](docs/tut_05.gif)


Para mais informações sobre estes conceitos, consulte
- [Game Loop by Robert Nystrom](http://gameprogrammingpatterns.com/game-loop.html)
- [Fix Your Timestep! by Glenn Fiedler](https://gafferongames.com/post/fix_your_timestep/)
- [The Game Loop By Gilles Bellot](https://bell0bytes.eu/the-game-loop/)


@TODO

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