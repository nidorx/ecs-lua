local ECS = _G.ECS

local Client = script.Parent.Parent

local Utility = require(Client.Utility)
local Constants = require(Client.Constants)

local Components = Client.components
local Ball = require(Components.Ball)
local Paddle = require(Components.Paddle)
local Position = require(Components.Position)
local Velocity = require(Components.Velocity)
local Player = require(Components.Player)
local PlayerAI = Player.Qualifier("AI")
local PlayerHuman = Player.Qualifier("Human")

local ballMaxZ = Constants.COURT_HEIGHT/2 - Constants.BALL_RADIUS

local PlayerAiThinkSystem = ECS.System("process", 1, ECS.Query.All(PlayerAI, Paddle, Position))

function PlayerAiThinkSystem:Initialize(Time)
   self.queryHuman = ECS.Query.All(PlayerHuman, Paddle, Position).Build()
   self.queryBalls = ECS.Query.All(Ball, Position, Velocity).Build()
end

function PlayerAiThinkSystem:Update(Time)

   local ettPaddleAI = self:Result():FindAny()
   local paddle = ettPaddleAI[Paddle]
   local paddlePos = ettPaddleAI[Position].value

   -- Get the ball that is coming towards the AI and is closer
   local tgBallPos

   self:Result(self.queryBalls):ForEach(function(ettBall)
      local ballPos = ettBall[Position].value
      local ballVel = ettBall[Velocity].value
      
      local ballTowardsAI
      if paddle.side == "right" then
         ballTowardsAI = ballVel.X > 0
      else
         ballTowardsAI = ballVel.X < 0
      end
   
      if ballTowardsAI then
         if tgBallPos == nil then
            tgBallPos = ballPos
         else
            -- the target is the ball that is closest to the racket
            if paddle.side == "right" then
               if ballPos.X > tgBallPos.X then
                  tgBallPos = ballPos
               end
            else
               if ballPos.X < tgBallPos.X then
                  tgBallPos = ballPos
               end
            end
         end
      end
   end)

   if tgBallPos then
      paddle.target = Utility.map(tgBallPos.Z, -ballMaxZ, ballMaxZ, -1, 1)
   end
end

return PlayerAiThinkSystem
