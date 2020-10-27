
-- Services
local RunService = game:GetService('RunService')

--[[

   https://www.youtube.com/watch?v=W3aieHjyNvw&ab_channel=GDC
   https://developer.roblox.com/en-us/articles/task-scheduler
   https://medium.com/@timonpost/game-networking-1-interval-and-ticks-b39bb51ccca9
   http://clintonbrennan.com/2013/12/lockstep-implementation-in-unity3d/
   https://www.youtube.com/watch?v=W5lUCeAu_2k&feature=emb_logo&ab_channel=Battle%28non%29sense
   https://www.raywenderlich.com/7630142-entity-component-system-for-unity-getting-started
   https://levelup.gitconnected.com/a-simple-guide-to-get-started-with-unity-ecs-b0e6a036e707
   https://www.raywenderlich.com/7630142-entity-component-system-for-unity-getting-started

   Remover closures, transformar funções em locais

   @TODO
      - Table pool (avoid GC)
      - System readonly? Paralel execution
      - Debugging?
      - Fazer benchmark usando cubos do Unity (Local Script vs ECS implementation)
      - Basic physics (managed)
      - TagComponents
      - SharedComponent?
]]


local function NOW()
	return DateTime.now().UnixTimestampMillis
end

local PRINT_LIMIT_LAST_TIME = {}
local PRINT_LIMIT_COUNT = {}
local function debugF(message)
   local t =  PRINT_LIMIT_LAST_TIME[message]
   if t ~= nil then
      if (t + 1000) < NOW() then
         print(PRINT_LIMIT_COUNT[message],' times > ', message)
         PRINT_LIMIT_LAST_TIME[message] = NOW()
         PRINT_LIMIT_COUNT[message] = 0
         return
      end
      PRINT_LIMIT_COUNT[message] =  PRINT_LIMIT_COUNT[message] + 1
   else
      PRINT_LIMIT_LAST_TIME[message] = NOW()
      PRINT_LIMIT_COUNT[message] = 1
   end
end

-- precision
local EPSILON = 0.0000000001

local function floatEQ(n0, n1)
   if n0 == n1 then
      return true
   end
   
   return math.abs(n1 - n0) < EPSILON
end

local function vectorEQ(v0, v1)
   if v0 == v1 then
      return true
   end

   if not floatEQ(v0.X, v1.X) or not floatEQ(v0.Y, v1.Y) or not floatEQ(v0.Z, v1.Z) then
      return false
   else
      return true
   end
end

-- Ensures values are unique, removes nil values as well
local function safeNumberTable(values)
   if values == nil then
      values = {}
   end

   local hash = {}
	local res  = {}
   for _,v in pairs(values) do
      if v ~= nil and hash[v] == nil then
         table.insert(res, v)
         hash[v] = true
      end
   end
   table.sort(res)
	return res
end

-- generate an identifier for a table that has only numbers
local function hashNumberTable(numbers)
   numbers = safeNumberTable(numbers)
   return '_' .. table.concat(numbers, '_'), numbers
end

--[[
   Global cache result.

   The validated components are always the same (reference in memory, except within the archetypes),
   in this way, you can save the result of a query in an archetype, reducing the overall execution
   time (since we don't need to iterate all the time)

   @Type { [key:Array<number>] : { matchAll,matchAny,rejectAll|rejectAny: {[key:string]:boolean} } }
]]
local FILTER_CACHE_RESULT = {}

--[[
   Generate a function responsible for performing the filter on a list of components.
   It makes use of local and global cache in order to decrease the validation time (avoids looping in runtime of systems)

   Params
      requireAll {Array<number>}
      requireAny {Array<number>}
      rejectAll {Array<number>}
      rejectAny {Array<number>}

   Returns function(Array<number>) => boolean
]]
local function componentFilter(requireAll, requireAny, rejectAll, rejectAny)

   -- local cache (L1)
   local cache = {}

   local requireAllKey, requireAnyKey, rejectAllKey, rejectAnyKey

   requireAllKey, requireAll  = hashNumberTable(requireAll)
   requireAnyKey, requireAny  = hashNumberTable(requireAny)
   rejectAllKey, rejectAll    = hashNumberTable(rejectAll)
   rejectAnyKey, rejectAny    = hashNumberTable(rejectAny)

   -- match function
   return function(components)

      -- check local cache
      local cacheResult = cache[components]
      if cacheResult == false then
         return false

      elseif cacheResult == true then
         return true

      else

         -- check global cache (executed by other filter instance)
         local cacheResultG = FILTER_CACHE_RESULT[components]
         if cacheResultG == nil then
            cacheResultG = { matchAny = {}, matchAll = {}, rejectAny = {}, rejectAll = {} }
            FILTER_CACHE_RESULT[components] = cacheResultG
         end

         -- verifica se essas combinações existem nesse array de componentes
         if rejectAnyKey ~= '_' then
            if cacheResultG.rejectAny[rejectAnyKey] or cacheResultG.rejectAll[rejectAnyKey] then
               cache[components] = false
               return false
            end

            for _, v in pairs(rejectAny) do
               if table.find(components, v) then
                  cache[components] = false
                  cacheResultG.matchAny[rejectAnyKey] = true
                  cacheResultG.rejectAny[rejectAnyKey] = true
                  return false
               end
            end
         end

         if rejectAllKey ~= '_' then
            if cacheResultG.rejectAll[rejectAllKey] then
               cache[components] = false
               return false
            end

            local haveAll = true
            for _, v in pairs(rejectAll) do
               if not table.find(components, v) then
                  haveAll = false
                  break
               end
            end

            if haveAll then
               cache[components] = false
               cacheResultG.matchAll[rejectAllKey] = true
               cacheResultG.rejectAll[rejectAllKey] = true
               return false
            end
         end

         if requireAnyKey ~= '_' then
            if cacheResultG.matchAny[requireAnyKey] or cacheResultG.matchAll[requireAnyKey] then
               cache[components] = true
               return true
            end

            for _, v in pairs(requireAny) do
               if table.find(components, v) then
                  cacheResultG.matchAny[requireAnyKey] = true
                  cache[components] = true
                  return true
               end
            end
         end

         if requireAllKey ~= '_' then
            if cacheResultG.matchAll[requireAllKey] then
               cache[components] = true
               return true
            end

            local haveAll = true
            for _, v in pairs(requireAll) do
               if not table.find(components, v) then
                  haveAll = false
                  break
               end
            end

            if haveAll then
               cache[components] = true
               cacheResultG.matchAll[requireAllKey] = true
               cacheResultG.rejectAll[requireAllKey] = true
               return true
            end
         end

         cache[components] = false
         return false
      end
   end
end


----------------------------------------------------------------------------------------------------------------------
-- ARCHETYPE
----------------------------------------------------------------------------------------------------------------------

--[[
    Archetype:
      Uma entidade possui um Archetype (definido pelos componentes que possui). Um arquetipo é um 
      identificador para cada combinção única de componentes. Um arquétipo é singleton

      O ECS usa os arqétipos para agrupar entidades que possuem a mesma estrutura juntas. 
      O ECS guarda estes componentes em blocos de memória chamados "chunks". Um  chunk só guarda 
      entidades que possue a mesma estrutura

      chunkCount: Numero de chunks usados para guardar entitades deste tipo 
]]
local ARCHETYPES = {}

-- Moment when the last archetype was recorded. Used to cache the systems execution plan
local LAST_ARCHETYPE_INSTANT = NOW()

local Archetype  = {}
Archetype.__index = Archetype

--[[
   Obtém a referencia para um arquétipo a partir dos componentes informados

   Params
      components Array<number> IDs dos componentes que definem esse arquétipo
]]
function Archetype.get(components)

   local id

   id, components = hashNumberTable(components)

   if ARCHETYPES[id] == nil then
      ARCHETYPES[id] = setmetatable({
         id          = id,
         components  = components
      }, Archetype)

      LAST_ARCHETYPE_INSTANT = NOW()
   end

   return ARCHETYPES[id]
end

--[[
   Obtém a referência para um arquétipo que possua os componentes atuais + o component informado
]]
function Archetype:with(component)
   if table.find(self.components, component) ~= nil then
      -- componente existe nessa lista, retorna o próprio arquétipo
      return self
   end

   -- obtém a referencia para 
   local len = table.getn(self.components)
   local newCoomponents = table.create(len + 1)
   newCoomponents[0] = component
   table.move(self.components, 1, len, 2, newCoomponents)
   return Archetype.get(newCoomponents)
end

--[[
   Obtém a referência para um arquétipo que possua os componentes atuais - o component informado
]]
function Archetype:without(component)
   if table.find(self.components, component) == nil then
      -- componente não existe nessa lista, retorna o próprio arquétipo
      return self
   end

   -- obtém a referencia para
   local len = table.getn(self.components)
   local newCoomponents = table.create(len - 1)
   local a = 1
   for i = 1, len do
      if self.components[i] ~= component then
         newCoomponents[a] = self.components[i]
         a = a + 1
      end
   end

   return Archetype.get(newCoomponents)
end

-- Arquétipo generico, para entidades que não possuem componentes
local ARCHETYPE_EMPTY = Archetype.get({})

----------------------------------------------------------------------------------------------------------------------
-- COMPONENT
----------------------------------------------------------------------------------------------------------------------
local COMPONENTS_NAME            = {}
local COMPONENTS_CONSTRUCTOR     = {}
local COMPONENTS_IS_TAG          = {}
local COMPONENTS_INDEX_BY_NAME   = {}

local function DEFAULT_CONSTRUCOTR(value)
   return value
end

local Component  = {
   --[[
      Register a new component

      Params:
         name {String} Unique identifier for this component

         constructor {Function} Allow you to validate or parse data

         @TODO: shared  {Boolean} (see https://docs.unity3d.com/Packages/com.unity.entities@0.7/manual/shared_component_data.html)

      Returns component ID
   ]]
   register = function(name, constructor, isTag) : number

      if name == nil then
         error('Component name is required for registration')
      end

      if constructor ~= nil and type(constructor) ~= 'function' then
         error('The component constructor must be a function, or nil')
      end

      if constructor == nil then
         constructor = DEFAULT_CONSTRUCOTR
      end

      if isTag == nil then
         isTag = false
      end

      if COMPONENTS_INDEX_BY_NAME[name] ~= nil then
         error('Another component already registered with that name')
      end

      -- component type ID = index
      local ID = table.getn(COMPONENTS_NAME) + 1

      COMPONENTS_INDEX_BY_NAME[name] = ID

      table.insert(COMPONENTS_NAME, name)
      table.insert(COMPONENTS_IS_TAG, isTag)
      table.insert(COMPONENTS_CONSTRUCTOR, constructor)

      return ID
   end
}

-- identificador especial usado para identificar a entidade dona de um dado
local ENTITY_ID_KEY = Component.register('_ECS_ENTITY_ID_')

----------------------------------------------------------------------------------------------------------------------
-- CHUNK
----------------------------------------------------------------------------------------------------------------------
local Chunk  = {}
Chunk.__index = Chunk

local CHUNK_SIZE = 500

--[[
   A block of memory containing the components for entities sharing the same Archetype

   Um chunk é uma base de dados burra, apenas organiza em memória os componentes
]]
function  Chunk.new(world, archetype)

   local buffers = {}
    -- um buffer especial que identifica o id da entidade
   buffers[ENTITY_ID_KEY] = table.create(CHUNK_SIZE)

   for _, componentID in pairs(archetype.components) do
      if COMPONENTS_IS_TAG[componentID] then
         -- tag component dont consumes memory
         buffers[componentID] = nil
      else
         buffers[componentID] = table.create(CHUNK_SIZE)
      end
   end

   return setmetatable({
      version     = 0,
      count       = 0,
      world       = world,
      archetype   = archetype,
      buffers     = buffers,
   }, Chunk)
end

--[[
   Realiza a limpeza de um índice específico dentro deste chunk
]]
function  Chunk:clear(index)
   local buffers = self.buffers
   for k in pairs(buffers) do
     buffers[k][index] = nil
   end
end

--[[
   Obtém o valor de um componente para um indice específico

   Params
      index {number}
         posição no chunk

      component {number}
         Id do component
]]
function Chunk:getValue(index, component)
   local buffers = self.buffers
   if buffers[component] == nil then
      return nil
   end
   return buffers[component][index]
end

--[[
   Obtém o valor de um componente para um indice específico

   Params
      index {number}
         posição no chunk

      component {number}
         Id do component

      value {any}
         Valor a ser persistido em memória
]]
function Chunk:setValue(index, component, value)
   local buffers = self.buffers
   if buffers[component] == nil then
      return
   end
   buffers[component][index] = value
end

--[[
   Obtém todos os dados do buffer em um índice especifico
]]
function Chunk:get(index)
   local data = {}
   local buffers = self.buffers
   for component in pairs(buffers) do
      data[component] = buffers[component][index]
   end
   return data
end

--[[
   Seta todos os dados do buffer para o índice específico. 

   Copia apenas os dados dos componentes existentes neste chunk (portanto, ignora outros registros)
]]
function Chunk:set(index, data)
   local buffers = self.buffers
   for component, value in pairs(data) do
      if buffers[component] ~= nil then
         buffers[component][index] = value
      end
   end
end

--[[
   Define o entity a qual esse dado pertence
]]
function Chunk:setEntityId(index, entity)
   self.buffers[ENTITY_ID_KEY][index] = entity
end


----------------------------------------------------------------------------------------------------------------------
-- ENTITY MANAGER
----------------------------------------------------------------------------------------------------------------------

--[[
   Responsável por gerenciar as entidades e chunks de um world.
]]
local EntityManager  = {}
EntityManager.__index = EntityManager

function  EntityManager.new(world)
   return setmetatable({
      world = world,

      COUNT = 0,

      --[[
         Qual é o índice local dessa entidade (para acesso aos outros valores)

         @Type { [entityID] : { archetype: string, chunk: number, chunkIndex: number } }
      ]]
      ENTITIES = {},

      --[[
         { 
            [archetypeID] : {
               -- Qual é o índice do útimo chunk livre para uso?
               lastChunk:number,
               -- Dentro do chunk disponível, qual é o próximo indice disponível para alocação?
               -- The number of entities currently stored in the chunk.
               nextChunkIndex:number,
               chunks: Array<Chunk>}
            }
      ]]
      ARCHETYPES   = {}
   }, EntityManager)
end

--[[
   Reserva o espaço pra uma entidade em um chunk desse arquétipo

   É importante que alterações no EntityManager principal só ocorra após 
      a execução do frame corrente (update de scripts), pois alguns scripts executam em paralelo,
      deste modo pode apontar para índice errado durante a execução
   
   A estratégia para evitar estes problemas é que o mundo possua 2 EntityManagers distintos,
      1 - EntityManager Principal
         Onde estão registrados as entidaes que serão atualizados no update dos scripts
      2 - EntityManager Novo
         Onde o sistema registra as novas entidades criadas durante a execução dos scripts. 
         Após a finalização da execução atual, copia-se todas essas novas entidades para o 
         EntityManager principal
]]
function  EntityManager:set(entityID, archetype)

   local archetypeID = archetype.id
   local entity      = self.ENTITIES[entityID]

   local oldEntityData = nil

   -- entidade já está registrada neste entity manager?
   if entity ~= nil then
      if entity.archetype == archetypeID then
         -- entidade já está registrada no arquétipo informado, nada a fazer
         return
      end

      -- Arquétipo diferente
      -- faz backup dos dados antigos
      oldEntityData = self.ARCHETYPES[entity.archetype].chunks[entity.chunk]:get(entity.chunkIndex)

      -- remove entidade do arquétipo (e consequentemente chunk) atual
      self:remove(entityID)
   end

   -- Verifica se tem chunk disponível (pode ser a primeira entidade para o arquétipo informado)
   if self.ARCHETYPES[archetypeID] == nil then
      -- não existe nenhum chunk para esse arquétipo, inicia a lista
      self.ARCHETYPES[archetypeID] = {
         count          = 0,
         lastChunk      = 1,
         nextChunkIndex = 1,
         chunks         = { Chunk.new(self.world, archetype) }
      }
   end

   -- aldiciona entidade no fim do chunk correto
   local db = self.ARCHETYPES[archetypeID]

   -- novo registro da entidade
   self.ENTITIES[entityID] = {
      archetype   = archetypeID,
      chunk       = db.lastChunk,
      chunkIndex  = db.nextChunkIndex
   }
   self.COUNT = self.COUNT + 1

   local chunk = db.chunks[db.lastChunk]

   -- Limpa qualquer lixo de memória
   chunk:clear(db.nextChunkIndex)

    -- atualiza índices da entidade
    if oldEntityData ~= nil then
      -- se é mudança de arquétipo, restaura o backup dos dados antigos
      chunk:set(db.nextChunkIndex, oldEntityData)
    end
    chunk:setEntityId(db.nextChunkIndex, entityID)

   db.count = db.count + 1
   chunk.count = db.nextChunkIndex

   -- atualiza indice do chunk
   db.nextChunkIndex = db.nextChunkIndex + 1

   -- marca a nova versão do CHUNK (momento que houve alteração)
   chunk.version = self.world.version

   -- se o chunk estiver cheio, já cria um novo chunk para recepcionar novas entidades futuras
   if db.nextChunkIndex > CHUNK_SIZE  then
      db.lastChunk            = db.lastChunk + 1
      db.nextChunkIndex       = 1
      db.chunks[db.lastChunk] = Chunk.new(self.world, archetype)
   end
end

--[[
   Remove uma entidade deste entity manager

   Faz a limpeza dos índices e reorganização dos dados no Chunk

   É importante que alterações no EntityManager principal só ocorra após 
      a execução do frame corrente (update de scripts), pois alguns scripts executam em paralelo,
      deste modo pode apontar para índice errado durante a execução.

   A estratégia para evitar tais problemas é que o sistema registre em uma tabela separado os 
      IDs das entidades removidas durante a execução dos scripts. Após a finalização da execução 
      atual, solicita a remoção de fato dessas entidades do EntityManager principal
]]
function  EntityManager:remove(entityID)
   local entity = self.ENTITIES[entityID]

   if entity == nil then
      return
   end

   local db = self.ARCHETYPES[entity.archetype]
   local chunk = db.chunks[entity.chunk]

   -- limpa dados no chunk
   chunk:clear(entity.chunkIndex)
   chunk.count = chunk.count - 1

   -- limpa referencias da entidade
   self.ENTITIES[entityID] = nil
   self.COUNT = self.COUNT - 1
   db.count = db.count - 1

   -- Ajusta os chunks, evita buracos
   if db.nextChunkIndex == 1 then
      -- o último chunk está vazio e foi removido um item de algum chunk anterior
      -- sistema deve remover este chunk (pois existe um buraco nos chunks anteriores que deve ser preenchido antes)
      db.chunks[db.lastChunk] = nil
      db.lastChunk      = db.lastChunk - 1
      db.nextChunkIndex = CHUNK_SIZE + 1 -- (+1, proximos passos pego o valor -1)
   end

   if db.count > 0 then
      if db.nextChunkIndex > 1 then
         -- Move ultimo item do ultimo chunk para a posição que ficou aberta, para isso, necessário desobrir a
         -- qual entidade pertence, afim de manter as referencias consistentes
         local otherEntityData = db.chunks[db.lastChunk]:get(db.nextChunkIndex-1)
         db.chunks[entity.chunk]:set(entity.chunkIndex, otherEntityData)
   
         -- recua o apontamento e faz a limpeza do registro não usado
         db.nextChunkIndex = db.nextChunkIndex - 1
         db.chunks[db.lastChunk]:clear(db.nextChunkIndex)
   
         -- atualiza índices da entidade
         local otherEntityID     = otherEntityData[ENTITY_ID_KEY]
         local otherEntity       = self.ENTITIES[otherEntityID]
         otherEntity.chunk       = entity.chunk
         otherEntity.chunkIndex  = entity.chunkIndex
      end
   else
      db.nextChunkIndex = db.nextChunkIndex - 1
   end
end

--[[
   Quantas entidades este EntityManager possui
]]
function EntityManager:count()
   return self.COUNT
end

--[[
   Realiza a limpeza dos dados de uma entidae SEM REMOVE-LA.

   Usada durante a execução dos scripts quando um script solicita a remoção 
      de uma entidade. Como o sistema posterga a remoção real até o fim da execução dos scripts, 
      neste momento ele apenas realiza a limpeza dos dados (Permitindo aos scripts posteriores 
      realizarem a verificação)
]]
function EntityManager:clear(entityID)
   local entity = self.ENTITIES[entityID]
   if entity == nil then
      return
   end

   local chunk = self.ARCHETYPES[entity.archetype].chunks[entity.chunk]
   chunk:clear(entity.chunkIndex)
end

--[[
   Obtém o valor atual de um componente de uma entidade

   Params
      entity {number} 
      component {number}
]]
function EntityManager:getValue(entityID, component)
   local entity = self.ENTITIES[entityID]
   if entity == nil then
      return nil
   end

   return self.ARCHETYPES[entity.archetype].chunks[entity.chunk]:getValue(entity.chunkIndex, component)
end

--[[
   Salva o valor de um componente de uma entidade

   Params
      entity {number} 
         Id da entidade a ser alterada

      component {number}
         ID do componente

      value {any}
         Novo valor
]]
function EntityManager:setValue(entityID, component, value)
   local entity = self.ENTITIES[entityID]
   if entity == nil then
      return 
   end

   local chunk = self.ARCHETYPES[entity.archetype].chunks[entity.chunk]

  

   chunk:setValue(entity.chunkIndex, component, value)
end

--[[
   Obtém todos os valores dos componentes de uma entidade

   Params
      entity {number}
         ID da entidade
]]
function EntityManager:getData(entityID)
   local entity = self.ENTITIES[entityID]
   if entity == nil then
      return nil
   end

   local chunk = self.ARCHETYPES[entity.archetype].chunks[entity.chunk]
   return chunk:get(entity.chunkIndex)
end

--[[
   Salva o valor de um componente de uma entidade

   Params
      entity {number} 
         Id da entidade a ser alterada

      component {number}
         ID do componente

      data {table}
         Tabela com os novos valores que serão persistidos em memória neste chunk
]]
function EntityManager:setData(entityID, component, data)
   local entity = self.ENTITIES[entityID]
   if entity == nil then
      return
   end

   local chunk = self.ARCHETYPES[entity.archetype].chunks[entity.chunk]
   chunk:set(entity.chunkIndex, component, data)
end


--[[
   Obtém o chunk e o índice de uma entidade
]]
function EntityManager:getEntityChunk(entityID)
   local entity = self.ENTITIES[entityID]
   if entity == nil then
      return
   end

   return self.ARCHETYPES[entity.archetype].chunks[entity.chunk], entity.chunkIndex
end

--[[
   Gets all chunks that match the given filter

   Params
      filterFn {function(components) => boolean}
]]
function EntityManager:filterChunks(filterMatch)
   local chunks = {}
   for archetypeID, db in pairs(self.ARCHETYPES) do
      if filterMatch(ARCHETYPES[archetypeID].components) then
         for i, chunk in pairs(db.chunks) do
            table.insert(chunks, chunk)
         end
      end
   end
   return chunks
end

----------------------------------------------------------------------------------------------------------------------
-- SYSTEM
----------------------------------------------------------------------------------------------------------------------
local SYSTEM                 = {}
local SYSTEM_INDEX_BY_NAME   = {}

-- Filter: require all, require any, reject all, reject any


--[[
   Represents the logic that transforms component data of an entity from its current 
   state to its next state. A system runs on entities that have a specific set of 
   component types.
]]
local System  = {}

--[[
   Allow to create new System Class Type

   Params:
      config {

         name: string,
            Unique name for this System

         requireAll|requireAny: Array<number|string>,
            components this system expects the entity to have before it can act on. If you want 
            to create a system that acts on all entities, enter nil

         rejectAll|rejectAny: Array<number|string>,
            Optional It allows informing that this system will not be invoked if the entity has any of these components

         

         step: render|process|transform Defaults to process
            Em qual momento, durante a execução de um Frame do Roblox, este sistema deverá ser executado (https://developer.roblox.com/en-us/articles/task-scheduler)
            render      : RunService.RenderStepped
            process     : RunService.Stepped
            transform   : RunService.Heartbeat

         order: number,
            Allows you to define the execution priority level for this system

         readonly: boolean, (WIP)
            Indicates that this system does not change entities and components, so it can be executed
            in parallel with other systems in same step and order

         -- Versionamento, ver https://gametorrahod.com/designing-an-efficient-system-with-version-numbers/
         update: function(time, world, dirty, entity, index, [component_N_items...]) -> boolean
            Invoked in updates, limited to the value set in the "frequency" attribute			
         			 	
			beforeUpdate(time: number): void
			 	Invoked before updating entities available for this system. 
			 	It is only invoked when there are entities with the characteristics 
			 	expected by this system.			 	  	 
			 
			afterUpdate(time: number, entities: Entity[]): void
			 	Invoked after performing update of entities available for this system. 
			 	It is only invoked when there are entities with the characteristics 
			 	expected by this system
			 	
			change(entity: Entity, added?: Component<any>, removed?: Component<any>): void
			 	 Invoked when an expected feature of this system is added or removed from the entity
			 	 			 	 
			   enter(entity: Entity): void;
			 	Invoked when:
			    	a) An entity with the characteristics (components) expected by this system is 
			    		added in the world;
			     	b) This system is added in the world and this world has one or more entities with 
			     		the characteristics expected by this system;
			     	c) An existing entity in the same world receives a new component at runtime 
			     		and all of its new components match the standard expected by this system.
			     		
			exit(entity: Entity): void;
				Invoked when:
     				a) An entity with the characteristics (components) expected by this system is 
     					removed from the world;
    				b) This system is removed from the world and this world has one or more entities 
    					with the characteristics expected by this system;
     				c) An existing entity in the same world loses a component at runtime and its new 
     					component set no longer matches the standard expected by this system
   }
]]
function System.register(config)

   if config == nil then
      error('System configuration is required for its creation')
   end

   if config.name == nil then
      error('The system "name" is required for registration')
   end

   if SYSTEM_INDEX_BY_NAME[config.name] ~= nil then
      error('Another System already registered with that name')
   end

   if config.requireAll == nil and config.requireAny == nil then
      error('It is necessary to define the components using the "requireAll" or "requireAny" parameters')
   end

   if config.requireAll ~= nil and config.requireAny ~= nil then
      error('It is not allowed to use the "requireAll" and "requireAny" settings simultaneously')
   end

   if config.requireAll ~= nil then
      config.requireAllOriginal = config.requireAll
      config.requireAll = safeNumberTable(config.requireAll)
      if table.getn(config.requireAll) == 0 then
         error('You must enter at least one component id in the "requireAll" field')
      end
   elseif config.requireAny ~= nil then
      config.requireAnyOriginal = config.requireAny
      config.requireAny = safeNumberTable(config.requireAny)
      if table.getn(config.requireAny) == 0 then
         error('You must enter at least one component id in the "requireAny" field')
      end
   end

   if config.rejectAll ~= nil and config.rejectAny ~= nil then
      error('It is not allowed to use the "rejectAll" and "rejectAny" settings simultaneously')
   end

   if config.rejectAll ~= nil then
      config.rejectAll = safeNumberTable(config.rejectAll)
      if table.getn(config.rejectAll) == 0 then
         error('You must enter at least one component id in the "rejectAll" field')
      end
   elseif config.rejectAny ~= nil then
      config.rejectAny = safeNumberTable(config.rejectAny)
      if table.getn(config.rejectAny) == 0 then
         error('You must enter at least one component id in the "rejectAny" field')
      end
   end

   if config.step == nil then
      config.step = 'transform'
   end

   if config.step ~= 'render' and config.step ~= 'process' and config.step ~= 'processIn' and config.step ~= 'processOut' and config.step ~= 'transform' then
      error('The "step" parameter must be "render", "process", "transform", "processIn" or "processOut"')
   end

   if config.order == nil or config.order < 0 then
		config.order = 50
   end

   -- imutable
   table.insert(SYSTEM, {
      name                 = config.name,
      requireAll           = config.requireAll,
      requireAny           = config.requireAny,
      requireAllOriginal   = config.requireAllOriginal,
      requireAnyOriginal   = config.requireAnyOriginal,
      rejectAll            = config.rejectAll,
      rejectAny            = config.rejectAny,
      beforeUpdate         = config.beforeUpdate,
      update               = config.update,
      onEnter              = config.onEnter,
      step                 = config.step,
      order                = config.order
   })

   local ID = table.getn(SYSTEM)

   SYSTEM_INDEX_BY_NAME[config.name] = ID

	return ID
end

--[[
   Generates an execution plan for the systems.
   An execution plan is a function that, when called, will perform the orderly processing of these systems.
]]
local function NewExecutionPlan(world, systems)

   local updateSteps = {
      render         = {},
      process        = {},
      transform      = {},
      processIn    = {},
      processOut   = {},
   }

   --[[      
      local updateStepsOrder = {
         render      = {},
         simulation  = {},
         heartbeat   = {},
      }
   ]]

   -- sistemas que esperam o evento onEnter
   local onEnterSystems = {}

   for k, system in pairs(systems) do
      -- filtro de componentes, usados para obter os chunks corretos no entity manager
      system.filter = componentFilter(system.requireAll, system.requireAny, system.rejectAll, system.rejectAny)

      if system.update ~= nil then
         if updateSteps[system.step][system.order] == nil then
            updateSteps[system.step][system.order] = {}
            --table.insert(updateStepsOrder[system.step], system.order)
         end

         table.insert(updateSteps[system.step][system.order], system)
      end

      if system.onEnter ~= nil then
         table.insert(onEnterSystems, system)
      end
   end

   --updateStepsOrder.render = safeNumberTable(updateStepsOrder.render)
   --updateStepsOrder.simulation = safeNumberTable(updateStepsOrder.render)
   --updateStepsOrder.heartbeat = safeNumberTable(updateStepsOrder.render)

   -- Update systems
   local onUpdate = function(step, entityManager, time, interpolation)
      for i, stepSystems  in pairs(updateSteps[step]) do
         for j, system  in pairs(stepSystems) do
            -- execute system update

            system.lastUpdate = time

            -- what components the system expects
            local whatComponents = system.requireAllOriginal
            if whatComponents == nil then
               whatComponents = system.requireAnyOriginal
            end

            local whatComponentsLen    = table.getn(whatComponents)
            local systemVersion        = system.version

            -- Gets all the chunks that apply to this system
            local chunks = entityManager:filterChunks(system.filter)

            -- update: function(time, world, dirty, entity, index, [component_N_items...]) -> boolean
            local updateFn = system.update

            -- increment Global System Version (GSV), before system update
            world.version = world.version + 1

            if system.beforeUpdate ~= nil then
               system.beforeUpdate(time, interpolation, world, system)
            end

            for k, chunk in pairs(chunks) do
               -- se a versão do chunk é maior do que o do sistema, significa que este chunk já sofreu
               -- alteração que não foi realizada após a última execução deste sistema
               local dirty = chunk.version == 0 or chunk.version > systemVersion
               local buffers = chunk.buffers
               local entityIDBuffer = buffers[ENTITY_ID_KEY]
               local componentsData = table.create(whatComponentsLen)

               local hasChangeThisChunk = false

               for l, compID in ipairs(whatComponents) do
                  if buffers[compID] ~= nil then
                     componentsData[l] = buffers[compID]
                  else
                     componentsData[l] = {}
                  end
               end

               for index = 1, chunk.count do
                  if updateFn(time, world, dirty, entityIDBuffer[index], index, table.unpack(componentsData)) then
                     hasChangeThisChunk = true
                  end
               end

               if hasChangeThisChunk then
                  -- If any system execution informs you that it has changed data in 
                  -- this chunk, it then performs the versioning of the chunk
                  chunk.version = world.version
               end
            end

            -- update last system version with GSV
            system.version = world.version
         end
      end
   end

   local onEnter = function(onEnterEntities, entityManager, time)
      -- increment Global System Version (GSV), before system update
      world.version = world.version + 1

      -- temporary filters
      local systemsFilters = {}

      for entityID, newComponents in pairs(onEnterEntities) do

         -- obtém o chunk e indice dessa entidade
         local chunk, index = entityManager:getEntityChunk(entityID)
         if chunk == nil then
            continue
         end

         local buffers = chunk.buffers
            
         for j, system in pairs(onEnterSystems) do

            -- system não aplica para o arquétipo dessa entidade
            if not system.filter(chunk.archetype.components) then
               continue
            end

            -- what components the system expects
            local whatComponents = system.requireAllOriginal
            if whatComponents == nil then
               whatComponents = system.requireAnyOriginal
            end

            if systemsFilters[system.id] == nil then
               systemsFilters[system.id] = componentFilter(nil, newComponents, nil, nil)
            end

            -- componentes recebidos não estão na lista dos componentes esperados pelo system
            if not systemsFilters[system.id](whatComponents) then
               continue
            end
            
            local componentsData = table.create(table.getn(whatComponents))

            for l, compID in ipairs(whatComponents) do
               if buffers[compID] ~= nil then
                  componentsData[l] = buffers[compID]
               else
                  componentsData[l] = {}
               end
            end

            -- onEnter: function(world, entity, index, [component_N_items...]) -> boolean
            if system.onEnter(time, world, entityID, index, table.unpack(componentsData)) then
               -- If any system execution informs you that it has changed data in
               -- this chunk, it then performs the versioning of the chunk
               chunk.version = world.version
            end
         end
      end
   end

   return onUpdate, onEnter
end

----------------------------------------------------------------------------------------------------------------------
-- ECS
----------------------------------------------------------------------------------------------------------------------

-- The very definition of the ECS. Also called Admin or Manager in other implementations.
local ECS = {
	-- references for simplicity, allow to use ECS.Entity
	Component 	= Component,
	System 		= System
}

-- constructor
function ECS.newWorld(systems, config)

   if config == nil then
      config = {}
   end

   -- frequence: number,
   -- The maximum times per second this system should be updated. Defaults 30
   if config.frequence == nil then
      config.frequence = 30
   end

   local safeFrequency  = math.round(math.abs(config.frequence)/5)*5
   if safeFrequency < 5 then
      safeFrequency = 5
   end

   if config.frequence ~= safeFrequency then
      config.frequence = safeFrequency
      print(string.format(">>> ATTENTION! The execution frequency of world has been changed to %d <<<", safeFrequency))
   end
   
   local SEQ_ENTITY 	= 1

   -- systems in this world
   local worldSystems = {}

   -- System execution plan
   local updateExecPlan, enterExecPlan

   -- Deve ser o mesmo valor do sistema com a maior frequencia (msPerUpdate = 1000/frequencia.)
   local proccessDeltaTime = 1000/config.frequence/1000

   -- INTERPOLATION: The proportion of time since the previous transform relative to proccessDeltaTime
   local interpolation           = 1

   local FIRST_UPDATE_TIME = nil

   local timeLastFrame     = 0

   -- The time at the beginning of this frame. The world receives the current time at the beginning 
   -- of each frame, with the value increasing per frame.
   local timeCurrentFrame  = 0

   -- The time the latest proccess step has started.
   local timeProcess  = 0

   local timeProcessOld = 0

   -- The completion time in seconds since the last frame. This property provides the time between the current and previous frame.
   local timeDelta = 0

   -- se a execução ficar lenta, realiza até 10 updates simultaneos
   -- afim de manter o fixrate
   local maxSkipFrames = 10

   local lastKnownArchetypeInstant = 0

   --[[
      O EntityManager principal

      É importante que alterações no EntityManager principal só ocorra após 
      a execução do frame corrente (update de scripts), pois alguns scripts executam em paralelo,
      deste modo pode apontar para índice errado durante a execução
   
      A estratégia para evitar estes problemas é que o mundo possua 2 EntityManagers distintos,
         1 - EntityManager Principal
            Onde estão registrados as entidaes que serão atualizados no update dos scripts
         2 - EntityManager Novo
            Onde o sistema registra as novas entidades criadas durante a execução dos scripts. 
            Após a finalização da execução atual, copia-se todas essas novas entidades para o 
            EntityManager principal
   ]]
   local entityManager

   -- O EntityManager usado para abrigar as novas entidades
   local entityManagerNew

   -- O EntityManager usado para abrigar a cópia dos dados da entidade que sofreu alteração
   -- No final da execução dos scripts, a entidade será atualizada no entity manger principal
   local entityManagerUpdated

   -- Entidades que foram removidas durante a execução (só remove após o último passo de execução)
   local entitiesRemoved = {}

   -- Entidades que sofreram alteraçao durante a execução
   -- (recebeu ou perdeu componentes, portanto, alterou o arquétipo)
   local entitiesUpdated = {}

   -- Entidades que foram criadas durante a execução do update, 
   -- serão transportadas do "entityManagerNew" para o "entityManager"
   local entitiesNew = {}

   -- referencia do arquétipo mais atualizado de uma entidade (sujo)
   -- A alteração do arquétipo nao reflete na execução atual dos scripts, é usado apenas para a atualização dos 
   -- dados no entity manager principal
   local entitiesArchetypes  = {}

   local world

   -- 
   local cleanupEnvironment

   -- True when environment has been modified while a system is running
   local dirtyEnvironment = false
   
	world = {

      version = 0,
      frequence = config.frequence,

      --[[
         Create a new entity
      ]]
      create = function()
         local ID = SEQ_ENTITY
         SEQ_ENTITY = SEQ_ENTITY + 1

         entityManagerNew:set(ID, ARCHETYPE_EMPTY)

         -- informa que possui nova entidade
         entitiesNew[ID] = true

         entitiesArchetypes[ID] = ARCHETYPE_EMPTY

         dirtyEnvironment = true

         return ID
      end,

      --[[
         Get entity compoment data
      ]]
      get = function(entity, component)
         if entitiesNew[entity] == true then
            return entityManagerNew:getValue(entity, component)
         else
            return entityManager:getValue(entity, component)
         end
      end,

      --[[
         Define o valor de um componente para uma entidade.

         Essa alteração
      ]]
      set = function(entity, component, ...)
         local archetype = entitiesArchetypes[entity]
         if archetype == nil then
            -- entity doesn exist
            return
         end

         dirtyEnvironment = true

         local archetypeNew = archetype:with(component)
         local archetypeChanged = archetype ~= archetypeNew
         if archetypeChanged then
            entitiesArchetypes[entity] = archetypeNew
         end

         local value = COMPONENTS_CONSTRUCTOR[component](table.unpack({...}))

         if entitiesNew[entity] == true then
            if archetypeChanged then
               entityManagerNew:set(entity, archetypeNew)
            end

            entityManagerNew:setValue(entity, component, value)
         else
            if archetypeChanged then
               -- entidade sofreu alteração de arquétipo. Registra uma cópia em outro entity manager, que será
               -- processado após a execução dos scripts atuais
               if entitiesUpdated[entity] == nil then
                  entitiesUpdated[entity] = {
                     received = {},
                     lost = {}
                  }
                  -- primeira vez que está modificando os componentes dessa entidade
                  -- nessa execução, necessário realizar copia dos dados da entidade
                  entityManagerUpdated:set(entity, archetypeNew)
                  entityManagerUpdated:setData(entity, entityManager:getData(entity))
               else
                  -- apenas realiza a atualização do arquétipo no entityManager
                  entityManagerUpdated:set(entity, archetypeNew)
               end
            end

            if entitiesUpdated[entity]  ~= nil then
               -- registra uma cópia do valor
               entityManagerUpdated:setValue(entity, component, value)

               -- removed before, received again
               local ignoreChange = false
               for k, v in pairs(entitiesUpdated[entity].lost) do
                  if v == component then
                     table.remove(entitiesUpdated[entity].lost, k)
                     ignoreChange = true
                     break
                  end
               end
               if not ignoreChange then
                  table.insert(entitiesUpdated[entity].received, component)
               end
            end

            -- registra o valor no entityManager atual, usado pelos scripts
            entityManager:setValue(entity, component, value)
         end
      end,

      --[[
         Removing a entity or Removing a component from a entity at runtime
      ]]
      remove = function(entity, component)
         local archetype = entitiesArchetypes[entity]
         if archetype == nil then
            return
         end

         if entitiesRemoved[entity] == true then
            return
         end

         dirtyEnvironment = true

         if component == nil then
            -- remove entity
            if entitiesNew[entity] == true then
               entityManagerNew:remove(entity)
               entitiesNew[entity] = nil
               entitiesArchetypes[entity] = nil
            else
               if entitiesRemoved[entity] == nil then
                  entitiesRemoved[entity] = true
               end
            end
         else
            -- remove component from entity
            local archetypeNew = archetype:without(component)
            local archetypeChanged = archetype ~= archetypeNew
            if archetypeChanged then
               entitiesArchetypes[entity] = archetypeNew
            end
            if entitiesNew[entity] == true then
               if archetypeChanged then
                  entityManagerNew:set(entity, archetypeNew)
               end
            else
               if archetypeChanged then

                  -- entidade sofreu alteração de arquétipo. Registra uma cópia em outro entity manager, que será
                  -- processado após a execução dos scripts atuais
                  if entitiesUpdated[entity] == nil then
                     entitiesUpdated[entity] = {
                        received = {},
                        lost = {}
                     }
                     -- primeira vez que está modificando os componentes dessa entidade
                     -- nessa execução, necessário realizar copia dos dados da entidade
                     entityManagerUpdated:set(entity, archetypeNew)
                     entityManagerUpdated:setData(entity, entityManager:getData(entity))
                  else
                     -- apenas realiza a atualização do arquétipo no entityManager
                     entityManagerUpdated:set(entity, archetypeNew)
                  end
               end

               if entitiesUpdated[entity] ~= nil then
                  -- registra uma cópia do valor
                  entityManagerUpdated:setValue(entity, component, nil)

                  -- received before, removed again
                  local ignoreChange = false
                  for k, v in pairs(entitiesUpdated[entity].received) do
                     if v == component then
                        table.remove(entitiesUpdated[entity].received, k)
                        ignoreChange = true
                        break
                     end
                  end
                  if not ignoreChange then
                     table.insert(entitiesUpdated[entity].lost, component)
                  end
               end

               -- registra o valor no entityManager atual, usado pelos scripts
               entityManager:setValue(entity, component, nil)
            end
         end
      end,

      --[[
         Get entity compoment data
      ]]
      has = function(entity, component)
         if entitiesArchetypes[entity] == nil then
            return false
         end

         return entitiesArchetypes[entity]:has(component)
      end,

      --[[
         Remove an entity from this world
      ]]
      addSystem = function (systemID, order, config)
         if systemID == nil then
            return
         end

         if SYSTEM[systemID] == nil then
            error('There is no registered system with the given ID')
         end

         if worldSystems[systemID] ~= nil then
            -- This system has already been registered in this world
            return
         end

         if entityManager:count() > 0 or entityManagerNew:count() > 0 then
            error('Adding systems is not allowed after adding entities in the world')
         end

         if config == nil then
            config = {}
         end

         local system = {
            id                   = systemID,
            name                 = SYSTEM[systemID].name,
            requireAll           = SYSTEM[systemID].requireAll,
            requireAny           = SYSTEM[systemID].requireAny,
            requireAllOriginal   = SYSTEM[systemID].requireAllOriginal,
            requireAnyOriginal   = SYSTEM[systemID].requireAnyOriginal,
            rejectAll            = SYSTEM[systemID].rejectAll,
            rejectAny            = SYSTEM[systemID].rejectAny,
            beforeUpdate         = SYSTEM[systemID].beforeUpdate,
            update               = SYSTEM[systemID].update,
            onEnter              = SYSTEM[systemID].onEnter,
            step                 = SYSTEM[systemID].step,
            order                = SYSTEM[systemID].order,
            -- instance properties
            version              = 0,
            lastUpdate           = timeProcess,
            config               = config
         }

         if order ~= nil and order < 0 then
            system.order = 50
         end

         worldSystems[systemID] = system

         if system.msPerUpdate ~= nil then
             -- o sistema com maior frequencia tem o menor ms por update
            proccessDeltaTime = math.min(proccessDeltaTime, system.msPerUpdate)
         end

         -- forces re-creation of the execution plan
         lastKnownArchetypeInstant = 0
      end,

      --[[
         Is the Entity still alive?
      ]]
      alive = function(entity)
         if entitiesArchetypes[entity] == nil then
            return false
         end

         if entitiesNew[entity] == true then
            return false
         end

         if entitiesRemoved[entity] == true then
            return false
         end

         return true
      end,

      --[[
         Remove all entities and systems
      ]]
      destroy = function()

         for i = #self.entities, 1, -1 do
            self:removeEntity(self.entities[i])
         end

         for i = #self.systems, 1, -1 do
            self:removeSystem(self.systems[i])
         end

         self._steppedConn:Disconnect()
      end,

      --[[
         Realizes world update
      ]]
      update = function(step, now)
         if not RunService:IsRunning() then
            return
         end

         if FIRST_UPDATE_TIME == nil then
            FIRST_UPDATE_TIME = now
         end

         -- corrects for internal time
         now = now - FIRST_UPDATE_TIME
         
         -- need to update execution plan?
         if lastKnownArchetypeInstant < LAST_ARCHETYPE_INSTANT then
            updateExecPlan, enterExecPlan = NewExecutionPlan(world, worldSystems)
            lastKnownArchetypeInstant = LAST_ARCHETYPE_INSTANT
         end

         if step ~= 'process' then
            -- executed only once per frame

            if timeProcess ~= timeProcessOld then
               interpolation = 1 + (now - timeProcess)/proccessDeltaTime
            else
               interpolation = 1
            end

            if step == 'processIn' then

               -- first step, initialize current frame time
               timeCurrentFrame  = now
               if timeLastFrame == 0 then
                  timeLastFrame = timeCurrentFrame
               end
               if timeProcess == 0 then
                  timeProcess    = timeCurrentFrame
                  timeProcessOld = timeCurrentFrame
               end
               timeDelta = timeCurrentFrame - timeLastFrame
               interpolation = 1

            elseif step == 'render' then
               -- last step, save last frame time
               timeLastFrame = timeCurrentFrame
            end

            updateExecPlan(step, entityManager, {
               process        = timeProcess,
               frame          = timeCurrentFrame,
               delta          = timeDelta
            }, interpolation)

            cleanupEnvironment()
         else

            local timeProcessOldTmp = timeProcess

            --[[
               Adjusting the framerate, the world must run on the same frequency as the
               system that has the highest frequency, this ensures determinism in the
               execution of the scripts

               Each system in "transform" step is executed at a predetermined frequency (in Hz).

               Ex. If the game is running on the client at 30FPS but a system needs to be run at
               120Hz or 240Hz, this logic will ensure that this frequency is reached

               @see
                  https://gafferongames.com/post/fix_your_timestep/
                  https://gameprogrammingpatterns.com/game-loop.html
                  https://bell0bytes.eu/the-game-loop/
            ]]
            local nLoops = 0
            local updated =  false
            -- Fixed time is updated in regular intervals (equal to fixedDeltaTime) until time property is reached.
            while timeProcess < timeCurrentFrame and nLoops < maxSkipFrames do

               debugF('Update')

               updated = true
               -- need to update execution plan?
               if lastKnownArchetypeInstant < LAST_ARCHETYPE_INSTANT then
                  updateExecPlan, enterExecPlan = NewExecutionPlan(world, worldSystems)
                  lastKnownArchetypeInstant = LAST_ARCHETYPE_INSTANT
               end

               updateExecPlan(step, entityManager, {
                  process        = timeProcess,
                  frame          = timeCurrentFrame,
                  delta          = timeDelta
               }, 1)
               cleanupEnvironment()

               nLoops   += 1
               timeProcess += proccessDeltaTime
            end

            if updated then
               timeProcessOld = timeProcessOldTmp
            end
         end
      end
   }

   -- realiza a limpeza após a execução dos scripts
   cleanupEnvironment = function()

      if not dirtyEnvironment then
         -- fast exit
         return
      end

      dirtyEnvironment = false

      -- 1: remove entities
      -- @TODO: Event onRemove?
      for entityID, V in pairs(entitiesRemoved) do
         entityManager:remove(entityID)
         entitiesArchetypes[entityID] = nil

         -- was removed after update
         if entitiesUpdated[entityID] ~= nil then
            entitiesUpdated[entityID] = nil
            entityManagerUpdated:remove(entityID)
         end
      end

      local haveOnEnter = false
      local onEnterEntities = {}

      -- 2: Update entities in memory
      -- @TODO: Event onChange?
      for entityID, updated in pairs(entitiesUpdated) do
         entityManager:set(entityID, entitiesArchetypes[entityID])
         entityManager:setData(entityID, entityManagerUpdated:getData(entityID))
         entityManagerUpdated:remove(entityID)

         if table.getn(updated.received) > 0 then
            onEnterEntities[entityID] = updated.received
            haveOnEnter = true
         end
      end
      entitiesUpdated = {}

      -- 3: Add new entities              
      for entityID, V in pairs(entitiesNew) do
         entityManager:set(entityID, entitiesArchetypes[entityID])        
         entityManager:setData(entityID,  entityManagerNew:getData(entityID))
         entityManagerNew:remove(entityID)
         onEnterEntities[entityID] = entitiesArchetypes[entityID].components
         haveOnEnter = true
      end
      entitiesNew = {}

      if haveOnEnter then
         enterExecPlan(onEnterEntities, entityManager)
         onEnterEntities = nil
      end
   end

   -- all managers in this world
   entityManager        = EntityManager.new(world)
   entityManagerNew     = EntityManager.new(world)
   entityManagerUpdated = EntityManager.new(world)

   -- add user systems
   if systems ~= nil then
		for i, system in pairs(systems) do
			world.addSystem(system)
		end
   end

   -- add default systems
   if not config.disableDefaultSystems then
      
      -- processIn
      world.addSystem(ECS.Util.BasePartToEntityProcessInSystem)

      -- process
      world.addSystem(ECS.Util.MoveForwardSystem)

      -- processOut
      world.addSystem(ECS.Util.EntityToBasePartProcessOutSystem)

      -- transform
      world.addSystem(ECS.Util.BasePartToEntityTransformSystem)
      world.addSystem(ECS.Util.EntityToBasePartTransformSystem)
      world.addSystem(ECS.Util.EntityToBasePartInterpolationTransformSystem)
   end

   if not config.disableAutoUpdate then

      world._steppedConn = RunService.Stepped:Connect(function()
         world.update('processIn', tick())
         world.update('process', tick())
         world.update('processOut', tick())
      end)

      world._heartbeatConn = RunService.Heartbeat:Connect(function()
         world.update('transform', tick())
      end)

      world._renderSteppedConn = RunService.RenderStepped:Connect(function()
         world.update('render', tick())
      end)
   end

	return world
end


----------------------------------------------------------------------------------------------------------------------
-- UTILITY COMPONENTS & SYSTEMS
----------------------------------------------------------------------------------------------------------------------

ECS.Util = {}

-- Creates an entity related to a BasePart
function ECS.Util.NewBasePartEntity(world, part, syncBasePartToEntity, syncEntityToBasePart, interpolate)
   local entityID = world.create()

   world.set(entityID, ECS.Util.BasePartComponent, part)
   world.set(entityID, ECS.Util.PositionComponent, part.CFrame.Position)
   world.set(entityID, ECS.Util.RotationComponent, part.CFrame.RightVector, part.CFrame.UpVector, part.CFrame.LookVector)

   if syncBasePartToEntity then 
      world.set(entityID, ECS.Util.BasePartToEntitySyncComponent)
   end

   if syncEntityToBasePart then 
      world.set(entityID, ECS.Util.EntityToBasePartSyncComponent)
   end

   if interpolate then
      world.set(entityID, ECS.Util.PositionInterpolationComponent, part.CFrame.Position)
      world.set(entityID, ECS.Util.RotationInterpolationComponent, part.CFrame.RightVector, part.CFrame.UpVector, part.CFrame.LookVector)
   end

   return entityID
end

-- Tag para sincronização
ECS.Util.BasePartToEntitySyncComponent = Component.register('BasePartToEntitySync', nil, true)
ECS.Util.EntityToBasePartSyncComponent = Component.register('EntityToBasePartSync', nil, true)

-- A component that facilitates access to BasePart
ECS.Util.BasePartComponent = Component.register('BasePart', function(object)
   if object == nil or object['IsA'] == nil or object:IsA('BasePart') == false then
      error("This component only works with BasePart objects")
   end

   return object
end)

-- Component that works with a position Vector3
ECS.Util.PositionComponent = Component.register('Position', function(position)
   if position ~= nil and typeof(position) ~= 'Vector3' then
      error("This component only works with Vector3 objects")
   end

   if position == nil then 
      position = Vector3.new(0, 0, 0)
   end

   return position
end)

ECS.Util.PositionInterpolationComponent = Component.register('PositionInterpolation', function(position)
   if position ~= nil and typeof(position) ~= 'Vector3' then
      error("This component only works with Vector3 objects")
   end

   if position == nil then 
      position = Vector3.new(0, 0, 0)
   end

   return {position, position}
end)

local VEC3_R = Vector3.new(1, 0, 0)
local VEC3_U = Vector3.new(0, 1, 0)
local VEC3_F = Vector3.new(0, 0, 1)

--[[
   Rotational vectors that represents the object in the 3d world. 
   To transform into a CFrame use CFrame.fromMatrix(pos, rot[1], rot[2], rot[3] * -1)

   Params
      lookVector  {Vector3}   @See CFrame.LookVector
      rightVector {Vector3}   @See CFrame.RightVector
      upVector    {Vector3}   @See CFrame.UpVector

   @See 
      https://devforum.roblox.com/t/understanding-cframe-frommatrix-the-replacement-for-cframe-new/593742
      https://devforum.roblox.com/t/handling-the-edge-cases-of-cframe-frommatrix/632465
]]
ECS.Util.RotationComponent = Component.register('Rotation', function(rightVector, upVector, lookVector)

   if rightVector ~= nil and typeof(rightVector) ~= 'Vector3' then
      error("This component only works with Vector3 objects [param=rightVector]")
   end

   if upVector ~= nil and typeof(upVector) ~= 'Vector3' then
      error("This component only works with Vector3 objects [param=upVector]")
   end

   if lookVector ~= nil and typeof(lookVector) ~= 'Vector3' then
      error("This component only works with Vector3 objects [param=lookVector]")
   end

   if rightVector == nil then
      rightVector = VEC3_R
   end

   if upVector == nil then
      upVector = VEC3_U
   end

   if lookVector == nil then
      lookVector = VEC3_F
   end

   return {rightVector, upVector, lookVector}
end)

ECS.Util.RotationInterpolationComponent = Component.register('RotationInterpolation', function(rightVector, upVector, lookVector)

   if rightVector ~= nil and typeof(rightVector) ~= 'Vector3' then
      error("This component only works with Vector3 objects [param=rightVector]")
   end

   if upVector ~= nil and typeof(upVector) ~= 'Vector3' then
      error("This component only works with Vector3 objects [param=upVector]")
   end

   if lookVector ~= nil and typeof(lookVector) ~= 'Vector3' then
      error("This component only works with Vector3 objects [param=lookVector]")
   end

   if rightVector == nil then
      rightVector = VEC3_R
   end

   if upVector == nil then
      upVector = VEC3_U
   end

   if lookVector == nil then
      lookVector = VEC3_F
   end

   return {{rightVector, upVector, lookVector}, {rightVector, upVector, lookVector}}
end)

-- Moviment 
ECS.Util.MoveForwardComponent = Component.register('MoveForward')

-- This component requests that if another component is moving the PositionComponent
-- it should respect this value and move the position at the constant speed specified.
ECS.Util.MoveSpeedComponent = Component.register('MoveSpeed', function(speed)
   if speed == nil or typeof(speed) ~= 'number' then 
      error("This component only works with number value")
   end

   return speed
end)

------------------------------------------
--[[
   Utility system that copies the direction and position of a Roblox BasePart to the ECS entity

   Executed in two moments: At the beginning of the "process" step and at the beginning of the "transform" step
]] 
---------------------------------------->>
local function BasePartToEntityUpdate(time, world, dirty, entity, index, parts, positions, rotations)

   local changed = false
   local part = parts[index]

   if part ~= nil then

      local position = positions[index]
      local basePos = part.CFrame.Position
      if position == nil or not vectorEQ(basePos, position) then
         positions[index] = basePos
         changed = true
      end

      local rotation    = rotations[index]
      local rightVector =  part.CFrame.RightVector
      local upVector    =  part.CFrame.UpVector
      local lookVector  =  part.CFrame.LookVector
      if rotation == nil or not vectorEQ(rightVector, rotation[1]) or not vectorEQ(upVector, rotation[2]) or not vectorEQ(lookVector, rotation[3]) then
         rotations[index] = {rightVector, upVector, lookVector}
         changed = true
      end
   end

   return changed
end

-- copia dados de basepart para entidade no inicio do processamento, ignora entidades marcadas com Interpolation
ECS.Util.BasePartToEntityProcessInSystem = System.register({
   name  = 'BasePartToEntityProcessIn',
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
   },
   update = BasePartToEntityUpdate
})

-- copia dados de um BasePart para entidade no inicio do passo transform
ECS.Util.BasePartToEntityTransformSystem = System.register({
   name  = 'BasePartToEntityTransform',
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
   },
   update = BasePartToEntityUpdate
})
----------------------------------------<<

------------------------------------------
--[[
   Utility system that copies the direction and position from ECS entity to a Roblox BasePart

   Executed in two moments: At the end of the "process" step and at the end of the "transform" step
]] 
---------------------------------------->>

local function EntityToBasePartUpdate(time, world, dirty, entity, index, parts, positions, rotations)

   if not dirty then
      return false
   end

   local changed  = false
   local part     = parts[index]
   local position = positions[index]
   local rotation = rotations[index]
   if part ~= nil then
      local basePos     = part.CFrame.Position
      local rightVector = part.CFrame.RightVector
      local upVector    = part.CFrame.UpVector
      local lookVector  = part.CFrame.LookVector

      -- goal cframe, allow interpolation
      local cframe = part.CFrame

      if position ~= nil and not vectorEQ(basePos, position) then
         cframe = CFrame.fromMatrix(position, rightVector, upVector, lookVector * -1)
         changed = true
      end

      if rotation ~= nil then
         if not vectorEQ(rightVector, rotation[1]) or not vectorEQ(upVector, rotation[2]) or not vectorEQ(lookVector, rotation[3]) then
            cframe = CFrame.fromMatrix(cframe.Position, rotation[1], rotation[2], rotation[3] * -1)
            changed = true
         end
      end

      if changed then
         part.CFrame = cframe
      end
   end

   return changed
end

-- copia dados da entidade para um BaseParte no fim do processamento
ECS.Util.EntityToBasePartProcessOutSystem = System.register({
   name  = 'EntityToBasePartProcess',
   step  = 'processOut',
   order = 100,
   requireAll = {
      ECS.Util.BasePartComponent,
      ECS.Util.PositionComponent,
      ECS.Util.RotationComponent,
      ECS.Util.EntityToBasePartSyncComponent
   },
   update = EntityToBasePartUpdate
})

-- copia dados de uma entidade para um BsePart no passo de transformação, ignora entidades com interpolação
ECS.Util.EntityToBasePartTransformSystem = System.register({
   name  = 'EntityToBasePartTransform',
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
   },
   update = EntityToBasePartUpdate
})

-- Interpolates BasePart to the latest Fixed Update transform
local interpolationFactor = 1
ECS.Util.EntityToBasePartInterpolationTransformSystem = System.register({
   name  = 'EntityToBasePartInterpolationTransform',
   step  = 'transform',
   order = 100,
   requireAll = {
      ECS.Util.BasePartComponent,
      ECS.Util.PositionComponent,
      ECS.Util.RotationComponent,
      ECS.Util.PositionInterpolationComponent,
      ECS.Util.RotationInterpolationComponent,
      ECS.Util.EntityToBasePartSyncComponent
   },
   beforeUpdate = function(time, interpolation, world, system)
      interpolationFactor = interpolation
   end,
   update = function(time, world, dirty, entity, index, parts, positions, rotations, positionsInt, rotationsInt)

      local part     = parts[index]
      local position = positions[index]
      local rotation = rotations[index]

      if part ~= nil then
          -- goal cframe, allow interpolation
          local cframe = part.CFrame

         -- swap old and new position, if changed
         if position ~= nil then
            local rightVector = part.CFrame.RightVector
            local upVector    = part.CFrame.UpVector
            local lookVector  = part.CFrame.LookVector

            if not vectorEQ(positionsInt[index][1], position) then
               positionsInt[index][2] = positionsInt[index][1]
               positionsInt[index][1] = position
            end

            local oldPosition = positionsInt[index][2]
            cframe = CFrame.fromMatrix(oldPosition:Lerp(position, interpolationFactor), rightVector, upVector, lookVector * -1)
         end

         -- swap old and new rotation, if changed
         if rotation ~= nil then
            if not vectorEQ(rotationsInt[index][1][1], rotation[1])
               or not vectorEQ(rotationsInt[index][1][2], rotation[2])
               or not vectorEQ(rotationsInt[index][1][3], rotation[3])
            then
               rotationsInt[index][2] = rotationsInt[index][1]
               rotationsInt[index][1] = rotation
            end

            local oldRotation = rotationsInt[index][2]
            cframe = CFrame.fromMatrix(
               cframe.Position,
               oldRotation[1]:Lerp(rotation[1], interpolationFactor),
               oldRotation[2]:Lerp(rotation[2], interpolationFactor),
               (oldRotation[3] * -1):Lerp((rotation[3] * -1), interpolationFactor)
            )
         end

         part.CFrame = cframe
      end

      -- readonly
      return false
   end
})
----------------------------------------<<

-- Generic system that acts on entities that have basepart,
-- position and rotation (updates Position and rotation)
local moveForwardSpeedFactor = 1
ECS.Util.MoveForwardSystem = System.register({
   name = 'MoveForward',
   step = 'process',
   requireAll = {
      ECS.Util.MoveSpeedComponent,
      ECS.Util.PositionComponent,
      ECS.Util.RotationComponent,
      ECS.Util.MoveForwardComponent,
   },
   beforeUpdate = function(time, interpolation, world, system)
      moveForwardSpeedFactor = world.frequence/60
   end,
   update = function (time, world, dirty, entity, index, speeds, positions, rotations, forwards)

      local position = positions[index]
      if position ~= nil then

         local rotation = rotations[index]
         if rotation ~= nil then

            local speed = speeds[index]
            if speed ~= nil then
               -- speed/2 = 1 studs per second (120 = frequence)
               positions[index] = position + speed/moveForwardSpeedFactor  * rotation[3]
               return true
            end
         end
      end

      return false
   end
})

-- export ECS lib
return ECS
