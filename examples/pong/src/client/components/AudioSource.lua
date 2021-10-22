
local AudioSource = _G.ECS.Component({
   clip = "",     -- sound asset
   volume = 10,    -- playback volume between [0..10]
   loop = false,  -- If true, the audio clip replays when it ends
   sound = nil
})

AudioSource.States = {
   ["Playing"] = { "Stopped" },
   ["Stopped"] = { "Playing" }
}

AudioSource.StateInitial = "Stopped"

AudioSource.Case = {
   Playing = function(self, previous)
      if self.sound then
         self.sound:Play()
      end
   end,
   Stopped = function(self, previous)
      if self.sound then
         self.sound:Stop()
      end
   end
}

return AudioSource
