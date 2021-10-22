local ECS = _G.ECS

local Client = script.Parent.Parent
local Components = Client.components
local BasePart = require(Components.BasePart)
local Position = require(Components.Position)
local AudioSource = require(Components.AudioSource)

local AudioSystem = ECS.System("transform", 100, ECS.Query.All(AudioSource))

function AudioSystem:Initialize(Time)
   self.queryStopped = ECS.Query.All(AudioSource, AudioSource.In("Stopped")).Build()
end

function AudioSystem:Update(Time)
   self:Result(self.queryStopped):ForEach(function(entity)
      self._world:Remove(entity)
   end)
end

function AudioSystem:OnEnter(Time, entity)
   local source = entity[AudioSource]
   local position = entity[Position]
   
   -- create a sound
   local sound = Instance.new("Sound")
   sound.SoundId = source.clip
   sound.Looped = source.loop
   source.sound = sound

   if position then
      -- create a part
      local part = Instance.new("Part")
      part.Anchored = true
      part.CanCollide = false
      part.Transparency = 1
      part.Position = position.value
      part.Name = "sound#"..source.clip

      sound.Parent = part
      part.Parent = game.Workspace
      entity[BasePart] = BasePart(part)
   end

   sound.Ended:Connect(function()
      source:SetState("Stopped")
   end)

   source:SetState("Playing")
end

function AudioSystem:OnExit(Time, entity)
   local part = entity[BasePart]
   if part then
      part.value.Parent = nil
   end
end

function AudioSystem:OnRemove(Time, entity)
   local part = entity[BasePart]
   if part then
      part.value.Parent = nil
   end
end

return AudioSystem
