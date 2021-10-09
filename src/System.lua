
local SEQ = 0

local STEPS = { 'task', 'render', 'process', 'transform' }

local System = {}

--[[
   Allow to create new System Class Type

   @param query {Query|QueryConfig} Unique name for this System
   @param step {task|render|process|transform} Em qual momento, durante a execução de um Frame do 
      Roblox, este sistema deverá ser executado (https://developer.roblox.com/en-us/articles/task-scheduler)
         render      : RunService.RenderStepped
         process     : RunService.Stepped
         transform   : RunService.Heartbeat
]]
function System.Create(step, order, query)

   if step == nil then
      step = 'transform'
   end

   if not table.find(STEPS, step) then
      error('The "step" parameter must one of ', table.concat(STEPS, ', '))
   end

   if step == 'task' then
      -- Task-type systems do not accept the "Order" parameter')
      order = nil

      -- if config.ShouldUpdate ~= nil then
      --    error('Task-type systems do not accept the "ShouldUpdate" parameter')
      -- end

      -- if config.BeforeUpdate ~= nil then
      --    error('Task-type systems do not accept the "BeforeUpdate" parameter')
      -- end

      -- if config.Update ~= nil then
      --    error('Task-type systems do not accept the "Update" parameter')
      -- end

      -- if config.AfterUpdate ~= nil then
      --    error('Task-type systems do not accept the "AfterUpdate" parameter')
      -- end

      -- if config.OnEnter ~= nil then
      --    error('Task-type systems do not accept the "OnEnter" parameter')
      -- end

      -- if config.OnExit ~= nil then
      --    error('Task-type systems do not accept the "OnExit" parameter')
      -- end

      -- if config.Execute == nil then
      --    error('The task "Execute" method is required for registration')
      -- end
   end

   if order == nil or order < 0 then
      order = 50
   end

   if (query) then
      if (query.IsBuilder) then
         query = query.Build()
      end

      if query.IsQuery ~= true then
         error('The system "query" need to be a Query instance')
      end
   end

   SEQ = SEQ + 1

   local Id = SEQ
   local IdString = tostring(SEQ)

   local SystemClass = {
      Id = Id,
      Step = step,
      -- Allows you to define the execution priority level for this system
      Order = order,
      Query = query,
      -- After = {SystemC, SystemD}, An update order that requests ECS update this system after it updates another specified system.
      -- Before = {SystemA, SystemB}, An update order that requests ECS update this system before it updates another specified system.
      -- RequireAll           = config.RequireAll,
      -- RequireAny           = config.RequireAny,
      -- RequireAllOriginal   = config.RequireAllOriginal,
      -- RequireAnyOriginal   = config.RequireAnyOriginal,
      -- RejectAll            = config.RejectAll,
      -- RejectAny            = config.RejectAny,
   
      --[[
         Order: number,
            Allows you to define the execution priority level for this system

         ShouldUpdate(Time): void - It allows informing if the update methods of this system should be invoked
         Update: function(Time, dirty) -> boolean -Invoked in updates, limited to the value set in the "Frequency" attribute

         [QuerySystem]
            OnRemove(Time, enity)
            OnExit(Time, entity) -> boolean
            OnEnter(Time, entity) -> boolean

         [JobSystem] https://developer.roblox.com/en-us/api-reference/lua-docs/coroutine
            OnJoin(Time)
      ]]
   }
   SystemClass.__index = SystemClass

   setmetatable(SystemClass, {
      __tostring = function(t)
         return IdString
      end
   })

   -- Cria uma instancia desse system
   function SystemClass.New(world, config)
      local system = setmetatable({
         World = world
         Config = config
         Version = 0,
      }, SystemClass)

      if system.Initialize then
         system:Initialize()
      end

      return system
   end

   function SystemClass:Exec(query)
      return self.World:Exec(query or SystemClass.Query)
   end

   if query then
      SystemClass.IsQuerySystem = true
      
      function SystemClass:ForEach(callback)
         self:Exec(query):ForEach(callback)
      end
      
      function SystemClass:Entities()
         return self:Exec(query):ToArray()
      end      
   end

   function SystemClass:Destroy()      
      setmetatable(self, nil)
      for k,v in pairs(self) do
         self[k] = nil
      end
   end

   return SystemClass
end

return System
