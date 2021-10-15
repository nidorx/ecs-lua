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


local Query = require("Query")

--[[
   Filter used in Query and QueryResult

   @see QueryResult.lua

   Ex. ECS.Query.All(Movement.In("Standing", "Walking"))
]]
local queryFilterCTypeStateIn = Query.Filter(function(entity, config)
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
end)

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

         if table.find(value, "*") then
            rawset(states, newState, "*")
         else
            local idxSelf = table.find(value, newState)
            if idxSelf ~= nil then
               table.remove(value, idxSelf)
               if #value == 0 then
                  value = "*"
               end
            end
            rawset(states, newState, value)
         end
      end
   })
   rawset(superClass, "__States", cTypeStates)

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

   componentClass.IsFSM = true
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
         return {}
      end

      return queryFilterCTypeStateIn({
         States = states,
         IsSuperClass = (componentClass == superClass),
         ComponentClass = componentClass, 
      })
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
         if (transtions ~= "*" and table.find(transtions, newState) == nil) then
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
