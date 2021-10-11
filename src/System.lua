
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

   if (query and query.IsQueryBuilder) then
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
         Version = 0,
         World = world,
         Config = config,
      }, SystemClass)

      if system.Initialize then
         system:Initialize()
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

   function SystemClass:Result(newQuery)
      return self.World:Exec(newQuery or query)
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
