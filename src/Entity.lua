--[[
   Identifies an entity.

   The entity is a fundamental part of the Entity Component System. Everything in your game that has data or an 
   identity of its own is an entity. However, an entity does not contain either data or behavior itself. Instead, 
   the data is stored in the components and the behavior is provided by the systems that process those components. 
   The entity acts as an identifier or key to the data stored in components.

   Entities are managed by the EntityManager class and exist within a World. An Entity struct refers to an entity, but 
   is not a reference. Rather the Entity struct contains an Index used to access entity data and a Version used to 
   check whether the Index is still valid. Note that you generally do not use the Index or Version values directly, 
   but instead pass the Entity struct to the relevant API methods.

   Pass an Entity struct to methods of the EntityManager, the EntityCommandBuffer, or the ComponentSystem in order to 
   add or remove components, to access components, or to destroy the entity.

   local entity = world:Entity(comp1, comp2, ...)
   local entity = Entity.New(world, onChange, comp1, comp2, ...)


]]

local Archetype = require("Archetype")

local SEQ  = 0

--[[
   [GET]

   01) comp1 = entity[CompType1]
   02) comp1 = entity:Get(CompType1)
   03) comps = entity[{CompType1, CompType2, ...}]
   04) comps = entity:Get({CompType1, CompType2, ...})
]]
local function getComponent(entity, cType)

   if (cType.IsCType == true) then
      -- 01) comp1 = entity[CompType1]
      -- 02) comp1 = entity:Get(CompType1)
      return entity._Data[cType]
   end
   
   -- 03) comps = entity[{CompType1, CompType2, ...}]
   -- 04) comps = entity:Get({CompType1, CompType2, ...})
   local cTypes = cType
   local components = {}
   local data = entity._Data
   
   for i,cType in ipairs(cTypes) do
      local component = data[cType]
      if component then
         table.insert(components, component)
      end
   end

   return components
end

--[[
   [SET]

   01) entity:Set(comp1)
   02) entity[CompType1] = nil
   03) entity:Set(CompType1, nil)   
   04) entity[CompType1] = value
   05) entity:Set(CompType1, value)
   06) entity:Set({comp1, comp2, ...})
   07) entity[{CompType1, CompType2, ...}] = nil
   08) entity:Set({CompType1, CompType2, ...}, nil)
   09) entity[{CompType1, CompType2, ...}] = {value1, value2, ...}
   10) entity:Set({CompType1, CompType2, ...}, {value1, value2, ...})
   11) entity[{CompType1, CompType2, ...}] = {nil, value2, ...}
   12) entity:Set({CompType1, CompType2, ...}, {nil, value2, ...})
]]
local function setComponent(self, cType, value)

   local data = self._Data
   local archetypeOld = self.Archetype
   local archetypeNew = archetypeOld

   if cType.IsComponent then
      -- 01) entity:Set(comp1)
      local component = cType
      cType = component:GetType()
      data[cType] = component
      archetypeNew = archetypeNew:With(cType)

   elseif cType.IsCType then
      if (value == nil) then
         -- 02) entity[CompType1] = nil
         -- 03) entity:Set(CompType1, nil)  
         data[cType] = nil
         archetypeNew = archetypeNew:Without(cType)

      else
         -- 04) entity[CompType1] = value
         -- 05) entity:Set(CompType1, value)
         if (value.IsComponent) then
            cType = value:GetType()
            data[cType] = value
         else
            data[cType] = cType(value)
         end
         archetypeNew = archetypeNew:With(cType)

      end
   elseif #cType > 0 then
      local first = cType[1]
      if first.IsComponent then
         -- 06) entity:Set({comp1, comp2, ...})
         for _,component in ipairs(cType) do
            if (component.IsComponent) then
               cType = component:GetType()
               data[cType] = component
               archetypeNew = archetypeNew:With(cType)
            end
         end
      else
         local cTypes = cType
         local values = value
         if (values == nil) then
            -- 07) entity[{CompType1, CompType2, ...}] = nil
            -- 08) entity:Set({CompType1, CompType2, ...}, nil)
            values = {}
         end

         -- 09) entity[{CompType1, CompType2, ...}] = {value1, value2, ...}
         -- 10) entity:Set({CompType1, CompType2, ...}, {value1, value2, ...})
         for i,cType in ipairs(cTypes) do
            if (cType.IsCType) then
               local component = values[i]
               if component == nil then
                  -- 11) entity[{CompType1, CompType2, ...}] = {nil, value2, ...}
                  -- 12) entity:Set({CompType1, CompType2, ...}, {nil, value2, ...})
                  data[cType] = nil
                  archetypeNew = archetypeNew:Without(cType)

               elseif (component.IsComponent) then
                  cType = component:GetType()                     
                  data[cType] = component
                  archetypeNew = archetypeNew:With(cType)

               else
                  data[cType] = cType(component)
                  archetypeNew = archetypeNew:With(cType)

               end
            end
         end
      end
   end

   if (archetypeOld ~= archetypeNew) then
      self.Archetype = archetypeNew
      self._OnChange:Fire(self, archetypeOld)
   end
end

--[[
   [UNSET]

   01) enity:Unset(comp1)
   02) entity[CompType1] = nil
   03) enity:Unset(CompType1)
   04) enity:Unset({comp1, comp1, ...})
   05) enity:Unset({CompType1, CompType2, ...})
   06) entity[{CompType1, CompType2}] = nil
]]
local function unsetComponent(self, cType)

   local data = self._Data
   local archetypeOld = self.Archetype
   local archetypeNew = archetypeOld
   
   if cType.IsComponent then
      -- 01) enity:Unset(comp1)
      local component = cType
      cType = component:GetType()                     
      data[cType] = nil
      archetypeNew = archetypeNew:Without(cType)

   elseif cType.IsCType then
      -- 02) entity[CompType1] = nil
      -- 03) enity:Unset(CompType1)
      data[cType] = nil
      archetypeNew = archetypeNew:Without(cType)

   else
      local values = cType
      for _,value in ipairs(values) do
         if value.IsComponent then
            -- 04) enity:Unset({comp1, comp1, ...})
            cType = value:GetType()  
            data[cType] = nil
            archetypeNew = archetypeNew:Without(cType)

         elseif value.IsCType then
            -- 05) enity:Unset({CompType1, CompType2, ...})
            -- 06) entity[{CompType1, CompType2}] = nil
            cType = value
            data[cType] = nil
            archetypeNew = archetypeNew:Without(cType)
         end
      end
   end

   if self.Archetype ~= archetypeNew then
      self.Archetype = archetypeNew
      self._OnChange:Fire(self, archetypeOld)
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
      if (type(key) == "table") then
         -- 01) entity[CompType1] = nil
         -- 02) entity[CompType1] = value
         -- 03) entity[{CompType1, CompType2, ...}] = nil
         -- 04) entity[{CompType1, CompType2, ...}] = {value1, value2, ...}
         -- 05) entity[{CompType1, CompType2, ...}] = {nil, value2, ...}
         if (key.IsCType or key.IsComponent) then
            setComponent(e, key, value)
         elseif #key > 0 then
            local first = key[1]
            if (type(first) == "table" and (first.IsCType)) then
               setComponent(e, key, value)
            else
               rawset(e, key, value)
            end
         else
            rawset(e, key, value)
         end
      else
         rawset(e, key, value)
      end
   end
}

--[[
   Creates an entity having components of the specified types.

   @param world {World}
   @param OnChangeArchetype {Event}
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
      _Data = data,
      _OnChange = onChange,
      Id = SEQ,
      IsAlive = false,
      Archetype = archetype,
      Get = getComponent,
      Set = setComponent,
      Unset = unsetComponent,
   }, Entity)
end

return Entity
