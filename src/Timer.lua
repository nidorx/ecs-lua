
-- if execution is slow, perform a maximum of 4 simultaneous updates in order to keep the fixrate
local MAX_SKIP_FRAMES = 4

local Time = {}
Time.__index = Time

local Timer = {}
Timer.__index = Timer

function Timer.Create(frequency)
   local timer = setmetatable({
      Time = setmetatable({
         Now = 0,
         -- The time at the beginning of this frame. The world receives the current time at the beginning
         -- of each frame, with the value increasing per frame.
         Frame = 0,
         -- The completion time in seconds since the last frame. This property provides the time between the current 
         -- and previous frame.
         Delta = 0,
         -- The time the latest process step has started.
         Process = 0,
         NowReal = 0,
         -- The REAL time at the beginning of this frame.
         FrameReal = 0,
         DeltaProcess = 0,
         -- INTERPOLATION: The proportion of time since the previous transform relative to processDeltaTime
         Interpolation = 0
      }, Time)
      Frequency = 0,
      LastFrame = 0,
      ProcessOld = 0,
      FirstUpdate = 0,
   }, Timer)

   timer:SetFrequency(frequency)
end

--[[
   Allows you to change the frequency of the 'process' step at run time
]]
function Timer:SetFrequency(frequency)
   frequency  = frequency

   -- frequency: number,
   -- The maximum times per second this system should be updated. Defaults 30
   if frequency == nil then
      frequency = 30
   end

   local safeFrequency  = math.round(math.abs(frequency)/2)*2
   if safeFrequency < 2 then
      safeFrequency = 2
   end

   if frequency ~= safeFrequency then
      frequency = safeFrequency
      print(string.format(">>> ATTENTION! The execution frequency of world has been changed to %d <<<", safeFrequency))
   end

   self.Frequency = frequency
   self.Time.Delta = 1000/frequency/1000
end


function Timer:Update(now, step, callback)
   if (self.FirstUpdate == 0) then
      self.FirstUpdate = now
   end

   -- corrects for internal time
   local nowReal = now
   now = now - self.FirstUpdate

   local Time = self.Time

   Time.Now = now
   Time.NowReal = nowReal

   if step ~= 'process' then
      -- executed only once per frame

      if Time.Process ~= self.ProcessOld then
         Time.Interpolation = 1 + (now - Time.Process)/Time.DeltaProcess
      else
         Time.Interpolation = 1
      end

      if step == 'render' then
         -- last step, save last frame time
         self.LastFrame = Time.Frame
      end
      
      callback(Time)
   else
      local processOldTmp = Time.Process

      -- first step, initialize current frame time
      Time.Frame = now
      Time.FrameReal = nowReal

      if self.LastFrame == 0 then
         self.LastFrame = Time.Frame
      end

      if Time.Process == 0 then
         Time.Process = Time.Frame
         self.ProcessOld = Time.Frame
      end

      Time.Delta = Time.Frame - self.LastFrame
      Time.Interpolation = 1

      --[[
         Adjusting the framerate, the world must run on the same frequency,
         this ensures determinism in the execution of the scripts

         Each system in "transform" step is executed at a predetermined frequency (in Hz).

         Ex. If the game is running on the client at 30FPS but a system needs to be run at
         120Hz or 240Hz, this logic will ensure that this frequency is reached

         @see
            https://gafferongames.com/post/fix_your_timestep/
            https://gameprogrammingpatterns.com/game-loop.html
            https://bell0bytes.eu/the-game-loop/
      ]]
      local nLoops = 0
      local updated = false

      -- Fixed time is updated in regular intervals (equal to fixedDeltaTime) until time property is reached.
      while (Time.Process < Time.Frame and nLoops < MAX_SKIP_FRAMES) do

         -- debugF('Update')

         updated = true

         callback(Time)

         nLoops = nLoops + 1
         Time.Process = Time.Process + Time.DeltaProcess
      end

      if updated then
         self.ProcessOld = processOldTmp
      end
   end
end

return Timer
