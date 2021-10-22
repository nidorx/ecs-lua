local ECS = _G.ECS

local Client = script.Parent.Parent
local Components = Client.components
local Position = require(Components.Position)
local BasePart = require(Components.BasePart)

local RenderSystem = ECS.System("render", 2, ECS.Query.All(Position, BasePart))

function RenderSystem:Update(Time)
   self:Result():ForEach(function(entity)
      local position = entity[Position]
      local part = entity[BasePart].value
   
      if position.valueOld then
         part.Position = position.valueOld:Lerp(position.value, Time.Interpolation)
      else
         part.Position = position.value
      end
   end)
end

return RenderSystem
