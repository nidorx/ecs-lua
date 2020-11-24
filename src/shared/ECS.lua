--[[
   Roblox-ECS v1.1

   Roblox-ECS is a tiny and easy to use ECS (Entity Component System) engine for
   game development on the Roblox platform

   https://github.com/nidorx/roblox-ecs

   Discussions about this script are at https://devforum.roblox.com/t/841175

   ------------------------------------------------------------------------------

   MIT License

   Copyright (c) 2020 Alex Rodin

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in all
   copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE.
]]

-- Services
local RunService = game:GetService('RunService')

--[[
  @TODO
      - Serialize componentes
      - Server entities
      - Client - Server sincronization (snapshot, delta, spatial index, grid manhatham distance)
      - Table pool (avoid GC)
      - System readonly? Paralel execution
      - Debugging?
      - Benchmark (Local Script vs ECS implementation)
      - Basic physics (managed)
      - SharedComponent?
]]

-- precision
local EPSILON = 0.000000001

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
local function Filter(config)

   -- local cache (L1)
   local cache = {}

   if config == nil then
      config = {}
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

   local requireAllKey, requireAll  = hashNumberTable(config.requireAll)
   local requireAnyKey, requireAny  = hashNumberTable(config.requireAny)
   local rejectAllKey, rejectAll    = hashNumberTable(config.rejectAll)
   local rejectAnyKey, rejectAny    = hashNumberTable(config.rejectAny)

   -- Maintains the original component list, used to correctly display the attributes
   local components = config.requireAllOriginal
   if components == nil then
      components = config.requireAnyOriginal
   end

   -- match function
   return {
      components  = components,
      match = function(components)

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

            -- check if these combinations exist in this component array
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
   }
end

----------------------------------------------------------------------------------------------------------------------
-- Red Black Trees, Used by the process scheduler
----------------------------------------------------------------------------------------------------------------------

--[[
   Red Black Trees

   (C) 2020  Alex Rodin <contato@alexrodin.info>

   Based on https://github.com/sjnam/lua-rbtree/blob/master/rbtree.lua

   Links
      https://en.wikipedia.org/wiki/Red%E2%80%93black_tree
      https://adtinfo.org/libavl.html/Red_002dBlack-Trees.html
--]]

-- colors
local BLACK = 0
local RED   = 1

-- https://en.wikipedia.org/wiki/Sentinel_node
local RB_SENTINEL = { key = 0, color = BLACK }

local function __rb_rotate_left(tree, node)
   local right = node.right
   node.right = right.left

   if right.left ~= RB_SENTINEL then
       right.left.parent = node
   end

   right.parent = node.parent

   if node.parent == RB_SENTINEL then
       tree.root = right
   elseif node == node.parent.left then
       node.parent.left = right
   else
       node.parent.right = right
   end

   right.left = node
   node.parent = right
end

local function __rb_rotate_right(tree, node)
   local left = node.left
   node.left = left.right

   if left.right ~= RB_SENTINEL then
       left.right.parent = node
   end

   left.parent = node.parent

   if node.parent == RB_SENTINEL then
       tree.root = left
   elseif node == node.parent.right then
       node.parent.right = left
   else
       node.parent.left = left
   end

   left.right = node
   node.parent = left
end

--[[
   Usado na remoção de nós, faz a substituição de um nó pele seu filho
]]
local function __rb_replace(tree, node, child)
   if node.parent == RB_SENTINEL then
      tree.root = child
   elseif node == node.parent.left then
      node.parent.left = child
   else
      node.parent.right = child
   end
   child.parent = node.parent
end

--[[
   Obtém o nó mais a esquerda (o menor valor) a partir de um nó da árvore

   Se buscar a partir do root, obtém o menor valor de toda a arvore
]]
local function rb_minimum(node)
   while node.left ~= RB_SENTINEL do
      node = node.left
   end
   return node
end

--[[
   A partir de um nó da árvore, obtém o nó seguinte
]]
local function rb_next(node)
   if node == RB_SENTINEL then
      return nil
   end

   if node.parent == node then
      return nil
   end

   -- If we have a right-hand child, go down and then left as far as we can
   if node.right ~= RB_SENTINEL then
		return rb_minimum(node.right)
   end

   local parent

   -- No right-hand children. Everything down and left is smaller than us, so any 'next'
   -- node must be in the general direction of our parent. Go up the tree; any time the
   -- ancestor is a right-hand child of its parent, keep going up. First time it's a
   -- left-hand child of its parent, said parent is our 'next' node.
   while true do
      parent = node.parent
      if parent == RB_SENTINEL then
         return nil
      end
      if node == parent.right then
         node = parent
      else
         break
      end
   end

   return parent
end

--[[
   Insere um nó em uma árvore
]]
local function rb_insert(tree, node)
   local parent = RB_SENTINEL
   local root  = tree.root

   while root ~= RB_SENTINEL do
      parent = root
      if node.key < root.key then
         root = root.left
      else
         root = root.right
      end
   end

   node.parent = parent

   if parent == RB_SENTINEL then
      tree.root = node
   elseif node.key < parent.key then
      parent.left = node
   else
      parent.right = node
   end

   node.left   = RB_SENTINEL
   node.right  = RB_SENTINEL
   node.color  = RED

   -- insert-fixup
   while node.parent.color == RED do
      if node.parent == node.parent.parent.left then
         parent = node.parent.parent.right
         if parent.color == RED then
            node.parent.color = BLACK
            parent.color = BLACK
            node.parent.parent.color = RED
            node = node.parent.parent
         else
            if node == node.parent.right then
               node = node.parent
               __rb_rotate_left(tree, node)
            end
            node.parent.color = BLACK
            node.parent.parent.color = RED
            __rb_rotate_right(tree, node.parent.parent)
         end
      else
         parent = node.parent.parent.left
         if parent.color == RED then
            node.parent.color = BLACK
            parent.color = BLACK
            node.parent.parent.color = RED
            node = node.parent.parent
         else
            if node == node.parent.left then
               node = node.parent
               __rb_rotate_right(tree, node)
            end
            node.parent.color = BLACK
            node.parent.parent.color = RED
            __rb_rotate_left(tree, node.parent.parent)
         end
      end
   end

   tree.root.color = BLACK
end

--[[
   Remove um nó de uma árvore
]]
local function rb_delete(tree, node)
   if node == RB_SENTINEL then
      return
   end

   local x, w
   local y_original_color = node.color

   if node.left == RB_SENTINEL then
      x = node.right
      __rb_replace(tree, node, node.right)

   elseif node.right == RB_SENTINEL then
      x = node.left
      __rb_replace(tree, node, node.left)

   else
      local y = rb_minimum(node.right)
      y_original_color = y.color
      x = y.right
      if y.parent == node then
         x.parent = y
      else
         __rb_replace(tree, y, y.right)
         y.right = node.right
         y.right.parent = y
      end
      __rb_replace(tree, node, y)
      y.left = node.left
      y.left.parent = y
      y.color = node.color
   end

   if y_original_color ~= BLACK then
      return
   end

   -- delete-fixup
   while x ~= tree.root and x.color == BLACK do
      if x == x.parent.left then
         w = x.parent.right
         if w.color == RED then
            w.color = BLACK
            x.parent.color = RED
            __rb_rotate_left(tree, x.parent)
            w = x.parent.right
         end
         if w.left.color == BLACK and w.right.color == BLACK then
            w.color = RED
            x = x.parent
         else
            if w.right.color == BLACK then
               w.left.color = BLACK
               w.color = RED
               __rb_rotate_right(tree, w)
               w = x.parent.right
            end
            w.color = x.parent.color
            x.parent.color = BLACK
            w.right.color = BLACK
            __rb_rotate_left(tree, x.parent)
            x = tree.root
         end
      else
         w = x.parent.left
         if w.color == RED then
            w.color = BLACK
            x.parent.color = RED
            __rb_rotate_right(tree, x.parent)
            w = x.parent.left
         end
         if w.right.color == BLACK and w.left.color == BLACK then
            w.color = RED
            x = x.parent
         else
            if w.left.color == BLACK then
               w.right.color = BLACK
               w.color = RED
               __rb_rotate_left(tree, w)
               w = x.parent.left
            end
            w.color = x.parent.color
            x.parent.color = BLACK
            w.left.color = BLACK
            __rb_rotate_right(tree, x.parent)
            x = tree.root
         end
      end
   end

   x.color = BLACK
end

--[[
   Obtém um nó a partir da key

   Chaves menores estão a esquerda da arvore, valores maiores estão na direita
]]
local function rb_get(tree, key)
   local node = tree.root
   while node ~= RB_SENTINEL and key ~= node.key do
      if key < node.key then
         node = node.left
      else
         node = node.right
      end
   end
   return node
end

--[[
   Returns the first node (in sort order) of the tree
]]
local function rb_first(tree)
   if tree.root == RB_SENTINEL then
      return nil
   end
   return rb_minimum(tree.root)
end

--[[
   Itera em toda a árvore retornando a lista de nós que se aplicam na função teste
]]
local function rb_filter(tree, testFn)
   local nodes = {}
   local node = rb_first(tree)
   while node ~= nil do
      if testFn(node) then
         table.insert(nodes, node)
      end
      node = rb_next(node)
   end
   return nodes
end

--[[
   Permite iterar em todos os nós da árvore
]]
local function rb_each(tree, callback)
   local node = rb_first(tree)
   while node ~= nil do
      callback(node)
      node = rb_next(node)
   end
end

--[[
   Obtém todos os nós da árvore
]]
local function rb_all(tree)
   local nodes = {}
   local node = rb_first(tree)
   while node ~= nil do
      table.insert(nodes, node)
      node = rb_next(node)
   end
   return nodes
end

--[[
   Cria uma nova árvore

   Returns
      struct Tree {
         root:    Node     - Tree's root.
         count:   Number   - Number of items in tree
      };
]]
local function rb_create()
   return {
      root  = RB_SENTINEL,
      count = 0
   }
end

--[[
   Cria um novo nó para a árvore

   Returns
      struct Node {
         key      : Number
         data     : any
         parent   : Node
         left     : Node
         right    : Node
         color    : BLACK=0, RED=1
      }
]]
local function rb_node(key, data)
   return {
      key   = key,
      data  = data
   }
end

----------------------------------------------------------------------------------------------------------------------
-- ARCHETYPE
----------------------------------------------------------------------------------------------------------------------

--[[
    Archetype:
      An entity has an Archetype (defined by the components it has).
      An archetype is an identifier for each unique combination of components.
      An archetype is singleton
]]
local ARCHETYPES = {}

-- Moment when the last archetype was recorded. Used to cache the systems execution plan
local LAST_ARCHETYPE_INSTANT = os.clock()

local Archetype  = {}
Archetype.__index = Archetype

--[[
   Gets the reference to an archetype from the informed components

   Params
      components Array<number> Component IDs that define this archetype
]]
function Archetype.get(components)

   local id

   id, components = hashNumberTable(components)

   if ARCHETYPES[id] == nil then
      ARCHETYPES[id] = setmetatable({
         id          = id,
         components  = components
      }, Archetype)

      LAST_ARCHETYPE_INSTANT = os.clock()
   end

   return ARCHETYPES[id]
end

--[[
   Gets the reference to an archetype that has the current components + the informed component
]]
function Archetype:with(component)
   if table.find(self.components, component) ~= nil then
      -- component exists in that list, returns the archetype itself
      return self
   end

   local len = table.getn(self.components)
   local newCoomponents = table.create(len + 1)
   newCoomponents[0] = component
   table.move(self.components, 1, len, 2, newCoomponents)
   return Archetype.get(newCoomponents)
end

--[[
   Gets the reference to an archetype that has the current components - the informed component
]]
function Archetype:without(component)
   if table.find(self.components, component) == nil then
      -- component does not exist in this list, returns the archetype itself
      return self
   end

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


--[[
   Verifica se esse arquétipo possui o componente informado
]]
function Archetype:has(component)
   return table.find(self.components, component) ~= nil
end

-- Generic archetype, for entities that do not have components
local ARCHETYPE_EMPTY = Archetype.get({})

----------------------------------------------------------------------------------------------------------------------
-- COMPONENT
----------------------------------------------------------------------------------------------------------------------
local COMPONENTS_NAME            = {}
local COMPONENTS_CONSTRUCTOR     = {}
local COMPONENTS_API             = {}
local COMPONENTS_IS_TAG          = {}
local COMPONENTS_INDEX_BY_NAME   = {}

local function DEFAULT_CONSTRUCOTR(value)
   return value
end

local DEFAULT_API = {}

local Component  = {
   --[[
      Register a new component

      Params:
         name {String}
            Unique identifier for this component

         constructor {Function}
            Allow you to validate or parse data

         isTag {Boolean}

         api {{[key:string] -> Function(component, [PARAM_N...])}}
            allows you to add "methods" to that component. The methods are invoked as follows:
            "world.call(entity, Component, 'methodName', param1, paramN)"

         @TODO: shared  {Boolean}
            see https://docs.unity3d.com/Packages/com.unity.entities@0.7/manual/shared_component_data.html

      Returns component ID
   ]]
   register = function(name, constructor, isTag, api)

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

      if api == nil then
         api = DEFAULT_API
      end

      if COMPONENTS_INDEX_BY_NAME[name] ~= nil then
         error('Another component already registered with that name')
      end

      -- component type ID = index
      local ID = table.getn(COMPONENTS_NAME) + 1

      COMPONENTS_INDEX_BY_NAME[name] = ID

      table.insert(COMPONENTS_NAME, name)
      table.insert(COMPONENTS_API, api)
      table.insert(COMPONENTS_IS_TAG, isTag)
      table.insert(COMPONENTS_CONSTRUCTOR, constructor)

      return ID
   end
}

-- Special component used to identify the entity that owns a data
local ENTITY_ID_KEY = Component.register('_ECS_ENTITY_ID_')

----------------------------------------------------------------------------------------------------------------------
-- CHUNK
----------------------------------------------------------------------------------------------------------------------
local Chunk    = {}
Chunk.__index  = Chunk

local CHUNK_SIZE = 300

--[[
   A block of memory containing the components for entities sharing the same Archetype

   A chunk is a dumb database, it only organizes the components in memory
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
   Performs cleaning of a specific index within this chunk
]]
function  Chunk:clear(index)
   local buffers = self.buffers
   for k in pairs(buffers) do
      buffers[k][index] = nil
   end
end

--[[
   Gets the value of a component for a specific index

   Params
      index {number}
         chunk position

      component {number}
         Component Id
]]
function Chunk:getValue(index, component)
   local buffers = self.buffers
   if buffers[component] == nil then
      return nil
   end
   return buffers[component][index]
end

--[[
   Sets the value of a component to a specific index

   Params
      index {number}
         chunk position

      component {number}
         Component Id

      value {any}
         Value to be persisted in memory
]]
function Chunk:setValue(index, component, value)
   local buffers = self.buffers
   if buffers[component] == nil then
      return
   end
   buffers[component][index] = value
end

--[[
   Get all buffer data at a specific index
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
   Sets all buffer data to the specific index.

   Copies only the data of the components existing in this chunk (therefore, ignores other records)
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
   Defines the entity to which this data belongs
]]
function Chunk:setEntityId(index, entity)
   self.buffers[ENTITY_ID_KEY][index] = entity
end

----------------------------------------------------------------------------------------------------------------------
-- ENTITY MANAGER
----------------------------------------------------------------------------------------------------------------------

--[[
   Responsible for managing the entities and chunks of a world
]]
local EntityManager  = {}
EntityManager.__index = EntityManager

function  EntityManager.new(world)
   return setmetatable({
      world = world,

      -- Incremented whenever it undergoes structural changes (add or remove archetypes or chunks)
      version = 0,

      COUNT = 0,

      --[[
         What is the local index of that entity (for access to other values)

         @Type { [entityID] : { archetype: string, chunk: number, chunkIndex: number } }
      ]]
      ENTITIES = {},

      --[[
         {
            [archetypeID] : {
               -- The number of entities currently stored
               count: number
               -- What is the index of the last free chunk to use?
               lastChunk:number,
               -- Within the available chunk, what is the next available index for allocation?
               nextChunkIndex:number,
               chunks: Array<Chunk>}
            }
      ]]
      ARCHETYPES   = {}
   }, EntityManager)
end

--[[
   Reserve space for an entity in a chunk of this archetype

   It is important that changes in the main EntityManager only occur after the
   execution of the current frame (script update), as some scripts run in parallel,
   so it can point to the wrong index during execution

   The strategy to avoid these problems is that the world has 2 different EntityManagers,
      1 - Primary EntityManager
         Where are registered the entities that will be updated in the update of the scripts
      2 - Secondary EntityManager
         Where the system registers the new entities created during the execution of the
         scripts. After completing the current run, all these new entities are copied to
         the primary EntityManager
]]
function  EntityManager:set(entityID, archetype)

   local archetypeID = archetype.id
   local entity      = self.ENTITIES[entityID]

   local oldEntityData = nil

   -- entity is already registered with this entity manager?
   if entity ~= nil then
      if entity.archetype == archetypeID then
         -- entity is already registered in the informed archetype, nothing to do
         return
      end

      --Different archetype
      -- back up old data
      oldEntityData = self.ARCHETYPES[entity.archetype].chunks[entity.chunk]:get(entity.chunkIndex)

      -- removes entity from the current (and hence chunk) archetype
      self:remove(entityID)
   end

   -- Check if chunk is available (may be the first entity for the informed archetype)
   if self.ARCHETYPES[archetypeID] == nil then
      -- there is no chunk for this archetype, start the list
      self.ARCHETYPES[archetypeID] = {
         count          = 0,
         lastChunk      = 1,
         nextChunkIndex = 1,
         chunks         = { Chunk.new(self.world, archetype) }
      }

      self.version = self.version + 1
   end

   -- add entity at the end of the correct chunk
   local db = self.ARCHETYPES[archetypeID]

   -- new entity record
   self.ENTITIES[entityID] = {
      archetype   = archetypeID,
      chunk       = db.lastChunk,
      chunkIndex  = db.nextChunkIndex
   }
   self.COUNT = self.COUNT + 1

   local chunk = db.chunks[db.lastChunk]

   -- Clears any memory junk
   chunk:clear(db.nextChunkIndex)

   -- update entity indexes
   if oldEntityData ~= nil then
      -- if it's archetype change, restore backup of old data
      chunk:set(db.nextChunkIndex, oldEntityData)
   end
   chunk:setEntityId(db.nextChunkIndex, entityID)

   db.count = db.count + 1
   chunk.count = db.nextChunkIndex

   -- update chunk index
   db.nextChunkIndex = db.nextChunkIndex + 1

   -- marks the new version of chunk (moment that changed)
   chunk.version = self.world.version

   -- if the chunk is full, it already creates a new chunk to welcome new future entities
   if db.nextChunkIndex > CHUNK_SIZE  then
      db.lastChunk            = db.lastChunk + 1
      db.nextChunkIndex       = 1
      db.chunks[db.lastChunk] = Chunk.new(self.world, archetype)
      
      self.version = self.version + 1
   end
end

--[[
   Removes an entity from this entity manager

   Clean indexes and reorganize data in Chunk

   It is important that changes in the main EntityManager only
   occur after the execution of the current frame (script update),
   as some scripts run in parallel, so it can point to the wrong
   index during execution.

   The strategy to avoid such problems is for the system to register
   in a separate table the IDs of the entities removed during the
   execution of the scripts. Upon completion of the current run,
   requests to actually remove these entities from the main EntityManager
]]
function  EntityManager:remove(entityID)
   local entity = self.ENTITIES[entityID]

   if entity == nil then
      return
   end

   local db = self.ARCHETYPES[entity.archetype]
   local chunk = db.chunks[entity.chunk]

   -- clear data in chunk
   chunk:clear(entity.chunkIndex)
   chunk.count = chunk.count - 1

   -- clears entity references
   self.ENTITIES[entityID] = nil
   self.COUNT = self.COUNT - 1
   db.count = db.count - 1

   -- Adjust chunks, avoid holes
   if db.nextChunkIndex == 1 then
      -- the last chunk is empty and an item from a previous chunk has been removed
      -- system should remove this chunk (as there is a hole in the previous chunks that must be filled before)
      db.chunks[db.lastChunk] = nil
      db.lastChunk      = db.lastChunk - 1
      db.nextChunkIndex = CHUNK_SIZE + 1 -- (+1, next steps get -1)

      self.version = self.version + 1
   end

   if db.count > 0 then
      if db.nextChunkIndex > 1 then
         -- ignore when entity is the laste item
         if not (db.lastChunk == entity.chunk and (db.nextChunkIndex - 1) == entity.chunkIndex) then
            -- Moves the last item of the last chunk to the position that was left open, for
            -- this, it is necessary to find out which entity belongs, in order to keep
            -- the references consistent
            local lastEntityData = db.chunks[db.lastChunk]:get(db.nextChunkIndex-1)
            db.chunks[entity.chunk]:set(entity.chunkIndex, lastEntityData)

            -- update entity indexes
            local otherEntityID     = lastEntityData[ENTITY_ID_KEY]
            local otherEntity       = self.ENTITIES[otherEntityID]
            otherEntity.chunk       = entity.chunk
            otherEntity.chunkIndex  = entity.chunkIndex
         end

         -- backs down the note and clears the unused record
         db.nextChunkIndex = db.nextChunkIndex - 1
         db.chunks[db.lastChunk]:clear(db.nextChunkIndex)
      end
   else
      db.nextChunkIndex = db.nextChunkIndex - 1
   end
end

--[[
   How many entities does this EntityManager have
]]
function EntityManager:count()
   return self.COUNT
end

--[[
   Performs the cleaning of an entity's data WITHOUT REMOVING IT.

   Used when running scripts when a script requests the removal of an
   entity. As the system postpones the actual removal until the end
   of the execution of the scripts, at this moment it only performs
   the cleaning of the data (Allowing the subsequent scripts to
   perform the verification)
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
   Gets the current value of an entity component

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
   Saves the value of an entity component

   Params
      entity {number}
         Entity Id to be changed

      component {number}
         Component ID

      value {any}
         New value
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
   Gets all values of the components of an entity

   Params
      entity {number}
         Entity ID
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
   Saves the value of an entity component

   Params
      entity {number}
         Entity Id to be changed

      component {number}
         Component ID

      data {table}
         Table with the new values that will be persisted in memory in this chunk
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
   Gets an entity's chunk and index
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

         update: function(time, world, dirty, entity, index, [component_N_items...]) -> boolean
            Invoked in updates, limited to the value set in the "frequency" attribute

         beforeUpdate(time: number): void
            Invoked before updating entities available for this system.
            It is only invoked when there are entities with the characteristics
            expected by this system

         onEnter(entity: Entity): void;
            Invoked when:
               a) An entity with the characteristics (components) expected by this system is
                  added in the world;
               b) This system is added in the world and this world has one or more entities with
                  the characteristics expected by this system;
               c) An existing entity in the same world receives a new component at runtime
                  and all of its new components match the standard expected by this system.

         onRemove(time, world, enity, index, [component_N_items...])


         @TODO afterUpdate(time: number, entities: Entity[]): void
            Invoked after performing update of entities available for this system.
            It is only invoked when there are entities with the characteristics
            expected by this system

         @TODO change(entity: Entity, added?: Component<any>, removed?: Component<any>): void
             Invoked when an expected feature of this system is added or removed from the entity

         @onExit(entity: Entity): void;
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

   local filter = Filter(config)

   if config.step == nil then
      config.step = 'transform'
   end

   if config.step ~= 'task' and config.step ~= 'render' and config.step ~= 'process' and config.step ~= 'processIn' and config.step ~= 'processOut' and config.step ~= 'transform' then
      error('The "step" parameter must be "task", "render", "process", "transform", "processIn" or "processOut"')
   end

   if config.step == 'task' then
      if config.order ~= nil then
         error('Task-type systems do not accept the "order" parameter')
      end

      if config.update ~= nil then
         error('Task-type systems do not accept the "update" parameter')
      end

      if config.beforeUpdate ~= nil then
         error('Task-type systems do not accept the "beforeUpdate" parameter')
      end

      if config.afterUpdate ~= nil then
         error('Task-type systems do not accept the "afterUpdate" parameter')
      end

      if config.onEnter ~= nil then
         error('Task-type systems do not accept the "onEnter" parameter')
      end

      if config.execute == nil then
         error('The task "execute" method is required for registration')
      end
   end

   if config.order == nil or config.order < 0 then
      config.order = 50
   end

   -- imutable
   table.insert(SYSTEM, {
      name                 = config.name,
      filter               = filter,
      requireAll           = config.requireAll,
      requireAny           = config.requireAny,
      requireAllOriginal   = config.requireAllOriginal,
      requireAnyOriginal   = config.requireAnyOriginal,
      rejectAll            = config.rejectAll,
      rejectAny            = config.rejectAny,
      beforeUpdate         = config.beforeUpdate,
      afterUpdate          = config.afterUpdate,
      update               = config.update,
      onCreate             = config.onCreate,
      onEnter              = config.onEnter,
      onRemove             = config.onRemove,
      beforeExecute        = config.beforeExecute,
      execute              = config.execute,
      step                 = config.step,
      order                = config.order
   })

   local ID = table.getn(SYSTEM)

   SYSTEM_INDEX_BY_NAME[config.name] = ID

   return ID
end

----------------------------------------------------------------------------------------------------------------------
-- Process Scheduler
-- based on Linux CFS (Completely Fair Scheduler) 
-- https://en.m.wikipedia.org/wiki/Completely_Fair_Scheduler
-- https://www.kernel.org/doc/Documentation/scheduler/sched-design-CFS.txt
----------------------------------------------------------------------------------------------------------------------
-- p->se.vruntime = p->se.vruntime + (start - end)
--  always tries to run the task with the smallest p->se.vruntime value (i.e., the task which executed least so far)
-- os.clock()
--[[
   Uma tarefa é executado no máximo uma vez por frame para cada chunk

   CFS also maintains the rq->cfs.min_vruntime value, which is a monotonic
   increasing value tracking the smallest vruntime among all tasks in the
   runqueue.  The total amount of work done by the system is tracked using
   min_vruntime; that value is used to place newly activated entities on the left
   side of the tree as much as possible.
]]

--[[

]]
local Scheduler  = {}
Scheduler.__index = Scheduler

-- In each frame, if there are tasks, the Scheduler runs for at 
-- least that period of time (or even executes all tasks)
local SCHED_MIN_EXEC_TIME = 0.008

-- Time set aside for the render step
local SCHED_RESERVED_TIME_RENDER = 0.002

--[[
   Instancia um nov scheduler.
]]
function Scheduler.new(world, entityManager)
   return setmetatable({
      world          = world,
      entityManager  = entityManager,

       -- tracking the smallest vruntime among all tasks in the runqueue
       min_vruntime = 0,

       -- a time-ordered rbtree to build a "timeline" of future task execution
       rbtree = rb_create(),

      -- sempre que o entity manger sofre alteração estrutural (adiciona ou remove chunks)
      -- este Scheduler precisará atualizar a arvore de tarefas
      lastEntityManagerVersion = -1,

      -- Sistemas do tipo Task, no formato {[key=system.id] => system}
      systems = {}
   }, Scheduler)
end

--[[
   Adiciona um sistema neste scheduler
]]
function Scheduler:addSystem(systemID, config)
   if self.systems[systemID] ~= nil then
      -- This system has already been registered
      return
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
      filter               = SYSTEM[systemID].filter,
      beforeExecute        = SYSTEM[systemID].beforeExecute,
      execute              = SYSTEM[systemID].execute,
      -- instance properties
      config               = config
   }

   self.systems[systemID] = system

   -- forces re-creation of tasks list
   self.lastEntityManagerVersion = 0
end

--[[
   Realiza o gerencimanto para execução das tarefas agendadas 

   o Scheduler tenta garantir que todo o sistema rode a no mínimo 60FPS.

   Partindo desse principio, em cada frame nós temos apenas 16.67ms para executar toda
   a lógica do jogo (incluindo execução de scripts Lua e funcionalidades internas do Roblox)

   O scheduler faz o seguinte cálculo para determinar o tempo disponível para a execução das tarefas neste frame:

   SPENT          = FRAME_START - NOW
   AVAILABLE      = (16.67 - SPENT) - SCHED_RESERVED_TIME_RENDER
   MAX_RUN_TIME   = math.max(SCHED_MIN_EXEC_TIME, AVAILABLE)


   Na implementação atual, o Scheduler deve ser executado após o passo 'transform'
      (RunService.Heartbeat, até ser disponiilizado multi-thread)
   
]]
function Scheduler:run(time)
   if self.entityManager.version ~= self.lastEntityManagerVersion then
      self:update()
      self.lastEntityManagerVersion = self.entityManager.version
   end

   local tree           = self.rbtree
   local world          = self.world

   -- 0.01667 = 1000/60/1000
   local maxExecTime  = math.max(SCHED_MIN_EXEC_TIME, (0.01667 - (os.clock() - time.frameReal)) - SCHED_RESERVED_TIME_RENDER)

   -- tarefas que foram executadas nessa chamada
   local tasks = {}

   local timeInitSched = os.clock()
   local timeInitTask, chunk, system, taskVersion, lastExec

   -- the leftmost node of the scheduling (as it will have the lowest spent execution time)
   local task = rb_first(tree)
   while task ~= nil do
      -- remove from tree
      rb_delete(tree, task)

      -- sent for execution
      chunk          = task.data[1]
      system         = task.data[2]
      taskVersion    = task.data[3]
      lastExec       = task.data[4]
      timeInitTask   = os.clock()

      if lastExec == 0 then
         lastExec = timeInitTask
      end

      -- what components the system expects
      local whatComponents = system.requireAllOriginal
      if whatComponents == nil then
         whatComponents = system.requireAnyOriginal
      end

      local whatComponentsLen = table.getn(whatComponents)

      -- execute: function(time, world, dirty, entity, index, [component_N_items...]) -> boolean
      local executeFn = system.execute

      -- increment Global System Version (GSV), before system execute
      world.version = world.version + 1

      if system.beforeExecute ~= nil then
         system.beforeExecute(time, world, system)
      end

      -- if the version of the chunk is larger than the task, it means
      -- that this chunk has already undergone a change that was not performed
      -- after the last execution of this task
      local dirty = chunk.version == 0 or chunk.version > taskVersion
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

      local taskTime = {
         process        = time.process,
         frame          = time.frame,
         frameReal      = time.frameReal,
         delta          = time.delta,
         deltaExec      = timeInitTask - lastExec
      }

      for index = 1, chunk.count do
         if executeFn(taskTime, world, dirty, entityIDBuffer[index], index, table.unpack(componentsData)) then
            hasChangeThisChunk = true
         end
      end

      if hasChangeThisChunk then
         -- If any system execution informs you that it has changed data in
         -- this chunk, it then performs the versioning of the chunk
         chunk.version = world.version
      end

      -- update last task version with GSV
      task.data[3] = world.version
      task.data[4] = timeInitTask

      -- recalculate task vruntime
      task.key = task.key + (os.clock() - timeInitTask)
      rb_insert(tree, task)

      -- maximum execution time
      if os.clock() - timeInitSched > maxExecTime then
         break
      end

      -- the new leftmost node will then be selected from the tree, repeating the iteration.
      task = rb_next(task)      
   end

   -- recalculate min_vruntime
   local leftmost = rb_first(tree)
   if leftmost ~= nil then
      self.min_vruntime = math.max(leftmost.key - EPSILON, 0)
   else
      self.min_vruntime = 0
   end
end

--[[
   Atualiza a arvore e tarefas

   Este método
   
   Se um chunk foi removido, remove as tarefas associadas para este chunk
   Se um chunk foi adicionado, cria uma tarefa para cada sistema que deva trabalhar neste chunk

   TaskDate = { chunk, system, version, lastExecTime }
]]
function Scheduler:update()
   local tree           = self.rbtree
   local systems        = self.systems
   local entityManager  = self.entityManager
   local min_vruntime   = self.min_vruntime
   local worldVersion   = self.world.version

   local taskByChunkSystem  = {}

   local chunksRemoved  = {}

   local chunk, system
   rb_each(tree, function(task)
      chunk = task.data[1]
      system = task.data[2]

      if taskByChunkSystem[chunk] == nil then
         taskByChunkSystem[chunk] = {}
      end

      if taskByChunkSystem[chunk][system] == nil then
         taskByChunkSystem[chunk][system] = {}
      end

      table.insert(taskByChunkSystem[chunk][system], task)

      -- considera inicialmente que todos os chunks foram removidos
      chunksRemoved[chunk] = true
   end)

   for i, system_a in pairs(systems) do

      -- Gets all the chunks that apply to this system
      local chunks = entityManager:filterChunks(system_a.filter.match)

      for j, chunk_a in pairs(chunks) do

         -- chunk não foi removido
         chunksRemoved[chunk_a] = nil

         if taskByChunkSystem[chunk_a] == nil then
            -- chunk foi adicionado agora, adiciona tarefa para o sitema atuar neste chunk
            rb_insert(tree, rb_node(min_vruntime, {chunk_a, system_a, worldVersion, 0}))

         elseif taskByChunkSystem[chunk_a][system_a] == nil then
             -- sistema foi adicionado agora [ainda não é possível], adiciona tarefa para o sitema atuar neste chunk
             rb_insert(tree, rb_node(min_vruntime, {chunk_a, system_a, worldVersion, 0}))
         end
      end
   end

   -- remove todas a tarefas dos chunks removidos
   for chunk_b, _ in pairs(chunksRemoved) do
      for system_b, tasks in pairs(taskByChunkSystem[chunk_b]) do
         for _, task in ipairs(tasks) do
            rb_delete(tree, task)
         end
      end
   end
end

----------------------------------------------------------------------------------------------------------------------
-- Execution Plan
----------------------------------------------------------------------------------------------------------------------

--[[
   Generates an execution plan for the systems.
   An execution plan is a function that, when called, will perform the orderly processing of these systems.
]]
local function NewExecutionPlan(world, systems)

   local updateSteps = {
      processIn      = {},
      process        = {},
      processOut     = {},
      transform      = {},
      render         = {}
   }

   local updateStepsOrder = {
      processIn      = {},
      process        = {},
      processOut     = {},
      transform      = {},
      render         = {}
   }

   -- systems that process the onEnter event
   local onEnterSystems = {}

   -- systems that process the onRemove event
   local onRemoveSystems = {}

   for k, system in pairs(systems) do
      if system.update ~= nil then
         if updateSteps[system.step][system.order] == nil then
            updateSteps[system.step][system.order] = {}
            table.insert(updateStepsOrder[system.step], system.order)
         end

         table.insert(updateSteps[system.step][system.order], system)
      end

      if system.onEnter ~= nil then
         table.insert(onEnterSystems, system)
      end

      if system.onRemove ~= nil then
         table.insert(onRemoveSystems, system)
      end
   end

   for _, order in ipairs(updateStepsOrder) do
      table.sort(order)
   end

   -- Update systems
   local onUpdate = function(step, entityManager, time, interpolation)
      local stepSystems = updateSteps[step]
      for i, order  in pairs(updateStepsOrder[step]) do
         for j, system  in pairs(stepSystems[order]) do
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
            local chunks = entityManager:filterChunks(system.filter.match)

            -- update: function(time, world, dirty, entity, index, [component_N_items...]) -> boolean
            local updateFn = system.update

            -- increment Global System Version (GSV), before system update
            world.version = world.version + 1

            if system.beforeUpdate ~= nil then
               system.beforeUpdate(time, interpolation, world, system)
            end

            for k, chunk in pairs(chunks) do
               -- if the version of the chunk is larger than the system, it means
               -- that this chunk has already undergone a change that was not performed
               -- after the last execution of this system
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

            if system.afterUpdate ~= nil then
               system.afterUpdate(time, interpolation, world, system)
            end

            -- update last system version with GSV
            system.version = world.version
         end
      end
   end

   local onEnter = function(onEnterEntities, entityManager, time)
      -- increment Global System Version (GSV), before system update
      world.version = world.version + 1

      for entityID, newComponents in pairs(onEnterEntities) do

         -- temporary filter
         local filterHasAny = Filter({ requireAny = newComponents })

         -- get the chunk and index of this entity
         local chunk, index = entityManager:getEntityChunk(entityID)
         if chunk ~= nil then
            local buffers = chunk.buffers

            for j, system in pairs(onEnterSystems) do

               -- system does not apply to the archetype of that entity
               if system.filter.match(chunk.archetype.components) then

                  -- what components the system expects
                  local whatComponents = system.requireAllOriginal
                  if whatComponents == nil then
                     whatComponents = system.requireAnyOriginal
                  end

                  -- components received are not in the list of components expected by the system
                  if filterHasAny.match(whatComponents) then
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
         end
      end
   end

   local onRemove = function(removedEntities, entityManager, time)
      -- increment Global System Version (GSV), before system update
      world.version = world.version + 1

      for entityID, _  in pairs(removedEntities) do

         -- get the chunk and index of this entity
         local chunk, index = entityManager:getEntityChunk(entityID)
         if chunk ~= nil then
            local buffers = chunk.buffers

            for _, system in pairs(onRemoveSystems) do

               -- system does not apply to the archetype of that entity
               if system.filter.match(chunk.archetype.components) then

                  -- what components the system expects
                  local whatComponents = system.requireAllOriginal
                  if whatComponents == nil then
                     whatComponents = system.requireAnyOriginal
                  end

                  local componentsData = table.create(table.getn(whatComponents))

                  for l, compID in ipairs(whatComponents) do
                     if buffers[compID] ~= nil then
                        componentsData[l] = buffers[compID]
                     else
                        componentsData[l] = {}
                     end
                  end

                  -- onRemove: function(world, entity, index, [component_N_items...]) -> boolean
                  if system.onRemove(time, world, entityID, index, table.unpack(componentsData)) then
                     -- If any system execution informs you that it has changed data in
                     -- this chunk, it then performs the versioning of the chunk
                     chunk.version = world.version
                  end
               end
            end
         end
      end
   end

   return onUpdate, onEnter, onRemove
end

----------------------------------------------------------------------------------------------------------------------
-- ECS
----------------------------------------------------------------------------------------------------------------------
local ECS = {
   Component   = Component,
   System      = System,
   Filter      = Filter
}

-- World constructor
function ECS.newWorld(systems, config)

   if config == nil then
      config = {}
   end

   -- frequency: number,
   -- The maximum times per second this system should be updated. Defaults 30
   if config.frequency == nil then
      config.frequency = 30
   end

   local safeFrequency  = math.round(math.abs(config.frequency)/2)*2
   if safeFrequency < 2 then
      safeFrequency = 2
   end

   if config.frequency ~= safeFrequency then
      config.frequency = safeFrequency
      print(string.format(">>> ATTENTION! The execution frequency of world has been changed to %d <<<", safeFrequency))
   end

   local SEQ_ENTITY  = 1

   -- systems in this world
   local worldSystems = {}

   -- Job system
   local scheduler

   -- System execution plan
   local updateExecPlan, enterExecPlan, removeExecPlan

   local processDeltaTime = 1000/config.frequency/1000

   -- INTERPOLATION: The proportion of time since the previous transform relative to processDeltaTime
   local interpolation = 1

   local FIRST_UPDATE_TIME = nil

   local timeLastFrame = 0

   -- The time at the beginning of this frame. The world receives the current time at the beginning
   -- of each frame, with the value increasing per frame.
   local timeCurrentFrame  = 0

   -- The REAL time at the beginning of this frame.
   local timeCurrentFrameReal  = 0

   -- The time the latest process step has started.
   local timeProcess  = 0

   local timeProcessOld = 0

   -- The completion time in seconds since the last frame. This property provides the time between the current and previous frame.
   local timeDelta = 0

   -- if execution is slow, perform a maximum of 10 simultaneous
   -- updates in order to keep the fixrate
   local maxSkipFrames = 10

   local lastKnownArchetypeInstant = 0

   --[[
      The main EntityManager

      It is important that changes in the main EntityManager only occur after the execution
      of the current frame (script update), as some scripts run in parallel, so
      it can point to the wrong index during execution

      The strategy to avoid these problems is that the world has 2 different EntityManagers,
         1 - Primary EntityManager
            Where are registered the entities that will be updated in the update of the scripts
         2 - Secondary EntityManager
            Where the system registers the new entities created during the execution of the scripts.
            After completing the current run, all these new entities are copied to the primary EntityManager
   ]]
   local entityManager

   -- The EntityManager used to house the new entities
   local entityManagerNew

   -- The EntityManager used to house the copy of the data of the entity that changed
   -- At the end of the execution of the scripts of the current step, the entity will be updated in the main entity manger
   local entityManagerUpdated

   -- Entities that were created during the execution of the update, will be transported from "entityManagerNew" to "entityManager"
   local entitiesNew = {}

   -- Entities that were removed during execution (only removed after the last execution step)
   local entitiesRemoved = {}

   -- Entities that changed during execution (received or lost components, therefore, changed the archetype)
   local entitiesUpdated = {}

   -- reference to the most updated archetype of an entity (dirty)
   -- Changing the archetype does not reflect the current execution of the scripts, it is only used
   -- for updating the data in the main entity manager
   local entitiesArchetypes  = {}

   local world

   -- Environment cleaning method
   local cleanupEnvironmentFn

   -- True when environment has been modified while a system is running
   local dirtyEnvironment = false

   world = {

      version = 0,

      frequency = config.frequency,

      --[[
         Create a new entity
      ]]
      create = function()
         local ID = SEQ_ENTITY
         SEQ_ENTITY = SEQ_ENTITY + 1

         entityManagerNew:set(ID, ARCHETYPE_EMPTY)

         -- informs that it has a new entity
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
         elseif entitiesUpdated[entity] ~= nil then
            return entityManagerUpdated:getValue(entity, component)
         else
            return entityManager:getValue(entity, component)
         end
      end,

      --[[
         Defines the value of a component for an entity
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

         local value
         local arg = {...}
         if arg and arg[1] and typeof(arg[1]) == 'table' and arg[1].__v then
            -- invocado pelo método call
            value = arg[1].__v[0]
         else
            value = COMPONENTS_CONSTRUCTOR[component](table.unpack(arg))
         end

         if entitiesNew[entity] == true then
            if archetypeChanged then
               entityManagerNew:set(entity, archetypeNew)
            end

            entityManagerNew:setValue(entity, component, value)
         else
            if archetypeChanged then
               -- entity has undergone an archetype change. Registers a copy in another entity
               -- manager, which will be processed after the execution of the current scripts
               if entitiesUpdated[entity] == nil then
                  entitiesUpdated[entity] = {
                     received = {},
                     lost = {}
                  }
                  -- the first time you are modifying the components of this entity in
                  -- this execution, you need to copy the data of the entity
                  entityManagerUpdated:set(entity, archetypeNew)
                  entityManagerUpdated:setData(entity, entityManager:getData(entity))
               else
                  -- just perform the archetype update on the entityManager
                  entityManagerUpdated:set(entity, archetypeNew)
               end
            end

            if entitiesUpdated[entity]  ~= nil then
               -- register a copy of the value
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

            -- records the value in the current entityManager, used by the scripts
            entityManager:setValue(entity, component, value)
         end
      end,

      --[[
         Invokes a utility method from a component's api
      ]]
      call = function(entity, component, method, ...)

         local fn = COMPONENTS_API[component][method]
         if not fn then
            return nil
         end

         local changed, value = fn(world.get(entity, component), table.unpack({...}))

         if changed then
            world.set(entity, component, {__v = {value}})
         end

         return value
      end,

      --[[
         Removing a entity or Removing a component from an entity at runtime
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

                  -- entity has undergone an archetype change. Registers a copy in
                  -- another entity manager, which will be processed after the execution of the current scripts
                  if entitiesUpdated[entity] == nil then
                     entitiesUpdated[entity] = {
                        received = {},
                        lost = {}
                     }
                     -- the first time you are modifying the components of this entity
                     -- in this execution, you need to copy the data of the entity
                     entityManagerUpdated:set(entity, archetypeNew)
                     entityManagerUpdated:setData(entity, entityManager:getData(entity))
                  else
                     -- just perform the archetype update on the entityManager
                     entityManagerUpdated:set(entity, archetypeNew)
                  end
               end

               if entitiesUpdated[entity] ~= nil then
                  -- register a copy of the value
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

               -- records the value in the current entityManager, used by the scripts
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
         Allows you to perform the interaction between all active entities that is compatible with the informed filter

         Params
            filter {ECS.Filter instance}
               The filter that will be applied to obtain the entities

            callback {function(stop, entity, index, [Component_N_Data...]) => bool}
               Function that will be invoked for each filtered entity. To stop execution, use the 'stop'
                  method received in the parameters.
               This function should return true if you have made changes to the component or data of
                  the chunk being worked on
      ]]
      forEach = function(filter, callback)

         local stopped = false

         -- Allows the developer to stop execution
         local stop = function()
            stopped = true
         end

         -- Gets all the chunks that apply to this filter
         local chunks = entityManager:filterChunks(filter.match)

         for k, chunk in pairs(chunks) do
            local buffers = chunk.buffers

            local componentsData = table.create(table.getn(filter.components))
            for l, compID in ipairs(filter.components) do
               if buffers[compID] ~= nil then
                  componentsData[l] = buffers[compID]
               else
                  componentsData[l] = {}
               end
            end

            local entityIDBuffer = buffers[ENTITY_ID_KEY]
            local hasChangeThisChunk = false
            for index = 1, chunk.count do
               if callback(stop, entityIDBuffer[index], index, table.unpack(componentsData)) then
                  hasChangeThisChunk = true
               end
               if stopped then
                  break
               end
            end

            if hasChangeThisChunk then
               -- If any system execution informs you that it has changed data in
               -- this chunk, it then performs the versioning of the chunk
               chunk.version = world.version
            end

            if stopped then
               break
            end
         end
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

         if SYSTEM[systemID].step == 'task' then
            scheduler:addSystem(systemID)
         else
            if worldSystems[systemID] ~= nil then
               -- This system has already been registered in this world
               return
            end
   
            -- @TODO: why?
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
               filter               = SYSTEM[systemID].filter,
               beforeUpdate         = SYSTEM[systemID].beforeUpdate,
               afterUpdate          = SYSTEM[systemID].afterUpdate,
               update               = SYSTEM[systemID].update,
               onCreate             = SYSTEM[systemID].onCreate,
               onEnter              = SYSTEM[systemID].onEnter,
               onRemove             = SYSTEM[systemID].onRemove,
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
   
            -- forces re-creation of the execution plan
            lastKnownArchetypeInstant = 0

            if system.onCreate ~= nil then
               system.onCreate(world, system)
            end
         end
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
         if world._steppedConn ~= nil then
            world._steppedConn:Disconnect()
            world._steppedConn = nil
         end

         if world._heartbeatConn ~= nil then
            world._heartbeatConn:Disconnect()
            world._heartbeatConn = nil
         end

         if world._renderSteppedConn ~= nil then
            world._renderSteppedConn:Disconnect()
            world._renderSteppedConn = nil
         end

         -- Clears all references. An ECS world never creates external references (cache, etc.), all variables are enclosed in this block
         entityManager        = nil
         entityManagerNew     = nil
         entityManagerUpdated = nil
         entitiesUpdated      = nil
         entitiesRemoved      = nil
         worldSystems         = nil
         updateExecPlan       = nil
         enterExecPlan        = nil
         removeExecPlan       = nil
         cleanupEnvironmentFn = nil
         entitiesArchetypes   = nil
         scheduler            = nil

         -- It also removes all methods in the world, avoids external calls
         world.create      = nil
         world.set         = nil
         world.get         = nil
         world.remove      = nil
         world.has         = nil
         world.forEach     = nil
         world.addSystem   = nil
         world.alive       = nil
         world.update      = nil
         world.destroy     = nil
         world             = nil
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
         local nowReal = now
         now = now - FIRST_UPDATE_TIME

         -- need to update execution plan?
         if lastKnownArchetypeInstant < LAST_ARCHETYPE_INSTANT then
            updateExecPlan, enterExecPlan, removeExecPlan = NewExecutionPlan(world, worldSystems)
            lastKnownArchetypeInstant = LAST_ARCHETYPE_INSTANT
         end

         if step ~= 'process' then
            -- executed only once per frame

            if timeProcess ~= timeProcessOld then
               interpolation = 1 + (now - timeProcess)/processDeltaTime
            else
               interpolation = 1
            end

            if step == 'processIn' then

               -- first step, initialize current frame time
               timeCurrentFrame  = now
               timeCurrentFrameReal = nowReal
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

            local time = {
               process        = timeProcess,
               frame          = timeCurrentFrame,
               frameReal      = timeCurrentFrameReal,
               now            = now,
               nowReal        = nowReal,
               delta          = timeDelta
            }

            updateExecPlan(step, entityManager, time, interpolation)

            while dirtyEnvironment do
               cleanupEnvironmentFn(time)
            end

            if step == 'transform' then
               scheduler:run(time)
               cleanupEnvironmentFn(time)
            end
         else

            local timeProcessOldTmp = timeProcess

            --[[
               Adjusting the framerate, the world must run on the same frequency,
               this ensures determinism in the execution of the scripts

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

               -- debugF('Update')

               updated = true
               -- need to update execution plan?
               if lastKnownArchetypeInstant < LAST_ARCHETYPE_INSTANT then
                  updateExecPlan, enterExecPlan = NewExecutionPlan(world, worldSystems)
                  lastKnownArchetypeInstant = LAST_ARCHETYPE_INSTANT
               end

               local time = {
                  process        = timeProcess,
                  processDelta   = processDeltaTime,
                  frame          = timeCurrentFrame,
                  frameReal      = timeCurrentFrameReal,
                  now            = now,
                  nowReal        = nowReal,
                  delta          = timeDelta
               }

               updateExecPlan(step, entityManager, time, 1)

               while dirtyEnvironment do
                  cleanupEnvironmentFn(time)
               end

               nLoops      = nLoops + 1
               timeProcess = timeProcess + processDeltaTime
            end

            if updated then
               timeProcessOld = timeProcessOldTmp
            end
         end
      end
   }

   -- cleans up after running scripts
   cleanupEnvironmentFn = function(time)

      if not dirtyEnvironment then
         -- fast exit
         return
      end

      dirtyEnvironment = false

      local haveOnEnter = false
      local onEnterEntities = {}

      -- 1: remove entities
      -- Event onRemove
      removeExecPlan(entitiesRemoved, entityManager, time)
      for entityID, V in pairs(entitiesRemoved) do
         entityManager:remove(entityID)
         entitiesArchetypes[entityID] = nil

         -- was removed after update
         if entitiesUpdated[entityID] ~= nil then
            entitiesUpdated[entityID] = nil
            entityManagerUpdated:remove(entityID)
         end
      end
      entitiesRemoved = {}

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
         enterExecPlan(onEnterEntities, entityManager, time)
         onEnterEntities = nil
      end
   end

   -- all managers in this world
   entityManager        = EntityManager.new(world)
   entityManagerNew     = EntityManager.new(world)
   entityManagerUpdated = EntityManager.new(world)

   scheduler = Scheduler.new(world, entityManager)

   -- add user systems
   if systems ~= nil then
      for i, system in pairs(systems) do
         world.addSystem(system)
      end
   end

   if not config.disableAutoUpdate then

      world._steppedConn = RunService.Stepped:Connect(function()
         world.update('processIn',  os.clock())
         world.update('process',    os.clock())
         world.update('processOut', os.clock())
      end)

      world._heartbeatConn = RunService.Heartbeat:Connect(function()
         world.update('transform', os.clock())
      end)

      world._renderSteppedConn = RunService.RenderStepped:Connect(function()
         world.update('render', os.clock())
      end)
   end

   return world
end

-- export ECS lib
return ECS
