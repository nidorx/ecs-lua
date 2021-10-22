local ECS = _G.ECS

local Client = script.Parent.Parent
local Utility = require(Client.Utility)
local Constants = require(Client.Constants)

local Components = Client.components
local Ball = require(Components.Ball)
local Paddle = require(Components.Paddle)
local Position = require(Components.Position)
local Velocity = require(Components.Velocity)
local AudioSource = require(Components.AudioSource)

local PADDLE_AIM_C = 1.5

-- compute outgoing angle depending on which point the ball hits the paddle
local function computeBounce(ettBall, ettPaddle)
   
   local ball = ettBall[Ball]
   local ballPos = ettBall[Position].value
   local ballVel = ettBall[Velocity].value
   local paddle = ettPaddle[Paddle]
   local paddlePos = ettPaddle[Position].value

   -- The sharpness of the angle is determined by where the ball hits the paddle
   local angle = PADDLE_AIM_C * (ballPos.Z - paddlePos.Z)/Constants.PADDLE_HEIGHT

   local spped = ball.secondary and Constants.BALL_SPEED_SECONDARY or Constants.BALL_SPEED

   local ballVelZ = math.sin(angle) * spped
   local ballVelX = math.cos(angle) * spped
   
   -- if the angle exceeds a magic value, the ball gets an extra speed boost
   local angleAbs = math.abs(angle)
   if (angleAbs > 0.6) then
      local boost = (1 + angleAbs * Constants.BALL_BOOST)
      ballVelX = ballVelX * boost
      ballVelZ = ballVelZ * boost
   end

   -- Determine the direction in which the ball should go
   if paddle.side == "right" then
      ballVelX = ballVelX*-1
   end
   ettBall[Velocity].value = Vector3.new(ballVelX, 0, ballVelZ)
end

local function intersects(ettBall, ettPaddle)

   local ball = ettBall[Ball]
   local ballPos = ettBall[Position].value
   local paddlePos = ettPaddle[Position].value
   
   -- circle
   local cx, cz, radius = ballPos.X, ballPos.Z, Constants.BALL_RADIUS
   -- rectangle
   local rw, rh = Constants.PADDLE_WIDTH, Constants.PADDLE_HEIGHT
   local rx, rz = paddlePos.X - rw/2, paddlePos.Z - rh/2
   
   -- temporary variables to set edges for testing
   local testX = cx
   local testZ = cz
   
   local xEdge, zEdge
   -- which edge is closest?
   if cx < rx then
      testX = rx 
      xEdge = "left"
   elseif cx > rx + rw then    
      testX = rx+rw
      xEdge = "right"
   end 

   if cz < rz then
      testZ = rz
      zEdge = "top"
   elseif cz > rz+rh then    
      testZ = rz+rh
      zEdge = "bottom"
   end 

   -- get distance from closest edges

   local distX = cx-testX
   local distY = cz-testZ   
   local distance = math.sqrt( (distX*distX) + (distY*distY) );
 
   -- if the distance is less than the radius, collision!
   if (distance <= radius) then
      local normal 
      if distY < distX then
         normal = (zEdge == "top") and Vector3.new(0, 0, 1) or Vector3.new(0, 0, -1)
      else
         normal = (xEdge == "left") and Vector3.new(1, 0, 0) or Vector3.new(-1, 0, 0)
      end
      return {
         normal = normal,
         distance = distance
      }
   end
   return nil   
end

local PaddleHitSystem = ECS.System("transform", 2, ECS.Query.All(Paddle, Position))

function PaddleHitSystem:Initialize(Time)
   self.queryBalls = ECS.Query.All(Ball, Position).Build()
end

function PaddleHitSystem:Update(Time)
   local ettsBall = self:Result(self.queryBalls):ToArray()

   local ballSpawned = false

   self:Result():ForEach(function(ettPaddle)
      local paddle = ettPaddle[Paddle]
      local pPosition = ettPaddle[Position]
   
      -- collision detection
      for i,ettBall in ipairs(ettsBall) do
         local collistion = intersects(ettBall, ettPaddle)
         if collistion then
   
            -- move the ball out of the paddle
            local ballPos = ettBall[Position].value
            ettBall[Position].value = ballPos - collistion.normal * collistion.distance
           
            computeBounce(ettBall, ettPaddle)

            if #ettsBall < 2 then               
               paddle.hits = paddle.hits + 1
               if paddle.hits == 5 then
                  -- create new ball
                  local inverseDirection = (paddle.side == "left") and "right" or "left" 
                  self._world:Entity(Ball({ initialDirection = inverseDirection, secondary = true }))
                  ballSpawned = true
               end
            end

            -- sound effect
            self._world:Entity(
               Position(ballPos),
               AudioSource({ clip = "rbxassetid://4458219865" })
            )

            -- break
            return true
         end
      end
   end)

   if ballSpawned then
      self:Result():ForEach(function(ettPaddle)
         local paddle = ettPaddle[Paddle]
         paddle.hits = 0
      end)
   end
end

return PaddleHitSystem
