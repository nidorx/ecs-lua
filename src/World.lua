local Timer = require("Timer")
local Event = require("Event")
local Entity = require("Entity")
local Scheduler = require("Scheduler")
local Archetype = require("Archetype")
local ExecutionPlan = require("ExecutionPlan")
local EntityRepository = require("EntityRepository")

local World = {}
World.__index = World

--[[
   wordl:Serialize()
   wordl:Serialize(entity)
]]
function World.Create(systemClasses, frequency, disableAutoUpdate)   
   local world = setmetatable({
      Version = 0,
      -- systems in this world
      _Systems = {},
      -- True when environment has been modified while a system is running
      -- When create/remove entity, add/remove entity component (change archetype)
      _Dirty = false,
      _Timer = Timer.Create(frequency),
      _LastKnownArchetypeInstant = 0,
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
      _Repository = EntityRepository.New(),
      -- Entities that were created during the execution of the Update
      _EntitiesCreated = {},
      -- Entities that were removed during execution (only removed after the last execution step)
      _EntitiesRemoved = {},
      -- Entities that changed during execution (received or lost components, therefore, changed the archetype)
      _EntitiesUpdated = {},    
      _OnChangeArchetypeEvent = Event.New()
   }, World)

   -- System execution plan
   world._ExecPlan = ExecutionPlan.Create(world, world._Repository)

   -- Job system
   world._Scheduler = Scheduler.New(world)

   world._OnChangeArchetypeEvent:Connect(function(entity, archetypeOld, archetypeNew)      
      world:_OnChangeArchetype(entity, archetypeOld, archetypeNew)
   end)

   -- add systems
   if (systemClasses ~= nil) then
      for _, SystemClass in pairs(systemClasses) do
         world:addSystem(SystemClass)
      end
   end

   if (not disableAutoUpdate) then
      world._hostConn = World.Host.Create(world)
   end

   return world
end

function World:SetFrequency(frequency) 
   self._Timer:SetFrequency(frequency) 
end

function World:GetFrequency(frequency) 
   self._Timer.Frequency
end

--[[
   Add a new system to the world
]]
function World:AddSystem(systemClass, order, config)
   if systemClass == nil then
      return
   end

   if config == nil then
      config = {}
   end

   if order ~= nil and order < 0 then
      order = 50
   end   
  
   if (systemClass.Step == 'task') then
      local system = systemClass.New(self, config)
      system.Order = order
      self._Scheduler:AddSystem(system)
   else
      if self._Systems[systemClass] ~= nil then
         -- This system has already been registered in this world
         return
      end
      
      local system = systemClass.New(self, config)
      system.Order = order

      self._Systems[systemClass] = system

      -- forces re-creation of the execution plan
      self._LastKnownArchetypeVersion = 0
   end
end

--[[
   Create a new entity
]]
function World:Entity(...)
   local entity = Entity.New(self, self._OnChangeArchetypeEvent, {...})

   self._Dirty = true
   self._EntitiesCreated[entity] = true
   
   entity._IsAlive = false
   return entity
end

--[[
   Removing a entity at runtime
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

      if self._EntitiesUpdated[entity] ~= nil then
         -- was removed after update
         self._EntitiesUpdated[entity] = nil
      end
   end

   self._Dirty = true
   entity._IsAlive = false
end

--[[
   Executa uma query
]]
function World:Exec(query)
   if (query.IsBuilder) then
      query = query.Build()
   end

   return query:Exec(self._Repository)
end

--[[
   Realizes world update
]]
function World:Update(step, now)
   -- if not RunService:IsRunning() then
   --    return
   -- end

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
   
   if step ~= 'process' then
      -- need to update execution plan?
      local archetypesVersion = Archetype.Version()
      if self._LastKnownArchetypeVersion < archetypesVersion then
         self._LastKnownArchetypeVersion = archetypesVersion
         self._ExecutionPlan:Refresh(self._Systems)
      end

      self._Timer:Update(now, step, function(Time)
         self._ExecutionPlan:ExecUpdate(step, Time)

         while self._Dirty do
            self:_Clean(Time)
         end
   
         if step == 'transform' then
            self._Scheduler:Run(Time)
         end
      end)      
   else
      self._Timer:Update(now, step, function(Time)

         -- need to update execution plan?
         local archetypesVersion = Archetype.Version()
         if self._LastKnownArchetypeVersion < archetypesVersion then
            self._LastKnownArchetypeVersion = archetypesVersion
            self._ExecutionPlan:Refresh(self._Systems)
         end

         self._ExecutionPlan:ExecUpdate(step, Time, 1)

         while self._Dirty do
            self:_Clean(Time)
         end
      end)
   end
end

--[[
   Remove all entities and systems
]]
function World:Destroy()
   local self

   if self._hostConn then
      self._hostConn:Destroy()
   end

   self._OnChangeArchetypeEvent:Destroy()
   self._OnChangeArchetypeEvent = nil

   self._Scheduler:Destroy()
   self._Scheduler = nil

   self._Repository:Destroy()
   self._Repository = nil

   for _, system in ipairs(self._Systems) do
      system:Destroy()
   end
   self._Systems = nil
   
   self._Timer = nil
   self._ExecPlan = nil
   self._EntitiesCreated = nil
   self._EntitiesUpdated = nil
   self._EntitiesRemoved = nil

   setmetatable(self, nil)
end

local function World:_OnChangeArchetype(entity, archetypeOld, archetypeNew)
   if entity._IsAlive then
      -- self._EntitiesCreated[entity] = nil
      -- self._EntitiesRemoved[entity] = nil

      if self._EntitiesUpdated[entity] == nil then
         self._Dirty = true
         self._EntitiesUpdated[entity] = archetypeOld
      end
   
      self._Repository:Update(entity)
   end
end

--[[
   cleans up after running scripts
]]
local function World:_Clean(Time)
   if self._Dirty then
      self._Dirty = false
   
      -- 1: remove entities
      local entitiesRemoved = self._EntitiesRemoved
      self._EntitiesRemoved = {}
      self._ExecutionPlan:OnRemove(entitiesRemoved, Time)
      entitiesRemoved = nil
   
      local changed = {}
      local hasChange = false
   
      -- 2: Update entities in memory
      for entity, archetypeOld in pairs(self._EntitiesUpdated) do
         if archetypeOld ~= entity.Archetype then
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
         self._ExecutionPlan:ExecEnterOrExit(changed, Time)
         changed = nil
      end
   end
end

return World
