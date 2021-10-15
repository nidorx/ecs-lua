local Utility = require("Utility")
local ComponentFSM = require("ComponentFSM")

local copyDeep = Utility.copyDeep
local mergeDeep = Utility.mergeDeep

local CLASS_SEQ = 0

--[[
   @param initializer {function(table) => table}
   @param superClass {ComponentClass}
   @return ComponentClass
]]
local function createComponentClass(initializer, superClass)
   CLASS_SEQ = CLASS_SEQ + 1

   local ComponentClass = {
      Id = CLASS_SEQ,
      IsCType = true,
      -- Primary component
      SuperClass = superClass
   }
   ComponentClass.__index = ComponentClass

   if superClass == nil then
      superClass = ComponentClass
      superClass._Qualifiers = { ["Primary"] = ComponentClass }
      superClass._QualifiersArr = { ComponentClass }
      superClass._Initializers = {}
   else
      superClass.HasQualifier = true
      ComponentClass.IsQualifier = true
      ComponentClass.HasQualifier = true
   end

   local Qualifiers = superClass._Qualifiers
   local QualifiersArr = superClass._QualifiersArr

   setmetatable(ComponentClass, {
      __call = function(t, value)
         return ComponentClass.New(value)
      end,
      __index = function(t, key)
         if (key == "States") then
            return superClass.__States       
         end
         if (key == "Case" or key == "StateInitial") then
            return rawget(superClass, key)       
         end
      end,
      __newindex = function(t, key, value)
         if (key == "Case" or key == "States" or key == "StateInitial") then
            -- (FMS) Finite State Machine
            if ComponentClass == superClass then
               if (key == "States") then
                  if not superClass.IsFSM then
                     ComponentFSM.AddCapability(superClass, value)
                     for _, qualifiedClass in pairs(Qualifiers) do
                        if qualifiedClass ~= superClass then
                           ComponentFSM.AddMethods(superClass, qualifiedClass)               
                        end
                     end
                  end
               else
                  rawset(t, key, value)
               end
            end
         else
            rawset(t, key, value)
         end
      end
   })

   if superClass.IsFSM then
      ComponentFSM.AddMethods(superClass, ComponentClass)               
   end

   --[[
      Gets a qualifier for this type of component. If the qualifier does not exist, a new class will be created, 
      otherwise it brings the already registered class qualifier reference with the same name.

      @param qualifier {string|ComponentClass}
      @return ComponentClass
   ]]
   function ComponentClass.Qualifier(qualifier)
      if type(qualifier) ~= "string" then
         for _, qualifiedClass in ipairs(QualifiersArr) do
            if qualifiedClass == qualifier then
               return qualifier
            end
         end
         return nil
      end

      local qualifiedClass = Qualifiers[qualifier]
      if qualifiedClass == nil then
         qualifiedClass = createComponentClass(initializer, superClass)
         Qualifiers[qualifier] = qualifiedClass
         table.insert(QualifiersArr, qualifiedClass)
      end
      return qualifiedClass
   end

   --[[
      Get all qualified class

      @param ... {string|ComponentClass} (Optional) Allows to filter the specific qualifiers
      @return ComponentClass[]
   ]]
   function ComponentClass.Qualifiers(...)
      local filter = {...}
      if #filter == 0 then
         return QualifiersArr
      else
         local qualifiers = {}
         local cTypes = {}
         for _,qualifier in ipairs({...}) do
            local qualifiedClass = ComponentClass.Qualifier(qualifier)
            if qualifiedClass and cTypes[qualifiedClass] == nil then
               cTypes[qualifiedClass] = true
               table.insert(qualifiers, qualifiedClass)
            end
         end
         return qualifiers      
      end
   end

   --[[
      Constructor

      @param value {any} If the value is not a table, it will be converted to the format "{ value = value}"
      @return Component
   ]]
   function ComponentClass.New(value)
      if (value ~= nil and type(value) ~= "table") then
         -- local MyComponent = Component({ value = Vector3.new(0, 0, 0) })
         -- local component = MyComponent(Vector3.new(10, 10, 10))
         value = { value = value }
      end
      local component = setmetatable(initializer(value) or {}, ComponentClass)
      for _, fn in ipairs(superClass._Initializers) do
         fn(component)
      end
      component.isComponent = true
      component._qualifiers = { [ComponentClass] = component }
      return component
   end

   --[[
      Get this component's class

      @return ComponentClass
   ]]
   function ComponentClass:GetType()
      return ComponentClass
   end

   --[[
      Check if this component is of the type informed

      @param componentClass {ComponentClass}
      @return bool
   ]]
   function ComponentClass:Is(componentClass)
      return componentClass == ComponentClass or componentClass == superClass
   end

   --[[
      Get the instance for the primary qualifier of this class

      @return Component|nil
   ]]
   function ComponentClass:Primary()
      return self._qualifiers[superClass]
   end

   --[[
      Get the instance for the given qualifier of this class

      @param name {string|ComponentClass}
      @return Component|nil
   ]]
   function ComponentClass:Qualified(qualifier)
      return self._qualifiers[ComponentClass.Qualifier(qualifier)]
   end

   --[[
      Get all instances for all qualifiers of that class

      @return Component[]
   ]]
   function ComponentClass:QualifiedAll()
      local qualifiedAll = {}
      for name, qualifiedClass in pairs(Qualifiers) do
         qualifiedAll[name] = self._qualifiers[qualifiedClass]
      end
      return qualifiedAll
   end

   --[[
      Merges data from the other component into the current component. This method should not be invoked, it is used
      by the entity to ensure correct retrieval of a component's qualifiers.

      @param other {Component}
   ]]
   function ComponentClass:Merge(other)
      if superClass.HasQualifier then
         if self == other then
            return
         end
   
         if self._qualifiers == other._qualifiers then
            return
         end
   
         if not other:Is(superClass) then
            return
         end
   
         local selfClass = ComponentClass
         local otherClass = other:GetType()
   
         -- does anyone know the reference to the primary entity?
         local primaryQualifiers
         if selfClass == superClass then
            primaryQualifiers = self._qualifiers
         elseif otherClass == superClass then
            primaryQualifiers = other._qualifiers
         elseif self._qualifiers[superClass] ~= nil then
            primaryQualifiers = self._qualifiers[superClass]._qualifiers
         elseif other._qualifiers[superClass] ~= nil then
            primaryQualifiers = other._qualifiers[superClass]._qualifiers
         end
   
         if primaryQualifiers ~= nil then
            if self._qualifiers ~= primaryQualifiers then
               for qualifiedClass, component in pairs(self._qualifiers) do
                  if superClass ~= qualifiedClass then
                     primaryQualifiers[qualifiedClass] = component
                     component._qualifiers = primaryQualifiers
                  end
               end
            end
   
            if other._qualifiers ~= primaryQualifiers then
               for qualifiedClass, component in pairs(other._qualifiers) do
                  if superClass ~= qualifiedClass then
                     primaryQualifiers[qualifiedClass] = component
                     component._qualifiers = primaryQualifiers
                  end
               end
            end
         else
            -- none of the instances know the Primary, use the current object reference
            for qualifiedClass, component in pairs(other._qualifiers) do
               if selfClass ~= qualifiedClass then
                  self._qualifiers[qualifiedClass] = component
                  component._qualifiers = self._qualifiers
               end
            end
         end
      end
   end

   --[[
      Unlink this component with the other qualifiers
   ]]
   function ComponentClass:Detach()
      if not superClass.HasQualifier then
         return
      end

      -- remove old unlink
      self._qualifiers[ComponentClass] = nil

      -- new link
      self._qualifiers = { [ComponentClass] = self }
   end

   return ComponentClass
end

local function defaultInitializer(value)
   return value or {}
end

--[[
   A Component is an object that can store data but should have not behaviour (As that should be handled by systems). 
]]
local Component = {}

--[[
   Register a new ComponentClass

   @param template {table|function(table?) -> table} 
      When `table`, this template will be used for creating component instances
      When it's a `function`, it will be invoked when a new component is instantiated. The creation parameter of the 
         component is passed to template function
      If the template type is different from `table` and `function`, **ECS Lua** will generate a template in the format 
         `{ value = template }`.
   @return ComponentClass  
]]
function Component.Create(template)

   local initializer = defaultInitializer

   if template ~= nil then
      local ttype = type(template)
      if (ttype == "function") then
         initializer = template
      else
         if (ttype ~= "table") then
            template = { value = template }
         end

         initializer = function(value)
            local data = copyDeep(template)
            if (value ~= nil) then
               mergeDeep(data, value)
            end
            return data
         end
      end
   end
   
   return createComponentClass(initializer, nil)
end

return Component
