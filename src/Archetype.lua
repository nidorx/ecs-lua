
local archetypes = {}

local CACHE_WITH = {}
local CACHE_WITHOUT = {}

-- Version of the last registered archetype. Used to cache the systems execution plan
local Version = 0

--[[
   An Archetype is a unique combination of component types. The EntityRepository uses the archetype to group all 
   entities that have the same sets of components.

   An entity can change archetype fluidly over its lifespan. For example, when you add or remove components, 
   the archetype of the affected entity changes.

   An archetype object is not a container; rather it is an identifier to each unique combination of component 
   types that an application has created at run time, either directly or implicitly.

   You can create archetypes directly using ECS.Archetype.Of(Components[]). You also implicitly create archetypes 
   whenever you add or remove a component from an entity. An Archetype object is an immutable singleton; 
   creating an archetype with the same set of components, either directly or implicitly, results in the same 
   archetype.

   The ECS framework uses archetypes to group entities that have the same structure together. The ECS framework stores 
   component data in blocks of memory called chunks. A given chunk stores only entities having the same archetype. 
   You can get the Archetype object for a chunk from its Archetype property.

   Use ECS.Archetype.Of(Components[]) to get a Archetype reference.
]]
local Archetype  = {}
Archetype.__index = Archetype

--[[
   Gets the reference to an archetype from the informed components

   @param componentClasses {ComponentClass[]} Component that define this archetype
   @return Archetype
]]
function Archetype.Of(componentClasses)

   local ids = {}
   local cTypes = {}
   for _, cType in ipairs(componentClasses) do
      if (cType.IsCType and not cType.isComponent) then
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
   local id = "_" .. table.concat(ids, "_")

   if archetypes[id] == nil then
      archetypes[id] = setmetatable({
         id = id,
         _components = cTypes
      }, Archetype)
      Version = Version + 1
   end

   return archetypes[id]
end

--[[
   Get the version of archetype definitions

   @return number
]]
function Archetype.Version()
   return Version
end

--[[
   Checks whether this archetype has the informed component

   @param componentClass {ComponentClass}
   @return bool
]]
function Archetype:Has(componentClass)
   return (self._components[componentClass] == true)
end

--[[
   Gets the reference to an archetype that has the current components + the informed component

   @param componentClass {ComponentClass}
   @return Archetype
]]
function Archetype:With(componentClass)
   if self._components[componentClass] == true then
      -- component exists in that list, returns the archetype itself
      return self
   end

   local cache = CACHE_WITH[self]
   if not cache then
      cache =  {}
      CACHE_WITH[self] = cache
   end

   local other = cache[componentClass]
   if other == nil then
      local componentTs = {componentClass}
      for component,_ in pairs(self._components) do
         table.insert(componentTs, component)
      end
      other = Archetype.Of(componentTs)
      cache[componentClass] = other
   end
   return other
end

--[[
   Gets the reference to an archetype that has the current components + the informed components

   @param componentClasses {ComponentClass[]}
   @return Archetype
]]
function Archetype:WithAll(componentClasses)

   local cTypes = {}
   for component,_ in pairs(self._components) do
      table.insert(cTypes, component)
   end
   
   for _,component in ipairs(componentClasses) do
      if self._components[component] == nil then
         table.insert(cTypes, component)
      end
   end

   return Archetype.Of(cTypes)
end

--[[
   Gets the reference to an archetype that has the current components - the informed component
   
   @param componentClass {ComponentClass}
   @return Archetype
]]
function Archetype:Without(componentClass)

   if self._components[componentClass] == nil then
      -- component does not exist in this list, returns the archetype itself
      return self
   end

   local cache = CACHE_WITHOUT[self]
   if not cache then
      cache =  {}
      CACHE_WITHOUT[self] = cache
   end

   local other = cache[componentClass]
   if other == nil then      
      local componentTs = {}
      for component,_ in pairs(self._components) do
         if component ~= componentClass then
            table.insert(componentTs, component)
         end
      end
      other =  Archetype.Of(componentTs)
      cache[componentClass] = other
   end
      
   return other
end

--[[
   Gets the reference to an archetype that has the current components - the informed components

   @param componentClasses {ComponentClass[]}
   @return Archetype
]]
function Archetype:WithoutAll(componentClasses)

   local toIgnoreIdx = {}
   for _,component in ipairs(componentClasses) do
      toIgnoreIdx[component] = true
   end
   
   local cTypes = {}
   for component,_ in pairs(self._components) do
      if toIgnoreIdx[component] == nil then
         table.insert(cTypes, component)
      end
   end

   return Archetype.Of(cTypes)
end

-- Generic archetype, for entities that do not have components
Archetype.EMPTY = Archetype.Of({})

return Archetype
