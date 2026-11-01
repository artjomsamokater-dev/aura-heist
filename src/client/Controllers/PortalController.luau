--!strict
-- PortalController: оживляет портал на этом клиенте (задачи 6.0, 6.2) — только картинка:
-- детали построил сервер (MapBuilder), а двигать их локально — плавно и без нагрузки на сеть.
--   • кольцо бусин и вихрь искр крутятся;
--   • кристаллы на колоннах крутятся;
--   • вывеска «MEME ZONE» слегка покачивается;
--   • стрелка на полу пульсирует.
-- Скорости — StyleConfig.Portal, центр — MapConfig.Portal.Position.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)

local PortalController = {}

function PortalController.Start()
	local style = StyleConfig.Portal
	local hub = Workspace:WaitForChild("Hub")
	local ring = hub:WaitForChild("PortalRing")
	local portal = hub:WaitForChild("Portal")
	local vortex = portal:WaitForChild("PortalVortex")
	local decor = hub:WaitForChild("PortalDecor")
	local sign = decor:WaitForChild("Sign")
	local arrowFolder = decor:WaitForChild("Arrow")
	if not ring:IsA("Model") or not vortex:IsA("BasePart") or not sign:IsA("BasePart") then
		return
	end

	local crystals: { { Part: BasePart, Base: CFrame } } = {}
	for _, name in ipairs({ "Crystal1", "Crystal2" }) do
		local crystal = decor:WaitForChild(name)
		if crystal:IsA("BasePart") then
			table.insert(crystals, { Part = crystal, Base = crystal.CFrame })
		end
	end
	local arrows: { BasePart } = {}
	for _, arm in ipairs(arrowFolder:GetChildren()) do
		if arm:IsA("BasePart") then
			table.insert(arrows, arm)
		end
	end

	local center = CFrame.new(MapConfig.Portal.Position)
	local signBase = sign.CFrame
	local ringSpeed = math.rad(style.Ring.SpinDegreesPerSecond)
	local vortexSpeed = math.rad(style.Vortex.SpinDegreesPerSecond)
	local crystalSpeed = math.rad(style.CrystalSpinDegreesPerSecond)
	local pulse = style.ArrowTransparency
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		ring:PivotTo(center * CFrame.Angles(0, 0, t * ringSpeed))
		vortex.CFrame = center * CFrame.Angles(0, 0, t * vortexSpeed)
		for i, crystal in ipairs(crystals) do
			-- Вращение вокруг вертикали, в разные стороны у двух колонн
			local direction = if i % 2 == 0 then -1 else 1
			crystal.Part.CFrame = CFrame.new(crystal.Base.Position) * CFrame.Angles(0, direction * t * crystalSpeed, 0) * crystal.Base.Rotation
		end
		local rock = math.sin(t * style.SignRockHz * 2 * math.pi) * math.rad(style.SignRockDegrees)
		sign.CFrame = signBase * CFrame.Angles(0, 0, rock)
		local wave = (math.sin(t * style.ArrowPulseHz * 2 * math.pi) + 1) / 2
		for _, arm in ipairs(arrows) do
			arm.Transparency = pulse.Min + (pulse.Max - pulse.Min) * wave
		end
	end)
end

return PortalController
