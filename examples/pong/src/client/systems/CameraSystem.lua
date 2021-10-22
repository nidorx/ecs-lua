local ECS = _G.ECS

local Client = script.Parent.Parent
local Constants = require(Client.Constants)

local CFRAME = CFrame.new(Vector3.new(0, Constants.CAMERA_DISTANCE, 30), Vector3.new(0, 0, 0))

local CameraSystem = ECS.System("render", 1, function()
   game.Workspace.CurrentCamera.CFrame = CFRAME
end)

return CameraSystem
