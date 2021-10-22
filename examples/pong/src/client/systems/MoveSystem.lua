local ECS = _G.ECS

local Client = script.Parent.Parent
local Components = Client.components
local Velocity = require(Components.Velocity)
local Position = require(Components.Position)

local MoveSystem = ECS.System("process", 10, ECS.Query.All(Position, Velocity))

function MoveSystem:Update(Time)
   self:Result(self.queryBalls):ForEach(function(entity)
      local position = entity[Position]
      local velocity = entity[Velocity]
   
      -- interpolation
      -- position.valueOld = position.value
      position.value = position.value + velocity.value * Time.DeltaFixed
   end)
end

return MoveSystem
