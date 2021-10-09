
local function OperationFilter(predicate, value, count)
   -- newValue, acceptItem, mustContinue
   return value, (predicate(value) == true), true
end

local function OperationMap(mapper, value, count)
   -- newValue, acceptItem, mustContinue
   return mapper(value), true, true
end

local function OperationLimit(limit, value, count)
   -- newValue, acceptItem, mustContinue
   local accept = (count <= limit)
   return value, accept, accept
end

local function OperationClauseNone(clauses, value, count)
   local acceptItem = true
   for _,clause in ipairs(clauses) do
      if (clause.Filter.Function(value, clause.Filter.Config) == true) then
         acceptItem = false
         break
      end 
   end

   -- newValue, acceptItem, mustContinue
   return value, acceptItem, true
end

local function OperationClauseAll(clauses, value, count)
   local acceptItem = true
   for _,clause in ipairs(clauses) do
      if (clause.Filter.Function(value, clause.Filter.Config) == false) then
         acceptItem = false
         break
      end
   end

   -- newValue, acceptItem, mustContinue
   return value, acceptItem, true
end

local function OperationClauseAny(clauses, value, count)
   local acceptItem = false
   for _,clause in ipairs(clauses) do
      if (clause.Filter.Function(value, clause.Filter.Config) == true) then
         acceptItem = true
         break
      end
   end

   -- newValue, acceptItem, mustContinue
   return value, acceptItem, true
end

local EMPTY_OBJECT = {}

local QueryResult = {}
QueryResult.__index = QueryResult

function QueryResult.New(chunks, clauses)

   local pipeline = EMPTY_OBJECT
   if (clauses and #clauses > 0) then
      local all = {}
      local any = {}
      local none = {}

      pipeline = {}
      
      for i,clause in ipairs(clauses) do
         if clause.IsNoneFilter then
            table.insert(none, clause)
         elseif clause.IsAnyFilter then
            table.insert(any, clause)
         else
            table.insert(all, clause)
         end 
      end

      if (#none > 0) then
         table.insert(pipeline, {OperationClauseNone, none})
      end
      
      if (#all > 0) then
         table.insert(pipeline, {OperationClauseAll, all})
      end

      if (#any > 0) then
         table.insert(pipeline, {OperationClauseAny, any})
      end
     
   end

   return setmetatable({
      Chunks = chunks,
      _Pipeline = pipeline,
   }, QueryResult)
end

--[[ -------------------------------------------------------------------------------------------------------------------
   Intermediate Operations

   Intermediate operations return a new QueryResult. They are always lazy; executing an intermediate operation such as 
   QueryResult:Filter() does not actually perform any filtering, but instead creates a new QueryResult that, when traversed, 
   contains the elements of the initial QueryResult that match the given predicate. Traversal of the pipeline source 
   does not begin until the terminal operation of the pipeline is executed.
]] ---------------------------------------------------------------------------------------------------------------------

--[[
   Returns a QueryResult consisting of the elements of this QueryResult with a new pipeline operation

   @param operation {function(param, value, count) => newValue, accept, continues}
   @param param {any}
   @return the new QueryResult
]]
function QueryResult:With(operation, param)
   local pipeline = {}
   for _,operator in ipairs(self._Pipeline) do
      table.insert(pipeline, operator)
   end
   table.insert(pipeline, { operation, param })

   return setmetatable({
      Chunks = self.Chunks,
      _Pipeline = pipeline,
   }, QueryResult)
end

--[[
   Returns a QueryResult consisting of the elements of this QueryResult that match the given predicate.

   @param predicate {function(value) => bool} a predicate to apply to each element to determine if it should be included
   @return the new QueryResult
]]
function QueryResult:Filter(predicate)
   return self:With(OperationFilter, predicate)
end

--[[
   Returns a QueryResult consisting of the results of applying the given function to the elements of this QueryResult.

   @param mapper {function(value) => newValue} a function to apply to each element
   @return the new QueryResult
]]
function QueryResult:Map(mapper)
   return self:With(OperationMap, mapper)
end

--[[
   Returns a QueryResult consisting of the elements of this QueryResult, truncated to be no longer than maxSize in length.
   
   This is a short-circuiting stateful intermediate operation.

   @param mapper {function(value) => newValue} a function to apply to each element
   @return the new QueryResult
]]
function QueryResult:Limit(maxSize)
   return self:With(OperationLimit, maxSize)
end

--[[ -------------------------------------------------------------------------------------------------------------------
   Terminal Operations

   Terminal operations, such as QueryResult:ForEach or QueryResult.AllMatch, may traverse the QueryResult to produce a 
   result or a side-effect. After the terminal operation is performed, the pipeline is considered consumed, and can no 
   longer be used; if you need to traverse the same data source again, you must return to the data source to get a new 
   QueryResult.
]] ---------------------------------------------------------------------------------------------------------------------

--[[
   Returns whether any elements of this result match the provided predicate.

   @param predicate { function(Entity) => bool} a predicate to apply to elements of this result
   @returns true if any elements of the result match the provided predicate, otherwise false
]]
function QueryResult:AnyMatch(predicate)
   local anyMatch = false
   self:Run(function(value)
      if predicate(value) then
         anyMatch = true
      end
      -- break if true
      return anyMatch
   end)
   return anyMatch
end

--[[
   Returns whether all elements of this result match the provided predicate.

   @param predicate { function(Entity) => bool} a predicate to apply to elements of this result
   @returns true if either all elements of the result match the provided predicate or the result is empty, otherwise false
]]
function QueryResult:AllMatch(predicate)
   local allMatch = true
   self:Run(function(value)
      if (not predicate(value)) then
         allMatch = false
      end
      -- break if false
      return allMatch == false
   end)
   return allMatch
end

--[[
   Returns some element of the result, or nil if the result is empty.

   This is a short-circuiting terminal operation.

   The behavior of this operation is explicitly nondeterministic; it is free to select any element in the result. 
   
   Multiple invocations on the same result may not return the same value.

   @param predicate { function(Entity) => bool} a predicate to apply to elements of this result
]]
function QueryResult:FindAny()
   local out
   self:Run(function(value)
      out = value
      -- break
      return true
   end)
   return out
end

--[[
   Performs an action for each element of this QueryResult.

   This is a terminal operation.

   The behavior of this operation is explicitly nondeterministic. This operation does not guarantee to respect the 
   encounter order of the QueryResult.

   @param action {function(value) => bool} A action to perform on the elements, breaks execution case returns true
]]
function QueryResult:ForEach(action)
   self:Run(function(value)
      return action(value) == true
   end)
end

--[[
   Returns an array containing the elements of this QueryResult.

   This is a terminal operation.
]]
function QueryResult:ToArray()
   local array = {}
   self:Run(function(value)
      table.insert(array, value)
   end)
   return array
end

--[[
   Pipeline this QueryResult, applying callback to each value

   @param callback {function(value, count) => bool} Break execution case returns true
]]
function QueryResult:Run(callback)
   local count = 1
   local pipeline = self._Pipeline

   local hasPipeline = #pipeline > 0 
   if (not hasPipeline) then
      -- faster
      for _, entities in ipairs(self.Chunks) do
         for entity, _ in pairs(entities) do
            if (callback(entity, count) == true) then
               return
            end
            count = count + 1  
         end
      end
   else
      for i, entities in ipairs(self.Chunks) do
         for entity,_ in pairs(entities) do
            local mustStop = false
            local itemAccepted = true

            local value = entity
            if (itemAccepted and hasPipeline) then               
               for _, operator in ipairs(pipeline) do
                  local newValue, acceptItem, canContinue = operator[1](operator[2], value, count)
                  if (not canContinue) then
                     mustStop = true
                  end
   
                  if acceptItem then
                     value = newValue
                  else
                     itemAccepted = false
                     break
                  end
               end
            end
            
            if itemAccepted then
               if (callback(value, count) == true) then
                  return
               end
               count = count + 1
            end
   
            if mustStop then
               return
            end
         end
      end
   end
end

return QueryResult