local Timer = require("Timer")
local Event = require("Event")
local Entity = require("Entity")
local Archetype = require("Archetype")
local SystemExecutor = require("SystemExecutor")
local EntityRepository = require("EntityRepository")

local World = {}
World.__index = World

--[[  
   @param systemClasses {SystemClass[]}
   @param frequency {number} (Optional)
   @param disableAutoUpdate {bool} (Optional)
]]
function World.New(systemClasses, frequency, disableAutoUpdate)   
   local world = setmetatable({
      Version = 0,
      MaxScheduleExecTimePercent = 0.7,
      _Dirty = false, -- True when create/remove entity, add/remove entity component (change archetype)
      _Timer = Timer.New(frequency),
      _Systems = {}, -- systems in this world
      _Repository = EntityRepository.New(),
      _EntitiesCreated = {}, -- created during the execution of the Update
      _EntitiesRemoved = {}, -- removed during execution (only removed after the last execution step)
      _EntitiesUpdated = {}, -- changed during execution (received or lost components, therefore, changed the archetype)
      _LastKnownArchetypeInstant = 0,
      _OnChangeArchetypeEvent = Event.New(),
   }, World)

   -- System execution plan
   world._Executor = SystemExecutor.New(world, {})

   world._OnChangeArchetypeEvent:Connect(function(entity, archetypeOld, archetypeNew)      
      world:_OnChangeArchetype(entity, archetypeOld, archetypeNew)
   end)

   -- add systems
   if (systemClasses ~= nil) then
      for _, systemClass in ipairs(systemClasses) do
         world:AddSystem(systemClass)
      end
   end

   if (not disableAutoUpdate and World.LoopManager) then
      world._LoopCancel = World.LoopManager.Register(world)
   end

   return world
end

--[[
   Changes the frequency of execution of the "process" step

   @param frequency {number}
]]
function World:SetFrequency(frequency) 
   frequency = self._Timer:SetFrequency(frequency) 

   -- 60FPS = ((1000/60/1000)*0.7)/3 = 0.0038888888888888883
   -- 30FPS = ((1000/30/1000)*0.7)/3 = 0.007777777777777777
   self.MaxScheduleExecTime = (self._Timer.Time.DeltaFixed * (self.MaxScheduleExecTimePercent or 0.7))/3
end

--[[
   Get the frequency of execution of the "process" step

   @return number
]]
function World:GetFrequency(frequency) 
   return self._Timer.Frequency
end

--[[
   Add a new system to the world

   @param systemClass {SystemClass}
   @param order {number}
   @param config {Object}
]]
function World:AddSystem(systemClass, config)
   if systemClass then
      if config == nil then
         config = {}
      end
     
      if self._Systems[systemClass] == nil then
         self._Systems[systemClass] = systemClass.New(self, config)
         self._Executor = SystemExecutor.New(self, self._Systems)
      end
   end
end

--[[
   Create a new entity

   @param args {Component[]}
]]
function World:Entity(...)
   local entity = Entity.New(self._OnChangeArchetypeEvent, {...})

   self._Dirty = true
   self._EntitiesCreated[entity] = true
   
   entity.Version = self.Version -- update entity version using current Global System Version (GSV)
   entity._IsAlive = false

   return entity
end

--[[
   Removing a entity at runtime

   @param entity {Entity}
]]
function World:Remove(entity)

   if self._EntitiesRemoved[entity] == true then
      return
   end

   if self._EntitiesCreated[entity] == true then
      self._EntitiesCreated[entity] = nil
   else
      self._Repository:Remove(entity)
      self._EntitiesRemoved[entity] = true

      if self._EntitiesUpdated[entity] == nil then
         self._EntitiesUpdated[entity] = entity.Archetype
      end
   end

   self._Dirty = true
   entity._IsAlive = false
end

--[[
   Run a query in this world

   @param query {Query|QueryBuilder}
   @return QueryResult
]]
function World:Exec(query)
   if (query.IsQueryBuilder) then
      query = query.Build()
   end

   return self._Repository:Query(query)
end

--[[
   Execute world update

   @param step {"process"|"transform"|"render"}
   @param now {number}
]]
function World:Update(step, now)

   --[[
      .-------------------------------------.
      |----- process|transform|render ------| 
      |                  |                  |
      | s:ShouldUpdate() | <                |
      | s:Update()       |     s:OnRemove() |
      |                  |     s:OnExit()   |
      |                  |     s:OnEnter()  |
      |                  | >{0...n}         |
      |                  |                  |
      '-------------------------------------'
   ]]
   
   self._Timer:Update(now, step, function(Time)
      if step == 'process' then
         self._Executor:ScheduleTasks(Time)
         self._Executor:ExecProcess(Time)
      elseif step == 'transform' then
         self._Executor:ExecTransform(Time)
      else
         self._Executor:ExecRender(Time)
      end

      -- run suspended Tasks
      self._Executor:ExecTasks(self.MaxScheduleExecTime)

      -- cleans up after running scripts
      while self._Dirty do
         self._Dirty = false
      
         -- 1: remove entities
         local entitiesRemoved = {}
         for entity,_ in pairs(self._EntitiesRemoved) do
            entitiesRemoved[entity] = self._EntitiesUpdated[entity]
            self._EntitiesUpdated[entity] = nil
         end
         self._EntitiesRemoved = {}
         self._Executor:ExecOnRemove(Time, entitiesRemoved)
         entitiesRemoved = nil
      
         local changed = {}
         local hasChange = false
      
         -- 2: Update entities in memory
         for entity, archetypeOld in pairs(self._EntitiesUpdated) do
            if (archetypeOld ~= entity.Archetype) then
               hasChange = true
               changed[entity] = archetypeOld
            end
         end
         self._EntitiesUpdated = {}
      
         -- 3: Add new entities
         for entity, _ in pairs(self._EntitiesCreated) do
            hasChange = true
            changed[entity] = Archetype.EMPTY
      
            entity._IsAlive = true
            self._Repository:Insert(entity) 
         end
         self._EntitiesCreated = {}
      
         if hasChange then
            self._Executor:ExecOnExitEnter(Time, changed)
            changed = nil
         end
      end
   end)
end

--[[
   Remove all entities and systems
]]
function World:Destroy()

   if self._LoopCancel then
      self._LoopCancel()
      self._LoopCancel = nil
   end

   if self._OnChangeArchetypeEvent then
      self._OnChangeArchetypeEvent:Destroy()
      self._OnChangeArchetypeEvent = nil
   end

   self._Repository = nil

   if self._Systems then
      for _,system in pairs(self._Systems) do
         system:Destroy()
      end
      self._Systems = nil
   end
   
   self._Timer = nil
   self._ExecPlan = nil
   self._EntitiesCreated = nil
   self._EntitiesUpdated = nil
   self._EntitiesRemoved = nil

   setmetatable(self, nil)
end

function World:_OnChangeArchetype(entity, archetypeOld, archetypeNew)
   if entity._IsAlive then

      if self._EntitiesUpdated[entity] == nil then
         self._Dirty = true
         self._EntitiesUpdated[entity] = archetypeOld
      end
   
      self._Repository:Update(entity)

      -- update entity version using current Global System Version (GSV)
      entity.Version = self.Version
   end
end

return World
