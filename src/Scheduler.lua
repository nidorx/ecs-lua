
--[[
   https://blog.molecular-matters.com/2012/04/05/building-a-load-balanced-task-scheduler-part-1-basics/
   https://blog.molecular-matters.com/2015/08/24/job-system-2-0-lock-free-work-stealing-part-1-basics/
]]
local RedBlackTree = require("RedBlackTree")

local rb_get = RedBlackTree.get
local rb_all = RedBlackTree.all
local rb_each = RedBlackTree.each
local rb_node = RedBlackTree.node
local rb_next = RedBlackTree.next
local rb_first = RedBlackTree.first
local rb_create = RedBlackTree.create
local rb_filter = RedBlackTree.filter
local rb_delete = RedBlackTree.delete
local rb_insert = RedBlackTree.insert
local rb_minimum = RedBlackTree.minimum

-- precision
local EPSILON = 0.000000001

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
      local entityIDBuffer = buffers[EntityIdComponent]
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

return Scheduler
