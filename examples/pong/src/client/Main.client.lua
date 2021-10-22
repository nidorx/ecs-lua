
local ECS = require(game.ReplicatedStorage:WaitForChild("ECS"))

local Constants = require(script.Parent:WaitForChild("Constants"))

local Components = script.Parent:WaitForChild("components")
local Ball = require(Components.Ball)
local Score = require(Components.Score)
local Paddle = require(Components.Paddle)
local Player = require(Components.Player)
local PlayerAI = Player.Qualifier("AI")
local PlayerHuman = Player.Qualifier("Human")

local Systems = script.Parent.systems
local MoveSystem = require(Systems.MoveSystem)
local BallSystem = require(Systems.BallSystem)
local AudioSystem = require(Systems.AudioSystem)
local ScoreSystem = require(Systems.ScoreSystem)
local PaddleSystem = require(Systems.PaddleSystem)
local PaddleHitSystem = require(Systems.PaddleHitSystem)
local PlayerAiThinkSystem = require(Systems.PlayerAiThinkSystem)
local PlayerHumanInputSystem = require(Systems.PlayerHumanInputSystem)

local RenderSystem = require(Systems.RenderSystem)
local CameraSystem = require(Systems.CameraSystem)

local world = ECS.World({
   MoveSystem,
   BallSystem,
   AudioSystem,
   ScoreSystem, 
   PaddleSystem, 
   PaddleHitSystem, 
   PlayerAiThinkSystem,
   PlayerHumanInputSystem,
   CameraSystem,
   RenderSystem,
}, 60)

-- Ball
world:Entity(Ball())

-- Player
world:Entity(
   Score(),
   PlayerHuman(),
   Paddle({ side = "left" })
)

-- AI
world:Entity(
   Score(),
   PlayerAI(),
   Paddle({ side = "right" })
)
