

local function teste()

   local value = 0

   local co = coroutine.create(function ()	
      -- https://github.com/wahern/cqueues/issues/231#issuecomment-562838785
      local i, len = 0, 10000-1
      -- while i <= len do
      --    i = i + 1
      --    if i%1000 == 0 then
      --       print( "Before yield", i, value)
      --       coroutine.yield()	
      --       print( "After yield", i, value)
      --    end	
      -- end
      for i=1,10000 do		
         if i%1000 == 0 then
            print( "Before yield", i, value)
            coroutine.yield()	
            print( "After yield", i, value)
         end		
      end
   end)
   
   coroutine.resume(co)
   value = 1

   coroutine.resume(co)
   value = 2

   coroutine.resume(co)
   value = 3

   coroutine.resume(co)
   value = 4

   coroutine.resume(co)
   value = 5

   coroutine.resume(co)
   value = 6

   coroutine.resume(co)
   value = 7

   coroutine.resume(co)
   value = 8

   coroutine.resume(co)
   value = 9

   coroutine.resume(co)
   value = 10
   
   coroutine.resume(co)
   value = 11
end

teste()
