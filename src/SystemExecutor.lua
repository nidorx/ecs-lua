
--[[
   After = {SystemC, SystemD}, An update order that requests ECS update this system after it updates another specified system.
   Before = {SystemA, SystemB}, An update order that requests ECS update this system before it updates another specified system.
]]
local function mapTaskDependencies(systems)

   local nodes = {}
   local nodesByType = {}

   for i,system in ipairs(systems) do
      local sType = system:GetType()

      if (system._TaskState == nil) then
         -- suspended, scheduled, running
         system._TaskState = "suspended"
      end

      if not nodesByType[sType] then
         local node = {
            Type = sType,
            System = system,
            -- @type {[Node]=true}
            Depends = {}
         }
         nodesByType[sType] = node
         table.insert(nodes, node)        
      end
   end

   for _, node in ipairs(nodes) do
       -- this system will update Before another specified system
       local before = node.Type.Before
       if (before ~= nil and #before > 0) then
          for _,sTypeOther in ipairs(before) do
             local otherNode = nodesByType[sTypeOther]
             if otherNode then
                otherNode.Depends[node] = true
             end
          end
       end

      -- this system will update After another specified system
      local after = node.Type.After
      if (after ~= nil and #after > 0) then
         for _,sTypeOther in ipairs(after) do
            local otherNode = nodesByType[sTypeOther]
            if otherNode then
               node.Depends[otherNode] = true
            end
         end
      end
   end

   return nodes
end

local function orderSystems(a, b)
   return a.Order < b.Order
end

--[[
   Responsible for coordinating and executing the systems methods
]]
local SystemExecutor = {}
SystemExecutor.__index = SystemExecutor

function SystemExecutor.New(world)   
   local executor =  setmetatable({
      _world = world,
      _onExit = {},
      _onEnter = {},
      _onRemove = {},
      _task = {},
      _render = {},
      _process = {},
      _transform = {},
      _schedulers = {},
      _lastFrameMatchQueries = {},
      _currentFrameMatchQueries = {},
   }, SystemExecutor)

   world:OnQueryMatch(function(query)
      executor._currentFrameMatchQueries[query] = true
   end)

   return executor
end

function SystemExecutor:SetSystems(systems)
   local onExit = {}
   local onEnter = {}
   local onRemove = {}
   -- system:Update()
   local updateTask = {}
   local updateRender = {}
   local updateProcess = {}
   local updateTransform = {}

   for _, system in pairs(systems) do      
      local step = system.Step
      if system.Update then
         if step == "task" then
            table.insert(updateTask, system)
            
         elseif step == "process" then
            table.insert(updateProcess, system) 

         elseif step == "transform" then
            table.insert(updateTransform, system)

         elseif step == "render" then
            table.insert(updateRender, system)

         end
      end

      if (system.Query and system.Query.isQuery and step ~= "task") then
         if system.OnExit then
            table.insert(onExit, system)
         end

         if system.OnEnter then
            table.insert(onEnter, system)
         end
   
         if system.OnRemove then
            table.insert(onRemove, system)
         end
      end
   end

   updateTask = mapTaskDependencies(updateTask)
   
   table.sort(onExit, orderSystems)
   table.sort(onEnter, orderSystems)
   table.sort(onRemove, orderSystems)
   table.sort(updateRender, orderSystems)
   table.sort(updateProcess, orderSystems)
   table.sort(updateTransform, orderSystems)

   self._onExit = onExit
   self._onEnter = onEnter
   self._onRemove = onRemove
   self._task = updateTask
   self._render = updateRender
   self._process = updateProcess
   self._transform = updateTransform
end

--[[
      
   @param Time
   @param changedEntities { { [Entity] = Old<Archetype> } }
]]
function SystemExecutor:ExecOnExitEnter(Time, changedEntities)
   local isEmpty = true

   -- { [Old<Archetype>] = { [New<Archetype>] = {Entity, Entity, ...} } }
   local oldIndexed = {}
   for entity, archetypeOld in pairs(changedEntities) do
      local newIndexed = oldIndexed[archetypeOld]
      if not newIndexed then
         newIndexed = {}
         oldIndexed[archetypeOld] = newIndexed
      end
      local archetypeNew = entity.archetype

      local entities = newIndexed[archetypeNew]
      if not entities then
         entities = {}
         newIndexed[archetypeNew] = entities
      end
      table.insert(entities, entity)
      isEmpty = false
   end
   if isEmpty then
      return
   end
   self:_ExecOnEnter(Time, oldIndexed)
   self:_ExecOnExit(Time, oldIndexed)
end

--[[
   Executes the systems' OnEnter method

   @param Time {Time}
   @param entities {{[Key=Entity] => Archetype}}
   ]]
function SystemExecutor:_ExecOnEnter(Time, oldIndexed)
   local world = self._world
   for _, system in ipairs(self._onEnter) do
      local query = system.Query
      for archetypeOld, newIndexed in pairs(oldIndexed) do
         if not query:Match(archetypeOld) then
            for archetypeNew, entities in pairs(newIndexed) do
               if query:Match(archetypeNew) then
                  for i,entity in ipairs(entities) do                  
                     world.version = world.version + 1   -- increment Global System Version (GSV)
                     system:OnEnter(Time, entity)        -- local dirty = entity.version > system.version
                     system.version = world.version      -- update last system version with GSV
                  end
               end
            end
         end         
      end
   end
end

--[[
   Executes the systems' OnExit method

   @param Time {Time}
   @param entities {{[Key=Entity] => Archetype}}
]]
function SystemExecutor:_ExecOnExit(Time, oldIndexed)
   local world = self._world
   for _, system in ipairs(self._onExit) do
      local query = system.Query
      for archetypeOld, newIndexed in pairs(oldIndexed) do
         if query:Match(archetypeOld) then
            for archetypeNew, entities in pairs(newIndexed) do
               if not query:Match(archetypeNew) then
                  for i,entity in ipairs(entities) do                  
                     world.version = world.version + 1   -- increment Global System Version (GSV)
                     system:OnExit(Time, entity)         -- local dirty = entity.version > system.version
                     system.version = world.version      -- update last system version with GSV
                  end
               end
            end
         end         
      end
   end
end

--[[
   Executes the systems' OnRemove method

   @param Time {Time}
   @param entities {{[Key=Entity] => Archetype}}
]]
function SystemExecutor:ExecOnRemove(Time, removedEntities)
   
   local isEmpty = true
   local oldIndexed = {}
   for entity, archetypeOld in pairs(removedEntities) do
      local entities = oldIndexed[archetypeOld]
      if not entities then
         entities = {}
         oldIndexed[archetypeOld] = entities
      end
      table.insert(entities, entity)
      isEmpty = false
   end
   if isEmpty then
      return
   end
   
   local world = self._world
   for _, system in ipairs(self._onRemove) do 
      for archetypeOld, entities in pairs(oldIndexed) do
         if system.Query:Match(archetypeOld) then
            for i,entity in ipairs(entities) do  
               world.version = world.version + 1   -- increment Global System Version (GSV)
               system:OnRemove(Time, entity)       -- local dirty = entity.version > system.version
               system.version = world.version      -- update last system version with GSV
            end
         end
      end
   end
end

local function execUpdate(executor, systems, Time)
   local world = executor._world
   local lastFrameMatchQueries = executor._lastFrameMatchQueries
   local currentFrameMatchQueries = executor._currentFrameMatchQueries
   for j, system in ipairs(systems) do
      local canExec = true
      if system.Query then
         local query = system.Query
         if lastFrameMatchQueries[query] == true or currentFrameMatchQueries[query] == true then
            -- If the query ran in the last frame, it is likely to run successfully on this
            canExec = true
         else
            -- Always revalidates, the repository undergoes constant change
            canExec = world:FastCheck(query)
            currentFrameMatchQueries[query] = canExec
         end
      end
      if canExec then
         if (system.ShouldUpdate == nil or system.ShouldUpdate(Time)) then
            world.version = world.version + 1   -- increment Global System Version (GSV)
            system:Update(Time)                 -- local dirty = entity.version > system.version
            system.version = world.version      -- update last system version with GSV
         end
      end
   end
end

function SystemExecutor:ExecProcess(Time)
   self._currentFrameMatchQueries = {}
   execUpdate(self, self._process, Time)   
end

function SystemExecutor:ExecTransform(Time)
   execUpdate(self, self._transform, Time)
end

function SystemExecutor:ExecRender(Time)
   execUpdate(self, self._render, Time)
   self._lastFrameMatchQueries = self._currentFrameMatchQueries
end

--[[
   Starts the execution of Jobs.

   Each Job is performed in an individual coroutine

   @param maxExecTime {number} limits the amount of time jobs can run
]]
function SystemExecutor:ExecTasks(maxExecTime)
   while maxExecTime > 0 do
      local hasMore = false

      -- https://github.com/wahern/cqueues/issues/231#issuecomment-562838785
      local i, len = 0, #self._schedulers-1
      while i <= len do
         i = i + 1

         local scheduler = self._schedulers[i]
         local tasksTime, hasMoreTask = scheduler.Resume(maxExecTime)
         
         if hasMoreTask then
            hasMore = true
         end
   
         maxExecTime = maxExecTime - (tasksTime + 0.00001)
         
         if (maxExecTime <= 0) then
            break
         end
      end

      if not hasMore then
         return
      end
   end
end

local function execTask(node, Time, world, onComplete)
   local system = node.System
   system._TaskState = "running"
   if (system.ShouldUpdate == nil or system.ShouldUpdate(Time)) then
      world.version = world.version + 1   -- increment Global System Version (GSV)
      system:Update(Time)                 -- local dirty = entity.version > system.version
      system.version = world.version      -- update last system version with GSV
   end
   system._TaskState = "suspended"
   onComplete(node)
end

--[[
   Invoked at the beginning of each frame, it schedules the execution of the next tasks
]]
function SystemExecutor:ScheduleTasks(Time)
   local world = self._world

   local rootNodes = {}    -- Node[]
   local runningNodes = {} -- Node[]
   local scheduled = {}    -- { [Node] = true }
   local completed = {}    -- { [Node] = true }
   local dependents = {}   -- { [Node] = Node[] }

   local i, len = 0, #self._task-1
   while i <= len do
      i = i + 1
      local node = self._task[i]
      
      if (node.System._TaskState == "suspended") then
         -- will be executed
         node.System._TaskState = "scheduled"

         local hasDependencies = false
         for other,_ in pairs(node.Depends) do
            hasDependencies = true
            if dependents[other] == nil then
               dependents[other] = {}
            end
            table.insert(dependents[other], node)
         end
         
         if (not hasDependencies) then
            table.insert(rootNodes, node)
         end

         scheduled[node] = true
      end
   end

   -- suspended, scheduled, running
   local function onComplete(node)

      node.Thread = nil
      node.LastExecTime = nil
      completed[node] = true

      -- alguma outra tarefa depende da execucao deste no para executar?
      if dependents[node] then
         local dependentsFromNode = dependents[node]

         local i, len = 0, #dependentsFromNode-1
         while i <= len do
            i = i + 1
            local dependent = dependentsFromNode[i]
            if scheduled[dependent] then
               local allDependenciesCompleted = true
               for otherNode,_ in pairs(dependent.Depends) do
                  if completed[otherNode] ~= true then
                     allDependenciesCompleted = false
                     break
                  end
               end
   
               if allDependenciesCompleted then
                  scheduled[dependent] = nil
                  dependent.LastExecTime = 0
                  dependent.Thread = coroutine.create(execTask)
                  table.insert(runningNodes, dependent)
               end
            end
         end
      end
   end

   if #rootNodes > 0 then
      local i, len = 0, #rootNodes-1
      while i <= len do
         i = i + 1
         local node = rootNodes[i]
         scheduled[node] = nil
         node.LastExecTime = 0
         node.Thread = coroutine.create(execTask)
         table.insert(runningNodes, node)
      end

      local scheduler
      scheduler = {
         Resume = function(maxExecTime)

            -- orders the threads, executing the ones with the least execution time first this prevents long tasks 
            -- from taking up all the processing time
            table.sort(runningNodes, function(nodeA, nodeB)
               return nodeA.LastExecTime < nodeB.LastExecTime
            end)

            local totalTime = 0

            -- https://github.com/wahern/cqueues/issues/231#issuecomment-562838785
            local i, len = 0, #runningNodes-1
            while i <= len do
               i = i + 1
               local node = runningNodes[i]

               if node.Thread ~= nil then
                  local execTime = os.clock()
                  node.LastExecTime = execTime
   
                  coroutine.resume(node.Thread, node, Time, world, onComplete)
   
                  totalTime = totalTime + (os.clock() - execTime)
   
                  if (totalTime > maxExecTime) then
                     break
                  end
               end
            end

            -- remove completed
            for i,node in ipairs(runningNodes) do
               if node.Thread == nil then                  
                  local idx = table.find(runningNodes, node)
                  if idx ~= nil then
                     table.remove(runningNodes, idx)
                  end
               end
            end

            local hasMore = #runningNodes > 0
   
            if (not hasMore) then
               local idx = table.find(self._schedulers, scheduler)
               if idx ~= nil then
                  table.remove(self._schedulers, idx)
               end
            end

            return totalTime, hasMore
         end
      }

      table.insert(self._schedulers, scheduler)
   end
end

return SystemExecutor
