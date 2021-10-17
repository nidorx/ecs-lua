local Timer = require("Timer")
local Event = require("Event")
local Entity = require("Entity")
local Archetype = require("Archetype")
local SystemExecutor = require("SystemExecutor")
local EntityRepository = require("EntityRepository")

local World = {}
World.__index = World

--[[  
   Create a new world instance

   @param systemClasses {SystemClass[]} (Optional) Array of system classes
   @param frequency {number} (Optional) define the frequency that the `process` step will be executed. Default 30
   @param disableAutoUpdate {bool} (Optional) when `~= false`, the world automatically registers in the `LoopManager`, 
   receiving the `World:Update()` method from it. Default false
]]
function World.New(systemClasses, frequency, disableAutoUpdate)   
   local world = setmetatable({
      --[[
         Global System Version (GSV).

         Before executing the Update method of each system, the world version is incremented, so at this point, the 
         world version will always be higher than the running system version.

         Whenever an entity archetype is changed (received or lost component) the entity's version is updated to the 
         current version of the world.

         After executing the System Update method, the version of this system is updated to the current world version.

         This mechanism allows a system to know if an entity has been modified after the last execution of this same 
         system, as the entity's version is superior to the version of the last system execution. Thus, a system can 
         contain logic if it only operates on "dirty" entities, which have undergone changes. The code for this 
         validation on a system is `local isDirty = entity.version > self.version`
      ]]
      version = 0,
      --[[
         Allows you to define the maximum time that the JobSystem can operate in each frame.

         The default value is 0.011666666666666665 = ((1000/60/1000)*0.7)

         A game that runs at 30fps has 0.0333 seconds to do all the processing for each frame, including rendering
            - 30FPS = ((1000/30/1000)*0.7)/3 = 0.007777777777777777

         A game that runs at 60fps has 0.0166 seconds to do all the processing for each frame, including rendering
            - 60FPS = ((1000/60/1000)*0.7)/3 = 0.0038888888888888883
      ]]
      maxTasksExecTime = 0.013333333333333334,
      _dirty = false, -- True when create/remove entity, add/remove entity component (change archetype)
      _timer = Timer.New(frequency),
      _systems = {}, -- systems in this world
      _repository = EntityRepository.New(),
      _entitiesCreated = {}, -- created during the execution of the Update
      _entitiesRemoved = {}, -- removed during execution (only removed after the last execution step)
      _entitiesUpdated = {}, -- changed during execution (received or lost components, therefore, changed the archetype)
      _onQueryMatch = Event.New(),
      _onChangeArchetypeEvent = Event.New(),
   }, World)

   -- System execution plan
   world._executor = SystemExecutor.New(world)

   world._onChangeArchetypeEvent:Connect(function(entity, archetypeOld, archetypeNew)      
      world:_OnChangeArchetype(entity, archetypeOld, archetypeNew)
   end)

   -- add systems
   if (systemClasses ~= nil) then
      for _, systemClass in ipairs(systemClasses) do
         world:AddSystem(systemClass)
      end
   end

   if (not disableAutoUpdate and World.LoopManager) then
      world._loopCancel = World.LoopManager.Register(world)
   end

   return world
end

--[[
   Changes the frequency of execution of the "process" step

   @param frequency {number}
]]
function World:SetFrequency(frequency) 
   frequency = self._timer:SetFrequency(frequency) 
end

--[[
   Get the frequency of execution of the "process" step

   @return number
]]
function World:GetFrequency(frequency) 
   return self._timer.Frequency
end

--[[
   Add a new system to the world.

   Only one instance per type is accepted. If there is already another instance of this system in the world, any new 
   invocation of this method will be ignored.

   @param systemClass {SystemClass} The system to be added in the world
   @param config {table} (Optional) System instance configuration
]]
function World:AddSystem(systemClass, config)
   if systemClass then
      if config == nil then
         config = {}
      end
     
      if self._systems[systemClass] == nil then
         self._systems[systemClass] = systemClass.New(self, config)

         self._executor:SetSystems(self._systems)
      end
   end
end

--[[
   Create a new entity.

   The entity is created in DEAD state (entity.isAlive == false) and will only be visible for queries after the 
   cleaning step (OnRemove, OnEnter, OnExit) of the current step

   @param args {Component[]}
   @return Entity
]]
function World:Entity(...)
   local entity = Entity.New(self._onChangeArchetypeEvent, {...})

   self._dirty = true
   self._entitiesCreated[entity] = true
   
   entity.version = self.version -- update entity version using current Global System Version (GSV)
   entity.isAlive = false

   return entity
end

--[[
   Performs immediate removal of an entity.

   If the entity was created in this step and the cleanup process has not happened yet (therefore the entity is 
   inactive, entity.isAlive == false), the `OnRemove` event will never be fired.

   If the entity is alive (entity.isAlive == true), even though it is removed immediately, the `OnRemove` event will be 
   fired at the end of the current step.

   @param entity {Entity}
]]
function World:Remove(entity)

   if self._entitiesRemoved[entity] == true then
      return
   end

   if self._entitiesCreated[entity] == true then
      self._entitiesCreated[entity] = nil
   else
      self._repository:Remove(entity)
      self._entitiesRemoved[entity] = true

      if self._entitiesUpdated[entity] == nil then
         self._entitiesUpdated[entity] = entity.archetype
      end
   end

   self._dirty = true
   entity.isAlive = false
end

--[[
   Run a query in this world

   @param query {Query|QueryBuilder}
   @return QueryResult
]]
function World:Exec(query)
   if (query.isQueryBuilder) then
      query = query.Build()
   end

   local result, match = self._repository:Query(query)

   if match then
      self._onQueryMatch:Fire(query)
   end

   return result
end

--[[
   Quick check to find out if a query is applicable.

   @param query {Query|QueryBuilder}
   @return QueryResult
]]
function World:FastCheck(query)
   if (query.isQueryBuilder) then
      query = query.Build()
   end

   return self._repository:FastCheck(query)
end

--[[
   Add a callback that is reported whenever a query has been successfully executed. Used internally 
   to quickly find out if a QuerySystem will run.
]]
function World:OnQueryMatch(callback)
   return self._onQueryMatch:Connect(callback)
end

--[[
   Perform world update.

   When registered, LoopManager will invoke World Update for each step in the sequence.

   - process At the beginning of each frame
   - transform After the game engine's physics engine runs
   - render Before rendering the current frame

   @param step {"process"|"transform"|"render"}
   @param now {number} Usually os.clock()
]]
function World:Update(step, now)

   
   self._timer:Update(
      now, step,
      function(Time)
         --[[
            JobSystem
            .------------------.
            |     pipeline     |
            |------------------| 
            | s:ShouldUpdate() |
            | s:Update()       |
            '------------------'
         ]]
         if step == "process" then
            self._executor:ScheduleTasks(Time)
         end
         -- run suspended Tasks
         self._executor:ExecTasks(self.maxTasksExecTime)
      end,
      function(Time)
         --[[
            .------------------.
            |     pipeline     |
            |------------------| 
            | s:ShouldUpdate() |
            | s:Update()       |
            |                  |
            |-- CLEAR ---------|
            | s:OnRemove()     |
            | s:OnExit()       |
            | s:OnEnter()      |
            '------------------'
         ]]
         if step == "process" then
            self._executor:ExecProcess(Time)
         elseif step == "transform" then
            self._executor:ExecTransform(Time)
         else
            self._executor:ExecRender(Time)
         end

         -- cleans up after running scripts
         while self._dirty do
            self._dirty = false
         
            -- 1: remove entities
            local entitiesRemoved = {}
            for entity,_ in pairs(self._entitiesRemoved) do
               entitiesRemoved[entity] = self._entitiesUpdated[entity]
               self._entitiesUpdated[entity] = nil
            end
            self._entitiesRemoved = {}
            self._executor:ExecOnRemove(Time, entitiesRemoved)
            entitiesRemoved = nil
         
            local changed = {}
            local hasChange = false
         
            -- 2: Update entities in memory
            for entity, archetypeOld in pairs(self._entitiesUpdated) do
               if (archetypeOld ~= entity.archetype) then
                  hasChange = true
                  changed[entity] = archetypeOld
               end
            end
            self._entitiesUpdated = {}
         
            -- 3: Add new entities
            for entity, _ in pairs(self._entitiesCreated) do
               hasChange = true
               changed[entity] = Archetype.EMPTY
         
               entity.isAlive = true
               self._repository:Insert(entity) 
            end
            self._entitiesCreated = {}
         
            if hasChange then
               self._executor:ExecOnExitEnter(Time, changed)
               changed = nil
            end
         end
      end
   )
end

--[[
   Destroy this instance, removing all entities, systems and events
]]
function World:Destroy()

   if self._loopCancel then
      self._loopCancel()
      self._loopCancel = nil
   end

   if self._onChangeArchetypeEvent then
      self._onChangeArchetypeEvent:Destroy()
      self._onChangeArchetypeEvent = nil
   end

   self._repository = nil

   if self._systems then
      for _,system in pairs(self._systems) do
         system:Destroy()
      end
      self._systems = nil
   end
   
   self._timer = nil
   self._ExecPlan = nil
   self._entitiesCreated = nil
   self._entitiesUpdated = nil
   self._entitiesRemoved = nil

   setmetatable(self, nil)
end

function World:_OnChangeArchetype(entity, archetypeOld, archetypeNew)
   if entity.isAlive then

      if self._entitiesUpdated[entity] == nil then
         self._dirty = true
         self._entitiesUpdated[entity] = archetypeOld
      end
   
      self._repository:Update(entity)

      -- update entity version using current Global System Version (GSV)
      entity.version = self.version
   end
end

return World
