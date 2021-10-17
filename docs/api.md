# API
<div class="api-docs">


# ECS
- `ECS.Query`
   - _@type_ `QueryClass`
- `ECS.Archetype`
   - _@type_ `ArchetypeClass`
- `ECS.World(systemClasses, frequency, disableAutoUpdate)`
   - Create a new world instance
   - _@param_ `systemClasses` `SystemClass[]` _optional_ Array of system classes
   - _@param_ `frequency` `number` _optional_ Define the frequency that the `process` step will be executed. Default 30
   - _@param_ `disableAutoUpdate` `bool` _optional_ When `~= false`, the world automatically registers in the `LoopManager`, 
   receiving the `World:Update()` method from it. Default false
   - _@return_ `World`
- `ECS.System(step, order, query, updateFn)`
   - Create new System Class
   - _@param_ `step` `process|transform|render|task`
   - _@param_ `order` `number` _optional_ Allows you to set an execution order (for systems that are not `task`). Default 50
   - _@param_ `query` `Query|QueryBuilder` _optional_ Filters the entities that will be processed by this system
   - _@param_ `updateFn` `Function(self, Time)` _optional_ A shortcut for creating systems that only have the Update method
   - _@return_ `SystemClass`
- `ECS.Component(template)`
   - Register a new ComponentClass
   - _@param_ `template` `table|function(table):table|any` 
      - When `table`, this template will be used for creating component instances
      - When it's a `function`, it will be invoked when a new component is instantiated. The creation parameter of the 
      component is passed to template function
      - If the template type is different from `table` and `function`, **ECS Lua** will generate a template in the format 
      `{ value = template }`.
   - _@return_ `ComponentClass`
- `ECS.SetLoopManager(manager)`
   - Defines the LoopManager that will be used by the worlds to receive the automatic update
   - _@param_ `manager` `LoopManager`

# Archetype

An Archetype is a unique combination of component types. The EntityRepository uses the archetype to group all 
entities that have the same sets of components.

An entity can change archetype fluidly over its lifespan. For example, when you add or remove components, the archetype 
of the affected entity changes.

An archetype object is not a container; rather it is an identifier to each unique combination of component types that 
an application has created at run time, either directly or implicitly.

You can create archetypes directly using `ECS.Archetype.Of(Components[])`. You also implicitly create archetypes 
whenever you add or remove a component from an entity. An Archetype object is an immutable singleton; creating an 
archetype with the same set of components, either directly or implicitly, results in the same archetype.

The ECS framework uses archetypes to group entities that have the same structure together. The ECS framework stores 
component data in blocks of memory called chunks. A given chunk stores only entities having the same archetype. You can 
get the Archetype object for a chunk from its Archetype property.

Use `ECS.Archetype.Of(Components[])` to get a Archetype reference.

- `Archetype.EMPTY`
   - Generic archetype, for entities that do not have components
   - _@type_ `Archetype`
- `Archetype.Of(componentClasses)`
   - Gets the reference to an archetype from the informed components
   - _@param_ `componentClasses` `ComponentClass[]` Component that define this archetype
   - _@return_ `Archetype`
- `Archetype.Version()`
   - Get the version of archetype definitions
   - _@return_ `number`
- `Archetype:Has(componentClass)`
   - Checks whether this archetype has the informed component
   - _@param_ `componentClass` `ComponentClass`
   - _@return_ `bool`
- `Archetype:With(componentClass)`
   - Gets the reference to an archetype that has the current components `+` the informed component
   - _@param_ `componentClass` `ComponentClass`
   - _@return_ `Archetype`
- `Archetype:WithAll(componentClasses)`
   - Gets the reference to an archetype that has the current components `+` the informed components
   - _@param_ `componentClass` `ComponentClass[]`
   - _@return_ `Archetype`
- `Archetype:Without(componentClass)`
   - Gets the reference to an archetype that has the current components `-` the informed component
   - _@param_ `componentClass` `ComponentClass`
   - _@return_ `Archetype`
- `Archetype:WithoutAll(componentClasses)`
   - Gets the reference to an archetype that has the current components `-` the informed components
   - _@param_ `componentClass` `ComponentClass[]`
   - _@return_ `Archetype`

# Component
- `ComponentClass.Id`
   - Identifier of this component
   - _@type_ `number`
- `ComponentClass.IsCType`
   - Indicates that this class is a Component
   - _@type_ `true`
- `ComponentClass.SuperClass`
   - Used internally for Qualifiers, it indicates the base class of this Component (or primary component).
   - _@type_ `ComponentClass`
- `ComponentClass.HasQualifier`
   - Indicates that this Component has qualifiers
   - _@type_ `bool`
- `ComponentClass.IsQualifier`
   - Indicates that this specific class is a Component qualifier.
   - _@type_ `bool`
- `ComponentClass.IsFSM`
   - Indicates that this Component is a [FSM - Finite State Machine][fsm]
   - _@type_ `bool`
- `ComponentClass.States`
   - When set, this Component becomes a [FSM - Finite State Machine][fsm]
      ```lua
      local Movement = ECS.Component({ speed = 0 })
      Movement.States = {
         Standing = {"Walking"},
         Walking  = "*",
         Running  = {"Walking"}
      }
      ```
   - _@type_ `table` _optional_
- `ComponentClass.StateInitial`
   - When the component is [FSM][fsm], it allows defining the initial state for new instances.
   - _@type_ `string` _optional_
- `ComponentClass.Case`
   - When the component is [FSM][fsm], it allows the component to handle transactions between states.
      ```lua
      Movement.Case = {
         Standing = function(self, previous)
            self.speed = 0
         end,
         Walking = function(self, previous)
            self.speed = 5
         end,
         Running = function(self, previous)
            self.speed = 10
         end
      }
      ```
   - _@type_ `table` _optional_
- `ComponentClass.Qualifier(qualifier)`
   - Gets a qualifier for this type of component. If the qualifier does not exist, a new class will be created, 
   otherwise it brings the already registered class qualifier reference with the same name.
   - _@param_ `qualifier` `string|ComponentClass`
   - _@return_ `ComponentClass`
- `ComponentClass.Qualifiers(...)`
   - Get all qualified class
   - _@param_ `...` `string|ComponentClass` _optional_ Allows to filter the specific qualifiers
   - _@return_ `ComponentClass[]`
- `ComponentClass(value)` | `ComponentClass.New(value)`
   - Builder, instantiate a new component of this type
   - _@param_ `value` `any` _optional_  If the value is not a table, it will be converted to the format `{ value = value}`
   - _@return_ `Component`
- `ComponentClass:GetType()`
   - Get this component's class
   - _@return_ `ComponentClass`
- `ComponentClass:Is(componentClass)`
   - Check if this component is of the type informed
   - _@param_ `componentClass` `ComponentClass|ComponentSuperClass`
   - _@return_ `bool`
- `ComponentClass:Primary()`
   - Get the instance for the primary qualifier of this class
   - _@return_ `Component|nil`
- `ComponentClass:Qualified(qualifier)`
   - Get the instance for the given qualifier of this class
   - _@param_ `qualifier` `string|ComponentClass`
   - _@return_ `Component|nil`
- `ComponentClass:QualifiedAll()`
   - Get all instances for all qualifiers of that class
   - _@return_ `Component[]`
- `ComponentClass:Merge(other)`
   - Merges data from the other component into the current component. **IMPORTANT!** This method should not be invoked, 
   it is used by the entity to ensure correct retrieval of a component's qualifiers.
   - _@param_ `other` `Component`
- `ComponentClass:Detach()`
   - Unlink this component with the other qualifiers. **IMPORTANT!** This method should not be invoked, it is used by 
   the entity to ensure correct retrieval of a component's qualifiers.
- `ComponentClass.In(...)`
   - When the component is [FSM][fsm], creates a clause used to filter repository entities in a Query or QueryResult. 
      ```lua
      ECS.Query.All(Movement.In("Walking", "Running"))
      ```
   - _@param_ `...` `string[]`
   - _@return_ `Clause`
- `ComponentClass:SetState(newState)`
   - When the component is [FSM][fsm], defines the current state
   - _@param_ `newState` `string`
- `ComponentClass:GetState()`
   - When the component is [FSM][fsm], get the current state
   - _@return_ `string`
- `ComponentClass:GetPrevState()`
   - When the component is [FSM][fsm], get the previous state
   - _@return_ `string|nil`
- `ComponentClass:GetStateTime()`
   - When the component is [FSM][fsm], gets the time it changed to the current state. Whenever the state is changed, the 
   instant is persisted internally using `os.clock()`
   - _@return_ `number`

# Entity
- `Entity.id`
   - Identifier of this entity
   - _@type_ `number`
- `Entity.isAlive`
   - The entity is created in _DEAD_ state (`entity.isAlive == false`) and will only be visible for queries after the 
   cleaning step _(`OnRemove`,`OnEnter`,`OnExit`)_ by the world
   - _@type_ `bool`
- `Entity.archetype`
   - The entity archetype
   - _@type_ `Archetype`
- `Entity.New(onChange, components)`
   - Creates an entity having components of the specified types.
   - _@param_ `onChange` `Event`
   - _@param_ `components` `Component[]` _optional_
   - _@return_ `Entity`
- `Entity:Get(componentClass)` | `entity[componentClass]`
   - Gets an entity component
   - _@param_ `componentClass` `ComponentClass` 
   - _@return_ `Component`
- `Entity:Get(...)`
   - Get multiple entity components at once
      ```lua
      local comp1, comp2, comp3 = entity:Get(CompType1, CompType2, CompType3)
      ```
   - _@param_ `..` `ComponentClass[]` 
   - _@return_ `Component ...`
- `Entity:Set(componentClass, value)` | `entity[componentClass] = value`
   - Sets the value of a component
   - _@param_ `componentClass` `ComponentClass` 
   - _@param_ `value` `any|nil` When nil, unset the component.
- `Entity:Set(...)`
   - Arrow one or more instances of a component
   - _@param_ `...` `Component`
- `Entity:Unset(componentClass|Component, ...)` | `entity[componentClass] = nil`
   - Remove one or more components from the entity
   - _@param_ `...` `componentClass|Component` 

# LoopManager
In order for the world's systems to receive an update, the `World:Update(step, now)` method must be invoked on each 
frame. To automate this process, **ECS Lua** provides a functionality so that, at the time of instantiation of a 
new world, it registers to receive the update automatically.

```lua
local MyLoopManager = {
   Register = function(world)
      local beforePhysics = MyGameEngine.BeforePhysics(function()
         world:Update("process", os.clock())
      end)

      local afterPhysics = MyGameEngine.AfterPhysics(function()
         world:Update("transform", os.clock())
      end)

      local beforeRender
      if (not MyGameEngine.IsServer()) then
         beforeRender = MyGameEngine.BeforeRender(function()
            world:Update("render", os.clock())
         end)
      end

      return function()
         beforePhysics:Disconnect()
         afterPhysics:Disconnect()
         if beforeRender then
            beforeRender:Disconnect()
         end
      end
   end
}

ECS.SetLoopManager(MyLoopManager)
```

- `LoopManager.Register(world)`
   - Allows the world to register to be updated.
   - _@param_ `world` `World` 
   - _@return_ `function` The world will invoke when destroyed

# Query
- `Query(all, any, none)` | `Query.New(all, any, none)`
   - Create a new Query used to filter entities in the world. It makes use of local and global cache in order to 
   decrease the validation time (avoids looping in runtime of systems)
   - _@param_ `all` `Array<ComponentClass|Clause>` _optional_
   - _@param_ `any` `Array<ComponentClass|Clause>` _optional_
   - _@param_ `none` `Array<ComponentClass|Clause>` _optional_
   - _@return_ `Query`
- `Query.All(...)`
   - _@param_ `...` `Array<ComponentClass|Clause>` 
   - _@return_ `QueryBuilder`
- `Query.Any(...)`
   - _@param_ `...` `Array<ComponentClass|Clause>` 
   - _@return_ `QueryBuilder`
- `Query.None(...)`
   - _@param_ `...` `Array<ComponentClass|Clause>` 
   - _@return_ `QueryBuilder`
- `Query.Filter(filter)`
   - Create custom filters that can be used in Queries. Its execution is delayed, invoked only in `QueryResult` methods.
   The result of executing the clause depends on how it was used in the query.
   Ex. If used in `Query.All()` the result is the inverse of using the same clause in `Query.None()`
      ```lua
      local Player = ECS.Component({ health = 100 })

      local HealthPlayerFilter = ECS.Query.Filter(function(entity, config)
         local player = entity[Player]
         return player.health >= config.minHealth and player.health <= config.maxHealth
      end)

      local healthyClause = HealthPlayerFilter({
         minHealth = 80,
         maxHealth = 100,
      })

      local healthyQuery = ECS.Query.All(Player, healthyClause)
      world:Exec(healthyQuery):ForEach(function(entity)
         -- this player is very healthy
      end)

      local notHealthyQuery = ECS.Query.All(Player).None(healthyClause)
      world:Exec(healthyQuery):ForEach(function(entity)
         -- this player is NOT very healthy
      end)

      local dyingClause = HealthPlayerClause({
         minHealth = 1,
         maxHealth = 20,
      })

      local dyingQuery = ECS.Query.All(Player, dyingClause)
      world:Exec(dyingQuery):ForEach(function(entity)
         -- this player is about to die
      end)

      local notDyingQuery = ECS.Query.All(Player).None(dyingClause)
      world:Exec(notDyingQuery):ForEach(function(entity)
         -- this player is NOT about to die
      end)
      ```
   - _@param_ `filter` `function(entity, config) -> bool`
   - _@return_ `function(config) -> Clause`
- `Query:Result(chunks)`
   - Generate a `QueryResult` with the chunks entered and the clauses of the current query
   - _@param_ `chunks` `Array<{ [Entity] = true }>` 
   - _@return_ `QueryResult`
- `Query:Match(archetype)`
   - Checks if the entered archetype is valid by the query definition
   - _@param_ `archetype` `Archetype` 
   - _@return_ `bool`

# QueryBuilder
- `QueryBuilder.isQueryBuilder`
   - Indicates that this is an instance of a QueryBuilder
   - _@type_ `true`
- `QueryBuilder.All(...)`
   - _@param_ `...` `Array<ComponentClass|Clause>` 
   - _@return_ `QueryBuilder`
- `QueryBuilder.Any(...)`
   - _@param_ `...` `Array<ComponentClass|Clause>` 
   - _@return_ `QueryBuilder`
- `QueryBuilder.None(...)`
   - _@param_ `...` `Array<ComponentClass|Clause>` 
   - _@return_ `QueryBuilder`
- `QueryBuilder.Build()`
   - _@return_ `Query`

# QueryResult
The result of a Query that was executed on an EntityStorage.

QueryResult provides several methods to facilitate the filtering of entities resulting from the execution of the query.

- **Intermediate Operations**
   -  Intermediate operations return a new QueryResult. They are always lazy; executing an intermediate operation such as 
   `QueryResult:Filter()` does not actually perform any filtering, but instead creates a new QueryResult that, when traversed, 
   contains the elements of the initial QueryResult that match the given predicate. Traversal of the pipeline source 
   does not begin until the terminal operation of the pipeline is executed.
- **Terminal Operations**
   - Terminal operations, such as `QueryResult:ForEach` or `QueryResult.AllMatch`, may traverse the QueryResult to produce a 
   result or a side-effect.

- `QueryResult.New(chunks, clauses)`
   - Build a new QueryResult
   - _@param_ `chunks` `Array<{ [Entity] = true }>`
   - _@param_ `clauses` `Clause[]` _optional_
   - _@return_ `QueryResult`
- `QueryResult:With(operation, param)`
   - Returns a QueryResult consisting of the elements of this QueryResult with a new pipeline operation
   - _@param_ `operation` `function(param, value, count) -> newValue, acceptItem, continuesLoop`
   - _@param_ `param` `any`
   - _@return_ `QueryResult` the new QueryResult
- `QueryResult:Filter(predicate)`
   - Returns a QueryResult consisting of the elements of this QueryResult that match the given predicate.
   - _@param_ `predicate` `function(value) -> bool` a predicate to apply to each element to determine if it should be included
   - _@return_ `QueryResult` the new QueryResult
- `QueryResult:Map(mapper)`
   - Returns a QueryResult consisting of the results of applying the given function to the elements of this QueryResult.
   - _@param_ `mapper` `function(value) -> newValue` a function to apply to each element
   - _@return_ `QueryResult` the new QueryResult
- `QueryResult:Limit(maxSize)`
   - Returns a QueryResult consisting of the elements of this QueryResult, truncated to be no longer than maxSize in length.
   - _@param_ `maxSize` `number`
   - _@return_ `QueryResult` the new QueryResult
- `QueryResult:AnyMatch(predicate)`
   - Returns whether any elements of this result match the provided predicate.
   - _@param_ `predicate` `function(value) -> bool` a predicate to apply to elements of this result
   - _@return_ `true` if any elements of the result match the provided predicate, otherwise `false`
- `QueryResult:AllMatch(predicate)`
   - Returns whether all elements of this result match the provided predicate.
   - _@param_ `predicate` `function(value) -> bool` a predicate to apply to elements of this result
   - _@return_ `true` if either all elements of the result match the provided predicate or the result is empty, otherwise `false`
- `QueryResult:FindAny()`
   - Returns some element of the result, or nil if the result is empty.

   This is a short-circuiting terminal operation.

   The behavior of this operation is explicitly nondeterministic; it is free to select any element in the result. 
   
   Multiple invocations on the same result may not return the same value.
   - _@return_ `any`
- `QueryResult:ForEach(action)`
   - Performs an action for each element of this QueryResult.

   This is a terminal operation.

   The behavior of this operation is explicitly nondeterministic. This operation does not guarantee to respect the 
   encounter order of the QueryResult.
   - _@param_ `action` `function(value, count) -> bool` A action to perform on the elements, breaks execution case returns true
- `QueryResult:ToArray()`
   - Returns an array containing the elements of this QueryResult.
   - _@return_ `Array<any>`
- `QueryResult:Iterator()`
   - Returns an Iterator, to use in for loop
      ```lua
      for count, entity in result:Iterator() do
         print(entity.id)
         break
      end
      ```  
   - _@return_ `Iterator`

# System

- `System.Step`
   - Step that this system will run
   - _@type_ `string` `process|transform|render|task`
- `System.Order`
   - For systems that are not `task`, execution order
   - _@type_ `number`
- `System.Query`
   - Filters the entities that will be processed by this system
   - _@type_ `number`
- `System.After`
   - When the system is a task, it allows you to define that this system should run AFTER other specific systems.
      ```lua
      local log = {}

      local Task_A = System.Create('task', function()
         -- In this example, TASK_A takes time to execute, delaying its execution
         local i = 0
         while i <= 4000 do
            i = i + 1
            if i%1000 == 0 then
               coroutine.yield()
            end
         end
         
         table.insert(log, 'A')
      end)

      local Task_B = System.Create('task', function()
         table.insert(log, 'B')
      end)

      local Task_C = System.Create('task', function()
         table.insert(log, 'C')
      end)

      local Task_D = System.Create('task', function()
         table.insert(log, 'D')
      end)

      local Task_E = System.Create('task', function()
         table.insert(log, 'E')
      end)

      local Task_F = System.Create('task', function()
         table.insert(log, 'F')
      end)

      local Task_G = System.Create('task', function()
         table.insert(log, 'G')
      end)
      
      local Task_H = System.Create('task', function(self)
         table.insert(log, 'H')
      end)

      --[[         
         A<-------C<---+-----F<----+
                  |    |     |     |
             +----+    E<----+     H
             |         |           |
         B<--+----D<---+------G<---+

         A - has no dependency
         B - has no dependency
         C - Depends on A,B
         D - Depends on B
         E - Depends on A,B,C,D
         F - Depends on A,B,C,D,E
         G - Depends on B,D
         H - Depends on A,B,C,D,E,F,G

         Completion order will be B,D,G,A,C,E,F,H      

         > In this example, TASK_A takes time to execute, delaying its execution
      ]]
      Task_A.Before = {Task_C}
      Task_B.Before = {Task_D}
      Task_C.After = {Task_B}
      Task_D.Before = {Task_G}
      Task_F.After = {Task_E}
      Task_E.After = {Task_D, Task_C}
      Task_C.Before = {Task_F}
      Task_H.After = {Task_F, Task_G}
      ```
   - _@type_ `SystemClass[]`
- `System.Before`
   - When the system is a task, it allows you to define that this system should run BEFORE other specific systems.
   - _@see_ `System.After`
   - _@type_ `SystemClass[]`
- `System.version`
   - System Version (GSV).
   - _@see_ `World.version`
   - _@type_ `Number`
- `System._world`
   - _@type_ `World`
- `System._config`
   - _@type_ `table`
- `System.New(world, config)`
   - Create an instance of this system
   - _@param_ `world` `World`
   - _@param_ `config` `table`
   - _@return_ `System`
- `System:GetType()`
   - Get this system class
   - _@return_ `SystemClass`
- `System:Result(query)`
   - Run a query in the world. A shortcut to `self._world:Exec(query)`
   - _@param_ `query` `Query|QueryBuilder` _optional_ If nil, use default query
   - _@return_ `QueryResult`
- `System:Destroy()`
   - Destroy this instance
- `System:OnDestroy()`
   - Allows you to perform some processing or cleaning when the instance is being destroyed
- `System:ShouldUpdate(Time)`
   - Invoked before 'Update', allows you to control the execution of the update
   - _@param_ `Time` `Time`
   - _@return_ `bool` If true, the Update method will be invoked.
- `System:Update(Time)`
   - Run the system's main method
   - _@param_ `Time` `Time`
- `System:OnRemove(Time, entity)`
   - When it is a `QuerySystem`, it allows to be informed when an entity with the characteristics of the query is 
   removed from the world. This method is performed in the step cleanup process.
   - _@param_ `Time` `Time`
   - _@param_ `entity` `Entity`
- `System:OnExit(Time, entity)`
   - When it is a `QuerySystem`, it allows to be informed when an entity has lost the characteristics of that query 
   (has suffered an archetype change and the current query no longer applies). This method is performed in the step 
   cleanup process.
   - _@param_ `Time` `Time`
   - _@param_ `entity` `Entity`
- `System:OnEnter(Time, entity)`
   - When it is a QuerySystem, it allows to be informed when an entity received the characteristics expected by this 
   query (it suffered an archetype change and the current query now applies). This method is performed in the step 
   cleanup process.
   - _@param_ `Time` `Time`
   - _@param_ `entity` `Entity`


# Time
Singleton, reference to the world's global processing time.

- `Time.Now`
   - World Runtime
   - _@type_ `number`
- `Time.NowReal`
   - Real time, received in `World:Update(step, now)` method
   - _@type_ `number`
- `Time.Frame`
   - The time at the beginning of this frame (process). The world receives the current time at the beginning of each 
   frame, with the value increasing per frame.
   - _@type_ `number`
- `Time.FrameReal`
   - The REAL time at the beginning of this frame (`World:Update(step, now)`).
   - _@type_ `number`
- `Time.Process`
   - The time the latest process step has started.
   - _@type_ `number`
- `Time.Delta`
   - The completion time in seconds since the last frame.
   - _@type_ `number`
- `Time.DeltaFixed`
   - Based on world update frequency (`process` step). 
      ```lua
      DeltaFixed = 1000/frequency/1000
      ```
   - _@see_ `World:SetFrequency()`
   - _@type_ `number`
- `Time.Interpolation`
   - The proportion of time since the previous transform relative to processDeltaTime. Used to do interpolation during 
   the rendering step. Allows the `process` step to run at low frequency _(Ex. 30hz)_ and `render` at the maximum rate 
   of the player's device _(Ex. 60hz)_
   - _@type_ `number`

# World
- `World.version`
   - Global System Version (GSV).

   Before executing the `Update()` method of each system, the world version is incremented, so at this point, the 
   world version will always be higher than the running system version.

   Whenever an entity archetype is changed (received or lost component) the entity's version is updated to the current 
   version of the world.

   After executing the System Update method, the version of this system is updated to the current world version.

   This mechanism allows a system to know if an entity has been modified after the last execution of this same system, 
   as the entity's version is superior to the version of the last system execution. Thus, a system can contain logic if 
   it only operates on "dirty" entities, which have undergone changes. The code for this validation on a system is: 
      - `local isDirty = entity.version > self.version`
   - _@type_ `number`
- `World.maxTasksExecTime`
   - Allows you to define the maximum time that the `JobSystem` can operate in each frame. The default value is 
   `0.011666666666666665` = `((1000/60/1000)*0.7)`
      - A game that runs at 30fps has 0.0333 seconds to do all the processing for each frame, including rendering
         - 30FPS = `(1000/30/1000)` = `0.03333333333333333`
      - A game that runs at 60fps has 0.0166 seconds to do all the processing for each frame, including rendering
         - 60FPS = `(1000/60/1000)` = `0.016666666666666666`
   - _@type_ `number` Default `0.011666666666666665`
- `World:SetFrequency(frequency)`
   - Define the frequency that the `process` step will be executed
   - _@param_ `frequency` `number` _optional_ Default 30
- `World:GetFrequency()`
   - Get the frequency of execution of the `process` step
   - _@return_ `number`
- `World:AddSystem(systemClass, config)`
   - Add a new system to the world. Only one instance per type is accepted. If there is already another instance of this 
   system in the world, any new invocation of this method will be ignored.
   - _@param_ `systemClass` `SystemClass` The system to be added in the world
   - _@param_ `config` `table` _optional_ System instance configuration
- `World:Entity(...)`
   - Create a new entity. The entity is created in _DEAD_ state (`entity.isAlive == false`) and will only be visible for 
   queries after the cleaning step _(`OnRemove`,`OnEnter`,`OnExit`)_ of the current step
   - _@param_ `...` `Component[]` _optional_ Instance of the components that this entity will have
   - _@return_ `Entity`
- `World:Remove(entity)`
   - Performs immediate removal of an entity.

   If the entity was created in this step and the cleanup process has not happened yet (therefore the entity is inactive, 
   `entity.isAlive == false`), the `OnRemove` event will never be fired.

   If the entity is alive (`entity.isAlive == true`), even though it is removed immediately, the `OnRemove` event will 
   be fired at the end of the current step.
   - _@param_ `entity` `Entity`
- `World:Exec(query)`
   - Run a query in this world
   - _@param_ `query` `Query|QueryBuilder`
   - _@return_ `QueryResult`
- `World:Update(step, now)`
   - Perform world update. When registered, the `LoopManager` will invoke World Update for each step in the sequence.
      - `process` At the beginning of each frame
      - `transform` After the game engine's physics engine runs
      - `render` Before rendering the current frame
   - _@param_ `step` `"process"|"transform"|"render"`
   - _@param_ `now` `number` Usually os.clock()
- `World:Destroy()`
   - Destroy this instance, removing all entities, systems and events

</div>

[fsm]:https://en.wikipedia.org/wiki/Finite-state_machine
