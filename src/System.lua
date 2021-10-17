
local STEPS = { "task", "render", "process", "transform" }

local System = {}

--[[
   Create new System Class

   @param step {process|transform|render|task}
   @param order {number} (Optional) Allows you to set an execution order (for systems that are not `task`). Default 50
   @param query {Query|QueryBuilder} (Optional) Filters the entities that will be processed by this system
   @param updateFn {function(self, Time)} (Optional) A shortcut for creating systems that only have the Update method
   @return SystemClass
]]
function System.Create(step, order, query, updateFn)

   if (step == nil or not table.find(STEPS, step)) then
      error("The step parameter must one of ", table.concat(STEPS, ", "))
   end

   if (order and type(order) == "function") then
      updateFn = order
      order = nil
   elseif query and type(query) == "function" then
      updateFn = query
      query = nil
   end

   if (order and type(order) == "table" and (order.isQuery or order.isQueryBuilder)) then
      query = order
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

   local SystemClass = {
      Step = step,
      -- Allows you to define the execution priority level for this system
      Order = order,
      Query = query,
      -- After = {SystemC, SystemD}, When the system is a task, it allows you to define that this system should run AFTER other specific systems.
      -- Before = {SystemA, SystemB}, When the system is a task, it allows you to define that this system should run BEFORE other specific systems.
      --[[

         ShouldUpdate(Time) -> bool - Invoked before 'Update', allows you to control the execution of the update
         Update(Time)

         [QuerySystem]
            OnRemove(Time, enity)
            OnExit(Time, entity)
            OnEnter(Time, entity)
      ]]
   }
   SystemClass.__index = SystemClass

   --[[
      Create an instance of this system

      @param world {World}
      @param config {table}
   ]]
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

   --[[
      Run a query in the world. A shortcut to `self._world:Exec(query)`

      @query {Query|QueryBuilder} Optional If nil, use default query
      @return QueryResult
   ]]
   function SystemClass:Result(query)
      return self._world:Exec(query or SystemClass.Query)
   end

   --[[
      destroy this instance
   ]]
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
