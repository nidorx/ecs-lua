local lu = require('luaunit')

local Event = require('Event')

TestEvent = {}

function TestEvent:test_ConnectFireDisconnectDestroy()

   local event = Event.New()

   local Object1 = {}
   local Object2 = {Object1}

   local Calls = { [1] = 0, [2] = 0 }

   local conn1 = event:Connect(function(obj1, obj2)
      lu.assertEquals(obj1, Object1)
      lu.assertEquals(obj2, Object2)
      Calls[1] = Calls[1] + 1
   end)

   local conn2 = event:Connect(function(obj1, obj2)
      lu.assertIsTrue(obj1 == Object1)
      lu.assertIsTrue(obj2 == Object2)
      Calls[2] = Calls[2] + 1
   end)   

   event:Fire(Object1, Object2)
   lu.assertEquals(Calls[1], 1)
   lu.assertEquals(Calls[2], 1)


   -- Disconnect
   conn1:Disconnect()
   event:Fire(Object1, Object2)
   lu.assertEquals(Calls[1], 1)
   lu.assertEquals(Calls[2], 2)

   lu.assertError(function()
      event:Connect("INVALID")   
   end)

   event:Destroy()
   conn2:Disconnect()
end
