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

<p align="center">
  <strong>ECS Lua</strong> is a fast and easy to use ECS (Entity Component System) engine for game development.
</p>

**ECS Lua** has no external dependencies and is compatible and tested with [Lua 5.1], [Lua 5.2], [Lua 5.3], [Lua 5.4],
[LuaJit] and [Roblox Luau](https://luau-lang.org/)

### Features

- **Game engine agnostic**: It can be used in any engine that has the Lua scripting language.
- **Ergonomic**: Focused on providing a simple yet efficient API
- **FSM**: Finite State Machines in an easy and intuitive way
- **JobSystem**: To running systems in parallel (through [coroutines])
- **Reactive**: Systems can be informed when an entity changes
- **Predictable**:
   - The systems will work in the order they were registered or based on the priority set when registering them.
   - Reactive events do not generate a random callback when issued, they are executed at a predefined step.

## Usage

Read our [Full Documentation][docs] to learn how to use **ECS Lua**.

## Get involved
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

## License

This code is distributed under the terms and conditions of the [MIT license](LICENSE).



