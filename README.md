<p align="center">
   <a href="https://nidorx.github.io/ecs-lua">
      <img 
         src="docs/assets/logo.svg" 
         alt="https://nidorx.github.io/ecs-lua" 
      />
   </a>
</p>

<p align="center">
   <a href="https://app.travis-ci.com/nidorx/ecs-lua">
      <img src="https://app.travis-ci.com/nidorx/ecs-lua.svg?branch=master" alt="Build Status" />
   </a>
</p>

<p align="center">
  <strong><a href="https://nidorx.github.io/ecs-lua#/">Read the Documentation</a></strong>
</p>

# What is it?

<strong>ECS Lua</strong> is a fast and easy to use ECS (Entity Component System) engine for game development.

<div align="center">

![](docs/assets/diagram-1.png)

</div>

The basic idea of this pattern is to stop defining entities using a 
[hierarchy](https://en.wikipedia.org/wiki/Inheritance_(object-oriented_programming)) of classes and start doing use of 
[composition](https://en.wikipedia.org/wiki/Object_composition) in a Data Oriented Programming paradigm.
([More information on Wikipedia](https://en.wikipedia.org/wiki/Entity_component_system)).
Programming with an ECS can result in code that is more efficient and easier to extend over time.


# How does it work?

<div align="center">

![ECS Lua pipeline](docs/assets/pipeline.png)

</div>


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

world:Entity(Position({ x = 5.0 }), Health())
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

# Usage

Read our [Full Documentation][docs] to learn how to use **ECS Lua**.

# Get involved
All kinds of contributions are welcome!

🐛 **Found a bug?**  
Let me know by [creating an issue][new-issue].

❓ **Have a question?**  
[Roblox DevForum][discussions] is a good place to start.

⚙️ **Interested in fixing a [bug][bugs] or adding a [feature][features]?**  
Check out the [contributing guidelines](CONTRIBUTING.md).

📖 **Can we improve [our documentation][docs]?**  
Pull requests even for small changes can be helpful. Each page in the docs can be edited by clicking the 
"Edit on GitHub" link at the bottom right.

[docs]: https://nidorx.github.io/ecs-lua
[bugs]: https://github.com/nidorx/ecs-lua/issues?q=is%3Aissue+is%3Aopen+label%3Abug
[features]: https://github.com/nidorx/ecs-lua/issues?q=is%3Aissue+is%3Aopen+label%3Afeature
[new-issue]: https://github.com/nidorx/ecs-lua/issues/new/choose
[discussions]: https://devforum.roblox.com/t/841175
[Lua 5.1]:https://app.travis-ci.com/github/nidorx/ecs-lua
[Lua 5.2]:https://app.travis-ci.com/github/nidorx/ecs-lua
[Lua 5.3]:https://app.travis-ci.com/github/nidorx/ecs-lua
[Lua 5.4]:https://app.travis-ci.com/github/nidorx/ecs-lua
[LuaJit]:https://app.travis-ci.com/github/nidorx/ecs-lua
[coroutines]:http://www.lua.org/pil/9.1.html

# License

This code is distributed under the terms and conditions of the [MIT license](LICENSE).



