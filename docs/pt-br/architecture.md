# Arquitetura

Em Engenharia de Software, ECS é o acrônimo de Entity Component System (em português: Sistema de Componente e Entidade), 
é um padrão de arquitetura de software usado principalmente no desenvolvimento de jogos eletrônicos. Um ECS segue o 
princípio da "composição ao invés de herança" que permite uma flexibilidade maior na definição de entidades, onde cada 
objeto em uma cena de um jogo é uma entidade (por exemplo inimigos, projéteis, veículos, etc.). Cada entidade consiste 
de um ou mais componentes que adicionam comportamento ou funcionalidade. Portanto, o comportamento de uma entidade pode 
ser alterado durante o tempo de execução simplesmente adicionando ou removendo componentes. Isso elimina problemas de 
ambiguidade com que sofrem as hierarquias de herança profunda e vasta, que são difíceis de entender, manter e estender.

Para mais detalhes:
- [Perguntas Freqüentes sobre ECS](https://github.com/SanderMertens/ecs-faq)
- [Entity Systems Wiki](http://entity-systems.wikidot.com/)
- [Evolua sua hierarquia](http://cowboyprogramming.com/2007/01/05/evolve-your-heirachy/)
- [ECS na Wikipedia](https://en.wikipedia.org/wiki/Entity_component_system)
- [ECS no Elixir](https://yos.io/2016/09/17/entity-component-systems/)
- [2017 GDC - Overwatch Gameplay Architecture e Netcode](https://www.youtube.com/watch?v=W3aieHjyNvw&ab_channel=GDC)


## Componente

Representam as diferentes características de uma entidade, como posição, velocidade, geometria, física e pontos de vida. 
Os componentes armazenam apenas dados brutos para um aspecto do objeto e como ele interage com o mundo. Em outras 
palavras, o componente rotula a entidade como tendo este aspecto particular.

No **ECS Lua**, a criacao de um componente é feito por meio do método `ECS.Component(template)`.

O parametro `template` pode ser de qualquer tipo, onde: 
- Quando `table`, este template sera usado para a criacao de instancias de componentes
   ```lua
   local Componente = ECS.Component({
      x = 0, y = 0, z = 0 
   })

   local comp = Componente({ x = 33, z = 80 })
   print(comp.x, comp.y, comp.z) -- > 33, 0, 80

   -- é o mesmo que 
   local comp = Componente.New({ x = 33, z = 80 })
   print(comp.x, comp.y, comp.z) -- > 33, 0, 80
   ```
- Quando for uma `function`, essa sera invocada na instanciacao de um novo componente. O parametro de criacao do 
componente é passado para a funcao de template
   ```lua
   local Componente = ECS.Component(function(param)
      return {
         x = param.x or 1,
         y = param.y or 1,
         z = param.z or 1
      }
   end)

   local comp = Componente({ x = 33, z = 80 })
   print(comp.x, comp.y, comp.z) -- > 33, 1, 80
   ```
- Caso o tipo do template seja diferente de `table` e `function`, o **ECS Lua** ira gerar um template no formato `{ value = template }`.
   ```lua
   local Componente = ECS.Component(55)

   local comp1 = Componente()
   print(comp1.value) -- > 55

   local comp2 = Componente({ value = 80 })
   print(comp2.value) -- > 80

   local comp3 = Componente("XPTO")
   print(comp3.value) -- > "XPTO"
   ```

### Métodos

No **ECS Lua**, os componentes são classes e podem portanto, possuir métodos auxiliares.

> IMPORTANTE! Evite criar métodos que modifiquem os dados da instancia do componente diretamente ou que possuam regras de 
negocio, o ideal é que essas lógicas fiquem dentro dos sistemas, que são, por definição, os responsáveis por alterar
os dados das entidades e seus componentes.

```lua
local Pessoa = ECS.Component({
   nome = "",
   sobrenome = "",
   nascimento = 0
})

function Pessoa:NomeCompleto()
   return self.nome.." "..self.sobrenome
end

function Pessoa:Idade()
   return tonumber(os.date("%Y", os.time())) - self.nascimento
end


local pessoa = Componente({ nome = "Joao", sobrenome = "Silva", nascimento = 2000 })

print(pessoa:NomeCompleto()) -- Joao Silva
print(pessoa:Idade()) -- 21
```

### Qualificadores

Nas implementações "ECS puras" existe a premissa de que um componente só pode ser adicionado uma única vez em uma entidade. 
Na grande maioria dos cenários, isso é verdade. Como por exemplo, você náo deseja que a sua entidade possua duas 
posições, não faz sentido! Portanto, sua entidade só irá possuir um componente do tipo Posição. 

Mas, as vezes voce irá construi alguma funcionalidade que precisa que sua entidade possua esse comportamento, possuir 
mais de um componente do mesmo **TIPO**. Quando o framework não dá suporte a esse tipo de implementação, voce acaba 
fazendo várias [gambiarras](https://pt.wikipedia.org/wiki/Gambiarra) para contornar o problema.

O **ECS Lua** implementa o mecanismo de **Qualificadores** para que voce possa representar uma categoria de componentes.

Para ilustrar o uso, vamos pensar no seguinte cenário: Eu quero adicionar no meu jogo um sistema de 
[Buff](https://en.wikipedia.org/wiki/Game_balance#Buff) para que meu personagem possa receber pontos extras de vida 
em situações específicas. Nós queremos ter a liberdade de aumentar ou diminuir a quantidade de buff de acordo com a 
regiao do mapa em que o jogador está.

Olhando para o cenario acima, poderiamos criar, em um primeiro momento, a solucao abaixo. Um componente `HealthBuff` 
para registrar a quantidade de vida extra e dois sistemas. O primeiro `MapRegionSystem` decide quantos pontos de vida 
adicional o jogador tera para cada regiao, já o segundo `HealthSystem` representa alguma funcionalidade do sistema que 
precisa obter o total de vida do jogador em certo momento.

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
         entity[HealthBuff] = nil -- remove o buff
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

Até aqui tranquilo. Porém, imagine agora que meu jogador possa receber **VÁRIOS** buffers. 
   - Ele pode receber um buffer pelo personagem que esta usando;
   - mais um buff quando desbloquear um item e;
   - pode também comprar buff na loja do jogo.

Neste novo cenário a nossa solução nao atende, pois o código do sistema `MapRegionSystem` não tem a informacao sobre os 
outros fatores, e para atender, deverá passar a conhecer ou gerenciar vários estados possíveis para decidir qual é a 
quantidade de vida que o jogador irá receber por estar em uma regiao específica. Os outros sistemas do jogo também 
precisaram conhecer a regiao para decir quanto de buffer pode somar. Em uma solução "ECS pura", nós vamos comecar a: 

1. compartilhar estado entre sistemas
1. criar "Componentes TAGs" para facilitar o gerenciamento desse estado distribuido, 
1. inflar os componentes com um atributo para cada tipo de sistema. 

Em um primeiro momento isso nao parece ser problema, mas com o tempo, vários sistemas serão executados de forma 
desnecessária (apenas para fazer um if e nao processar aquela entidade). Estes sistemas passaram a ter 
responsabilidades extras, aumentando a complexidade do codigo, dificultando a manutencao e facilitando o 
aparecimento de bugs.

No **ECS Lua**  nós resolvemos este tipo de problema criando qualificadores, por meio do método estático 
`ComponentClass.Qualifier(qualifier)`. Ele aceita uma string como parametro e retorna a referencia para uma classe 
especializada do nosso componente. Essa classe gerada mantém uma ligação forte com a classe base, permitindo a aplicacao 
de filtros de consulta mais complexas.

Vamos alterar o nosso exemplo fazendo uso de qualificadores. 

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
         entity[HealthBuffItem] = 15 -- o mesmo que entity:Set(HealthBuffItem.New(15))
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
         elseif player.Region == "hell" then
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

Pronto, nessa nova implementacao, o sistema `MapRegionSystem` só preocupa-se com o qualificador `HealthBuffMapRegion`, 
enquanto que o sistema `PlayerItemSystem` gerencia apenas o qualificador `HealthBuffItem`. Nos podemos agora criar 
sistemas especializados em qualificadores e gerenciar apenas este atributo da entidade. Já o `HealthSystem` obtém e 
processa todas as entidades que possuam qualquer qualificador do componente `HealthBuff`.

[Verifique na API](/pt-br/api?id=component) outros métodos que podem ser úteis ao trabalhar com qualificadores.

### FSM - Máquinas de Estado Finito

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

## Entidade

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

## Consulta

__UNDER_CONSTRUCTION__

## Sistema

__UNDER_CONSTRUCTION__

## Tarefas

__UNDER_CONSTRUCTION__

## Mundo

__UNDER_CONSTRUCTION__





