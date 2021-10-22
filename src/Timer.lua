
-- if execution is slow, perform a maximum of 4 simultaneous updates in order to keep the fixrate
local MAX_SKIP_FRAMES = 4

local function loop(Time)

   local accumulator = 0.0
   local lastStepTime = 0.0

   return function (newTime, stepName, beforeUpdateFn, updateFn)
      local dtFixed = Time.DeltaFixed
      local stepTime = newTime - lastStepTime
      if stepTime > 0.25 then
         stepTime = 0.25
      end
      lastStepTime = newTime

      Time.Now = newTime

      -- 1000/30/1000 = 0.03333333333333333
      accumulator = accumulator + stepTime
      
      --[[
         Adjusting the framerate, the world must run on the same frequency,
         this ensures determinism in the execution of the scripts

         Each system in "transform" step is executed at a predetermined frequency (in Hz).

         Ex. If the game is running on the client at 30FPS but a system needs to be run at
         120Hz or 240Hz, this logic will ensure that this frequency is reached

         @see https://gafferongames.com/post/fix_your_timestep/
         @see https://gameprogrammingpatterns.com/game-loop.html
         @see https://bell0bytes.eu/the-game-loop/
      ]]
      if stepName == "process" then
         if accumulator >= dtFixed then       
            Time.Interpolation = 1

            beforeUpdateFn(Time)
            local nLoops = 0
            while (accumulator >= dtFixed and nLoops < MAX_SKIP_FRAMES) do
               updateFn(Time)
               nLoops = nLoops + 1
               Time.Process = Time.Process + dtFixed
               accumulator = accumulator - dtFixed
            end
         end
      else
         Time.Interpolation = math.min(math.max(accumulator/dtFixed, 0), 1)
         beforeUpdateFn(Time)
         updateFn(Time)
      end
   end
end

local Timer = {}
Timer.__index = Timer

function Timer.New(frequency)
   local Time = {
      Now = 0,
      -- The time at the beginning of this frame. The world receives the current time at the beginning
      -- of each frame, with the value increasing per frame.
      Frame = 0,         
      Process = 0, -- The time the latest process step has started.
      Delta = 0, -- The completion time in seconds since the last frame.
      DeltaFixed = 0,
      -- INTERPOLATION: The proportion of time since the previous transform relative to processDeltaTime
      Interpolation = 0
   }

   local timer = setmetatable({
      -- Public, visible by systems
      Time = Time,
      Frequency = 0,
      _update = loop(Time)
   }, Timer)

   timer:SetFrequency(frequency)

   return timer
end

--[[
   Changes the frequency of execution of the "process" step

   @param frequency {number}
]]
function Timer:SetFrequency(frequency)

   -- frequency: number,
   -- The maximum times per second this system should be updated. Defaults 30
   if frequency == nil then
      frequency = 30
   end

   local safeFrequency  = math.floor(math.abs(frequency)/2)*2
   if safeFrequency < 2 then
      safeFrequency = 2
   end

   if frequency ~= safeFrequency then
      frequency = safeFrequency
   end

   self.Frequency = frequency
   self.Time.DeltaFixed = 1000/frequency/1000
end

function Timer:Update(now, step, beforeUpdate, update)
   self._update(now, step, beforeUpdate, update)
end

return Timer
