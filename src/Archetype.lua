
--[[
    Archetype:
      An entity has an Archetype (defined by the components it has).
      An archetype is an identifier for each unique combination of components.
      An archetype is singleton
]]
local archetypes = {}

local CACHE_WITH = {}
local CACHE_WITHOUT = {}

-- Moment when the last archetype was recorded. Used to cache the systems execution plan
local Version = 0

--[[
   An Archetype is a unique combination of component types. The EntityManager uses the archetype to group all 
   entities that have the same sets of components.

   An entity can change archetype fluidly over its lifespan. For example, when you add or remove components, 
   the archetype of the affected entity changes.

   An archetype object is not a container; rather it is an identifier to each unique combination of component 
   types that an application has created at run time, either directly or implicitly.

   You can create archetypes directly using ECS.Archetype.Of(Components[]). You also implicitly create archetypes 
   whenever you add or remove a component from an entity. An Archetype object is an immutable singleton; 
   creating an archetype with the same set of components, either directly or implicitly, results in the same 
   archetype for a given EntityManager.

   The ECS framework uses archetypes to group entities that have the same structure together. The ECS framework stores 
   component data in blocks of memory called chunks. A given chunk stores only entities having the same archetype. 
   You can get the Archetype object for a chunk from its Archetype property.

   Use ECS.Archetype.Of(Components[]) to create Archetype values.
]]
local Archetype  = {}
Archetype.__index = Archetype

--[[
   Gets the reference to an archetype from the informed components

   @param componentTs {ComponentClass[]} Component that define this archetype
]]
function Archetype.Of(componentTs)

   local ids = {}
   local cTypes = {}
   for _, cType in ipairs(componentTs) do
      if (cType.IsCType) then
         if cType.IsQualifier then
            if cTypes[cType] == nil then    
               cTypes[cType] = true
               table.insert(ids, cType.Id)
            end
            cType = cType.SuperClass
         end
         if cTypes[cType] == nil then    
            cTypes[cType] = true
            table.insert(ids, cType.Id)
         end
      end
   end

   table.sort(ids)
   local Id = '_' .. table.concat(ids, '_')

   if archetypes[Id] == nil then
      archetypes[Id] = setmetatable({
         Id = Id,
         _Components = cTypes
      }, Archetype)
      Version = Version + 1
   end

   return archetypes[Id]
end

function Archetype.Version()
   return Version
end

--[[
   Checks whether this archetype has the informed component
]]
function Archetype:Has(component)
   -- for ct,_ in pairs(self._Components) do
   --    print(ct.Id, component.Id)
   -- end
   return (self._Components[component] == true)
end

--[[
   Gets the reference to an archetype that has the current components + the informed component
]]
function Archetype:With(cType)
   if self._Components[cType] == true then
      -- component exists in that list, returns the archetype itself
      return self
   end

   local cache = CACHE_WITH[self]
   if not cache then
      cache =  {}
      CACHE_WITH[self] = cache
   end

   local other = cache[cType]
   if other == nil then
      local componentTs = {cType}
      for component,_ in pairs(self._Components) do
         table.insert(componentTs, component)
      end
      other = Archetype.Of(componentTs)
      cache[cType] = other
   end
   return other
end

--[[
   Gets the reference to an archetype that has the current components + the informed components

   @param componentTs {ComponentClass[]}
]]
function Archetype:WithAll(componentTs)

   local cTypes = {}
   for component,_ in pairs(self._Components) do
      table.insert(cTypes, component)
   end
   
   for _,component in ipairs(componentTs) do
      if self._Components[component] == nil then
         table.insert(cTypes, component)
      end
   end

   return Archetype.Of(cTypes)
end

--[[
   Gets the reference to an archetype that has the current components - the informed component
   
   @param cType {ComponentClass}
]]
function Archetype:Without(cType)

   if self._Components[cType] == nil then
      -- component does not exist in this list, returns the archetype itself
      return self
   end

   local cache = CACHE_WITHOUT[self]
   if not cache then
      cache =  {}
      CACHE_WITHOUT[self] = cache
   end

   local other = cache[cType]
   if other == nil then      
      local componentTs = {}
      for component,_ in pairs(self._Components) do
         if component ~= cType then
            table.insert(componentTs, component)
         end
      end
      other =  Archetype.Of(componentTs)
      cache[cType] = other
   end
      
   return other
end

--[[
   Gets the reference to an archetype that has the current components - the informed components
]]
function Archetype:WithoutAll(componentTs)

   local toIgnoreIdx = {}
   for _,component in ipairs(componentTs) do
      toIgnoreIdx[component] = true
   end
   
   local cTypes = {}
   for component,_ in pairs(self._Components) do
      if toIgnoreIdx[component] == nil then
         table.insert(cTypes, component)
      end
   end

   return Archetype.Of(cTypes)
end

-- Generic archetype, for entities that do not have components
Archetype.EMPTY = Archetype.Of({})

return Archetype
