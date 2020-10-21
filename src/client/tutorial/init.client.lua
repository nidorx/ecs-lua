repeat wait() until game.Players.LocalPlayer.Character

-- Player, Workspace & Environment
local Players 	   = game:GetService("Players")
local Player 	   = Players.LocalPlayer
local Character	= Player.Character
local Humanoid    = Character:WaitForChild("Humanoid")
local Camera 	   = workspace.CurrentCamera


-- services
local TweenService   = game:GetService("TweenService")
local ECS            = require(game.ReplicatedStorage:WaitForChild("ECS"))

-- Components
local Components = game.ReplicatedStorage:WaitForChild("tutorial"):WaitForChild("component")
local WeaponComponent = require(Components:WaitForChild("WeaponComponent"))

-- Systems
local Systems = game.ReplicatedStorage:WaitForChild("tutorial"):WaitForChild("system")
local FiringSystem         = require(Systems:WaitForChild("FiringSystem"))
local PlayerShootingSystem = require(Systems:WaitForChild("PlayerShootingSystem"))
local CleanupFiringSystem  = require(Systems:WaitForChild("CleanupFiringSystem"))

-- Our world
local World = ECS.newWorld()
World.addSystem(FiringSystem)
World.addSystem(PlayerShootingSystem)
World.addSystem(CleanupFiringSystem)

-- Our weapon
local BulletSpawnPart = Instance.new("Part")
BulletSpawnPart.Parent = game.Workspace

-- Create our entity
local bulletSpawnEntity = ECS.Util.newBasePartEntity(World, BulletSpawnPart)

-- Mark as weapon
World.set(bulletSpawnEntity, WeaponComponent)
