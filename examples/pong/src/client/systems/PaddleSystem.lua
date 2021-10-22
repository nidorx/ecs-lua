local ECS = _G.ECS

local Client = script.Parent.Parent
local Utility = require(Client.Utility)
local Constants = require(Client.Constants)

local Components = Client.components
local Paddle = require(Components.Paddle)
local Position = require(Components.Position)
local BasePart = require(Components.BasePart)

local PaddleSystem = ECS.System("process", 2, ECS.Query.All(Paddle))

function PaddleSystem:Update(Time)
   self:Result():ForEach(function(entity)
      local paddle = entity[Paddle]
      if paddle.target ~= paddle.position then
         paddle.position = Utility.lerp(paddle.position, paddle.target, Constants.PLAYER_SPEED * Time.DeltaFixed)
         entity[Position].value = self:GetPaddlePosition(paddle)
      end
   end)
end

function PaddleSystem:OnEnter(Time, entity)
   local paddle = entity[Paddle]
   paddle.target = 0
   paddle.position = 0

   local positionVec3 = self:GetPaddlePosition(paddle)
   entity[Position] = Position(positionVec3)

   local part = Instance.new("Part")
   part.Name = "Paddle_"..paddle.side
   part.Size = Vector3.new(Constants.PADDLE_WIDTH, 2, Constants.PADDLE_HEIGHT)
   part.Shape = Enum.PartType.Block
   part.Anchored = true
   part.Position = positionVec3
   part.Material = Enum.Material.SmoothPlastic

   if paddle.side == "left" then
      part.Color = Color3.fromRGB(33, 84, 185)
   else
      part.Color = Color3.fromRGB(255, 89, 89)
   end
   
   part.Parent = game.Workspace
   entity[BasePart] = BasePart(part)
end

function PaddleSystem:GetPaddlePosition(paddle)

   local xPos = Constants.COURT_WIDTH/2
   if paddle.side == "left" then
      xPos = xPos * -1
   end
   
   local zPosMax = Constants.COURT_HEIGHT/2 - Constants.PADDLE_HEIGHT/2
   local zPos = Utility.map(paddle.position, -1, 1, -zPosMax, zPosMax)
   return Vector3.new(xPos, 1, zPos)
end

return PaddleSystem
