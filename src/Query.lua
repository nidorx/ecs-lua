
local QueryResult = require("QueryResult")

--[[
   Global cache result.

   The validated components are always the same (reference in memory, except within the archetypes),
   in this way, you can save the result of a query in an archetype, reducing the overall execution
   time (since we don't need to iterate all the time)

   @type KEY string = concat(Array<ComponentClass.Id>, "_")
   @Type {
      [Archetype] = {
         Any  = { [KEY] = bool },
         All  = { [KEY] = bool },
         None = { [KEY] = bool },
      }
   }
]]
local CACHE = {}

--[[
   Interface for creating filters for existing entities in the ECS world
]]
local Query = {}
Query.__index = Query
setmetatable(Query, {
   __call = function(t, all, any, none)
      return Query.New(all, any, none)
   end,
})

local function parseFilters(list, clauseGroup, clauses)
   local indexed = {}
   local cTypes = {}
   local cTypeIds = {}
   
   for i,item in ipairs(list) do
      if (indexed[item] == nil) then
         if (item.IsCType and not item.isComponent) then
            indexed[item] = true
            table.insert(cTypes, item)
            table.insert(cTypeIds, item.Id)
         else
            -- clauses
            if item.Filter then
               indexed[item] = true
               item[clauseGroup] = true
               table.insert(clauses, item)
            end
         end
      end
   end

   if #cTypes > 0 then
      table.sort(cTypeIds)
      local cTypesKey = "_" .. table.concat(cTypeIds, "_")   
      return cTypes, cTypesKey
   end
end

--[[
   Create a new Query used to filter entities in the world. It makes use of local and global cache in order to 
   decrease the validation time (avoids looping in runtime of systems)

   @param all {Array<ComponentClass|Clause>} Optional All component types in this array must exist in the archetype
   @param any {Array<ComponentClass|Clause>} Optional At least one of the component types in this array must exist in the archetype
   @param none {Array<ComponentClass|Clause>} Optional None of the component types in this array can exist in the archetype
]]
function Query.New(all, any, none)

   -- used by QueryResult
   local clauses = {}

   local anyKey, allKey, noneKey

   if (any ~= nil) then
      any, anyKey = parseFilters(any, "IsAnyFilter", clauses)
   end

   if (all ~= nil) then
      all, allKey = parseFilters(all, "IsAllFilter", clauses)
   end

   if (none ~= nil) then
      none, noneKey = parseFilters(none, "IsNoneFilter", clauses)
   end

   return setmetatable({
      isQuery = true,
      _any = any,
      _all = all,
      _none = none,
      _anyKey = anyKey,
      _allKey = allKey,
      _noneKey = noneKey,
      _cache = {}, -- local cache (L1)
      _clauses = #clauses > 0 and clauses or nil
   }, Query)
end

--[[
   Generate a QueryResult with the chunks entered and the clauses of the current query

   @param chunks {Chunk}
   @return QueryResult
]]
function Query:Result(chunks)
   return QueryResult.New(chunks, self._clauses)
end

--[[
   Checks if the entered archetype is valid by the query definition

   @param archetype {Archetype}
   @return bool
]]
function Query:Match(archetype)

   -- cache L1
   local localCache = self._cache
   
   -- check local cache (L1)
   local cacheResult = localCache[archetype]
   if cacheResult ~= nil then
      return cacheResult
   else
      -- check global cache (executed by other filter instance)
      local globalCache = CACHE[archetype]
      if (globalCache == nil) then
         globalCache = { Any = {}, All = {}, None = {} }
         CACHE[archetype] = globalCache
      end
      
      -- check if these combinations exist in this component array

      local noneKey = self._noneKey
      if noneKey then
         local isNoneValid = globalCache.None[noneKey]
         if (isNoneValid == nil) then
            isNoneValid = true
            for _, cType in ipairs(self._none) do
               if archetype:Has(cType) then
                  isNoneValid = false
                  break
               end
            end
            globalCache.None[noneKey] = isNoneValid
         end

         if (isNoneValid == false) then
            localCache[archetype] = false
            return false
         end     
      end

      local anyKey = self._anyKey
      if anyKey then
         local isAnyValid = globalCache.Any[anyKey]
         if (isAnyValid == nil) then
            isAnyValid = false
            if (globalCache.All[anyKey] == true) then
               isAnyValid = true
            else
               for _, cType in ipairs(self._any) do
                  if archetype:Has(cType) then
                     isAnyValid = true
                     break
                  end
               end
            end
            globalCache.Any[anyKey] = isAnyValid
         end

         if (isAnyValid == false) then
            localCache[archetype] = false
            return false
         end
      end

      local allKey = self._allKey
      if allKey then
         local isAllValid = globalCache.All[allKey]
         if (isAllValid == nil) then
            local haveAll = true
            for _, cType in ipairs(self._all) do
               if (not archetype:Has(cType)) then
                  haveAll = false
                  break
               end
            end

            if haveAll then
               isAllValid = true
            else
               isAllValid = false
            end

            globalCache.All[allKey] = isAllValid
         end

         localCache[archetype] = isAllValid
         return isAllValid
      end

      -- empty query = SELECT * FROM
      localCache[archetype] = true
      return true
   end
end

local function builder()
   local builder = {
      isQueryBuilder = true
   }
   local query

   function builder.All(...)
      query = nil
      builder._all = {...}
      return builder
   end
   
   function builder.Any(...)
      query = nil
      builder._any = {...}
      return builder
   end
   
   function builder.None(...)
      query = nil
      builder._none = {...}
      return builder
   end

   function builder.Build()
      if query == nil then
         query = Query.New(builder._all, builder._any, builder._none)
      end
      return query
   end

   return builder
end

function Query.All(...)
   return builder().All(...)
end

function Query.Any(...)
   return builder().Any(...)
end

function Query.None(...)
   return builder().None(...)
end

--[[
   Create custom filters that can be used in Queries. Its execution is delayed, invoked only in QueryResult methods

   The result of executing the clause depends on how it was used in the query.

   Ex. If used in Query.All() the result is the inverse of using the same clause in Query.None()

      local Player = ECS.Component({ health = 100 })

      local HealthPlayerFilter = ECS.Query.Filter(function(entity, config)
         local player = entity[Player]
         return player.health >= config.minHealth and player.health <= config.maxHealth
      end)

      local healthyClause = HealthPlayerFilter({
         minHealth = 80,
         maxHealth = 100,
      })

      local healthyQuery = ECS.Query.All(Player, healthyClause)
      world:Exec(healthyQuery):ForEach(function(entity)
         -- this player is very healthy
      end)

      local notHealthyQuery = ECS.Query.All(Player).None(healthyClause)
      world:Exec(healthyQuery):ForEach(function(entity)
         -- this player is NOT very healthy
      end)

      local dyingClause = HealthPlayerClause({
         minHealth = 1,
         maxHealth = 20,
      })

      local dyingQuery = ECS.Query.All(Player, dyingClause)
      world:Exec(dyingQuery):ForEach(function(entity)
         -- this player is about to die
      end)

      local notDyingQuery = ECS.Query.All(Player).None(dyingClause)
      world:Exec(notDyingQuery):ForEach(function(entity)
         -- this player is NOT about to die
      end)

   @param filter {function(entity, config):bool} 
   @return function(config):Clause
]]
function Query.Filter(filter)
   return function (config)
      return {
         Filter = filter,
         Config = config
      }
   end
end

return Query
