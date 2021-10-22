--[[
   The entity is a fundamental part of the Entity Component System. Everything in your game that has data or an 
   identity of its own is an entity. However, an entity does not contain either data or behavior itself. Instead, 
   the data is stored in the components and the behavior is provided by the systems that process those components. 
]]

local Archetype = require("Archetype")

local SEQ  = 0

--[[
   [GET]
   01) comp1 = entity[CompType1]
   02) comp1 = entity:Get(CompType1)
   03) comp1, comp2, comp3 = entity:Get(CompType1, CompType2, CompType3)
]]
local function getComponent(entity, ...)

   local values = {...}
   local data = entity._data
   
   if (#values == 1) then
      local cType = values[1]
      if (cType.IsCType and not cType.isComponent) then
         -- 01) comp1 = entity[CompType1]
         -- 02) comp1 = entity:Get(CompType1)
         return data[cType]
      else
         return nil
      end
   end
   
   -- 03) comp1, comp2, comp3 = entity:Get(CompType1, CompType2, CompType3)
   local components = {}   
   for i,cType in ipairs(values) do
      if (cType.IsCType and not cType.isComponent) then         
         table.insert(components, data[cType])
      end
   end
   return table.unpack(components)
end

--[[
   Merges the qualifiers of a new added component.

   @param entity {Entity}
   @param newComponent {Component}
   @param newComponentClass {ComponentClass}
]]
local function mergeComponents(entity, newComponent, newComponentClass)
   local data = entity._data
   local otherComponent
   -- get first instance
   for _,oCType in ipairs(newComponentClass.Qualifiers()) do
      if oCType ~= newComponentClass then
         otherComponent = data[oCType]
         if otherComponent then
            break
         end
      end
   end

   if otherComponent then
      otherComponent:Merge(newComponent)
   end
end

--[[
   [SET]
   01) entity[CompType1] = nil
   02) entity[CompType1] = value
   03) entity:Set(CompType1, nil)   
   04) entity:Set(CompType1, value)
   05) entity:Set(comp1)
   06) entity:Set(comp1, comp2, ...)
]]
local function setComponent(entity, ...)

   local values = {...}
   local data = entity._data
   local archetypeOld = entity.archetype
   local archetypeNew = archetypeOld

   local toMerge = {}

   local cType = values[1]   
   if (cType and cType.IsCType and not cType.isComponent) then
      local value = values[2]
      local component
      -- 01) entity[CompType1] = nil
      -- 02) entity[CompType1] = value
      -- 03) entity:Set(CompType1, nil)   
      -- 04) entity:Set(CompType1, value)
      if value == nil then
         local old = data[cType]
         if old then
            old:Detach()
         end

         data[cType] = nil
         archetypeNew = archetypeNew:Without(cType)

      elseif (type(value) == "table" and value.isComponent) then
         local old = data[cType]         
         if (old ~= value) then
            if old then
               old:Detach()
            end

            cType = value:GetType()
            data[cType] = value
            archetypeNew = archetypeNew:With(cType)

            -- merge components
            if (cType.HasQualifier or cType.IsQualifier) then
               mergeComponents(entity, value, cType)
            end
         end
      else
         local old = data[cType]
         if old then
            old:Detach()
         end

         local component = cType(value)
         data[cType] = component
         archetypeNew = archetypeNew:With(cType)

         -- merge components
         if (cType.HasQualifier or cType.IsQualifier) then
            mergeComponents(entity, component, cType)
         end
      end
   else
      -- 05) entity:Set(comp1)
      -- 06) entity:Set(comp1, comp2, ...)
      for i,component in ipairs(values) do
         if (component.isComponent) then
            local cType = component:GetType()       
            local old = data[cType]
            if (old ~= component) then
               if old then
                  old:Detach()
               end

               data[cType] = component
               archetypeNew = archetypeNew:With(cType)
               
               -- merge components
               if (cType.HasQualifier or cType.IsQualifier) then
                  mergeComponents(entity, component, cType)
               end
            end              
         end
      end
   end

   if (archetypeOld ~= archetypeNew) then
      entity.archetype = archetypeNew
      entity._onChange:Fire(entity, archetypeOld)
   end
end

--[[
   [UNSET]
   01) enity:Unset(comp1)
   02) entity[CompType1] = nil
   03) enity:Unset(CompType1)
   04) enity:Unset(comp1, comp1, ...)
   05) enity:Unset(CompType1, CompType2, ...)
]]
local function unsetComponent(entity, ...)

   local data = entity._data
   local archetypeOld = entity.archetype
   local archetypeNew = archetypeOld

   for _,value in ipairs({...}) do
      if value.isComponent then
         -- 01) enity:Unset(comp1)
         -- 04) enity:Unset(comp1, comp1, ...)
         local cType = value:GetType()  
         local old = data[cType]
         if old then
            old:Detach()
         end
         data[cType] = nil
         archetypeNew = archetypeNew:Without(cType)
         
      elseif value.IsCType then
         -- 02) entity[CompType1] = nil
         -- 03) enity:Unset(CompType1)
         -- 05) enity:Unset(CompType1, CompType2, ...)
         local old = data[value]
         if old then
            old:Detach()
         end
         data[value] = nil
         archetypeNew = archetypeNew:Without(value)
      end
   end

   if entity.archetype ~= archetypeNew then
      entity.archetype = archetypeNew
      entity._onChange:Fire(entity, archetypeOld)
   end
end

--[[
   01) comps = entity:GetAll()
   01) qualifiers = entity:GetAll(PrimaryClass)
]]
local function getAll(entity, qualifier)
   local data = entity._data
   local components = {}
   if (qualifier ~= nil and qualifier.IsCType and not qualifier.isComponent) then
      local ctypes = qualifier.Qualifiers()
      for _,cType in ipairs(ctypes) do
         local component = data[cType]
         if component then
            table.insert(components, component)
         end
      end
   else
      for _, component in pairs(data) do
         table.insert(components, component)
      end
   end

   return components
end

--[[
   01) comp = entity:GetAny(PrimaryClass)
]]
local function getAny(entity, qualifier)
   if (qualifier ~= nil and qualifier.IsCType and not qualifier.isComponent) then
      local data = entity._data
      local ctypes = qualifier.Qualifiers()
      for _,cType in ipairs(ctypes) do
         local component = data[cType]
         if component then
            return component
         end
      end
   end
end

local Entity = {
   __index = function(e, key)
      if (type(key) == "table") then 
         -- 01) local comp1 = entity[CompType1]
         -- 01) local comps = entity[{CompType1, CompType2, ...}]
         return getComponent(e, key)
      end
   end,
   __newindex = function(e, key, value)
      local isComponentSet = true
      if (type(key) == "table" and (key.IsCType and not key.isComponent)) then
         -- 01) entity[CompType1] = nil
         -- 02) entity[CompType1] = value
         setComponent(e, key, value)
      else
         rawset(e, key, value)
      end
   end
}

--[[
   Creates an entity having components of the specified types.

   @param onChange {Event}
   @param components {Component[]} (Optional)
]]
function Entity.New(onChange, components)

   local archetype = Archetype.EMPTY
   local data = {}
   if (components ~= nil and #components > 0) then
      local cTypes = {}
      for _, component in ipairs(components) do
         local cType = component:GetType()
         table.insert(cTypes, cType)
         data[cType] = component
      end
      archetype = Archetype.Of(cTypes)
   end

   SEQ = SEQ + 1

   return setmetatable({
      _data = data,
      _onChange = onChange,
      id = SEQ,
      isAlive = false,
      archetype = archetype,
      Get = getComponent,
      Set = setComponent,
      Unset = unsetComponent,
      GetAll = getAll,
      GetAny = getAny,
   }, Entity)
end

return Entity
