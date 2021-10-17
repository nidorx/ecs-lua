# What is it?

**ECS Lua** is a fast and easy to use ECS (Entity Component System) engine for game development.

![](assets/diagram-1.png)

The basic idea of this pattern is to stop defining entities using a 
[hierarchy](https://en.wikipedia.org/wiki/Inheritance_(object-oriented_programming)) of classes and start doing use of 
[composition](https://en.wikipedia.org/wiki/Object_composition) in a Data Oriented Programming paradigm.
([More information on Wikipedia](https://en.wikipedia.org/wiki/Entity_component_system)).
Programming with an ECS can result in code that is more efficient and easier to extend over time.


# How does it work?

![ECS Lua pipeline](assets/pipeline.png)


# Talk is cheap. Show me the code!

```lua
local World, System, Query, Component = ECS.World, ECS.System, ECS.Query, ECS.Component

local Health = Component(100)
local Position = Component({ x = 0, y = 0})

local isInAcid = Query.Filter(function()
   return true  -- it's wet season
end)

local InAcidSystem = System("process", Query.All( Health, Position, isInAcid() ))

function InAcidSystem:Update()
   for i, entity in self:Result():Iterator() do
      local health = entity[Health]
      health.value = health.value - 0.01
   end
end

local world = World({ InAcidSystem })

world.Entity(Position({ x: 5.0 }), Health())
```

# Features

**ECS Lua** has no external dependencies and is compatible and tested with [Lua 5.1], [Lua 5.2], [Lua 5.3], [Lua 5.4],
[LuaJit] and [Roblox Luau](https://luau-lang.org/)

- **Game engine agnostic**: It can be used in any engine that has the Lua scripting language.
- **Ergonomic**: Focused on providing a simple yet efficient API
- **FSM**: Finite State Machines in an easy and intuitive way
- **JobSystem**: To running systems in parallel (through [coroutines])
- **Reactive**: Systems can be informed when an entity changes
- **Predictable**:
   - The systems will work in the order they were registered or based on the priority set when registering them.
   - Reactive events do not generate a random callback when issued, they are executed at a predefined step.

# Goal

To be a lightweight, simple, ergonomic and high-performance ECS library that can be easily extended. The **ECS Lua**
does not strictly follow _"pure ECS design"_.

# Next steps

You can browse or search for specific subjects in the side menu. Here are some relevant links:

<br>
<br>

<div class="home-row clearfix" style="text-align:center">
   <div class="home-col"><div class="panel home-panel"><div class="panel-body">

   [![Installation](assets/icon-download.png ":no-zoom")](/getting-started?id=installation)

   </div><div class="panel-heading">

   [Installation](/getting-started?id=installation)

   </div></div></div>

   <div class="home-col"><div class="panel home-panel"><div class="panel-body">

   [![General Concepts](assets/icon-parts.png ":no-zoom")](/getting-started?id=general-concepts)

   </div><div class="panel-heading">

   [General Concepts](/getting-started?id=general-concepts)

   </div></div></div>

   <div class="home-col"><div class="panel home-panel"><div class="panel-body">

   [![Architecture](assets/icon-advanced.png ":no-zoom")](/architecture)

   </div><div class="panel-heading">

   [Architecture](/architecture)

   </div></div></div>

   <div class="home-col"><div class="panel home-panel"><div class="panel-body">

   [![Tutorials](assets/icon-tutorial.png ":no-zoom")](/tutorial)

   </div><div class="panel-heading">

   [Tutorials](/tutorial)

   </div></div></div>
</div>

[Lua 5.1]:https://app.travis-ci.com/github/nidorx/ecs-lua
[Lua 5.2]:https://app.travis-ci.com/github/nidorx/ecs-lua
[Lua 5.3]:https://app.travis-ci.com/github/nidorx/ecs-lua
[Lua 5.4]:https://app.travis-ci.com/github/nidorx/ecs-lua
[LuaJit]:https://app.travis-ci.com/github/nidorx/ecs-lua
