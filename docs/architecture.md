# Architecture

In Software Engineering, ECS is the acronym for Entity Component System, is a software architecture pattern used 
primarily in video game development. An ECS follows the principle of "composition rather than inheritance" that allows 
greater flexibility in defining entities, where each object in a game scene is an entity (eg enemies, projectiles, 
vehicles, etc.). Each entity consists of of one or more components that add behavior or functionality. Therefore, 
the behavior of an entity can be changed at runtime by simply adding or removing components. This eliminates problems of
The ambiguity with which deep and vast inheritance hierarchies, which are difficult to understand, maintain and extend.

For more details:
- [Frequently Asked Questions about ECS](https://github.com/SanderMertens/ecs-faq)
- [Entity Systems Wiki](http://entity-systems.wikidot.com/)
- [Evolve your hierarchy](http://cowboyprogramming.com/2007/01/05/evolve-your-heirachy/)
- [ECS on Wikipedia](https://en.wikipedia.org/wiki/Entity_component_system)
- [ECS with Elixir](https://yos.io/2016/09/17/entity-component-systems/)
- [2017 GDC - Overwatch Gameplay Architecture e Netcode](https://www.youtube.com/watch?v=W3aieHjyNvw&ab_channel=GDC)


## Component

They represent the different characteristics of an entity, such as position, speed, geometry, physics, and hit points.
Components only store raw data for an aspect of the object and how it interacts with the world. In others words, the 
component labels the entity as having this particular aspect.

In **ECS Lua**, the creation of a component is done through the `ECS.Component(template)` method.

The `template` parameter can be of any type, where:
- When `table`, this template will be used for creating component instances
   ```lua
   local Component = ECS.Component({
      x = 0, y = 0, z = 0 
   })

   local comp = Component({ x = 33, z = 80 })
   print(comp.x, comp.y, comp.z) -- > 33, 0, 80

   -- it is the same as
   local comp = Component.New({ x = 33, z = 80 })
   print(comp.x, comp.y, comp.z) -- > 33, 0, 80
   ```
- When it's a `function`, it will be invoked when a new component is instantiated. The creation parameter of the 
component is passed to template function
   ```lua
   local Component = ECS.Component(function(param)
      return {
         x = param.x or 1,
         y = param.y or 1,
         z = param.z or 1
      }
   end)

   local comp = Component({ x = 33, z = 80 })
   print(comp.x, comp.y, comp.z) -- > 33, 1, 80
   ```
- If the template type is different from `table` and `function`, **ECS Lua** will generate a template in the format 
`{ value = template }`.
   ```lua
   local Component = ECS.Component(55)

   local comp1 = Component()
   print(comp1.value) -- > 55

   local comp2 = Component({ value = 80 })
   print(comp2.value) -- > 80

   local comp3 = Component("XPTO")
   print(comp3.value) -- > "XPTO"
   ```

### Methods

In **ECS Lua**, components are classes and can therefore have auxiliary methods.

> IMPORTANT! Avoid creating methods that modify component instance data directly, the ideal is that these logics 
stay within the systems, which are, by definition, responsible for changing the data of the entities and their 
components.

```lua
local Person = ECS.Component({
   name = "",
   surname = "",
   birth = 0
})

function Person:FullName()
   return self.name.." "..self.surname
end

function Person:Age()
   return tonumber(os.date("%Y", os.time())) - self.birth
end


local person = Person({ name = "John", surname = "Doe", birth = 2000 })

print(person:FullName()) -- John Doe
print(person:Age()) -- 21
```

### Qualifiers

In "pure ECS" implementations there is a premise that a component can only be added once to an entity. In the vast 
majority of scenarios, this is true. For example, you don't want your entity to have two positions, it makes no sense! 
Therefore, your entity will only have one component of type Position.

But sometimes you will build some functionality that needs your entity to have this behavior, to have more than one 
component of the same **TYPE**. When the framework doesn't support this kind of implementation, you end up with code 
full of hacks to [work around](https://en.wikipedia.org/wiki/Workaround) the problem.

**ECS Lua** implements the **Qualifiers** mechanism so that you can represent a category of components.

To illustrate the usage, let's think about the following scenario: I want to add a 
[Buff](https://en.wikipedia.org/wiki/Game_balance#Buff) system to my game so that my character can receive extra life 
points in specific situations. We want to have the freedom to increase or decrease the amount of buff according to the
region of the map where the player is.

Looking at the scenario above, we could create, at first, the solution below. A `HealthBuff` component to record the 
amount of extra life and two systems. The first `MapRegionSystem` decides how many additional health points the player 
will have for each region, while the second `HealthSystem` represents some system functionality that need to get the 
player's life total at a certain time.

```lua
-- components
local Player = ECS.Component({ health = 100, region = "easy", healthTotal = 100 })
local HealthBuff = ECS.Component({ value = 10 })

-- systems
local MapRegionSystem = System("process", 1, Query.All(Player))

function MapRegionSystem:Update(Time)
   for i, entity in self:Result():Iterator() do
      local player = entity[Player]      
      
      if player.region == "easy" then
         entity[HealthBuff] = nil -- remove buff
      else
         local buff = entity[HealthBuff]
         if buff == nil then
            buff = HealthBuff(0)
            entity:Set(buff)
         end

         if player.region == "hard" then
            buff.value = 15
         elseif player.region == "hell" then
            buff.value = 40
         end  
      end    
   end
end

local HealthSystem = System("process", 2, Query.All(Player).Any(HealthBuff)) 

function HealthSystem:Update(Time)
   for i, entity in self:Result():Iterator() do
      local player = entity[Player]

      local buff = entity[HealthBuff]
      if buff then 
         player.healthTotal = player.health + buff.value
      else
         player.healthTotal = player.health
      end
   end
end
```

So far quiet. However, imagine now that my player can receive **SEVERAL** buffers.
   - He can receive a buffer for the character he is using;
   - another buff when unlocking an item and;
   - you can also buy buffs from the in-game shop.

In this new scenario our solution does not meet, because the `MapRegionSystem` system code does not have the information 
about the other factors, and to attend to it, it will have to know or manage several possible states to decide which is 
the amount of health the player will receive for being in a specific region. The other systems in the game too needed 
to know the region to decide how much buffer to add. In a "pure ECS" solution, we're going to start:

1. share state between systems
1. create "Component TAGs" to facilitate the management of this distributed state,
1. inflate components with an attribute for each system type.

At first this doesn't seem to be a problem, but over time, multiple systems will be called unnecessarily (just to do an 
if and not process that entity). These systems now have extra responsibilities, increasing the complexity of the code, 
making maintenance difficult and facilitating the appearance of bugs.

In **ECS Lua** we solve this kind of problem by creating qualifiers, through the static method 
`ComponentClass.Qualifier(qualifier)`. It accepts a string as a parameter and returns a reference to a specialized class 
of our component. This generated class maintains a strong link with the base class, allowing more complex queries.

Let's change our example using qualifiers.

```lua
-- components
local Player = ECS.Component({ health = 100, region = "easy", healthTotal = 100 })
local HealthBuff = ECS.Component({ value = 10 })
local HealthBuffItem = HealthBuff.Qualifier("Item")
local HealthBuffMapRegion = HealthBuff.Qualifier("Region")
local Item = ECS.Component({ rarity = 0 })

-- systems
local PlayerItemSystem = System("process", 1, Query.All(Player, Item))

function PlayerItemSystem:Update(Time)
   for i, entity in self:Result():Iterator() do
      local item = entity[Item]
      local player = entity[Player]
      
      if item.rarity == "legendary" then
         entity[HealthBuffItem] = 15 -- same as entity:Set(HealthBuffItem.New(15))
      else
         entity[HealthBuffItem] = nil 
      end
   end
end

local MapRegionSystem = System("process", 1, Query.All(Player))

function MapRegionSystem:Update(Time)
   for i, entity in self:Result():Iterator() do
      local player = entity[Player]
      
      if player.region == "easy" then
         entity[HealthBuffMapRegion] = nil
      else
         local buff = entity[HealthBuffMapRegion]
         if buff == nil then
            buff = HealthBuffMapRegion(0)
            entity:Set(buff)
         end

         if player.region == "hard" then
            buff.value = 15
         elseif player.region == "hell" then
            buff.value = 40
         end      
      end
   end
end

local HealthSystem = System("process", 2, Query.All(Player).Any(HealthBuff))

function HealthSystem:Update(Time)
   for i, entity in self:Result():Iterator() do
      local player = entity[Player]

      local healthTotal = player.health

      local buffers = entity:GetAll(HealthBuff)
      for i,buff in ipairs(buffers) do
         healthTotal = healthTotal + buff.value
      end

      player.healthTotal = player.health
   end
end
```

Okay, in this new implementation, the `MapRegionSystem` system only cares about the `HealthBuffMapRegion` qualifier,
while the `PlayerItemSystem` system only manages the `HealthBuffItem` qualifier. We can now create systems that 
specialize in qualifiers and manage only this attribute of the entity. The `HealthSystem` gets and processes all 
entities that have any qualifier from the `HealthBuff` component.

[Check the API](/api?id=component) other methods that can be useful when working with qualifiers.

### FSM - Finite State Machines

__UNDER_CONSTRUCTION__


```lua
local Movement = Component.Create({ Speed = 0 })

--  [Standing] <--> [Walking] <--> [Running]
Movement.States = {
   Standing = {"Walking"},
   Walking  = "*",
   Running  = {"Walking"}
}

Movement.StateInitial = "Standing"

Movement.Case = {
   Standing = function(self, previous)
      print("Transition from "..previous.." to Standing")
   end,
   Walking = function(self, previous)
      print("Transition from "..previous.." to Walking")
   end,
   Running = function(self, previous)
      print("Transition from "..previous.." to Running")
   end
}


local movement = Movement()

movement:SetState("Walking")
movement:SetState("Running")

print(movement:GetState()) -- Running
print(movement:GetPrevState()) -- Walking

movement:SetState("Standing") -- invalid, Running -> Walking|Running
print(movement:GetState()) -- Running
print(movement:GetPrevState()) -- Walking

movement:SetState(nil)
print(movement:GetState()) -- Running
print(movement:GetPrevState()) -- Walking

movement:SetState("INVALID_STATE")
print(movement:GetState()) -- Running
print(movement:GetPrevState()) -- Walking


-- query
local queryStanding = Query.All(Movement.In("Standing"))
local queryInMovement = Query.Any(Movement.In("Walking", "Running"))


-- qualifier
local MovementB = Movement.Qualifier("Sub")
 -- ignored, "States", "StateInitial" and "Case" only work in primary class
MovementB.States = { Standing = {"Walking"} }
```

## Entity

__UNDER_CONSTRUCTION__

```lua
--[[
   [GET]
   01) comp1 = entity[CompType1]
   02) comp1 = entity:Get(CompType1)
   03) comp1, comp2, comp3 = entity:Get(CompType1, CompType2, CompType3)
]]

--[[
   [SET]
   01) entity[CompType1] = nil
   02) entity[CompType1] = value
   03) entity:Set(CompType1, nil)   
   04) entity:Set(CompType1, value)
   05) entity:Set(comp1)
   06) entity:Set(comp1, comp2, ...)
]]

--[[
   [UNSET]
   01) enity:Unset(comp1)
   02) entity[CompType1] = nil
   03) enity:Unset(CompType1)
   04) enity:Unset(comp1, comp1, ...)
   05) enity:Unset(CompType1, CompType2, ...)
]]

--[[
   [Utils]
   01) comps = entity:GetAll()
   01) qualifiers = entity:GetAll(PrimaryClass)
]]
```

## Query

__UNDER_CONSTRUCTION__

## System

__UNDER_CONSTRUCTION__

## Task

__UNDER_CONSTRUCTION__

```lua
local log = {}

local Task_A = System.Create('task', function()
   -- In this example, TASK_A takes time to execute, delaying its execution
   local i = 0
   while i <= 4000 do
      i = i + 1
      if i%1000 == 0 then
         -- Processing is parallel, any time-consuming task must invoke coroutine.yield() after a period of time to 
         -- not block processing
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

## World

__UNDER_CONSTRUCTION__





