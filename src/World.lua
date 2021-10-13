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
      version = 0,
      maxScheduleExecTimePercent = 0.7,
      _dirty = false, -- True when create/remove entity, add/remove entity component (change archetype)
      _timer = Timer.New(frequency),
      _systems = {}, -- systems in this world
      _repository = EntityRepository.New(),
      _entitiesCreated = {}, -- created during the execution of the Update
      _entitiesRemoved = {}, -- removed during execution (only removed after the last execution step)
      _entitiesUpdated = {}, -- changed during execution (received or lost components, therefore, changed the archetype)
      _onChangeArchetypeEvent = Event.New(),
   }, World)

   -- System execution plan
   world._executor = SystemExecutor.New(world, {})

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
     
      if self._systems[systemClass] == nil then
         self._systems[systemClass] = systemClass.New(self, config)
         self._executor = SystemExecutor.New(self, self._systems)
      end
   end
end

--[[
   Create a new entity

   @param args {Component[]}
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
   Removing a entity at runtime

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

   return self._repository:Query(query)
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
   
   self._timer:Update(now, step, function(Time)
      if step == 'process' then
         self._executor:ScheduleTasks(Time)
         self._executor:ExecProcess(Time)
      elseif step == 'transform' then
         self._executor:ExecTransform(Time)
      else
         self._executor:ExecRender(Time)
      end

      -- 60FPS = ((1000/60/1000)*0.7)/3 = 0.0038888888888888883
      -- 30FPS = ((1000/30/1000)*0.7)/3 = 0.007777777777777777
      local maxScheduleExecTime = (Time.DeltaFixed * (self.maxScheduleExecTimePercent or 0.7))/3

      -- run suspended Tasks
      self._executor:ExecTasks(maxScheduleExecTime)

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
   end)
end

--[[
   Remove all entities and systems
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
