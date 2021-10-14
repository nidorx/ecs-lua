# Contributing to ECS Lua
Thanks for considering contributing to ECS Lua! This guide has a few tips and guidelines to make contributing to the 
project as easy as possible.

## Bug Reports
Any bugs (or things that look like bugs) can be reported on the [GitHub issue tracker](https://github.com/nidorx/ecs-lua/issues).

Make sure you check to see if someone has already reported your bug first! Don't fret about it; if we notice a duplicate 
we'll send you a link to the right issue!

## Feature Requests
If there are any features you think are missing from ECS Lua, you can post a request in the 
[GitHub issue tracker](https://github.com/nidorx/ecs-lua/issues).

Just like bug reports, take a peak at the issue tracker for duplicates before opening a new feature request.

## Documentation
[ECS Lua documentation](https://nidorx.github.io/ecs-lua/) is built using [Docsify](https://docsify.js.org/#/), a 
fairly simple documentation generator.

## Working on ECS Lua
To get started working on ECS Lua, you'll need:
* Git
* Lua 5.1

You can run all of ECS Lua tests with:

```sh
lua test.lua -v
```

The LuaCov coverage report is available in the `luacov.report.out` file.

To build the concatenated and minified versions, run the command

```sh
lua build.lua
```

## Pull Requests
Before starting a pull request, open an issue about the feature or bug. This helps us prevent duplicated and wasted 
effort. These issues are a great place to ask for help if you run into problems!

### Code Style

In short:

- **SPACE** for indentation
- Identation size = 3 spaces
- Double quotes
- One statement per line

### Tests
When submitting a bug fix, create a test that verifies the broken behavior and that the bug fix works. This helps us 
avoid regressions!

When submitting a new feature, add tests for all functionality.

We use [LuaCov](https://keplerproject.github.io/luacov) for keeping track of code coverage. We'd like it to be as 
close to 100% as possible, but it's not always possible. Adding tests just for the purpose of getting coverage isn't 
useful; we should strive to make only useful tests!
