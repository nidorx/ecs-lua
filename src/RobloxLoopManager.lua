local function InitManager()
   local RunService = game:GetService('RunService')

   local RobloxLoop = {}

   -- if not RunService:IsRunning() then
   --    return
   -- end

   function RobloxLoop.Register(world)
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

      return setmetatable({
         _ProcessConn = processConn,
         _TransformConn = transformConn,
         _RenderConn = renderConn,
      }, RobloxLoop)

      return function ()
         processConn:Disconnect()
         processConn:Disconnect()
         processConn:Disconnect()
      end
   end

   return RobloxLoop
end

return InitManager
