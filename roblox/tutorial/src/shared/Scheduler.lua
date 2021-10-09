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

   local tree  = self.rbtree
   local world = self.World

   -- 0.01667 = 1000/60/1000
   local maxExecTime  = math.max(
      SCHED_MIN_EXEC_TIME, 
      (0.01667 - (os.clock() - time.frameReal)) - SCHED_RESERVED_TIME_RENDER
   )

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


 -- Job system
 local scheduler = Scheduler.New(world, entityManager)
