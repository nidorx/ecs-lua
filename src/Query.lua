
local Utility = require("Utility")
local QueryResult = require("QueryResult")

local hash = Utility.hash
local unique = Utility.unique

--[[
   Global cache result.

   The validated components are always the same (reference in memory, except within the archetypes),
   in this way, you can save the result of a query in an archetype, reducing the overall execution
   time (since we don't need to iterate all the time)

   @Type { [key:Array<number>] : { matchAll,matchAny,None: {[key:string]:boolean} } }
]]
local CacheGlobal = {}

local Query = {}
Query.__index = Query

local function Builder()
   local builder = {
      IsBuilder = true
   }

   function builder.All(components)
      builder._All = components
      return builder
   end
   
   function builder.Any(components)
      builder._Any = components
      return builder
   end
   
   function builder.None(components)
      builder._None = components
      return builder
   end

   function builder.Build()
      return Query.Create(builder._All, builder._Any, builder._None)
   end

   return builder
end

function Query.All(components)
   return Builder().All(components)
end

function Query.Any(components)
   return Builder().Any(components)
end

function Query.None(components)
   return Builder().None(components)
end

--[[
   Generate a function responsible for performing the filter on a list of components.
   It makes use of local and global cache in order to decrease the validation time (avoids looping in runtime of systems)

   ECS.Query.All({ Movement.In("Standing") })

   @param all {ComponentType[]} All component types in this array must exist in the archetype
   @param any {ComponentType[]} At least one of the component types in this array must exist in the archetype
   @param none {ComponentType[]} None of the component types in this array can exist in the archetype

]]
local function Query.Create(all, any, none)

   if (all == nil and any == nil and none == nil) then
      error('It is necessary to define the components using the "All", "Any" or "None" parameters')
   end

   if (all ~= nil and any ~= nil) then
      error('It is not allowed to use the "All" and "Any" settings simultaneously')
   end

   if all ~= nil then
      all = unique(all)
      if table.getn(all) == 0 then
         error('You must enter at least one component id in the "All" field')
      end

   elseif any ~= nil then
      any = unique(any)
      if table.getn(any) == 0 then
         error('You must enter at least one component id in the "Any" field')
      end
   end

   if none ~= nil then
      none = unique(none)
      if table.getn(none) == 0 then
         error('You must enter at least one component id in the "None" field')
      end
   end

   local allKey, all = hash(all)
   local anyKey, any = hash(any)
   local noneKey, none = hash(none)

   -- match function
   return setmetatable({
      _cache = {}, -- local cache (L1)
      any = any,
      all = all,
      none = none,
      allKey = allKey, 
      anyKey = anyKey, 
      noneKey = noneKey,
      IsQuery = true,
   }, Query)
end

function Query:Match(archetype)

   -- cache L1
   local cache = self._cache
   
   -- check local cache
   local cacheResult = cache[archetype]
   if cacheResult == false then
      return false

   elseif cacheResult == true then
      return true
   else
      
      -- check global cache (executed by other filter instance)
      cacheResult = CacheGlobal[archetype]
      if cacheResult == nil then
         cacheResult = {
            Any = {}, 
            All = {}, 
            None = {} 
         }
         CacheGlobal[archetype] = cacheResult
      end
      
      -- check if these combinations exist in this component array
      local acceptNoneKey = self._acceptNoneKey
      if acceptNoneKey ~= '_' then

         if cacheResult.None[acceptNoneKey] then
            cache[archetype] = false
            return false
         end

         for _, v in pairs(self._acceptNone) do
            if table.find(archetype, v) then
               cache[archetype] = false
               cacheResult.None[acceptNoneKey] = true
               cacheResult.Any[acceptNoneKey] = true
               return false
            end
         end
      end

      local requireAnyKey = self._requireAnyKey
      if requireAnyKey ~= '_' then
         if cacheResult.Any[requireAnyKey] or cacheResult.All[requireAnyKey] then
            cache[archetype] = true
            return true
         end

         for _, v in pairs(self._requireAny) do
            if table.find(archetype, v) then
               cacheResult.Any[requireAnyKey] = true
               cache[archetype] = true
               return true
            end
         end
      end

      local requireAllKey = self._requireAllKey
      if requireAllKey ~= '_' then
         if cacheResult.All[requireAllKey] then
            cache[archetype] = true
            return true
         end

         local haveAll = true
         for _, v in pairs(self._requireAll) do
            if not table.find(archetype, v) then
               haveAll = false
               break
            end
         end

         if haveAll then
            cache[archetype] = true
            cacheResult.All[requireAllKey] = true
            return true
         end
      end

      cache[archetype] = false
      return false
   end
end

--[[
   Executa essa query no mundo informado

   @Return QueryResult
]]
function Query:Exec(world)
   local chunks = {}

   return QueryResult.Create(chunks)
end

return Query
