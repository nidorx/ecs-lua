--[[
	ECS-Lua v2.0.0 [2021-10-02 17:25]

	ECS-Lua is a tiny and easy to use ECS (Entity Component System) engine for
	game development

	This is a minified version of ECS-Lua, to see the full source code visit
	https://github.com/nidorx/roblox-ecs

	------------------------------------------------------------------------------

	MIT License

	Copyright (c) 2021 Alex Rodin

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
]]

local __M__, __F__ = {}, {}
local function __REQUIRE__(m)
   if (not __M__[m]) then
      __M__[m] = { r = __F__[m]() }
   end
   return __M__[m].r
end

__F__["Archetype"] = function()
   -- src/Archetype.lua
   
   local archetypes = {}
   
   local CACHE_WITH = {}
   local CACHE_WITHOUT = {}
   
   -- Version of the last registered archetype. Used to cache the systems execution plan
   local Version = 0
   
   --[[
      An Archetype is a unique combination of component types. The EntityManager uses the archetype to group all 
      entities that have the same sets of components.
   
      An entity can change archetype fluidly over its lifespan. For example, when you add or remove components, 
      the archetype of the affected entity changes.
   
      An archetype object is not a container; rather it is an identifier to each unique combination of component 
      types that an application has created at run time, either directly or implicitly.
   
      You can create archetypes directly using ECS.Archetype.Of(Components[]). You also implicitly create archetypes 
      whenever you add or remove a component from an entity. An Archetype object is an immutable singleton; 
      creating an archetype with the same set of components, either directly or implicitly, results in the same 
      archetype for a given EntityManager.
   
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
      local id = '_' .. table.concat(ids, '_')
   
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
   
      @param componentClasses {ComponentClass}
      @return bool
   ]]
   function Archetype:Has(componentClass)
      -- for ct,_ in pairs(self._components) do
      --    print(ct.Id, component.Id)
      -- end
      return (self._components[componentClass] == true)
   end
   
   --[[
      Gets the reference to an archetype that has the current components + the informed component
   
      @param componentClasses {ComponentClass}
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
   
end

__F__["Component"] = function()
   -- src/Component.lua
   local Utility = __REQUIRE__("Utility")
   local ComponentFSM = __REQUIRE__("ComponentFSM")
   
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
         superClass._Initializers = {}
      else
         ComponentClass.IsQualifier = true
      end
   
      local Qualifiers = superClass._Qualifiers
   
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
            for _, qualifiedClass in pairs(Qualifiers) do
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
         end
         return qualifiedClass
      end
   
      --[[
         Get all qualified class
   
         @param ... {string|ComponentClass} (Optional) filter 
         @return ComponentClass[]
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
   
      --[[
         Constructor
   
         @param value {any} If the value is not a table, it will be converted to the format "{ value = value}"
         @return Component
      ]]
      function ComponentClass.New(value)
         if (value ~= nil and type(value) ~= 'table') then
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
   
         @return bool
      ]]
      function ComponentClass:Is(cType)
         return cType == ComponentClass or cType == superClass
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
      Register a new component
   
      @param template {table|function(table?) -> table}
      @return ComponentClass  
   ]]
   function Component.Create(template)
   
      local initializer = defaultInitializer
   
      if template ~= nil then
         local ttype = type(template)
         if (ttype == 'function') then
            initializer = template
         else
            if (ttype ~= 'table') then
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
   
end

__F__["ComponentFSM"] = function()
   -- src/ComponentFSM.lua
   --[[
      Facilitate the construction and use of a Finite State Machine (FSM) using ECS
   
      Example:
         local Movement = ECS.Component({ Speed = 0 })
   
         Movement.States = {
            Standing = "*",
            Walking  = {"Standing", "Running"},
            Running  = {"Walking"}
         }
   
         Movement.StateInitial = "Standing"
   
         Movement.Case = {
            Standing = function(self, previous)
               self.Speed = 0
            end,
            Walking = function(self, previous)
               self.Speed = 5
            end,
            Running = function(self, previous)
               self.Speed = 10
            end
         }
         
         local movement = entity[Movement]
         print(movement:GetState()) -- "Standing"
         movement:SetState("Walking")
         print(movement:GetPrevState()) -- "Standing"
         movement:GetStateTime()
   
         if (movement:GetState() == "Standing") then
            movement.Speed = 0
         end
   ]]
   
   --[[
      Filter used in Query and QueryResult
   
      @see QueryResult.lua
   
      Ex. ECS.Query.All(Movement.In("Standing", "Walking"))
   ]]
   local function queryFilterCTypeStateIn(entity, config)
      local states = config.States
      local isSuperClass = config.IsSuperClass
      local componentClass = config.ComponentClass
   
      if isSuperClass then
         local qualifiers = componentClass.Qualifiers()
         for _, qualifier in ipairs(qualifiers) do
            local component = entity[qualifier]
            if (component ~= nil and states[component:GetState()] == true) then
               return true
            end
         end
         return false
      else
         local component = entity[componentClass]
         if component == nil then
            return false
         end
         return states[component:GetState()] == true
      end
   end
   
   local ComponentFSM = {}
   
   --[[
      Adds FSM capability to a ComponentClass
   
      @param superClass {ComonentClass}
      @param states { {[key=string] => string|string[]}}
   
      @see Component.lua - createComponentClass() - ComponentClass__newindex
   ]]
   function ComponentFSM.AddCapability(superClass, states)
      
      superClass.IsFSM = true
   
      local cTypeStates = setmetatable({}, {
         __newindex = function(states, newState, value)   
   
            if (type(value) ~= "table") then
               value = {value}
            end
   
            if table.find(value, '*') then
               rawset(states, newState, '*')
            else
               local idxSelf = table.find(value, newState)
               if idxSelf ~= nil then
                  table.remove(value, idxSelf)
                  if #value == 0 then
                     value = '*'
                  end
               end
               rawset(states, newState, value)
            end
         end
      })
      rawset(superClass, '__States', cTypeStates)
   
      for state,value in pairs(states) do
         if superClass.StateInitial == nil then
            superClass.StateInitial = state
         end
         cTypeStates[state] = value
      end
   
      ComponentFSM.AddMethods(superClass, superClass)
   
      table.insert(superClass._Initializers, function(component)
         component:SetState(superClass.StateInitial)
      end)
   end
   
   --[[
      Adds FSM state change methods to a ComponentClass
   
      @param superClass {ComponentClass}
      @param componentClass {ComponentClass}
   ]]
   function ComponentFSM.AddMethods(superClass, componentClass)
      local cTypeStates = superClass.States
   
      --[[
         Creates a clause used to filter repository entities in a Query or QueryResult
   
         @param ... {string[]} 
         @return Clause
   
         Ex. ECS.Query.All(Movement.In("Walking", "Running"))
      ]]
      function componentClass.In(...)
         
         local states = {}
         local count = 0
         for _,state in ipairs({...}) do
            if (cTypeStates[state] ~= nil and states[state] == nil) then
               count = count + 1
               states[state] = true
            end
         end
   
         if count == 0 then
            -- In any state
            return {
               Components = {componentClass},
            }
         end
         
         return {
            Filter = queryFilterCTypeStateIn,
            Components = { componentClass },
            Config = {
               States = states,
               IsSuperClass = (componentClass == superClass),
               ComponentClass = componentClass, 
            }
         }
      end   
   
      --[[
         Defines the current state of the FSM
   
         @param newState {string}
      ]]
      function componentClass:SetState(newState)      
         if (newState == nil or cTypeStates[newState] == nil) then
            return
         end
   
         local actual = self:GetState()
         if (actual == newState) then
            return
         end
   
         if (actual ~= nil ) then
            local transtions = cTypeStates[actual]
            if (transtions ~= '*' and table.find(transtions, newState) == nil) then
               -- not allowed
               return
            end
         end
   
         self._state = newState
         self._statePrev = actual
         self._stateTime = os.clock()
   
         local action = superClass.Case and superClass.Case[newState]
         if action then
            action(self, actual)
         end
      end
   
      --[[
         Get the current state of the FSM
   
         @return string
      ]]
      function componentClass:GetState()
         return self._state or superClass.StateInitial
      end
   
      --[[
         Get the previous state of the FSM
   
         @return string|nil
      ]]
      function componentClass:GetPrevState()
         return self._statePrev or nil
      end
   
      --[[
         Gets the time it changed to the current state
      ]]
      function componentClass:GetStateTime()
         return self._stateTime or 0
      end
   end
   
   return ComponentFSM
   
end

__F__["ECS"] = function()
   -- src/ECS.lua
   --[[
      ECS-Lua v2.0.0 [2021-10-02 17:25]
   
      Roblox-ECS is a tiny and easy to use ECS (Entity Component System) engine for
      game development on the Roblox platform
   
      https://github.com/nidorx/roblox-ecs
   
      Discussions about this script are at https://devforum.roblox.com/t/841175
   
      ------------------------------------------------------------------------------
   
      MIT License
   
      Copyright (c) 2020 Alex Rodin
   
      Permission is hereby granted, free of charge, to any person obtaining a copy
      of this software and associated documentation files (the "Software"), to deal
      in the Software without restriction, including without limitation the rights
      to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
      copies of the Software, and to permit persons to whom the Software is
      furnished to do so, subject to the following conditions:
   
      The above copyright notice and this permission notice shall be included in all
      copies or substantial portions of the Software.
   
      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
      IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
      FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
      AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
      LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
      OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
      SOFTWARE.
   ]]
   
   local Query = __REQUIRE__("Query")
   local World = __REQUIRE__("World")
   local System = __REQUIRE__("System")
   local Archetype = __REQUIRE__("Archetype")
   local Component = __REQUIRE__("Component")
   
   local function setLoopManager(manager)
      World.LoopManager = manager
   end
   
   pcall(function()
      if (game and game.ClassName == 'DataModel') then
         -- is roblox
         setLoopManager(__REQUIRE__("RobloxLoopManager")())
      end
   end)
   
   --[[
     @TODO
         - Serialize componentes
         - Server entities
         - Client - Server sincronization (snapshot, delta, spatial index, grid manhatham distance)
         - Table pool (avoid GC)
         - System readonly? Paralel execution
         - Debugging?
         - Benchmark (Local Script vs ECS implementation)
         - Basic physics (managed)
         - SharedComponent?
         - Serializaton
            - world:Serialize()
            - world:Serialize(entity)
            - entity:Serialize()
            - component:Serialize()
   ]]
   local ECS = {
      Query = Query,
      World = World.New,
      System = System.Create,
      Archetype = Archetype,
      Component = Component.Create,
      SetLoopManager = setLoopManager
   }
   
   if _G.ECS == nil then
      _G.ECS = ECS
   else
      local warn = _G.warn or print
      warn("ECS Lua was not registered in the global variables, there is already another object registered.")
   end
   
   return ECS
   
end

__F__["Entity"] = function()
   -- src/Entity.lua
   --[[
      The entity is a fundamental part of the Entity Component System. Everything in your game that has data or an 
      identity of its own is an entity. However, an entity does not contain either data or behavior itself. Instead, 
      the data is stored in the components and the behavior is provided by the systems that process those components. 
   ]]
   
   local Archetype = __REQUIRE__("Archetype")
   
   local SEQ  = 0
   
   --[[
      [GET]
   
      01) comp1 = entity[CompType1]
      02) comp1 = entity:Get(CompType1)
      03) comps = entity[{CompType1, CompType2, ...}]
      04) comps = entity:Get({CompType1, CompType2, ...})
   ]]
   local function getComponent(entity, componentClass)
   
      if (componentClass.IsCType) then
         -- 01) comp1 = entity[CompType1]
         -- 02) comp1 = entity:Get(CompType1)
         return entity._data[componentClass]
      end
      
      -- 03) comps = entity[{CompType1, CompType2, ...}]
      -- 04) comps = entity:Get({CompType1, CompType2, ...})
      local cTypes = componentClass
      local components = {}
      local data = entity._data
      
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
   
      local data = self._data
      local archetypeOld = self.archetype
      local archetypeNew = archetypeOld
   
      if cType.isComponent then
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
            if (type(value) == 'table' and value.isComponent) then
               cType = value:GetType()
               data[cType] = value
            else
               data[cType] = cType(value)
            end
            archetypeNew = archetypeNew:With(cType)
   
         end
      elseif #cType > 0 then
         local first = cType[1]
         if first.isComponent then
            -- 06) entity:Set({comp1, comp2, ...})
            for _,component in ipairs(cType) do
               if (component.isComponent) then
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
   
                  elseif (component.isComponent) then
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
         self.archetype = archetypeNew
         self._onChange:Fire(self, archetypeOld)
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
   
      local data = self._data
      local archetypeOld = self.archetype
      local archetypeNew = archetypeOld
      
      if cType.isComponent then
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
            if value.isComponent then
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
   
      if self.archetype ~= archetypeNew then
         self.archetype = archetypeNew
         self._onChange:Fire(self, archetypeOld)
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
            if (key.IsCType or key.isComponent) then
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
      }, Entity)
   end
   
   return Entity
   
end

__F__["EntityRepository"] = function()
   -- src/EntityRepository.lua
   
   --[[
      The repository (database) of entities in a world.
   
      The repository indexes entities by archetype. Whenever the entity's archetype is changed, the entity is 
      transported to the correct storage.
   ]]
   local EntityRepository = {}
   EntityRepository.__index = EntityRepository
   
   --[[
      Create a new repository
   
      @return EntityRepository
   ]]
   function EntityRepository.New()
      return setmetatable({
         _archetypes = {},
         _entitiesArchetype = {},
      }, EntityRepository)
   end
   
   --[[
      Insert an entity into this repository
   
      @param entity {Entity}
   ]]
   function EntityRepository:Insert(entity)
      if (self._entitiesArchetype[entity] == nil) then
         local archetype = entity.archetype
         local storage = self._archetypes[archetype]
         if (storage == nil) then
            storage = { Count = 0, Entities = {} }
            self._archetypes[archetype] = storage
         end
      
         storage.Entities[entity] = true
         storage.Count = storage.Count + 1
         
         self._entitiesArchetype[entity] = archetype
      else
         self:Update(entity)
      end
   end
   
   --[[
      Remove an entity from this repository
   
      @param entity {Entity}
   ]]
   function EntityRepository:Remove(entity)
      local archetypeOld = self._entitiesArchetype[entity]
      if archetypeOld == nil then
         return
      end
      self._entitiesArchetype[entity] = nil
   
      local storage = self._archetypes[archetypeOld]
      if (storage ~= nil and storage.Entities[entity] == true) then
         storage.Entities[entity] = nil
         storage.Count = storage.Count - 1
         if (storage.Count == 0) then
            self._archetypes[archetypeOld] = nil
         end
      end
   end
   
   --[[
      Updates the entity in the repository, if necessary, moves the entity from one storage to another
   
      @param entity {Entity}
   ]]
   function EntityRepository:Update(entity)
      local archetypeOld = self._entitiesArchetype[entity]
      if (archetypeOld == nil or archetypeOld == entity.archetype) then
         return
      end
   
      self:Remove(entity)
      self:Insert(entity)
   end
   
   --[[
      Execute the query entered in this repository
   
      @param query {Query}
      @return QueryResult
   ]]
   function EntityRepository:Query(query)
      local chunks = {}
      for archetype, storage in pairs(self._archetypes) do
         if query:Match(archetype) then
            table.insert(chunks, storage.Entities)
         end
      end
      return query:Result(chunks)
   end
   
   return EntityRepository
   
end

__F__["Event"] = function()
   -- src/Event.lua
   
   --[[
      Subscription
   ]]
   local Connection = {}
   Connection.__index = Connection
   
   function Connection.New(event, handler)
      return setmetatable({ _Event = event, _Handler = handler }, Connection)
   end
   
   -- Unsubscribe
   function Connection:Disconnect()
      local event = self._Event
      if (event and not event.destroyed) then
         local idx = table.find(event._handlers, self._Handler)
         if idx ~= nil then
            table.remove(event._handlers, idx)
         end
      end
      setmetatable(self, nil)
   end 
   
   --[[
      Observer Pattern
   
      Allows the application to fire events of a particular type.
   ]]
   local Event = {}
   Event.__index = Event
   
   function Event.New()
   	return setmetatable({ _handlers = {} }, Event)
   end
   
   function Event:Connect(handler)
   	if (type(handler) == "function") then
         table.insert(self._handlers, handler)
         return Connection.New(self, handler)
   	end
   
      error(("Event:Connect(%s)"):format(typeof(handler)), 2)
   end
   
   function Event:Fire(...)
   	if not self.destroyed then
         for i,handler in ipairs(self._handlers) do
            handler(table.unpack({...}))
         end
   	end
   end
   
   function Event:Destroy()
   	setmetatable(self, nil)
      self._handlers = nil
      self.destroyed = true
   end
   
   return Event
   
end

__F__["Query"] = function()
   -- src/Query.lua
   
   local QueryResult = __REQUIRE__("QueryResult")
   
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
               if item.Components then
                  indexed[item] = true   
                  for _,cType in ipairs(item.Components) do
                     if (not indexed[cType] and cType.IsCType and not cType.isComponent) then
                        indexed[cType] = true
                        table.insert(cTypes, cType)
                        table.insert(cTypeIds, item.Id)
                     end
                  end
               end   
   
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
         local cTypesKey = '_' .. table.concat(cTypeIds, '_')   
         return cTypes, cTypesKey
      end
   end
   
   --[[
      Generate a function responsible for performing the filter on a list of components.
      It makes use of local and global cache in order to decrease the validation time (avoids looping in runtime of systems)
   
      ECS.Query.All(Movement.In("Standing"))
   
      @param all {Array<ComponentClass|Clause>[]} All component types in this array must exist in the archetype
      @param any {Array<ComponentClass|Clause>[]} At least one of the component types in this array must exist in the archetype
      @param none {Array<ComponentClass|Clause>[]} None of the component types in this array can exist in the archetype
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
         _clauses = #clauses > 0 and clauses or nil,
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
   
      function builder.All(...)
         builder._all = {...}
         return builder
      end
      
      function builder.Any(...)
         builder._any = {...}
         return builder
      end
      
      function builder.None(...)
         builder._none = {...}
         return builder
      end
   
      function builder.Build()
         return Query.New(builder._all, builder._any, builder._none)
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
   
   return Query
   
end

__F__["QueryResult"] = function()
   -- src/QueryResult.lua
   
   --[[
      OperatorFunction = function(param, value, count) => newValue, acceptItem, mustContinue
   ]]
   
   local function operatorFilter(predicate, value, count)
      return value, (predicate(value) == true), true
   end
   
   local function operatorMap(mapper, value, count)
      return mapper(value), true, true
   end
   
   local function operatorLimit(limit, value, count)
      local accept = (count <= limit)
      return value, accept, accept
   end
   
   local function operatorClauseNone(clauses, value, count)
      local acceptItem = true
      for _,clause in ipairs(clauses) do
         if (clause.Filter(value, clause.Config) == true) then
            acceptItem = false
            break
         end 
      end
      return value, acceptItem, true
   end
   
   local function operatorClauseAll(clauses, value, count)
      local acceptItem = true
      for _,clause in ipairs(clauses) do
         if (clause.Filter(value, clause.Config) == false) then
            acceptItem = false
            break
         end
      end
      return value, acceptItem, true
   end
   
   local function operatorClauseAny(clauses, value, count)
      local acceptItem = false
      for _,clause in ipairs(clauses) do
         if (clause.Filter(value, clause.Config) == true) then
            acceptItem = true
            break
         end
      end
      return value, acceptItem, true
   end
   
   local EMPTY_OBJECT = {}
   
   --[[
      The result of a Query that was executed on an EntityStorage.
   
      QueryResult provides several methods to facilitate the filtering of entities resulting from the execution of the 
      query.
   ]]
   local QueryResult = {}
   QueryResult.__index = QueryResult
   
   --[[
      Build a new QueryResult
   
      @param chunks { Array<{ [Entity] = true }> }
      @clauses {Clause[]}
   
      @see Query.lua
      @see EntityRepository:Query(query)
      @return QueryResult
   ]]
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
            table.insert(pipeline, {operatorClauseNone, none})
         end
         
         if (#all > 0) then
            table.insert(pipeline, {operatorClauseAll, all})
         end
   
         if (#any > 0) then
            table.insert(pipeline, {operatorClauseAny, any})
         end
        
      end
   
      return setmetatable({
         chunks = chunks,
         _pipeline = pipeline,
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
      for _,operator in ipairs(self._pipeline) do
         table.insert(pipeline, operator)
      end
      table.insert(pipeline, { operation, param })
   
      return setmetatable({
         chunks = self.chunks,
         _pipeline = pipeline,
      }, QueryResult)
   end
   
   --[[
      Returns a QueryResult consisting of the elements of this QueryResult that match the given predicate.
   
      @param predicate {function(value) => bool} a predicate to apply to each element to determine if it should be included
      @return the new QueryResult
   ]]
   function QueryResult:Filter(predicate)
      return self:With(operatorFilter, predicate)
   end
   
   --[[
      Returns a QueryResult consisting of the results of applying the given function to the elements of this QueryResult.
   
      @param mapper {function(value) => newValue} a function to apply to each element
      @return the new QueryResult
   ]]
   function QueryResult:Map(mapper)
      return self:With(operatorMap, mapper)
   end
   
   --[[
      Returns a QueryResult consisting of the elements of this QueryResult, truncated to be no longer than maxSize in length.
      
      This is a short-circuiting stateful intermediate operation.
   
      @param mapper {function(value) => newValue} a function to apply to each element
      @return the new QueryResult
   ]]
   function QueryResult:Limit(maxSize)
      return self:With(operatorLimit, maxSize)
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
      Returns an Iterator, to use in for loop
   
      for entity, count in result:Iterator() do
         print(entity.id)
      end
   ]]
   function QueryResult:Iterator()
      local thread = coroutine.create(function()
         self:Run(function(value, count)
            -- These will be passed back again next iteration
            coroutine.yield(value, count)
         end)
      end)
   
      return function()
         local success, item, index = coroutine.resume(thread)
         return index, item
      end
   end
   
   
   --[[
      Pipeline this QueryResult, applying callback to each value
   
      @param callback {function(value, count) => bool} Break execution case returns true
   ]]
   function QueryResult:Run(callback)
      local count = 1
      local pipeline = self._pipeline
   
      local hasPipeline = #pipeline > 0 
      if (not hasPipeline) then
         -- faster
         for _, entities in ipairs(self.chunks) do
            for entity, _ in pairs(entities) do
               if (callback(entity, count) == true) then
                  return
               end
               count = count + 1  
            end
         end
      else
         for i, entities in ipairs(self.chunks) do
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
   
end

__F__["RobloxLoopManager"] = function()
   -- src/RobloxLoopManager.lua
   local function InitManager()
      local RunService = game:GetService('RunService')
      return {
         Register = function(world)         
            -- if not RunService:IsRunning() then
            --    return
            -- end
            local processConn = RunService.Stepped:Connect(function()
               world:Update('process', os.clock())
            end)
      
            local transformConn = RunService.Heartbeat:Connect(function()
               world:Update('transform', os.clock())
            end)
      
            local renderConn
            if (not RunService:IsServer()) then
               renderConn = RunService.RenderStepped:Connect(function()
                  world:Update('render', os.clock())
               end)
            end
      
            return function()
               processConn:Disconnect()
               processConn:Disconnect()
               processConn:Disconnect()
            end
         end
      }
   end
   
   return InitManager
   
end

__F__["System"] = function()
   -- src/System.lua
   
   local SYSTEM_ID_SEQ = 0
   
   local STEPS = { 'task', 'render', 'process', 'transform' }
   
   local System = {}
   
   --[[
      Allow to create new System Class Type
   
      @param step {task|process|transform|render}
      @param order {number} (Optional)
      @param query {Query|QueryConfig} (Optional)
      @param updateFn {function} (Optional)
   ]]
   function System.Create(step, order, query, updateFn)
   
      if (step == nil or not table.find(STEPS, step)) then
         error('The "step" parameter must one of ', table.concat(STEPS, ', '))
      end
   
      if type(order) == "function" then
         updateFn = order
         order = nil
      end
   
      if (order == nil or order < 0) then
         order = 50
      end
   
      if type(query) == "function" then
         updateFn = query
         query = nil
      end
   
      if (query and query.isQueryBuilder) then
         query = query.Build()
      end
   
      SYSTEM_ID_SEQ = SYSTEM_ID_SEQ + 1
   
      local Id = SYSTEM_ID_SEQ
      local SystemClass = {
         Id = Id,
         Step = step,
         -- Allows you to define the execution priority level for this system
         Order = order,
         Query = query,
         -- After = {SystemC, SystemD}, An update order that requests ECS update this system after it updates another specified system.
         -- Before = {SystemA, SystemB}, An update order that requests ECS update this system before it updates another specified system.
         --[[
            ShouldUpdate(Time): void - It allows informing if the update methods of this system should be invoked
            Update: function(Time, dirty) -> boolean -Invoked in updates, limited to the value set in the "Frequency" attribute
   
            [QuerySystem]
               OnRemove(Time, enity)
               OnExit(Time, entity) -> boolean
               OnEnter(Time, entity) -> boolean
         ]]
      }
      SystemClass.__index = SystemClass
   
      -- Cria uma instancia desse system
      function SystemClass.New(world, config)
         local system = setmetatable({
            version = 0,
            _world = world,
            _config = config,
         }, SystemClass)
   
         if system.Initialize then
            system:Initialize(config)
         end
   
         return system
      end
   
       --[[
         Get this system class
   
         @return SystemClass
      ]]
      function SystemClass:GetType()
         return SystemClass
      end
   
      function SystemClass:Result(query)
         return self._world:Exec(query or SystemClass.Query)
      end
   
      function SystemClass:Destroy() 
         if self.OnDestroy then
            self.OnDestroy()
         end
         setmetatable(self, nil)
         for k,v in pairs(self) do
            self[k] = nil
         end
      end
   
      if updateFn and type(updateFn) == "function" then
         SystemClass.Update = updateFn
      end
   
      return SystemClass
   end
   
   return System
   
end

__F__["SystemExecutor"] = function()
   -- src/SystemExecutor.lua
   
   --[[
      After = {SystemC, SystemD}, An update order that requests ECS update this system after it updates another specified system.
      Before = {SystemA, SystemB}, An update order that requests ECS update this system before it updates another specified system.
   ]]
   local function mapTaskDependencies(systems)
   
      local nodes = {}
      local nodesByType = {}
   
      for i,system in ipairs(systems) do
         local sType = system:GetType()
   
         if (system._TaskState == nil) then
            -- suspended, scheduled, running
            system._TaskState = "suspended"
         end
   
         if not nodesByType[sType] then
            local node = {
               Type = sType,
               System = system,
               -- @type {[Node]=true}
               Depends = {}
            }
            nodesByType[sType] = node
            table.insert(nodes, node)        
         end
      end
   
      for _, node in ipairs(nodes) do
          -- this system will update Before another specified system
          local before = node.Type.Before
          if (before ~= nil and #before > 0) then
             for _,sTypeOther in ipairs(before) do
                local otherNode = nodesByType[sTypeOther]
                if otherNode then
                   otherNode.Depends[node] = true
                end
             end
          end
   
         -- this system will update After another specified system
         local after = node.Type.After
         if (after ~= nil and #after > 0) then
            for _,sTypeOther in ipairs(after) do
               local otherNode = nodesByType[sTypeOther]
               if otherNode then
                  node.Depends[otherNode] = true
               end
            end
         end
      end
   
      return nodes
   end
   
   local function orderSystems(a, b)
      return a.Order < b.Order
   end
   
   --[[
      Responsible for coordinating and executing the systems methods
   ]]
   local SystemExecutor = {}
   SystemExecutor.__index = SystemExecutor
   
   function SystemExecutor.New(world, systems)   
      local onExit = {}
      local onEnter = {}
      local onRemove = {}
      -- system:Update()
      local updateTask = {}
      local updateRender = {}
      local updateProcess = {}
      local updateTransform = {}
   
      for _, system in pairs(systems) do      
         local step = system.Step
         if system.Update then
            if step == 'task' then
               table.insert(updateTask, system)
               
            elseif step == 'process' then
               table.insert(updateProcess, system) 
   
            elseif step == 'transform' then
               table.insert(updateTransform, system)
   
            elseif step == 'render' then
               table.insert(updateRender, system)
   
            end
         end
   
         if (system.Query and system.Query.isQuery and step ~= 'task') then
            if system.OnExit then
               table.insert(onExit, system)
            end
   
            if system.OnEnter then
               table.insert(onEnter, system)
            end
      
            if system.OnRemove then
               table.insert(onRemove, system)
            end
         end
      end
   
      updateTask = mapTaskDependencies(updateTask)
      
      table.sort(onExit, orderSystems)
      table.sort(onEnter, orderSystems)
      table.sort(onRemove, orderSystems)
      table.sort(updateRender, orderSystems)
      table.sort(updateProcess, orderSystems)
      table.sort(updateTransform, orderSystems)
   
      -- tasks = resolveDependecy(systems)
      return setmetatable({
         _world = world,
         _onExit = onExit,
         _onEnter = onEnter,
         _onRemove = onRemove,
         _task = updateTask,
         _render = updateRender,
         _process = updateProcess,
         _transform = updateTransform,
         _schedulers = {},
      }, SystemExecutor)
   end
   
   --[[
         
      @param Time
      @param changedEntities { { [Entity] = Old<Archetype> } }
   ]]
   function SystemExecutor:ExecOnExitEnter(Time, changedEntities)
      local isEmpty = true
   
      -- { [Old<Archetype>] = { [New<Archetype>] = {Entity, Entity, ...} } }
      local oldIndexed = {}
      for entity, archetypeOld in pairs(changedEntities) do
         local newIndexed = oldIndexed[archetypeOld]
         if not newIndexed then
            newIndexed = {}
            oldIndexed[archetypeOld] = newIndexed
         end
         local archetypeNew = entity.archetype
   
         local entities = newIndexed[archetypeNew]
         if not entities then
            entities = {}
            newIndexed[archetypeNew] = entities
         end
         table.insert(entities, entity)
         isEmpty = false
      end
      if isEmpty then
         return
      end
      self:_ExecOnEnter(Time, oldIndexed)
      self:_ExecOnExit(Time, oldIndexed)
   end
   
   --[[
      Executes the systems' OnEnter method
   
      @param Time {Time}
      @param entities {{[Key=Entity] => Archetype}}
      ]]
   function SystemExecutor:_ExecOnEnter(Time, oldIndexed)
      local world = self._world
      for _, system in ipairs(self._onEnter) do
         local query = system.Query
         for archetypeOld, newIndexed in pairs(oldIndexed) do
            if not query:Match(archetypeOld) then
               for archetypeNew, entities in pairs(newIndexed) do
                  if query:Match(archetypeNew) then
                     for i,entity in ipairs(entities) do                  
                        world.version = world.version + 1   -- increment Global System Version (GSV)
                        system:OnEnter(Time, entity)        -- local dirty = entity.version > system.version
                        system.version = world.version      -- update last system version with GSV
                     end
                  end
               end
            end         
         end
      end
   end
   
   --[[
      Executes the systems' OnExit method
   
      @param Time {Time}
      @param entities {{[Key=Entity] => Archetype}}
   ]]
   function SystemExecutor:_ExecOnExit(Time, oldIndexed)
      local world = self._world
      for _, system in ipairs(self._onExit) do
         local query = system.Query
         for archetypeOld, newIndexed in pairs(oldIndexed) do
            if query:Match(archetypeOld) then
               for archetypeNew, entities in pairs(newIndexed) do
                  if not query:Match(archetypeNew) then
                     for i,entity in ipairs(entities) do                  
                        world.version = world.version + 1   -- increment Global System Version (GSV)
                        system:OnExit(Time, entity)         -- local dirty = entity.version > system.version
                        system.version = world.version      -- update last system version with GSV
                     end
                  end
               end
            end         
         end
      end
   end
   
   --[[
      Executes the systems' OnRemove method
   
      @param Time {Time}
      @param entities {{[Key=Entity] => Archetype}}
   ]]
   function SystemExecutor:ExecOnRemove(Time, removedEntities)
      
      local isEmpty = true
      local oldIndexed = {}
      for entity, archetypeOld in pairs(removedEntities) do
         local entities = oldIndexed[archetypeOld]
         if not entities then
            entities = {}
            oldIndexed[archetypeOld] = entities
         end
         table.insert(entities, entity)
         isEmpty = false
      end
      if isEmpty then
         return
      end
      
      local world = self._world
      for _, system in ipairs(self._onRemove) do 
         for archetypeOld, entities in pairs(oldIndexed) do
            if system.Query:Match(archetypeOld) then
               for i,entity in ipairs(entities) do  
                  world.version = world.version + 1   -- increment Global System Version (GSV)
                  system:OnRemove(Time, entity)       -- local dirty = entity.version > system.version
                  system.version = world.version      -- update last system version with GSV
               end
            end
         end
      end
   end
   
   local function execUpdate(world, systems, Time)
      for j, system in ipairs(systems) do
         if (system.ShouldUpdate == nil or system.ShouldUpdate(Time)) then
            world.version = world.version + 1   -- increment Global System Version (GSV)
            system:Update(Time)                 -- local dirty = entity.version > system.version
            system.version = world.version      -- update last system version with GSV
         end
      end
   end
   
   function SystemExecutor:ExecProcess(Time)
      execUpdate(self._world, self._process, Time)
   end
   
   function SystemExecutor:ExecTransform(Time)
      execUpdate(self._world, self._transform, Time)
   end
   
   function SystemExecutor:ExecRender(Time)
      execUpdate(self._world, self._render, Time)
   end
   
   --[[
      Starts the execution of Jobs.
   
      Each Job is performed in an individual coroutine
   
      @param maxExecTime {number} limits the amount of time jobs can run
   ]]
   function SystemExecutor:ExecTasks(maxExecTime)
      while maxExecTime > 0 do
         local hasMore = false
   
         -- https://github.com/wahern/cqueues/issues/231#issuecomment-562838785
         local i, len = 0, #self._schedulers-1
         while i <= len do
            i = i + 1
   
            local scheduler = self._schedulers[i]
            local tasksTime, hasMoreTask = scheduler.Resume(maxExecTime)
            
            if hasMoreTask then
               hasMore = true
            end
      
            maxExecTime = maxExecTime - (tasksTime + 0.00001)
            
            if (maxExecTime <= 0) then
               break
            end
         end
   
         if not hasMore then
            return
         end
      end
   end
   
   local function execTask(node, Time, world, onComplete)
      local system = node.System
      system._TaskState = "running"
      if (system.ShouldUpdate == nil or system.ShouldUpdate(Time)) then
         world.version = world.version + 1   -- increment Global System Version (GSV)
         system:Update(Time)                 -- local dirty = entity.version > system.version
         system.version = world.version      -- update last system version with GSV
      end
      system._TaskState = "suspended"
      onComplete(node)
   end
   
   --[[
      Invoked at the beginning of each frame, it schedules the execution of the next tasks
   ]]
   function SystemExecutor:ScheduleTasks(Time)
      local world = self._world
   
      local rootNodes = {}    -- Node[]
      local runningNodes = {} -- Node[]
      local scheduled = {}    -- { [Node] = true }
      local completed = {}    -- { [Node] = true }
      local dependents = {}   -- { [Node] = Node[] }
   
      local i, len = 0, #self._task-1
      while i <= len do
         i = i + 1
         local node = self._task[i]
         
         if (node.System._TaskState == "suspended") then
            -- will be executed
            node.System._TaskState = "scheduled"
   
            local hasDependencies = false
            for other,_ in pairs(node.Depends) do
               hasDependencies = true
               if dependents[other] == nil then
                  dependents[other] = {}
               end
               table.insert(dependents[other], node)
            end
            
            if (not hasDependencies) then
               table.insert(rootNodes, node)
            end
   
            scheduled[node] = true
         end
      end
   
      -- suspended, scheduled, running
      local function onComplete(node)
   
         node.Thread = nil
         node.LastExecTime = nil
         completed[node] = true
   
         -- alguma outra tarefa depende da execucao deste no para executar?
         if dependents[node] then
            local dependentsFromNode = dependents[node]
   
            local i, len = 0, #dependentsFromNode-1
            while i <= len do
               i = i + 1
               local dependent = dependentsFromNode[i]
               if scheduled[dependent] then
                  local allDependenciesCompleted = true
                  for otherNode,_ in pairs(dependent.Depends) do
                     if completed[otherNode] ~= true then
                        allDependenciesCompleted = false
                        break
                     end
                  end
      
                  if allDependenciesCompleted then
                     scheduled[dependent] = nil
                     dependent.LastExecTime = 0
                     dependent.Thread = coroutine.create(execTask)
                     table.insert(runningNodes, dependent)
                  end
               end
            end
         end
      end
   
      if #rootNodes > 0 then
         local i, len = 0, #rootNodes-1
         while i <= len do
            i = i + 1
            local node = rootNodes[i]
            scheduled[node] = nil
            node.LastExecTime = 0
            node.Thread = coroutine.create(execTask)
            table.insert(runningNodes, node)
         end
   
         local scheduler
         scheduler = {
            Resume = function(maxExecTime)
   
               -- orders the threads, executing the ones with the least execution time first this prevents long tasks 
               -- from taking up all the processing time
               table.sort(runningNodes, function(nodeA, nodeB)
                  return nodeA.LastExecTime < nodeB.LastExecTime
               end)
   
               local totalTime = 0
   
               -- https://github.com/wahern/cqueues/issues/231#issuecomment-562838785
               local i, len = 0, #runningNodes-1
               while i <= len do
                  i = i + 1
                  local node = runningNodes[i]
   
                  if node.Thread ~= nil then
                     local execTime = os.clock()
                     node.LastExecTime = execTime
      
                     coroutine.resume(node.Thread, node, Time, world, onComplete)
      
                     totalTime = totalTime + (os.clock() - execTime)
      
                     if (totalTime > maxExecTime) then
                        break
                     end
                  end
               end
   
               -- remove completed
               for i,node in ipairs(runningNodes) do
                  if node.Thread == nil then                  
                     local idx = table.find(runningNodes, node)
                     if idx ~= nil then
                        table.remove(runningNodes, idx)
                     end
                  end
               end
   
               local hasMore = #runningNodes > 0
      
               if (not hasMore) then
                  local idx = table.find(self._schedulers, scheduler)
                  if idx ~= nil then
                     table.remove(self._schedulers, idx)
                  end
               end
   
               return totalTime, hasMore
            end
         }
   
         table.insert(self._schedulers, scheduler)
      end
   end
   
   return SystemExecutor
   
end

__F__["Timer"] = function()
   -- src/Timer.lua
   
   -- if execution is slow, perform a maximum of 4 simultaneous updates in order to keep the fixrate
   local MAX_SKIP_FRAMES = 4
   
   local Time = {}
   Time.__index = Time
   
   local Timer = {}
   Timer.__index = Timer
   
   function Timer.New(frequency)
      local timer = setmetatable({
         -- Public, visible by systems
         Time = setmetatable({
            Now = 0,
            NowReal = 0,
            -- The time at the beginning of this frame. The world receives the current time at the beginning
            -- of each frame, with the value increasing per frame.
            Frame = 0,         
            FrameReal = 0, -- The REAL time at the beginning of this frame.
            Process = 0, -- The time the latest process step has started.
            Delta = 0, -- The completion time in seconds since the last frame.
            DeltaFixed = 0,
            -- INTERPOLATION: The proportion of time since the previous transform relative to processDeltaTime
            Interpolation = 0
         }, Time),
         Frequency = 0,
         LastFrame = 0,
         ProcessOld = 0,
         FirstUpdate = 0,
      }, Timer)
   
      timer:SetFrequency(frequency)
   
      return timer
   end
   
   --[[
      Changes the frequency of execution of the "process" step
   
      @param frequency {number}
   ]]
   function Timer:SetFrequency(frequency)
   
      -- frequency: number,
      -- The maximum times per second this system should be updated. Defaults 30
      if frequency == nil then
         frequency = 30
      end
   
      local safeFrequency  = math.floor(math.abs(frequency)/2)*2
      if safeFrequency < 2 then
         safeFrequency = 2
      end
   
      if frequency ~= safeFrequency then
         frequency = safeFrequency
         print(string.format(">>> ATTENTION! The execution frequency of world has been changed to %d <<<", safeFrequency))
      end
   
      self.Frequency = frequency
      self.Time.DeltaFixed = 1000/frequency/1000
   end
   
   function Timer:Update(now, step, callback)
      if (self.FirstUpdate == 0) then
         self.FirstUpdate = now
      end
   
      -- corrects for internal time
      local nowReal = now
      now = now - self.FirstUpdate
   
      local Time = self.Time
   
      Time.Now = now
      Time.NowReal = nowReal
   
      if step == 'process' then
         local processOldTmp = Time.Process
   
         -- first step, initialize current frame time
         Time.Frame = now
         Time.FrameReal = nowReal
   
         if self.LastFrame == 0 then
            self.LastFrame = Time.Frame
         end
   
         if Time.Process == 0 then
            Time.Process = Time.Frame
            self.ProcessOld = Time.Frame
         end
   
         Time.Delta = Time.Frame - self.LastFrame
         Time.Interpolation = 1
   
         --[[
            Adjusting the framerate, the world must run on the same frequency,
            this ensures determinism in the execution of the scripts
   
            Each system in "transform" step is executed at a predetermined frequency (in Hz).
   
            Ex. If the game is running on the client at 30FPS but a system needs to be run at
            120Hz or 240Hz, this logic will ensure that this frequency is reached
   
            @see https://gafferongames.com/post/fix_your_timestep/
            @see https://gameprogrammingpatterns.com/game-loop.html
            @see https://bell0bytes.eu/the-game-loop/
         ]]
         local nLoops = 0
         local updated = false
   
         -- Fixed time is updated in regular intervals (equal to DeltaFixed) until time property is reached.
         while (Time.Process <= Time.Frame and nLoops < MAX_SKIP_FRAMES) do
   
            -- debugF('Update')
   
            updated = true
   
            callback(Time)
   
            nLoops = nLoops + 1
            Time.Process = Time.Process + Time.DeltaFixed
         end
   
         if updated then
            self.ProcessOld = processOldTmp
         end
      else
         -- executed only once per frame
   
         if Time.Process ~= self.ProcessOld then
            Time.Interpolation = 1 + (now - Time.Process)/Time.Delta
         else
            Time.Interpolation = 1
         end
   
         callback(Time)
   
         if step == 'render' then
            -- last step, save last frame time
            self.LastFrame = Time.Frame
         end      
      end
   end
   
   return Timer
   
end

__F__["Utility"] = function()
   -- src/Utility.lua
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
   
end

__F__["World"] = function()
   -- src/World.lua
   local Timer = __REQUIRE__("Timer")
   local Event = __REQUIRE__("Event")
   local Entity = __REQUIRE__("Entity")
   local Archetype = __REQUIRE__("Archetype")
   local SystemExecutor = __REQUIRE__("SystemExecutor")
   local EntityRepository = __REQUIRE__("EntityRepository")
   
   local World = {}
   World.__index = World
   
   --[[  
      @param systemClasses {SystemClass[]}
      @param frequency {number} (Optional)
      @param disableAutoUpdate {bool} (Optional)
   ]]
   function World.New(systemClasses, frequency, disableAutoUpdate)   
      local world = setmetatable({
         version = 0,
         maxScheduleExecTimePercent = 0.7,
         _dirty = false, -- True when create/remove entity, add/remove entity component (change archetype)
         _timer = Timer.New(frequency),
         _systems = {}, -- systems in this world
         _repository = EntityRepository.New(),
         _entitiesCreated = {}, -- created during the execution of the Update
         _entitiesRemoved = {}, -- removed during execution (only removed after the last execution step)
         _entitiesUpdated = {}, -- changed during execution (received or lost components, therefore, changed the archetype)
         _onChangeArchetypeEvent = Event.New(),
      }, World)
   
      -- System execution plan
      world._executor = SystemExecutor.New(world, {})
   
      world._onChangeArchetypeEvent:Connect(function(entity, archetypeOld, archetypeNew)      
         world:_OnChangeArchetype(entity, archetypeOld, archetypeNew)
      end)
   
      -- add systems
      if (systemClasses ~= nil) then
         for _, systemClass in ipairs(systemClasses) do
            world:AddSystem(systemClass)
         end
      end
   
      if (not disableAutoUpdate and World.LoopManager) then
         world._loopCancel = World.LoopManager.Register(world)
      end
   
      return world
   end
   
   --[[
      Changes the frequency of execution of the "process" step
   
      @param frequency {number}
   ]]
   function World:SetFrequency(frequency) 
      frequency = self._timer:SetFrequency(frequency) 
   end
   
   --[[
      Get the frequency of execution of the "process" step
   
      @return number
   ]]
   function World:GetFrequency(frequency) 
      return self._timer.Frequency
   end
   
   --[[
      Add a new system to the world
   
      @param systemClass {SystemClass}
      @param order {number}
      @param config {Object}
   ]]
   function World:AddSystem(systemClass, config)
      if systemClass then
         if config == nil then
            config = {}
         end
        
         if self._systems[systemClass] == nil then
            self._systems[systemClass] = systemClass.New(self, config)
            self._executor = SystemExecutor.New(self, self._systems)
         end
      end
   end
   
   --[[
      Create a new entity
   
      @param args {Component[]}
   ]]
   function World:Entity(...)
      local entity = Entity.New(self._onChangeArchetypeEvent, {...})
   
      self._dirty = true
      self._entitiesCreated[entity] = true
      
      entity.version = self.version -- update entity version using current Global System Version (GSV)
      entity.isAlive = false
   
      return entity
   end
   
   --[[
      Removing a entity at runtime
   
      @param entity {Entity}
   ]]
   function World:Remove(entity)
   
      if self._entitiesRemoved[entity] == true then
         return
      end
   
      if self._entitiesCreated[entity] == true then
         self._entitiesCreated[entity] = nil
      else
         self._repository:Remove(entity)
         self._entitiesRemoved[entity] = true
   
         if self._entitiesUpdated[entity] == nil then
            self._entitiesUpdated[entity] = entity.archetype
         end
      end
   
      self._dirty = true
      entity.isAlive = false
   end
   
   --[[
      Run a query in this world
   
      @param query {Query|QueryBuilder}
      @return QueryResult
   ]]
   function World:Exec(query)
      if (query.isQueryBuilder) then
         query = query.Build()
      end
   
      return self._repository:Query(query)
   end
   
   --[[
      Execute world update
   
      @param step {"process"|"transform"|"render"}
      @param now {number}
   ]]
   function World:Update(step, now)
   
      --[[
         .-------------------------------------.
         |----- process|transform|render ------| 
         |                  |                  |
         | s:ShouldUpdate() | <                |
         | s:Update()       |     s:OnRemove() |
         |                  |     s:OnExit()   |
         |                  |     s:OnEnter()  |
         |                  | >{0...n}         |
         |                  |                  |
         '-------------------------------------'
      ]]
      
      self._timer:Update(now, step, function(Time)
         if step == 'process' then
            self._executor:ScheduleTasks(Time)
            self._executor:ExecProcess(Time)
         elseif step == 'transform' then
            self._executor:ExecTransform(Time)
         else
            self._executor:ExecRender(Time)
         end
   
         -- 60FPS = ((1000/60/1000)*0.7)/3 = 0.0038888888888888883
         -- 30FPS = ((1000/30/1000)*0.7)/3 = 0.007777777777777777
         local maxScheduleExecTime = (Time.DeltaFixed * (self.maxScheduleExecTimePercent or 0.7))/3
   
         -- run suspended Tasks
         self._executor:ExecTasks(maxScheduleExecTime)
   
         -- cleans up after running scripts
         while self._dirty do
            self._dirty = false
         
            -- 1: remove entities
            local entitiesRemoved = {}
            for entity,_ in pairs(self._entitiesRemoved) do
               entitiesRemoved[entity] = self._entitiesUpdated[entity]
               self._entitiesUpdated[entity] = nil
            end
            self._entitiesRemoved = {}
            self._executor:ExecOnRemove(Time, entitiesRemoved)
            entitiesRemoved = nil
         
            local changed = {}
            local hasChange = false
         
            -- 2: Update entities in memory
            for entity, archetypeOld in pairs(self._entitiesUpdated) do
               if (archetypeOld ~= entity.archetype) then
                  hasChange = true
                  changed[entity] = archetypeOld
               end
            end
            self._entitiesUpdated = {}
         
            -- 3: Add new entities
            for entity, _ in pairs(self._entitiesCreated) do
               hasChange = true
               changed[entity] = Archetype.EMPTY
         
               entity.isAlive = true
               self._repository:Insert(entity) 
            end
            self._entitiesCreated = {}
         
            if hasChange then
               self._executor:ExecOnExitEnter(Time, changed)
               changed = nil
            end
         end
      end)
   end
   
   --[[
      Remove all entities and systems
   ]]
   function World:Destroy()
   
      if self._loopCancel then
         self._loopCancel()
         self._loopCancel = nil
      end
   
      if self._onChangeArchetypeEvent then
         self._onChangeArchetypeEvent:Destroy()
         self._onChangeArchetypeEvent = nil
      end
   
      self._repository = nil
   
      if self._systems then
         for _,system in pairs(self._systems) do
            system:Destroy()
         end
         self._systems = nil
      end
      
      self._timer = nil
      self._ExecPlan = nil
      self._entitiesCreated = nil
      self._entitiesUpdated = nil
      self._entitiesRemoved = nil
   
      setmetatable(self, nil)
   end
   
   function World:_OnChangeArchetype(entity, archetypeOld, archetypeNew)
      if entity.isAlive then
   
         if self._entitiesUpdated[entity] == nil then
            self._dirty = true
            self._entitiesUpdated[entity] = archetypeOld
         end
      
         self._repository:Update(entity)
   
         -- update entity version using current Global System Version (GSV)
         entity.version = self.version
      end
   end
   
   return World
   
end

return __REQUIRE__("ECS")