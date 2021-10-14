# Introdução

**ECS Lua** é uma biblioteca de [ECS _(Entity Component System)_](https://en.wikipedia.org/wiki/Entity_component_system) 
em lua usada para desewnvolvimentos de jogos.

O **ECS Lua** nao possui dependencias externas e é compativel e testada com [Lua 5.1], [Lua 5.2], [Lua 5.3], [Lua 5.4], 
[LuaJit] e [Roblox Luau](https://luau-lang.org/)
    
## Características

- Agnóstico de engine de jogo. Pode ser usado em qualquer motor que tenha a linguagem de script Lua
- Focado em fornecer uma API simples, mas eficiente
- Múltiplas consultas por sistema
- Possui um `JobSystem` para a execucao de sistemas em paralelo (por meio de [coroutines](http://www.lua.org/pil/9.1.html))
- Reativo: Os sistemas podem ser informado quando uma entidade sofrer alteracao
- Previsível:
   - Os sistemas funcionarão na ordem em que foram registrados ou com base na prioridade definida ao registrá-los
   - Os eventos reativos não geram um retorno de chamada aleatório quando emitidos, sao executados em um passo pre-definido

## Objetivo

Ser uma biblioteca ECS leve, simples, ergonomica e de alto desempenho que pode ser facilmente estendida. O **ECS Lua** 
não segue estritamente o "design ECS puro".

## E agora?

Você pode navegar ou buscar assuntos específicos no menu lateral. A seguir, alguns links relevantes:

<br>
<br>

<div class="home-row clearfix" style="text-align:center">
   <div class="home-col"><div class="panel home-panel"><div class="panel-body">

   [![Primeiros Passos](../assets/icon-basic.png ":no-zoom")](/pt-br/getting-started?id=primeiros-passos)

   </div><div class="panel-heading">

   [Primeiros Passos](/pt-br/getting-started?id=primeiros-passos)

   </div></div></div>

   <div class="home-col"><div class="panel home-panel"><div class="panel-body">

   [![Conceitos Gerais](../assets/icon-parts.png ":no-zoom")](/pt-br/getting-started?id=conceitos-gerais)

   </div><div class="panel-heading">

   [Conceitos Gerais](/pt-br/getting-started?id=conceitos-gerais)

   </div></div></div>

   <div class="home-col"><div class="panel home-panel"><div class="panel-body">

   [![Arquitetura](../assets/icon-advanced.png ":no-zoom")](/pt-br/architecture)

   </div><div class="panel-heading">

   [Arquitetura](/pt-br/architecture)

   </div></div></div>

   <div class="home-col"><div class="panel home-panel"><div class="panel-body">

   [![Tutoriais](../assets/icon-tutorial.png ":no-zoom")](/pt-br/tutorial)

   </div><div class="panel-heading">

   [Tutoriais](/pt-br/tutorial)

   </div></div></div>
</div>

[Lua 5.1]:https://app.travis-ci.com/github/nidorx/ecs-lua
[Lua 5.2]:https://app.travis-ci.com/github/nidorx/ecs-lua
[Lua 5.3]:https://app.travis-ci.com/github/nidorx/ecs-lua
[Lua 5.4]:https://app.travis-ci.com/github/nidorx/ecs-lua
[LuaJit]:https://app.travis-ci.com/github/nidorx/ecs-lua
