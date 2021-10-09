--[[
   Utility library. Inspired by Lodash

   https://ramdajs.com/docs/
   https://github.com/lodash/lodash
   https://sugarjs.com/quickstart/
   https://gist.github.com/Lerg/8791431
]]

-- observable, compute, subscribe

if table.unpack == nil then
	table.unpack = unpack
end

if table.find == nil then
   --[[
      Within the given array-like table haystack, find the first occurrence of value needle, starting from index init 
      or the beginning if not provided. If the value is not found, nil is returned.

      A linear search algorithm is performed.
   ]]
   table.find = function(haystack, needle, init)
      local len = #haystack
      for i = init or 1, len, 1 do
         if haystack[i] == needle then
            return i
         end
      end

      return nil
   end
end

--======================================================================================================================
-- Function
--======================================================================================================================
local Function = {}

local function areInputsEqual(newArgs, lastArgs)
   local len = #newArgs
   if len ~= #lastArgs then
      return false
   end
   for i = 1, len do
      if newArgs[i] ~= lastArgs[i] then
         return false;
      end
   end
   -- for i,value in ipairs(newArgs) do
   --    if value ~= lastArgs[i] then
   --       return false;
   --    end
   -- end
   return true
end
Function.areInputsEqual = areInputsEqual

-- implementar logica para salvar processamento enquanto os atributos dos objetos nao sofrerem mudanca
-- @link https://github.com/alexreardon/memoize-one#custom-equality-function
local function memoize(resultFn, isEqual)
   local lastThis
   local lastArgs = {}
   local lastResult
   local calledOnce = false

   if not isEqual then
      isEqual = areInputsEqual
   end

   --  memoized
   return function(...)
      local newArgs = {...}
      if (calledOnce and isEqual(newArgs, lastArgs))  then
         return unpack(lastResult)
      end
      lastResult = { resultFn(...) }
      calledOnce = true
      lastArgs = newArgs
      return unpack(lastResult)
   end
end
Function.memoize = memoize

local NIL = {}

local function cache_get(cache, params)
   local node = cache
   local param
   for i=1, #params do
      param = params[i] or NIL
      node = node.children and node.children[param]
      if not node then 
         return nil 
      end
   end
   return node.results
end
 
 local function cache_put(cache, params, results)
   local node = cache
   local param
   for i=1, #params do
     param = params[i] or NIL
     node.children = node.children or {}
     node.children[param] = node.children[param] or {}
     node = node.children[param]
   end
   node.results = results
 end

local function memoizeCached(resultFn, cache)
   cache = cache or {}
   return function (...)
      local newArgs = {...}  
      local lastResult = cache_get(cache, newArgs)
      if not lastResult then
        lastResult = { resultFn(...) }
        cache_put(cache, newArgs, lastResult)
      end
  
      return unpack(lastResult)
    end
end
Function.memoizeCached = memoizeCached

--======================================================================================================================
-- Array
--======================================================================================================================
local Array = {}

local function isArray(value)
   return (type(value) == "table") and ((value[1] ~= nil) or (next(value, nil) == nil))
end
Array.isArray = isArray

--[[
   Creates an array of values by running each element of `array` thru `iteratee`.
   The iteratee is invoked with three arguments: (value, index, array).

   @category Array
   @param array {Array}  The array to iterate over.
   @param iteratee {Function}  The function invoked per iteration.
   @returns {Array} Returns the new mapped array.
   @example

   function square(n) {
      return n * n
   }

   map([4, 8], square)
   // => [16, 64]
]]
local function map(array, iteratee)
   local result
   if array == nil then
      result = {}
   else
      result = table.create(#array)
      for index,value in ipairs(array) do
         result[index] = iteratee(value, index, array)
      end
   end   

   return result
end
Array.map = map

local function slice(src, i)
   if i == nil then
      i = 1
   end
   local len = #src
   local dst = table.create(len - (i-1))
   table.move(src, i, len, 1, dst)
   return dst
end
Array.slice = slice

-- Ensures values are unique, removes nil values as well
local function unique(values)
   if values == nil then
      values = {}
   end

   local hash = {}
   local res  = {}
   local len  = #values
   for i = 1, len do
      local value = values[i]
      if (value ~= nil and hash[value] == nil) then
         table.insert(res, value)
         hash[value] = true
      end
   end
   table.sort(res)

   return res
end
Array.unique = unique

-- generate an identifier for a table that has only numbers
local function hash(arr)
   arr = unique(arr)
   return '_' .. table.concat(arr, '_'), arr
end
Array.hash = hash

--======================================================================================================================
-- Lang 
--======================================================================================================================
local Lang = {}

--======================================================================================================================
-- Object 
--======================================================================================================================
local Object = {}

--[[
   Assign properties from `src` to `dest`

   @param dest {table} The object to copy properties to
   @param src  {table} The object to copy properties from
   @returns {obj & props}
]]
local function assign(dest, src)
   for key,value in pairs(src) do
      dest[key] = value
   end
	return dest
end
Object.assign = assign

--[[
   Assign properties from `props` to `obj`

   @param obj     {table} The object to copy properties to
   @param props   {table[]} The object to copy properties from
   @returns {obj & props}
]]
local function assignAll(dest, ...)
   for i,props in ipairs({...}) do
      assign(dest, props)
   end
	return dest
end
Object.assignAll = assignAll

local function copyShallow(original)
	return assign({}, original)
end
Object.copyShallow = copyShallow


local function copyDeep(src)
	local copy = {}
   for k, v in pairs(src) do
      if type(v) == "table" then
         v = copyDeep(v)
      end
      copy[k] = v
   end
	
	return copy
end
Object.copyDeep = copyDeep

local function merge(dest, src)
   for k,valueSrc in pairs(src) do
      if (type(valueSrc) == "table") then
         local valueDest = dest[k]
         if (valueDest == nil or type(valueDest) ~= "table") then
            dest[k] = valueSrc
         else
            dest[k] = merge(valueDest, valueSrc)
         end
      else
         dest[k] = valueSrc
      end
   end
	return dest
end
Object.merge = merge

--[[
   Create a new object with the own properties of the first object merged with the own properties of the second object. 
   If a key exists in both objects, the value from the second object will be used.
]]
local function mergeAll(dest, ...)
   for i,src in ipairs({...}) do
      merge(dest, src)
   end
	return dest
end
Object.mergeAll = mergeAll

--[[
   Faz o merge dos atributos src com o dest
   Quando o um atributo do segundo é um "table", faz uma copia do valor
]]
local function mergeDeep(dest, src)
   for k,valueSrc in pairs(src) do
      if (type(valueSrc) == "table") then
         local valueDest = dest[k]
         if (valueDest == nil or type(valueDest) ~= "table") then
            dest[k] = copyDeep(valueSrc)
         else
            dest[k] = mergeDeep(valueDest, valueSrc)
         end
      else
         dest[k] = valueSrc
      end
   end
	return dest
end
Object.mergeDeep = mergeDeep

local function mergeDeepAll(dest, ...)
   for i,src in ipairs({...}) do
      mergeDeep(dest, src)
   end
	return dest
end
Object.mergeDeepAll = mergeDeepAll

local function mergeStyles(styles)
   return mergeDeepAll({}, table.unpack(styles))
end
Object.mergeStyles = mergeStyles



--======================================================================================================================
-- Collection 
--======================================================================================================================
local Collection = {}


--======================================================================================================================
-- Utility 
--======================================================================================================================
local Utility = {
   EMPTY_OBJ = {},
}
local Schemas = {
   Lang = Lang,
   Array = Array,
   Object = Object,
   Function = Function,
   Collection = Collection,
}

for schemaName,schema in pairs(Schemas) do
   Utility[schemaName] = schema
   for name,func in pairs(schema) do
      Utility[name] = func
   end
end

return Utility
