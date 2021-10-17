
--[[
   Subscription
]]
local Connection = {}
Connection.__index = Connection

function Connection.New(event, handler)
   return setmetatable({ _event = event, _handler = handler }, Connection)
end

-- Unsubscribe
function Connection:Disconnect()
   local event = self._event
   if (event and not event.destroyed) then
      local idx = table.find(event._handlers, self._handler)
      if idx ~= nil then
         table.remove(event._handlers, idx)
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
	return setmetatable({ _handlers = {} }, Event)
end

function Event:Connect(handler)
	if (type(handler) == "function") then
      table.insert(self._handlers, handler)
      return Connection.New(self, handler)
	end

   error(("Event:Connect(%s)"):format(typeof(handler)), 2)
end

function Event:Fire(...)
	if not self.destroyed then
      for i,handler in ipairs(self._handlers) do
         handler(table.unpack({...}))
      end
	end
end

function Event:Destroy()
	setmetatable(self, nil)
   self._handlers = nil
   self.destroyed = true
end

return Event
