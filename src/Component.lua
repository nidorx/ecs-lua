local Utility = require("Utility")
local ComponentFSM = require("ComponentFSM")

local function defaultInitializer(value)
   return value or {}
end

local SEQ = 0

local Component = {}

local function createComponentClass(isTag, initializer, superClass)
   SEQ = SEQ + 1

   local ComponentClass = {
      Id = SEQ,
      IsTag = isTag,
      IsCType = true,
      -- Primary component
      SuperClass = superClass
   }
   ComponentClass.__index = ComponentClass

   if superClass == nil then
      superClass = ComponentClass
      superClass.__Qualifiers = { ["Primary"] = ComponentClass }
      superClass.__Initializers = {}
   else
      ComponentClass.IsQualifier = true
   end

   local Qualifiers = superClass.__Qualifiers

   setmetatable(ComponentClass, {
      __call = function(t, value)
         return ComponentClass.New(value)
      end,
      __index = function(t, key)
         if (key == 'States') then
            return superClass.__States       
         end
         if (key == 'Case' or key == 'StateInitial') then
            return rawget(superClass, key)       
         end
      end,
      __newindex = function(t, key, value)
         if (key == 'Case' or key == 'States' or key == 'StateInitial') then
            -- (FMS) Finite State Machine
            if ComponentClass == superClass then
               if (key == 'States') then
                  if not superClass.IsFSM then
                     ComponentFSM.AddCapability(superClass, value)
                     for _, qualifiedClass in pairs(Qualifiers) do
                        if qualifiedClass ~= superClass then
                           ComponentFSM.AddMethods(qualifiedClass, superClass)               
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
      ComponentFSM.AddMethods(ComponentClass, superClass)               
   end

   --[[
      Obtém um qualificador para esse tipo de component
   ]]
   function ComponentClass.Qualifier(qualifier)
      if type(qualifier) ~= "string" then
         for _, qualifiedClass in pairs(Qualifiers) do
            if qualifiedClass == qualifier then
               return qualifier
            end
         end
         return nil
      end

      local qualifiedClass = Qualifiers[qualifier]
      if qualifiedClass == nil then
         qualifiedClass = createComponentClass(isTag, initializer, superClass)
         Qualifiers[qualifier] = qualifiedClass
      end
      return qualifiedClass
   end

   --[[
      Get all qualified class

      @param ... {string} (Optional) filter 
   ]]
   function ComponentClass.Qualifiers(...)
      
      local qualifiers = {}

      local filter = {...}
      if #filter == 0 then
         for _, qualifiedClass in pairs(Qualifiers) do
            table.insert(qualifiers, qualifiedClass)
         end
      else
         local cTypes = {}
         for _,qualifier in ipairs({...}) do
            local qualifiedClass = ComponentClass.Qualifier(qualifier)
            if qualifiedClass and cTypes[qualifiedClass] == nil then
               cTypes[qualifiedClass] = true
               table.insert(qualifiers, qualifiedClass)
            end
         end
      end

      return qualifiers      
   end

   function ComponentClass.New(value)
      if (value ~= nil and type(value) ~= 'table') then
         -- local MyComponent = Component({ Value = Vector3.new(0, 0, 0) })
         -- local component = MyComponent(Vector3.new(10, 10, 10))
         value = { Value = value }
      end
      local component = setmetatable(initializer(value) or {}, ComponentClass)
      for _, fn in ipairs(superClass.__Initializers) do
         fn(component)
      end
      component.IsComponent = true
      component._Qualifiers = { [ComponentClass] = component }
      return component
   end

   --[[
      Obtem a classe desse component
   ]]
   function ComponentClass:GetType()
      return ComponentClass
   end

   function ComponentClass:Is(cType)
      return cType == ComponentClass or cType == superClass
   end

   -- OBTER a instancia primaria
   function ComponentClass:Primary()
      return self._Qualifiers[superClass]
   end

   function ComponentClass:Qualified(name)
      return self._Qualifiers[ComponentClass.Qualifier(name)]
   end

   function ComponentClass:QualifiedAll()
      local qualifiedAll = {}
      for name, qualifiedClass in pairs(Qualifiers) do
         qualifiedAll[name] = self._Qualifiers[qualifiedClass]
      end
      return qualifiedAll
   end

   --[[
      Faz o merge dos dados do outro componente no componente atual
   ]]
   function ComponentClass:Merge(other)
      if self == other then
         return
      end

      if self._Qualifiers == other._Qualifiers then
         return
      end

      if not other:Is(superClass) then
         return
      end

      local selfClass = ComponentClass
      local otherClass = other:GetType()

      -- alguem conhece a referencia para a entidade primaria?
      local primaryQualifiers
      if selfClass == superClass then
         primaryQualifiers = self._Qualifiers
      elseif otherClass == superClass then
         primaryQualifiers = other._Qualifiers
      elseif self._Qualifiers[superClass] ~= nil then
         primaryQualifiers = self._Qualifiers[superClass]._Qualifiers
      elseif other._Qualifiers[superClass] ~= nil then
         primaryQualifiers = other._Qualifiers[superClass]._Qualifiers
      end

      if primaryQualifiers ~= nil then
         if self._Qualifiers ~= primaryQualifiers then
            for qualifiedClass, component in pairs(self._Qualifiers) do
               if superClass ~= qualifiedClass then
                  primaryQualifiers[qualifiedClass] = component
                  component._Qualifiers = primaryQualifiers
               end
            end
         end

         if other._Qualifiers ~= primaryQualifiers then
            for qualifiedClass, component in pairs(other._Qualifiers) do
               if superClass ~= qualifiedClass then
                  primaryQualifiers[qualifiedClass] = component
                  component._Qualifiers = primaryQualifiers
               end
            end
         end
      else
         -- nenhuma das instancias conhece o Primary, usa a referencia do objeto atual
         for qualifiedClass, component in pairs(other._Qualifiers) do
            if selfClass ~= qualifiedClass then
               self._Qualifiers[qualifiedClass] = component
               component._Qualifiers = self._Qualifiers
            end
         end
      end
   end

   return ComponentClass
end

--[[
   Register a new component

   @param template {table|Function(args...) -> table}
   @param isTag {Boolean}

   @TODO: shared see https://docs.unity3d.com/Packages/com.unity.entities@0.7/manual/shared_component_data.html
   

   @TODO: Componentes tem significado.
      Position = Vector3
      Velocity = Vector3

      Os tipos de dados sao os mesmos, mas o significado é outro


   [Qualifier]
      @TODO: Adicionar Qualificadores para Componentes (@Qualifier). Permite a definicao de um componente especializado 
      resolvendo o problema de uma entidade ter varios qualificadores
         local HealthBuff = ECS.Component({ Percent = 10 })
         local HealthBuffMission = HealthBuff.Qualifier("Mission")

         local allQualifiers = HealthBuff.Qualifiers()

         ECS.Query.All({HealthBuff}) --> {HealthBuff, HealthBuffMission}
         ECS.Query.All({HealthBuffMission}) --> {HealthBuffMission}

         entity[HealthBuff|HealthBuffMission] --> component
         entity:Get(HealthBuff|HealthBuffMission) --> component
         component.Percent = 1

         component:Primary().Time = 2
         component:Qualified("Primary") --> component
         component:Qualified("Mission") --> component
         component:QualifiedAll() --> { ["Primary"] = component, ["Mission"] = component }


         [SYSTEM]
            function Update()
               local healthBuff = 0
               local buffers = entity[HealthBuff]:QualifiedAll()
               for ctype, component in pairs(buffers) do
                  healthBuff = healthBuff + component.Percent
               end
               print(healthBuff)
            end

         https://ajmmertens.medium.com/doing-a-lot-with-a-little-ecs-identifiers-25a72bd2647

   [@TODO: Serializaton]
      entity:Serialize()
      component:Serialize()
]]
function Component.Create(template, isTag)

   if template == true then
      isTag = true
      template = nil
   end

   if isTag == nil then
      isTag = false
   elseif isTag then
      template = nil
   end

   local initializer = defaultInitializer

   if template ~= nil then
      local ttype = type(template)
      if (ttype == 'function') then
         initializer = template
      else
         if (ttype ~= 'table') then
            template = { Value = template }
         end

         initializer = function(value)
            local data = Utility.copyDeep(template)
            if (value ~= nil) then
               Utility.mergeDeep(data, value)
            end
            return data
         end
      end
   end

   local Qualifiers = {}
   
   SEQ = SEQ + 1

   local ComponentClass = createComponentClass(isTag, initializer, nil)
   return ComponentClass
end

return Component
