# Introduction

**ECS Lua** is a lua [ECS _(Entity Component System)_](https://en.wikipedia.org/wiki/Entity_component_system) library
used for game developments.

**ECS Lua** has no external dependencies and is compatible and tested with [Lua 5.1], [Lua 5.2], [Lua 5.3], [Lua 5.4],
[LuaJit] and [Roblox Luau](https://luau-lang.org/)
    
## Features

- Game engine agnostic. It can be used in any engine that has the Lua scripting language.
- Focused on providing a simple yet efficient API
- Multiple queries per system
- It has a `JobSystem` for running systems in parallel (through [coroutines](http://www.lua.org/pil/9.1.html))
- Reactive: Systems can be informed when an entity changes
- Predictable:
   - The systems will work in the order they were registered or based on the priority set when registering them.
   - Reactive events do not generate a random callback when issued, they are executed at a predefined step.

## Goal

To be a lightweight, simple, ergonomic and high-performance ECS library that can be easily extended. The **ECS Lua**
does not strictly follow "pure ECS design".

## And now?

You can browse or search for specific subjects in the side menu. Here are some relevant links:

<br>
<br>

<div class="home-row clearfix" style="text-align:center">
   <div class="home-col"><div class="panel home-panel"><div class="panel-body">

   [![Getting Started](../assets/icon-basic.png ":no-zoom")](/getting-started?id=getting-started)

   </div><div class="panel-heading">

   [Getting Started](/getting-started?id=getting-started)

   </div></div></div>

   <div class="home-col"><div class="panel home-panel"><div class="panel-body">

   [![General Concepts](../assets/icon-parts.png ":no-zoom")](/getting-started?id=general-concepts)

   </div><div class="panel-heading">

   [General Concepts](/getting-started?id=general-concepts)

   </div></div></div>

   <div class="home-col"><div class="panel home-panel"><div class="panel-body">

   [![Architecture](../assets/icon-advanced.png ":no-zoom")](/architecture)

   </div><div class="panel-heading">

   [Architecture](/architecture)

   </div></div></div>

   <div class="home-col"><div class="panel home-panel"><div class="panel-body">

   [![Tutorials](../assets/icon-tutorial.png ":no-zoom")](/tutorial)

   </div><div class="panel-heading">

   [Tutorials](/tutorial)

   </div></div></div>
</div>

[Lua 5.1]:https://app.travis-ci.com/github/nidorx/ecs-lua
[Lua 5.2]:https://app.travis-ci.com/github/nidorx/ecs-lua
[Lua 5.3]:https://app.travis-ci.com/github/nidorx/ecs-lua
[Lua 5.4]:https://app.travis-ci.com/github/nidorx/ecs-lua
[LuaJit]:https://app.travis-ci.com/github/nidorx/ecs-lua
