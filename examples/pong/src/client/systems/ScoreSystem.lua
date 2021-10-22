local ECS = _G.ECS

local Client = script.Parent.Parent
local Constants = require(Client.Constants)

local Components = Client.components
local Ball = require(Components.Ball)
local Paddle = require(Components.Paddle)
local Score = require(Components.Score)
local Player = require(Components.Player)
local Position = require(Components.Position)
local Velocity = require(Components.Velocity)
local BasePart = require(Components.BasePart)
local AudioSource = require(Components.AudioSource)

local ballMaxX = Constants.COURT_WIDTH/2
local ballMaxZ = Constants.COURT_HEIGHT/2 - Constants.BALL_RADIUS

local ScoreSystem = ECS.System("transform", 2, ECS.Query.All(Score, Paddle))

function ScoreSystem:Initialize(Time)
   self.queryBalls = ECS.Query.All(Ball, Position).Build()
end

function ScoreSystem:Update(Time)
   local ettScored = false
   local scoredSide

   local balls = self:Result(self.queryBalls):ToArray()

   self:Result():ForEach(function(entity)
      local paddle = entity[Paddle]
      local score = entity[Score]

      for i,ettBall in ipairs(balls) do         
         local ball = ettBall[Ball]
         local ballPos = ettBall[Position].value
      
         -- if ball hits horizontal wall, reset the game      
         if (paddle.side == "right" and ballPos.X < -ballMaxX) then
            ettScored = entity
         elseif (paddle.side == "left" and ballPos.X > ballMaxX ) then
            ettScored = entity
         end
   
         if ettScored then
            score.value = score.value + 1
            score.TextLabel.Text = tostring(score.value)

            -- sound effect
            self._world:Entity(
               Position(ballPos),
               AudioSource({ clip = "rbxassetid://1843023345" })
            )
   
            -- break
            return true
         end
      end
   end)

   if ettScored then
      -- remove all balls
      for i,ettBall in ipairs(balls) do
         self._world:Remove(ettBall)
      end

      -- create new ball
      self._world:Entity(Ball())

      self:Result(self.queryPlayers):ForEach(function(entity)
         local paddle = entity[Paddle]
         paddle.hits = 0
      end)
   end
end

function ScoreSystem:OnEnter(Time, entity)
   local score = entity[Score]
   local paddle = entity[Paddle]
   score.goalPart = game.Workspace:FindFirstChild("goal_"..paddle.side)
   score.TextLabel = score.goalPart.BillboardGui.TextLabel   
end

return ScoreSystem
