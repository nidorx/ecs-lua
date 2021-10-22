local ECS = _G.ECS

local Client = script.Parent.Parent
local Constants = require(Client.Constants)

local Components = Client.components
local Ball = require(Components.Ball)
local Position = require(Components.Position)
local Velocity = require(Components.Velocity)
local BasePart = require(Components.BasePart)
local AudioSource = require(Components.AudioSource)

local ballMaxX = Constants.COURT_WIDTH/2
local ballMaxZ = Constants.COURT_HEIGHT/2 - Constants.BALL_RADIUS

local BallSystem = ECS.System("transform", 1, ECS.Query.All(Ball))

function BallSystem:Update(Time)
   local scored = false
   local scoredSide

   self:Result():ForEach(function(entity)
      local ball = entity[Ball]
      local position = entity[Position]
      local velocity = entity[Velocity]
   
      local posValue = position.value
   
      if posValue.Z > ballMaxZ or posValue.Z < -ballMaxZ then
         -- Reverse z velocity if ball hits a vertical wall
         local v = velocity.value
         velocity.value = Vector3.new(v.X, v.Y, v.Z*-1)

         if posValue.Z > ballMaxZ then
            posValue = Vector3.new(posValue.X, posValue.Y, ballMaxZ)
         else
            posValue = Vector3.new(posValue.X, posValue.Y, -ballMaxZ )
         end
         position.value = posValue

         -- sound effect
         self._world:Entity(
            Position(posValue),
            AudioSource({ clip = "rbxassetid://4458219865" })
         )
      end
   end)
end

function BallSystem:OnEnter(Time, entity)
   
   local radius = Constants.BALL_RADIUS
   local size = radius*2

   local part = Instance.new("Part")
   part.Name = "Ball"
   part.Anchored = true
   part.Size = Vector3.new(size, size, size)
   part.Shape = Enum.PartType.Ball
   part.Color = Color3.fromRGB(255, 255, 255)
   part.Material = Enum.Material.Neon
   part.Parent = game.Workspace
   entity[BasePart] = BasePart(part)


   local speed = Constants.BALL_SERVE_SPEED
   local position = Vector3.new(0, radius, 0)
   
   local ball = entity[Ball]

   if ball.initialDirection then
      position = Vector3.new(-ballMaxX, radius, 0)
      if ball.initialDirection == "left" then
         speed = speed * -1
         position = Vector3.new(ballMaxX, radius, 0)
      end
   else
      if math.random() > 0.5 then
         speed = speed * -1
      end
   end

   entity[Position] = Position(position)
   entity[Velocity] = Velocity(Vector3.new(speed, 0, 0))

   -- sound effect
   self._world:Entity(
      Position(entity[Position].value),
      AudioSource({ clip = "rbxassetid://1837831535" })
   )
end

function BallSystem:OnRemove(Time, entity)
   local part = entity[BasePart].value
   part.Parent = nil
   entity[BasePart] = nil
end

return BallSystem
