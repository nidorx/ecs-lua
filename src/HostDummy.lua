--[[
   Implementacao vazia
]]
local function InitHost()
   local HostDummy = {}
   HostDummy.__index = HostDummy

   function HostDummy:Create(world)
      return setmetatable({}, HostDummy)
   end

   function HostDummy:Destroy()
   end

   return HostDummy
end

return InitHost
