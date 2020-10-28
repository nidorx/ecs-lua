repeat wait() until game:GetService('Players').LocalPlayer.Character

local DISABLED = true

--[[
   Benchmark, data oriented design
]]

-- “Script timeout: exhausted allowed execution time”
-- disable the timeout in Studio with the following command
-- settings().Studio.ScriptTimeoutLength = -1

local case = require(script:WaitForChild('soa'))

spawn(function()

   if DISABLED then
      return
   end

   wait(5)

   print('[Benchmark] '..case.name)
      
   local sizes = {1000, 2000, 5000, 10000, 50000, 100000, 200000, 300000, 500000}
   local sufs = {'OOP', 'DOP'}
   local samples = 20
   local groups = {}

   for it  = 1, samples do
      for _,size in ipairs(sizes) do
         print('[Benchmark] it '..it, ', size ', size)
         if groups['t'..size] == nil then
            groups['t'..size] = {}
         end
      
         for _,suffix in ipairs(sufs) do
            -- ignoring creation
            local input = case['gen'..suffix](size)

            if groups['t'..size][suffix] == nil then
               groups['t'..size][suffix] = 0
            end

            local start_time = os.clock()

            -- runing test
            case['run'..suffix](input)

            local duration = os.clock() - start_time
            groups['t'..size][suffix] = groups['t'..size][suffix]  + duration
         end
      end
   end

   -- print raw data, to use in excel
   print('[Benchmark] '..case.name)
   for i,size in ipairs(sizes) do
      if i == 1 then
         print('size', 'oop_avg_time', 'dop_avg_time')
      end
      local oop = groups['t'..size]['OOP']
      local dop = groups['t'..size]['DOP']
      print(size,'\t', oop/samples,'\t', dop/samples,'\t')
   end
end)