local ECS = _G.ECS

local UserInputService = game:GetService("UserInputService")
local CurrentCamera = game.workspace.CurrentCamera

local Client = script.Parent.Parent
local Utility = require(Client.Utility)

local Components = Client.components
local Paddle = require(Components.Paddle)
local Player = require(Components.Player)
local PlayerHuman = Player.Qualifier("Human")

local PlayerHumanInputSystem = ECS.System("process", 1, ECS.Query.All(PlayerHuman, Paddle))

function PlayerHumanInputSystem:Initialize()
   UserInputService.MouseIconEnabled = false
end

function PlayerHumanInputSystem:Update(Time)
   local screenSizeY = CurrentCamera.ViewportSize.Y
   local mousePosY = UserInputService:GetMouseLocation().Y

   local min = screenSizeY*0.2
   local max = screenSizeY*0.8

   mousePosY = math.max(math.min(mousePosY, max), min)

   local entity = self:Result():FindAny()
   local paddle = entity[Paddle]

   paddle.target = Utility.map(mousePosY, min, max, -1, 1)
end

return PlayerHumanInputSystem
