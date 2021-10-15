local function InitManager()
   local RunService = game:GetService("RunService")
   
   return {
      Register = function(world)         
         -- if not RunService:IsRunning() then
         --    return
         -- end
         local beforePhysics = RunService.Stepped:Connect(function()
            world:Update("process", os.clock())
         end)
   
         local afterPhysics = RunService.Heartbeat:Connect(function()
            world:Update("transform", os.clock())
         end)
   
         local beforeRender
         if (not RunService:IsServer()) then
            beforeRender = RunService.RenderStepped:Connect(function()
               world:Update("render", os.clock())
            end)
         end
   
         return function()
            beforePhysics:Disconnect()
            afterPhysics:Disconnect()
            if beforeRender then
               beforeRender:Disconnect()
            end
         end
      end
   }
end

return InitManager
