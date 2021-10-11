--[[
   Utility library.
]]
local Utility = {}

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
Utility.copyDeep = copyDeep

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
Utility.mergeDeep = mergeDeep

return Utility
