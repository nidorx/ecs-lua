local Event = require("Event")

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
      _archetypes = {},
      _entitiesArchetype = {},
      
   }, EntityRepository)
end

--[[
   Insert an entity into this repository

   @param entity {Entity}
]]
function EntityRepository:Insert(entity)
   if (self._entitiesArchetype[entity] == nil) then
      local archetype = entity.archetype
      local storage = self._archetypes[archetype]
      if (storage == nil) then
         storage = { count = 0, entities = {} }
         self._archetypes[archetype] = storage
      end
   
      storage.entities[entity] = true
      storage.count = storage.count + 1
      
      self._entitiesArchetype[entity] = archetype
   else
      self:Update(entity)
   end
end

--[[
   Remove an entity from this repository

   @param entity {Entity}
]]
function EntityRepository:Remove(entity)
   local archetypeOld = self._entitiesArchetype[entity]
   if archetypeOld == nil then
      return
   end
   self._entitiesArchetype[entity] = nil

   local storage = self._archetypes[archetypeOld]
   if (storage ~= nil and storage.entities[entity] == true) then
      storage.entities[entity] = nil
      storage.count = storage.count - 1
      if (storage.count == 0) then
         self._archetypes[archetypeOld] = nil
      end
   end
end

--[[
   Updates the entity in the repository, if necessary, moves the entity from one storage to another

   @param entity {Entity}
]]
function EntityRepository:Update(entity)
   local archetypeOld = self._entitiesArchetype[entity]
   if (archetypeOld == nil or archetypeOld == entity.archetype) then
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
   for archetype, storage in pairs(self._archetypes) do
      if query:Match(archetype) then
         table.insert(chunks, storage.entities)
      end
   end
   return query:Result(chunks), #chunks > 0
end

--[[
   Quick check to find out if a query is applicable.

   @param query {Query}
   @return bool
]]
function EntityRepository:FastCheck(query)
   for archetype, storage in pairs(self._archetypes) do
      if query:Match(archetype) then
         return true
      end
   end
   return false
end

return EntityRepository
