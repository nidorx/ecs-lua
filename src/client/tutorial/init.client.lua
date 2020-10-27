repeat wait() until game.Players.LocalPlayer.Character

-- Player, Workspace & Environment
local Players 	   = game:GetService("Players")
local Player 	   = Players.LocalPlayer
local Character	= Player.Character
local Humanoid    = Character:WaitForChild("Humanoid")
local Camera 	   = workspace.CurrentCamera

--[[
   
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
local world = ECS.newWorld(nil, { disableDefaultSystems = false, frequence = 20 })
world.addSystem(FiringSystem)
world.addSystem(PlayerShootingSystem)
world.addSystem(CleanupFiringSystem)

-- Our weapon
local rightHand = Character:WaitForChild("RightHand")
local weapon = Instance.new("Part", Character)
weapon.CanCollide = false
weapon.CastShadow = false
weapon.Size       = Vector3.new(0.2, 0.2, 2)
weapon.CFrame     = rightHand.CFrame + Vector3.new(0, 0, -1)
weapon.Color      = Color3.fromRGB(255, 0, 255)

local weldWeapon = Instance.new("WeldConstraint", weapon)
weldWeapon.Part0 = weapon
weldWeapon.Part1 = rightHand

local BulletSpawnPart   = Instance.new("Part", weapon)
BulletSpawnPart.CanCollide = false
BulletSpawnPart.CastShadow = false
BulletSpawnPart.Color      = Color3.fromRGB(255, 255, 0)
BulletSpawnPart.Size       = Vector3.new(0.6, 0.6, 0.6)
BulletSpawnPart.Shape      = Enum.PartType.Ball
BulletSpawnPart.CFrame     = (weapon.CFrame + Vector3.new(0, 0, -1)) * CFrame.Angles(math.rad(180), 0, 0)

local weldBulletSpawn = Instance.new("WeldConstraint", BulletSpawnPart)
weldBulletSpawn.Part0 = BulletSpawnPart
weldBulletSpawn.Part1 = weapon

-- Create our entity
local bulletSpawnEntity = ECS.Util.NewBasePartEntity(world, BulletSpawnPart, true, false)

-- Mark as weapon
world.set(bulletSpawnEntity, WeaponComponent)

]]