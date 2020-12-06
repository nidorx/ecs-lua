--[[
   Roblox-ECS v1.2 [2020-12-05 20:03]

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

   @Type { [key:Array<number>] : { matchAll,matchAny,RejectAll|RejectAny: {[key:string]:boolean} } }
]]
local FILTER_CACHE_RESULT = {}

--[[
   Generate a function responsible for performing the filter on a list of components.
   It makes use of local and global cache in order to decrease the validation time (avoids looping in runtime of systems)

   Params
      RequireAll {Array<number>}
      RequireAny {Array<number>}
      RejectAll {Array<number>}
      RejectAny {Array<number>}

   Returns function(Array<number>) => boolean
]]
local function Filter(config)

   -- local cache (L1)
   local cache = {}

   if config == nil then
      config = {}
   end

   if config.RequireAll == nil and config.RequireAny == nil then
      error('It is necessary to define the components using the "RequireAll" or "RequireAny" parameters')
   end

   if config.RequireAll ~= nil and config.RequireAny ~= nil then
      error('It is not allowed to use the "RequireAll" and "RequireAny" settings simultaneously')
   end

   if config.RequireAll ~= nil then
      config.RequireAllOriginal = config.RequireAll
      config.RequireAll = safeNumberTable(config.RequireAll)
      if table.getn(config.RequireAll) == 0 then
         error('You must enter at least one component id in the "RequireAll" field')
      end
   elseif config.RequireAny ~= nil then
      config.RequireAnyOriginal = config.RequireAny
      config.RequireAny = safeNumberTable(config.RequireAny)
      if table.getn(config.RequireAny) == 0 then
         error('You must enter at least one component id in the "RequireAny" field')
      end
   end

   if config.RejectAll ~= nil and config.RejectAny ~= nil then
      error('It is not allowed to use the "RejectAll" and "RejectAny" settings simultaneously')
   end

   if config.RejectAll ~= nil then
      config.RejectAll = safeNumberTable(config.RejectAll)
      if table.getn(config.RejectAll) == 0 then
         error('You must enter at least one component id in the "RejectAll" field')
      end
   elseif config.RejectAny ~= nil then
      config.RejectAny = safeNumberTable(config.RejectAny)
      if table.getn(config.RejectAny) == 0 then
         error('You must enter at least one component id in the "RejectAny" field')
      end
   end

   local requireAllKey, requireAll  = hashNumberTable(config.RequireAll)
   local requireAnyKey, requireAny  = hashNumberTable(config.RequireAny)
   local rejectAllKey, rejectAll    = hashNumberTable(config.RejectAll)
   local rejectAnyKey, rejectAny    = hashNumberTable(config.RejectAny)

   -- Maintains the original component list, used to correctly display the attributes
   local components = config.RequireAllOriginal
   if components == nil then
      components = config.RequireAnyOriginal
   end

   -- match function
   return {
      Components = components,
      Match = function(components)

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
               cacheResultG = { MatchAny = {}, MatchAll = {}, RejectAny = {}, RejectAll = {} }
               FILTER_CACHE_RESULT[components] = cacheResultG
            end

            -- check if these combinations exist in this component array
            if rejectAnyKey ~= '_' then
               if cacheResultG.RejectAny[rejectAnyKey] or cacheResultG.RejectAll[rejectAnyKey] then
                  cache[components] = false
                  return false
               end

               for _, v in pairs(rejectAny) do
                  if table.find(components, v) then
                     cache[components] = false
                     cacheResultG.MatchAny[rejectAnyKey] = true
                     cacheResultG.RejectAny[rejectAnyKey] = true
                     return false
                  end
               end
            end

            if rejectAllKey ~= '_' then
               if cacheResultG.RejectAll[rejectAllKey] then
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
                  cacheResultG.MatchAll[rejectAllKey] = true
                  cacheResultG.RejectAll[rejectAllKey] = true
                  return false
               end
            end

            if requireAnyKey ~= '_' then
               if cacheResultG.MatchAny[requireAnyKey] or cacheResultG.MatchAll[requireAnyKey] then
                  cache[components] = true
                  return true
               end

               for _, v in pairs(requireAny) do
                  if table.find(components, v) then
                     cacheResultG.MatchAny[requireAnyKey] = true
                     cache[components] = true
                     return true
                  end
               end
            end

            if requireAllKey ~= '_' then
               if cacheResultG.MatchAll[requireAllKey] then
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
                  cacheResultG.MatchAll[requireAllKey] = true
                  cacheResultG.RejectAll[requireAllKey] = true
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
local Archetypes = {}

-- Moment when the last archetype was recorded. Used to cache the systems execution plan
local LAST_ARCHETYPE_INSTANT = os.clock()

local Archetype  = {}
Archetype.__index = Archetype

--[[
   Gets the reference to an archetype from the informed components

   Params
      components Array<number> Component IDs that define this archetype
]]
function Archetype.Get(components)

   local id

   id, components = hashNumberTable(components)

   if Archetypes[id] == nil then
      Archetypes[id] = setmetatable({
         Id          = id,
         Components  = components
      }, Archetype)

      LAST_ARCHETYPE_INSTANT = os.clock()
   end

   return Archetypes[id]
end

--[[
   Gets the reference to an archetype that has the current components + the informed component
]]
function Archetype:With(component)
   local selfComps = self.Components
   if table.find(selfComps, component) ~= nil then
      -- component exists in that list, returns the archetype itself
      return self
   end

   local len = table.getn(selfComps)
   local newCoomponents = table.create(len + 1)
   newCoomponents[0] = component
   table.move(selfComps, 1, len, 2, newCoomponents)
   return Archetype.Get(newCoomponents)
end

--[[
   Gets the reference to an archetype that has the current components - the informed component
]]
function Archetype:Without(component)
   local selfComps = self.Components
   if table.find(selfComps, component) == nil then
      -- component does not exist in this list, returns the archetype itself
      return self
   end

   local len = table.getn(selfComps)
   local newCoomponents = table.create(len - 1)
   local a = 1
   for i = 1, len do
      if selfComps[i] ~= component then
         newCoomponents[a] = selfComps[i]
         a = a + 1
      end
   end

   return Archetype.Get(newCoomponents)
end

--[[
   Checks whether this archetype has the informed component
]]
function Archetype:Has(component)
   return table.find(self.Components, component) ~= nil
end

-- Generic archetype, for entities that do not have components
local ARCHETYPE_EMPTY = Archetype.Get({})

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
         "world.Call(entity, Component, 'methodName', param1, paramN)"

      @TODO: shared  {Boolean}
         see https://docs.unity3d.com/Packages/com.unity.entities@0.7/manual/shared_component_data.html

   Returns component ID
]]
local function RegisterComponent(name, constructor, isTag, api)

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

-- Special component used to identify the entity that owns a data
local ENTITY_ID_KEY = RegisterComponent('_ECS_ENTITY_ID_')

----------------------------------------------------------------------------------------------------------------------
-- CHUNK
----------------------------------------------------------------------------------------------------------------------
local Chunk    = {}
Chunk.__index  = Chunk

local CHUNK_SIZE = 10

--[[
   A block of memory containing the components for entities sharing the same Archetype

   A chunk is a dumb database, it only organizes the components in memory
]]
function  Chunk.New(world, archetype)

   local buffers = {}

   -- um buffer especial que identifica o id da entidade
   buffers[ENTITY_ID_KEY] = table.create(CHUNK_SIZE)

   for _, componentID in pairs(archetype.Components) do
      if COMPONENTS_IS_TAG[componentID] then
         -- tag component dont consumes memory
         buffers[componentID] = nil
      else
         buffers[componentID] = table.create(CHUNK_SIZE)
      end
   end

   return setmetatable({
      Version     = 0,
      Count       = 0,
      World       = world,
      Archetype   = archetype,
      Buffers     = buffers,
   }, Chunk)
end

--[[
   Performs cleaning of a specific index within this chunk
]]
function  Chunk:Clear(index)
   local buffers = self.Buffers
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
function Chunk:GetValue(index, component)
   local buffers = self.Buffers
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
function Chunk:SetValue(index, component, value)
   local buffers = self.Buffers
   if buffers[component] == nil then
      return
   end
   buffers[component][index] = value
end

--[[
   Get all buffer data at a specific index
]]
function Chunk:Get(index)
   local data = {}
   local buffers = self.Buffers
   for component in pairs(buffers) do
      data[component] = buffers[component][index]
   end
   return data
end

--[[
   Sets all buffer data to the specific index.

   Copies only the data of the components existing in this chunk (therefore, ignores other records)
]]
function Chunk:Set(index, data)
   local buffers = self.Buffers
   for component, value in pairs(data) do
      if buffers[component] ~= nil then
         buffers[component][index] = value
      end
   end
end

--[[
   Defines the entity to which this data belongs
]]
function Chunk:SetEntityId(index, entity)
   self.Buffers[ENTITY_ID_KEY][index] = entity
end

----------------------------------------------------------------------------------------------------------------------
-- ENTITY MANAGER
----------------------------------------------------------------------------------------------------------------------

--[[
   Responsible for managing the entities and chunks of a world
]]
local EntityManager  = {}
EntityManager.__index = EntityManager

function  EntityManager.New(world)
   return setmetatable({
      World = world,

      -- Incremented whenever it undergoes structural changes (add or remove archetypes or chunks)
      Version = 0,

      CountValue = 0,

      --[[
         What is the local index of that entity (for access to other values)

         @Type { [entityID] : { archetype: string, chunk: number, ChunkIndex: number } }
      ]]
      Entities = {},

      --[[
         {
            [archetypeID] : {
               -- The number of entities currently stored
               Count: number
               -- What is the index of the last free chunk to use?
               LastChunk:number,
               -- Within the available chunk, what is the next available index for allocation?
               NextChunkIndex:number,
               Chunks: Array<Chunk>}
            }
      ]]
      Archetypes   = {}
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
function  EntityManager:Set(entityID, archetype)

   local archetypeID = archetype.Id
   local entity      = self.Entities[entityID]

   local oldEntityData = nil

   -- entity is already registered with this entity manager?
   if entity ~= nil then
      if entity.Archetype == archetypeID then
         -- entity is already registered in the informed archetype, nothing to do
         return
      end

      --Different archetype
      -- back up old data
      oldEntityData = self.Archetypes[entity.Archetype].Chunks[entity.Chunk]:Get(entity.ChunkIndex)

      -- removes entity from the current (and hence chunk) archetype
      self:Remove(entityID)
   end

   -- Check if chunk is available (may be the first entity for the informed archetype)
   if self.Archetypes[archetypeID] == nil then
      -- there is no chunk for this archetype, start the list
      self.Archetypes[archetypeID] = {
         Count          = 0,
         LastChunk      = 1,
         NextChunkIndex = 1,
         Chunks         = { Chunk.New(self.World, archetype) }
      }

      self.Version = self.Version + 1
   end

   -- add entity at the end of the correct chunk
   local db = self.Archetypes[archetypeID]

   -- new entity record
   self.Entities[entityID] = {
      Archetype   = archetypeID,
      Chunk       = db.LastChunk,
      ChunkIndex  = db.NextChunkIndex
   }
   self.CountValue = self.CountValue + 1

   local chunk = db.Chunks[db.LastChunk]

   -- Clears any memory junk
   chunk:Clear(db.NextChunkIndex)

   -- update entity indexes
   if oldEntityData ~= nil then
      -- if it's archetype change, restore backup of old data
      chunk:Set(db.NextChunkIndex, oldEntityData)
   end
   chunk:SetEntityId(db.NextChunkIndex, entityID)

   db.Count = db.Count + 1
   chunk.Count = db.NextChunkIndex

   -- update chunk index
   db.NextChunkIndex = db.NextChunkIndex + 1

   -- marks the new version of chunk (moment that changed)
   chunk.Version = self.World.Version

   -- if the chunk is full, it already creates a new chunk to welcome new future entities
   if db.NextChunkIndex > CHUNK_SIZE  then
      db.LastChunk            = db.LastChunk + 1
      db.NextChunkIndex       = 1
      db.Chunks[db.LastChunk] = Chunk.New(self.World, archetype)

      self.Version = self.Version + 1
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
function  EntityManager:Remove(entityID)
   local entity = self.Entities[entityID]

   if entity == nil then
      return
   end

   local db = self.Archetypes[entity.Archetype]
   local chunk = db.Chunks[entity.Chunk]

   -- clear data in chunk
   chunk:Clear(entity.ChunkIndex)
   chunk.Count = chunk.Count - 1

   -- clears entity references
   self.Entities[entityID] = nil
   self.CountValue = self.CountValue - 1
   db.Count = db.Count - 1

   -- Adjust chunks, avoid holes
   if db.NextChunkIndex == 1 then
      -- the last chunk is empty and an item from a previous chunk has been removed
      -- system should remove this chunk (as there is a hole in the previous chunks that must be filled before)
      db.Chunks[db.LastChunk] = nil
      db.LastChunk      = db.LastChunk - 1
      db.NextChunkIndex = CHUNK_SIZE + 1 -- (+1, next steps get -1)

      self.Version = self.Version + 1
   end

   if db.Count > 0 then
      if db.NextChunkIndex > 1 then
         -- ignore when entity is the laste item
         if not (db.LastChunk == entity.Chunk and (db.NextChunkIndex - 1) == entity.ChunkIndex) then
            -- Moves the last item of the last chunk to the position that was left open, for
            -- this, it is necessary to find out which entity belongs, in order to keep
            -- the references consistent
            local lastEntityData = db.Chunks[db.LastChunk]:Get(db.NextChunkIndex-1)
            db.Chunks[entity.Chunk]:Set(entity.ChunkIndex, lastEntityData)

            -- update entity indexes
            local otherEntityID     = lastEntityData[ENTITY_ID_KEY]
            local otherEntity       = self.Entities[otherEntityID]
            otherEntity.Chunk       = entity.Chunk
            otherEntity.ChunkIndex  = entity.ChunkIndex
         end

         -- backs down the note and clears the unused record
         db.NextChunkIndex = db.NextChunkIndex - 1
         db.Chunks[db.LastChunk]:Clear(db.NextChunkIndex)
      end
   else
      db.NextChunkIndex = db.NextChunkIndex - 1
   end
end

--[[
   How many entities does this EntityManager have
]]
function EntityManager:Count()
   return self.CountValue
end

--[[
   Performs the cleaning of an entity's data WITHOUT REMOVING IT.

   Used when running scripts when a script requests the removal of an
   entity. As the system postpones the actual removal until the end
   of the execution of the scripts, at this moment it only performs
   the cleaning of the data (Allowing the subsequent scripts to
   perform the verification)
]]
function EntityManager:Clear(entityID)
   local entity = self.Entities[entityID]
   if entity == nil then
      return
   end

   local chunk = self.Archetypes[entity.Archetype].Chunks[entity.Chunk]
   chunk:Clear(entity.ChunkIndex)
end

--[[
   Gets the current value of an entity component

   Params
      entity {number}
      component {number}
]]
function EntityManager:GetValue(entityID, component)
   local entity = self.Entities[entityID]
   if entity == nil then
      return nil
   end

   return self.Archetypes[entity.Archetype].Chunks[entity.Chunk]:GetValue(entity.ChunkIndex, component)
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
function EntityManager:SetValue(entityID, component, value)
   local entity = self.Entities[entityID]
   if entity == nil then
      return
   end

   local chunk = self.Archetypes[entity.Archetype].Chunks[entity.Chunk]

   chunk:SetValue(entity.ChunkIndex, component, value)
end

--[[
   Gets all values of the components of an entity

   Params
      entity {number}
         Entity ID
]]
function EntityManager:GetData(entityID)
   local entity = self.Entities[entityID]
   if entity == nil then
      return nil
   end

   local chunk = self.Archetypes[entity.Archetype].Chunks[entity.Chunk]
   return chunk:Get(entity.ChunkIndex)
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
function EntityManager:SetData(entityID, component, data)
   local entity = self.Entities[entityID]
   if entity == nil then
      return
   end

   local chunk = self.Archetypes[entity.Archetype].Chunks[entity.Chunk]
   chunk:Set(entity.ChunkIndex, component, data)
end

--[[
   Gets an entity's chunk and index
]]
function EntityManager:GetEntityChunk(entityID)
   local entity = self.Entities[entityID]
   if entity == nil then
      return
   end

   return self.Archetypes[entity.Archetype].Chunks[entity.Chunk], entity.ChunkIndex
end

--[[
   Gets all chunks that match the given filter

   Params
      filterFn {function(components) => boolean}
]]
function EntityManager:FilterChunks(filterMatch)
   local chunks = {}
   for archetypeID, db in pairs(self.Archetypes) do
      if filterMatch(Archetypes[archetypeID].Components) then
         for i, chunk in pairs(db.Chunks) do
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

local SYSTEM_STEPS = {
   'task',
   'render',
   'process',
   'processIn',
   'processOut',
   'transform'
}

--[[
   Allow to create new System Class Type

   Params:
      config {

         Name: string,
            Unique name for this System

         RequireAll|RequireAny: Array<number>,
            components this system expects the entity to have before it can act on. If you want
            to create a system that acts on all entities, enter nil

         RejectAll|RejectAny: Array<number>,
            Optional It allows informing that this system will not be invoked if the entity has any of these components

         Step: task|render|process|processIn|processOut|transform' Defaults to process
            Em qual momento, durante a execução de um Frame do Roblox, este sistema deverá ser executado (https://developer.roblox.com/en-us/articles/task-scheduler)
            render      : RunService.RenderStepped
            process     : RunService.Stepped
            transform   : RunService.Heartbeat

         Order: number,
            Allows you to define the execution priority level for this system

         ShouldUpdate(time: number, interpolation:number, world, system): void
            It allows informing if the update methods of this system should be invoked

         BeforeUpdate(time: number, interpolation:number, world, system): void
            Invoked before updating entities available for this system.
            It is only invoked when there are entities with the characteristics
            expected by this system

         Update: function(time, world, dirty, entity, index, [component_N_items...]) -> boolean
            Invoked in updates, limited to the value set in the "frequency" attribute

         AfterUpdate(time: number, interpolation:number, world, system): void

         OnEnter(entity: Entity): void;
            Invoked when:
               a) An entity with the characteristics (components) expected by this system is
                  added in the world;
               b) This system is added in the world and this world has one or more entities with
                  the characteristics expected by this system;
               c) An existing entity in the same world receives a new component at runtime
                  and all of its new components match the standard expected by this system.

         OnRemove(time, world, enity, index, [component_N_items...])
   }
]]
local function RegisterSystem(config)

   if config == nil then
      error('System configuration is required for its creation')
   end

   if config.Name == nil then
      error('The system "Name" is required for registration')
   end

   if SYSTEM_INDEX_BY_NAME[config.Name] ~= nil then
      error('Another System already registered with that name')
   end

   if config.Step == nil then
      config.Step = 'transform'
   end

   if not table.find(SYSTEM_STEPS, config.Step) then
      error('The "step" parameter must one of ', table.concat(SYSTEM_STEPS, ', '))
   end

   if config.Step == 'task' then
      if config.Order ~= nil then
         error('Task-type systems do not accept the "Order" parameter')
      end

      if config.ShouldUpdate ~= nil then
         error('Task-type systems do not accept the "ShouldUpdate" parameter')
      end

      if config.BeforeUpdate ~= nil then
         error('Task-type systems do not accept the "BeforeUpdate" parameter')
      end

      if config.Update ~= nil then
         error('Task-type systems do not accept the "Update" parameter')
      end

      if config.AfterUpdate ~= nil then
         error('Task-type systems do not accept the "AfterUpdate" parameter')
      end

      if config.OnEnter ~= nil then
         error('Task-type systems do not accept the "OnEnter" parameter')
      end

      if config.Execute == nil then
         error('The task "Execute" method is required for registration')
      end
   end

   if config.Order == nil or config.Order < 0 then
      config.Order = 50
   end

   -- imutable
   table.insert(SYSTEM, {
      Filter               = Filter(config),
      Name                 = config.Name,
      RequireAll           = config.RequireAll,
      RequireAny           = config.RequireAny,
      RequireAllOriginal   = config.RequireAllOriginal,
      RequireAnyOriginal   = config.RequireAnyOriginal,
      RejectAll            = config.RejectAll,
      RejectAny            = config.RejectAny,
      ShouldUpdate         = config.ShouldUpdate,
      BeforeUpdate         = config.BeforeUpdate,
      Update               = config.Update,
      AfterUpdate          = config.AfterUpdate,
      OnCreate             = config.OnCreate,
      OnEnter              = config.OnEnter,
      OnRemove             = config.OnRemove,
      BeforeExecute        = config.BeforeExecute,
      Execute              = config.Execute,
      Step                 = config.Step,
      Order                = config.Order
   })

   local ID = table.getn(SYSTEM)

   SYSTEM_INDEX_BY_NAME[config.Name] = ID

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
function Scheduler.New(world, entityManager)
   return setmetatable({
      World          = world,
      EntityManager  = entityManager,

      -- tracking the smallest vruntime among all tasks in the runqueue
      min_vruntime = 0,

      -- a time-ordered rbtree to build a "timeline" of future task execution
      rbtree = rb_create(),

      -- sempre que o entity manger sofre alteração estrutural (adiciona ou remove chunks)
      -- este Scheduler precisará atualizar a arvore de tarefas
      LastEntityManagerVersion = -1,

      -- Sistemas do tipo Task, no formato {[key=system.id] => system}
      Systems = {}
   }, Scheduler)
end

--[[
   Adiciona um sistema neste scheduler
]]
function Scheduler:AddSystem(systemID, config)
   if self.Systems[systemID] ~= nil then
      -- This system has already been registered
      return
   end

   if config == nil then
      config = {}
   end

   local system = {
      Id                   = systemID,
      name                 = SYSTEM[systemID].Name,
      RequireAll           = SYSTEM[systemID].RequireAll,
      RequireAny           = SYSTEM[systemID].RequireAny,
      RequireAllOriginal   = SYSTEM[systemID].RequireAllOriginal,
      RequireAnyOriginal   = SYSTEM[systemID].RequireAnyOriginal,
      RejectAll            = SYSTEM[systemID].RejectAll,
      RejectAny            = SYSTEM[systemID].RejectAny,
      Filter               = SYSTEM[systemID].Filter,
      BeforeExecute        = SYSTEM[systemID].BeforeExecute,
      Execute              = SYSTEM[systemID].Execute,
      -- instance properties
      Config               = config
   }

   self.Systems[systemID] = system

   -- forces re-creation of tasks list
   self.LastEntityManagerVersion = 0
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
function Scheduler:Run(time)
   if self.EntityManager.Version ~= self.LastEntityManagerVersion then
      self:Update()
      self.LastEntityManagerVersion = self.EntityManager.Version
   end

   local tree           = self.rbtree
   local world          = self.World

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
      local whatComponents = system.RequireAllOriginal
      if whatComponents == nil then
         whatComponents = system.RequireAnyOriginal
      end

      local whatComponentsLen = table.getn(whatComponents)

      -- execute: function(time, world, dirty, entity, index, [component_N_items...]) -> boolean
      local executeFn = system.Execute

      -- increment Global System Version (GSV), before system execute
      world.Version = world.Version + 1

      if system.BeforeExecute ~= nil then
         system.BeforeExecute(time, world, system)
      end

      -- if the version of the chunk is larger than the task, it means
      -- that this chunk has already undergone a change that was not performed
      -- after the last execution of this task
      local dirty = chunk.Version == 0 or chunk.Version > taskVersion
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

      for index = 1, chunk.Count do
         if executeFn(taskTime, world, dirty, entityIDBuffer[index], index, table.unpack(componentsData)) then
            hasChangeThisChunk = true
         end
      end

      if hasChangeThisChunk then
         -- If any system execution informs you that it has changed data in
         -- this chunk, it then performs the versioning of the chunk
         chunk.Version = world.Version
      end

      -- update last task version with GSV
      task.data[3] = world.Version
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
function Scheduler:Update()
   local tree           = self.rbtree
   local systems        = self.Systems
   local entityManager  = self.EntityManager
   local min_vruntime   = self.min_vruntime
   local worldVersion   = self.World.Version

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
      local chunks = entityManager:FilterChunks(system_a.Filter.Match)

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
      if system.Update ~= nil then
         if updateSteps[system.Step][system.Order] == nil then
            updateSteps[system.Step][system.Order] = {}
            table.insert(updateStepsOrder[system.Step], system.Order)
         end

         table.insert(updateSteps[system.Step][system.Order], system)
      end

      if system.OnEnter ~= nil then
         table.insert(onEnterSystems, system)
      end

      if system.OnRemove ~= nil then
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
            if system.ShouldUpdate == nil or system.ShouldUpdate(time, interpolation, world, system) then

               system.lastUpdate = time

               -- what components the system expects
               local whatComponents = system.RequireAllOriginal
               if whatComponents == nil then
                  whatComponents = system.RequireAnyOriginal
               end

               local whatComponentsLen    = table.getn(whatComponents)
               local systemVersion        = system.Version

               -- Gets all the chunks that apply to this system
               local chunks = entityManager:FilterChunks(system.Filter.Match)

               -- update: function(time, world, dirty, entity, index, [component_N_items...]) -> boolean
               local updateFn = system.Update

               -- increment Global System Version (GSV), before system update
               world.Version = world.Version + 1

               if system.BeforeUpdate ~= nil then
                  system.BeforeUpdate(time, interpolation, world, system)
               end
   
               for k, chunk in pairs(chunks) do
                  -- if the version of the chunk is larger than the system, it means
                  -- that this chunk has already undergone a change that was not performed
                  -- after the last execution of this system
                  local dirty = chunk.Version == 0 or chunk.Version > systemVersion
                  local buffers = chunk.Buffers
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
   
                  for index = 1, chunk.Count do
                     if updateFn(time, world, dirty, entityIDBuffer[index], index, table.unpack(componentsData)) then
                        hasChangeThisChunk = true
                     end
                  end
   
                  if hasChangeThisChunk then
                     -- If any system execution informs you that it has changed data in
                     -- this chunk, it then performs the versioning of the chunk
                     chunk.Version = world.Version
                  end
               end
   
               if system.AfterUpdate ~= nil then
                  system.AfterUpdate(time, interpolation, world, system)
               end
   
               -- update last system version with GSV
               system.Version = world.Version
            end
         end
      end
   end

   local onEnter = function(onEnterEntities, entityManager, time)
      -- increment Global System Version (GSV), before system update
      world.Version = world.Version + 1

      for entityID, newComponents in pairs(onEnterEntities) do

         -- temporary filter
         local filterHasAny = Filter({ RequireAny = newComponents })

         -- get the chunk and index of this entity
         local chunk, index = entityManager:GetEntityChunk(entityID)
         if chunk ~= nil then
            local buffers = chunk.Buffers

            for j, system in pairs(onEnterSystems) do

               -- system does not apply to the archetype of that entity
               if system.Filter.Match(chunk.Archetype.Components) then

                  -- what components the system expects
                  local whatComponents = system.RequireAllOriginal
                  if whatComponents == nil then
                     whatComponents = system.RequireAnyOriginal
                  end

                  -- components received are not in the list of components expected by the system
                  if filterHasAny.Match(whatComponents) then
                     local componentsData = table.create(table.getn(whatComponents))

                     for l, compID in ipairs(whatComponents) do
                        if buffers[compID] ~= nil then
                           componentsData[l] = buffers[compID]
                        else
                           componentsData[l] = {}
                        end
                     end

                     -- onEnter: function(world, entity, index, [component_N_items...]) -> boolean
                     if system.OnEnter(time, world, entityID, index, table.unpack(componentsData)) then
                        -- If any system execution informs you that it has changed data in
                        -- this chunk, it then performs the versioning of the chunk
                        chunk.Version = world.Version
                     end
                  end
               end
            end
         end
      end
   end

   local onRemove = function(removedEntities, entityManager, time)
      -- increment Global System Version (GSV), before system update
      world.Version = world.Version + 1

      for entityID, _  in pairs(removedEntities) do

         -- get the chunk and index of this entity
         local chunk, index = entityManager:GetEntityChunk(entityID)
         if chunk ~= nil then
            local buffers = chunk.Buffers

            for _, system in pairs(onRemoveSystems) do

               -- system does not apply to the archetype of that entity
               if system.Filter.Match(chunk.Archetype.Components) then

                  -- what components the system expects
                  local whatComponents = system.RequireAllOriginal
                  if whatComponents == nil then
                     whatComponents = system.RequireAnyOriginal
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
                  if system.OnRemove(time, world, entityID, index, table.unpack(componentsData)) then
                     -- If any system execution informs you that it has changed data in
                     -- this chunk, it then performs the versioning of the chunk
                     chunk.Version = world.Version
                  end
               end
            end
         end
      end
   end

   return onUpdate, onEnter, onRemove
end

--[[
   World constructor
]]
local function CreateNewWorld(systems, config)

   if config == nil then
      config = {}
   end

   

   local SEQ_ENTITY  = 1

   -- systems in this world
   local worldSystems = {}

   -- Job system
   local scheduler

   -- System execution plan
   local updateExecPlan, enterExecPlan, removeExecPlan

   local processDeltaTime

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

   -- True when environment has been modified while a system is running
   local dirtyEnvironment = false

   --[[
      Create a new entity
   ]]
   local function CreateEntity()
      local ID = SEQ_ENTITY
      SEQ_ENTITY = SEQ_ENTITY + 1

      entityManagerNew:Set(ID, ARCHETYPE_EMPTY)

      -- informs that it has a new entity
      entitiesNew[ID] = true

      entitiesArchetypes[ID] = ARCHETYPE_EMPTY

      dirtyEnvironment = true

      return ID
   end

   --[[
      Get entity compoment data
   ]]
   local function GetComponentValue(entity, component)
      if entitiesNew[entity] == true then
         return entityManagerNew:GetValue(entity, component)
      elseif entitiesUpdated[entity] ~= nil then
         return entityManagerUpdated:GetValue(entity, component)
      else
         return entityManager:GetValue(entity, component)
      end
   end

   --[[
      Defines the value of a component for an entity
   ]]
   local function SetComponentValue(entity, component, ...)
      local archetype = entitiesArchetypes[entity]
      if archetype == nil then
         -- entity doesn exist
         return
      end

      dirtyEnvironment = true

      local archetypeNew = archetype:With(component)
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
            entityManagerNew:Set(entity, archetypeNew)
         end

         entityManagerNew:SetValue(entity, component, value)
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
               entityManagerUpdated:Set(entity, archetypeNew)
               entityManagerUpdated:SetData(entity, entityManager:GetData(entity))
            else
               -- just perform the archetype update on the entityManager
               entityManagerUpdated:Set(entity, archetypeNew)
            end
         end

         if entitiesUpdated[entity]  ~= nil then
            -- register a copy of the value
            entityManagerUpdated:SetValue(entity, component, value)

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
         entityManager:SetValue(entity, component, value)
      end
   end


   --[[
      Invokes a utility method from a component's api
   ]]
   local function CallComponentAPI(entity, component, method, ...)

      local fn = COMPONENTS_API[component][method]
      if not fn then
         return nil
      end

      local changed, value = fn(world.Get(entity, component), table.unpack({...}))

      if changed then
         world.Set(entity, component, {__v = {value}})
      end

      return value
   end

   --[[
      Removing a entity or Removing a component from an entity at runtime
   ]]
   local function RemoveEntityOrComponent(entity, component)
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
            entityManagerNew:Remove(entity)
            entitiesNew[entity] = nil
            entitiesArchetypes[entity] = nil
         else
            if entitiesRemoved[entity] == nil then
               entitiesRemoved[entity] = true
            end
         end
      else
         -- remove component from entity
         local archetypeNew = archetype:Without(component)
         local archetypeChanged = archetype ~= archetypeNew
         if archetypeChanged then
            entitiesArchetypes[entity] = archetypeNew
         end
         if entitiesNew[entity] == true then
            if archetypeChanged then
               entityManagerNew:Set(entity, archetypeNew)
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
                  entityManagerUpdated:Set(entity, archetypeNew)
                  entityManagerUpdated:SetData(entity, entityManager:GetData(entity))
               else
                  -- just perform the archetype update on the entityManager
                  entityManagerUpdated:Set(entity, archetypeNew)
               end
            end

            if entitiesUpdated[entity] ~= nil then
               -- register a copy of the value
               entityManagerUpdated:SetValue(entity, component, nil)

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
            entityManager:SetValue(entity, component, nil)
         end
      end
   end

   --[[
      Get entity compoment data
   ]]
   local function CheckComponentHas(entity, component)
      if entitiesArchetypes[entity] == nil then
         return false
      end

      return entitiesArchetypes[entity]:Has(component)
   end

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
   local function FilterForeach(filter, callback)

      local stopped = false

      -- Allows the developer to stop execution
      local stop = function()
         stopped = true
      end

      -- Gets all the chunks that apply to this filter
      local chunks = entityManager:FilterChunks(filter.Match)

      for k, chunk in pairs(chunks) do
         local buffers = chunk.Buffers

         local componentsData = table.create(table.getn(filter.Components))
         for l, compID in ipairs(filter.Components) do
            if buffers[compID] ~= nil then
               componentsData[l] = buffers[compID]
            else
               componentsData[l] = {}
            end
         end

         local entityIDBuffer = buffers[ENTITY_ID_KEY]
         local hasChangeThisChunk = false
         for index = 1, chunk.Count do
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
            chunk.Version = world.Version
         end

         if stopped then
            break
         end
      end
   end

   local function AddSystem(systemID, order, config)
      if systemID == nil then
         return
      end

      if SYSTEM[systemID] == nil then
         error('There is no registered system with the given ID')
      end

      if SYSTEM[systemID].Step == 'task' then
         scheduler:AddSystem(systemID)
      else
         if worldSystems[systemID] ~= nil then
            -- This system has already been registered in this world
            return
         end

         -- @TODO: why?
         if entityManager:Count() > 0 or entityManagerNew:Count() > 0 then
            error('Adding systems is not allowed after adding entities in the world')
         end

         if config == nil then
            config = {}
         end

         local system = {
            Id                   = systemID,
            Name                 = SYSTEM[systemID].Name,
            RequireAll           = SYSTEM[systemID].RequireAll,
            RequireAny           = SYSTEM[systemID].RequireAny,
            RequireAllOriginal   = SYSTEM[systemID].RequireAllOriginal,
            RequireAnyOriginal   = SYSTEM[systemID].RequireAnyOriginal,
            RejectAll            = SYSTEM[systemID].RejectAll,
            RejectAny            = SYSTEM[systemID].RejectAny,
            Filter               = SYSTEM[systemID].Filter,
            OnCreate             = SYSTEM[systemID].OnCreate,
            ShouldUpdate         = SYSTEM[systemID].ShouldUpdate,
            BeforeUpdate         = SYSTEM[systemID].BeforeUpdate,
            Update               = SYSTEM[systemID].Update,
            AfterUpdate          = SYSTEM[systemID].AfterUpdate,
            OnEnter              = SYSTEM[systemID].OnEnter,
            OnRemove             = SYSTEM[systemID].OnRemove,
            Step                 = SYSTEM[systemID].Step,
            Order                = SYSTEM[systemID].Order,
            -- instance properties
            Version              = 0,
            LastUpdate           = timeProcess,
            Config               = config
         }

         if order ~= nil and order < 0 then
            system.Order = 50
         end

         worldSystems[systemID] = system

         -- forces re-creation of the execution plan
         lastKnownArchetypeInstant = 0

         if system.OnCreate ~= nil then
            system.OnCreate(world, system)
         end
      end
   end

   --[[
      Is the Entity still alive?
   ]]
   local function IsEntityAlive(entity)
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
   end

   --[[
      Remove all entities and systems
   ]]
   local function DestroyWorld()
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
      entitiesArchetypes   = nil
      scheduler            = nil

      -- It also removes all methods in the world, avoids external calls
      world.Create      = nil
      world.Set         = nil
      world.Get         = nil
      world.Remove      = nil
      world.Has         = nil
      world.ForEach     = nil
      world.AddSystem   = nil
      world.Alive       = nil
      world.Update      = nil
      world.Destroy     = nil
      world             = nil
   end

   --[[
      cleans up after running scripts
   ]]
   local function CleanupEnvironment(time)

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
         entityManager:Remove(entityID)
         entitiesArchetypes[entityID] = nil

         -- was removed after update
         if entitiesUpdated[entityID] ~= nil then
            entitiesUpdated[entityID] = nil
            entityManagerUpdated:Remove(entityID)
         end
      end
      entitiesRemoved = {}

      -- 2: Update entities in memory
      -- @TODO: Event onChange?
      for entityID, updated in pairs(entitiesUpdated) do
         entityManager:Set(entityID, entitiesArchetypes[entityID])
         entityManager:SetData(entityID, entityManagerUpdated:GetData(entityID))
         entityManagerUpdated:Remove(entityID)

         if table.getn(updated.received) > 0 then
            onEnterEntities[entityID] = updated.received
            haveOnEnter = true
         end
      end
      entitiesUpdated = {}

      -- 3: Add new entities
      for entityID, V in pairs(entitiesNew) do
         entityManager:Set(entityID, entitiesArchetypes[entityID])
         entityManager:SetData(entityID,  entityManagerNew:GetData(entityID))
         entityManagerNew:Remove(entityID)
         onEnterEntities[entityID] = entitiesArchetypes[entityID].Components
         haveOnEnter = true
      end
      entitiesNew = {}

      if haveOnEnter then
         enterExecPlan(onEnterEntities, entityManager, time)
         onEnterEntities = nil
      end
   end

   --[[
      Allows you to change the frequency of the 'process' step at run time
   ]]
   local function SetFrequency(frequency)
      config.Frequency  = frequency

      -- frequency: number,
      -- The maximum times per second this system should be updated. Defaults 30
      if config.Frequency == nil then
         config.Frequency = 30
      end

      local safeFrequency  = math.round(math.abs(config.Frequency)/2)*2
      if safeFrequency < 2 then
         safeFrequency = 2
      end

      if config.Frequency ~= safeFrequency then
         config.Frequency = safeFrequency
         print(string.format(">>> ATTENTION! The execution frequency of world has been changed to %d <<<", safeFrequency))
      end

      processDeltaTime = 1000/config.Frequency/1000

      world.Frequency = config.Frequency
   end

   --[[
      Realizes world update
   ]]
   local function Update(step, now)
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
            CleanupEnvironment(time)
         end

         if step == 'transform' then
            scheduler:Run(time)
            CleanupEnvironment(time)
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
               CleanupEnvironment(time)
            end

            nLoops      = nLoops + 1
            timeProcess = timeProcess + processDeltaTime
         end

         if updated then
            timeProcessOld = timeProcessOldTmp
         end
      end
   end

  

   world = {
      Version        = 0,
      Frequency      = config.Frequency,
      -- Functions
      Create         = CreateEntity,
      Get            = GetComponentValue,
      Set            = SetComponentValue,
      Call           = CallComponentAPI,
      Remove         = RemoveEntityOrComponent,
      Has            = CheckComponentHas,
      ForEach        = FilterForeach,
      AddSystem      = AddSystem,
      Alive          = IsEntityAlive,
      Destroy        = DestroyWorld,
      Update         = Update,
      SetFrequency   = SetFrequency
   }

   SetFrequency(config.Frequency)

   -- all managers in this world
   entityManager        = EntityManager.New(world)
   entityManagerNew     = EntityManager.New(world)
   entityManagerUpdated = EntityManager.New(world)

   scheduler = Scheduler.New(world, entityManager)

   -- add user systems
   if systems ~= nil then
      for i, system in pairs(systems) do
         AddSystem(system)
      end
   end

   if not config.DisableAutoUpdate then
      world._steppedConn = RunService.Stepped:Connect(function()
         Update('processIn',  os.clock())
         Update('process',    os.clock())
         Update('processOut', os.clock())
      end)

      world._heartbeatConn = RunService.Heartbeat:Connect(function()
         Update('transform', os.clock())
      end)

      if not RunService:IsServer() then
         world._renderSteppedConn = RunService.RenderStepped:Connect(function()
            Update('render', os.clock())
         end)
      end
   end

   return world
end

------------------------------------------------------------------------------------------------------------------------
-- export ECS lib
------------------------------------------------------------------------------------------------------------------------
return {
   RegisterComponent = RegisterComponent,
   RegisterSystem    = RegisterSystem,
   Filter            = Filter,
   CreateWorld       = CreateNewWorld
}
