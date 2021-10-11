
--[[
   Subscription
]]
local Connection = {}
Connection.__index = Connection

function Connection.New(event, handler)
   return setmetatable({ _Event = event, _Handler = handler }, Connection)
end

-- Unsubscribe
function Connection:Disconnect()
   local event = self._Event
   if (event and not event._Destroyed) then
      local idx = table.find(event._Handlers, self._Handler)
      if idx ~= nil then
         table.remove(event._Handlers, idx)
      end
   end
   setmetatable(self, nil)
end 

--[[
   Observer Pattern

   Allows the application to fire events of a particular type.
]]
local Event = {}
Event.__index = Event

function Event.New()
	return setmetatable({ _Handlers = {} }, Event)
end

function Event:Connect(handler)
	if (type(handler) == "function") then
      table.insert(self._Handlers, handler)
      return Connection.New(self, handler)
	end

   error(("Event:Connect(%s)"):format(typeof(handler)), 2)
end

function Event:Fire(...)
	if not self._Destroyed then
      for i,handler in ipairs(self._Handlers) do
         handler(table.unpack({...}))
      end
	end
end

function Event:Destroy()
	setmetatable(self, nil)
   self._Handlers = nil
   self._Destroyed = true
end

return Event
