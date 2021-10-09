
local ExecutionPlan = {}
ExecutionPlan.__index = ExecutionPlan

function ExecutionPlan.Create(world, repository)
   return setmetatable({
      _World = world,
      _Repository = repository,
   }, ExecutionPlan)
end

--[[
   update execution plan
]]
function ExecutionPlan:Refresh(systems)
   local withUpdate = {
      render = {}
      process = {},
      transform = {},
   }

   local withUpdateOrder = {
      render = {}
      process = {},
      transform = {},
   }
   
   local withRemove = {}
   local withEnterOrExit = {}

   for k, system in pairs(systems) do
      local step, order = system.Step, system.Order
      if system.Update then
         if withUpdate[step][order] == nil then
            withUpdate[step][order] = {}
            table.insert(withUpdateOrder[step], order)
         end
         table.insert(withUpdate[step][order], system)
      end

      if (system.IsQuerySystem == true) then
         if (system.OnEnter ~= nil or system.OnExit ~= nil) then
            table.insert(withEnterOrExit, system)
         end
   
         if system.OnRemove ~= nil then
            table.insert(withRemove, system)
         end
      end
   end

   for _, orderList in pairs(withUpdateOrder) do
      table.sort(orderList)
   end

   self._Update = withUpdate
   self._Remove = withRemove
   self._EnterOrExit = withEnterOrExit
   self._UpdateOrder = withUpdateOrder
end

--[[

]]
function ExecutionPlan:ExecUpdate(step, Time)
   local world = self._World
   local systems = self._Update[step]
   local repository = self._Repository

   for i, order in pairs(self._UpdateOrder[step]) do
      for j, system  in pairs(systems[order]) do
         if (system.ShouldUpdate == nil or system.ShouldUpdate(Time)) then

            -- if the version of the chunk is larger than the system, it means
            -- that this chunk has already undergone a change that was not performed
            -- after the last execution of this system
            -- local dirty = chunk.Version == 0 or chunk.Version > system.Version
            local dirty = false
            
            -- increment Global System Version (GSV), before system update
            world.Version = world.Version + 1

            local hasChangeThisChunk = false
            if system:Update(Time, dirty) then
               hasChangeThisChunk = true
            end

            if hasChangeThisChunk then
               -- If any system execution informs you that it has changed data in
               -- this chunk, it then performs the versioning of the chunk
               -- chunk.Version = world.Version
            end

            -- update last system version with GSV
            system.Version = world.Version
         end
      end
   end
end

--[[

]]
function ExecutionPlan:ExecRemove(removedEntities, Time)

   local world = self._World
   local systems = self._Remove
   local entityManager = self._Repository

   -- increment Global System Version (GSV), before system update
   world.Version = world.Version + 1

   for entity, _ in pairs(removedEntities) do
      for _, system in pairs(systems) do
         -- system does not apply to the archetype of that entity
         if system.Query:Match(entity.Archetype) then
            if system:OnRemove(Time, entity) then
               -- If any system execution informs you that it has changed data in
               -- this chunk, it then performs the versioning of the chunk
               -- chunk.Version = world.Version
            end
         end
      end
   end
end

--[[

]]
function ExecutionPlan:ExecEnterOrExit(changedEntities, Time)   
   local world = self._World
   local systems = self._EnterOrExit
   local entityManager = self._Repository

   -- increment Global System Version (GSV), before system update
   world.Version = world.Version + 1

   for entity, archetypeOld in pairs(changedEntities) do
      local archetypeNew = entity.Archetype
      for j, system in pairs(systems) do

         local matchNew = system.Query:Match(archetypeNew)
         local matchOld = system.Query:Match(archetypeOld)

         if system.OnEnter ~= nil and matchNew and not matchOld then
            -- OnEnter
            if system:OnEnter(Time, entity) then
               -- If any system execution informs you that it has changed data in
               -- this chunk, it then performs the versioning of the chunk
               -- chunk.Version = world.Version
            end
         elseif system.OnExit ~= nil and matchOld and not matchNew then
            -- OnExit
            if system:OnExit(Time, entity) then
               -- If any system execution informs you that it has changed data in
               -- this chunk, it then performs the versioning of the chunk
               -- chunk.Version = world.Version
            end
         end
      end
   end
end

return ExecutionPlan
