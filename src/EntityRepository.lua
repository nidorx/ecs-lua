
--[[
   The repository (database) of entities in a world.

   The repository indexes entities by archetype. Whenever the entity's archetype is changed, the entity is 
   transported to the correct storage.
]]
local EntityRepository = {}
EntityRepository.__index = EntityRepository

--[[
   Create a new repository

   @return EntityRepository
]]
function EntityRepository.New()
   return setmetatable({
      _Archetypes = {},
      _EntitiesArchetype = {},
   }, EntityRepository)
end

--[[
   Insert an entity into this repository

   @param entity {Entity}
]]
function EntityRepository:Insert(entity)
   if (self._EntitiesArchetype[entity] == nil) then
      local archetype = entity.Archetype
      local storage = self._Archetypes[archetype]
      if (storage == nil) then
         storage = { Count = 0, Entities = {} }
         self._Archetypes[archetype] = storage
      end
   
      storage.Entities[entity] = true
      storage.Count = storage.Count + 1
      
      self._EntitiesArchetype[entity] = archetype
   else
      self:Update(entity)
   end
end

--[[
   Remove an entity from this repository

   @param entity {Entity}
]]
function EntityRepository:Remove(entity)
   local archetypeOld = self._EntitiesArchetype[entity]
   if archetypeOld == nil then
      return
   end
   self._EntitiesArchetype[entity] = nil

   local storage = self._Archetypes[archetypeOld]
   if (storage ~= nil and storage.Entities[entity] == true) then
      storage.Entities[entity] = nil
      storage.Count = storage.Count - 1
      if (storage.Count == 0) then
         self._Archetypes[archetypeOld] = nil
      end
   end
end

--[[
   Updates the entity in the repository, if necessary, moves the entity from one storage to another

   @param entity {Entity}
]]
function EntityRepository:Update(entity)
   local archetypeOld = self._EntitiesArchetype[entity]
   if (archetypeOld == nil or archetypeOld == entity.Archetype) then
      return
   end

   self:Remove(entity)
   self:Insert(entity)
end

--[[
   Execute the query entered in this repository

   @param query {Query}
   @return QueryResult
]]
function EntityRepository:Query(query)
   local chunks = {}
   for archetype, storage in pairs(self._Archetypes) do
      if query:Match(archetype) then
         table.insert(chunks, storage.Entities)
      end
   end
   return query:Result(chunks)
end

return EntityRepository
