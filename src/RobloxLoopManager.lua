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
