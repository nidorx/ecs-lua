

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
   [FSM] 
      Facilitar a construcao e uso de uma Maquina de Estado Finito usando ECS
      https://ajmmertens.medium.com/why-storing-state-machines-in-ecs-is-a-bad-idea-742de7a18e59

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
      
      ECS.Query.All({ Movement.In("Standing") })

      local movement = entity[Movement]
      movement:GetState() -> "Running"
      movement:SetState("Walking")
      movement:GetPrevState()
      movement:GetStateTime()

      if movement:GetState() == "Standing" then
         movement.Speed = 0
      end
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

   table.insert(superClass.__Initializers, function(component)
      component:SetState(superClass.StateInitial)
   end)
end

function ComponentFSM.AddMethods(componentClass, superClass)
   local cTypeStates = superClass.States

   --[[
      Query clause

      Ex. ECS.Query.All({ Movement.In("Walking", "Running") })
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
         Filter = {
            Function = queryFilterCTypeStateIn,
            Config = {
               States = states,
               IsSuperClass = (componentClass == superClass),
               ComponentClass = componentClass, 
            }
         },
         Components = {componentClass},
      }
   end   

   --[[
      
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

   function componentClass:GetState()
      return self._state or superClass.StateInitial
   end

   function componentClass:GetPrevState()
      return self._statePrev or nil
   end

   function componentClass:GetStateTime()
      return self._stateTime or 0
   end
end

return ComponentFSM
