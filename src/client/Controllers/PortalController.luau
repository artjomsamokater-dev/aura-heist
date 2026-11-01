--!strict
-- PortalController: вращает кольцо портала и вихрь искр (задача 6.0). Только картинка на этом клиенте:
-- детали построил сервер (MapBuilder), а вращать их локально — плавно и без нагрузки на сеть.
-- Скорости — StyleConfig.Portal.Ring / Vortex, центр — MapConfig.Portal.Position.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)

local PortalController = {}

function PortalController.Start()
	local hub = Workspace:WaitForChild("Hub")
	local ring = hub:WaitForChild("PortalRing")
	local portal = hub:WaitForChild("Portal")
	local vortex = portal:WaitForChild("PortalVortex")
	if not ring:IsA("Model") or not vortex:IsA("BasePart") then
		return
	end

	local center = CFrame.new(MapConfig.Portal.Position)
	local ringSpeed = math.rad(StyleConfig.Portal.Ring.SpinDegreesPerSecond)
	local vortexSpeed = math.rad(StyleConfig.Portal.Vortex.SpinDegreesPerSecond)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		ring:PivotTo(center * CFrame.Angles(0, 0, t * ringSpeed))
		vortex.CFrame = center * CFrame.Angles(0, 0, t * vortexSpeed)
	end)
end

return PortalController
