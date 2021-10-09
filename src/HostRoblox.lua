--[[
   Implementacao padrao para Roblox
]]
local function InitHost()
   local RunService = game:GetService('RunService')

   local HostRoblox = {}
   HostRoblox.__index = HostRoblox

   function HostRoblox:Create(world)
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
      }, HostRoblox)
   end

   function HostRoblox:Destroy()
      self._RenderConn:Disconnect()
      self._ProcessConn:Disconnect()
      self._TransformConn:Disconnect()
      
      self._RenderConn = nil
      self._ProcessConn = nil
      self._TransformConn = nil
   end

   return HostRoblox
end

return InitHost
