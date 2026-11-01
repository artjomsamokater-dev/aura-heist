--!strict
-- PortalController: оживляет порталы всех зон на этом клиенте (задачи 6.0, 6.2, 7.2) — только картинка:
-- детали построил сервер (MapBuilder, модели Hub.Portal_<Id>), а двигать их локально — плавно и без сети.
--   • кольцо бусин и вихрь искр крутятся вокруг центра портала;
--   • кристаллы на колоннах крутятся;
--   • вывеска с названием зоны слегка покачивается;
--   • стрелка на полу пульсирует;
--   • золотые ворота платной зоны прячутся, если доступ куплен (атрибут ZoneAccess_<Id> от сервера);
--     войти без доступа всё равно не даст сервер.
-- Скорости — StyleConfig.Portal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local PortalController = {}

local player = Players.LocalPlayer

type Animated = {
	Trigger: BasePart,
	Vortex: BasePart?,
	Beads: { { Part: BasePart, Offset: CFrame } }, -- бусина относительно триггера
	Crystals: { { Part: BasePart, Base: CFrame } },
	Sign: BasePart?,
	SignBase: CFrame,
	Arrows: { BasePart },
}

-- Ворота: у купивших — прозрачные, без подписи и без кнопки (только на этом клиенте)
local function bindGate(zoneId: string, gate: Instance)
	local function refresh()
		local owned = player:GetAttribute("ZoneAccess_" .. zoneId) == true
		for _, child in ipairs(gate:GetDescendants()) do
			if child:IsA("BasePart") then
				child.LocalTransparencyModifier = if owned then 1 else 0
			elseif child:IsA("BillboardGui") then
				child.Enabled = not owned
			elseif child:IsA("ProximityPrompt") then
				child.Enabled = not owned
			end
		end
	end
	player:GetAttributeChangedSignal("ZoneAccess_" .. zoneId):Connect(refresh)
	gate.DescendantAdded:Connect(refresh) -- кнопку покупки сервер вешает чуть позже
	refresh()
end

local function collect(zoneId: string, folder: Instance): Animated?
	local trigger = folder:WaitForChild("Portal")
	if not trigger:IsA("BasePart") then
		return nil
	end
	local animated: Animated = {
		Trigger = trigger,
		Vortex = nil,
		Beads = {},
		Crystals = {},
		Sign = nil,
		SignBase = CFrame.identity,
		Arrows = {},
	}
	local vortex = trigger:WaitForChild("PortalVortex")
	animated.Vortex = if vortex:IsA("BasePart") then vortex else nil
	for _, bead in ipairs(folder:WaitForChild("PortalRing"):GetChildren()) do
		if bead:IsA("BasePart") then
			table.insert(animated.Beads, { Part = bead, Offset = trigger.CFrame:ToObjectSpace(bead.CFrame) })
		end
	end
	local decor = folder:WaitForChild("PortalDecor")
	for _, name in ipairs({ "Crystal1", "Crystal2" }) do
		local crystal = decor:WaitForChild(name)
		if crystal:IsA("BasePart") then
			table.insert(animated.Crystals, { Part = crystal, Base = crystal.CFrame })
		end
	end
	local sign = decor:WaitForChild("Sign")
	if sign:IsA("BasePart") then
		animated.Sign = sign
		animated.SignBase = sign.CFrame
	end
	for _, arm in ipairs(decor:WaitForChild("Arrow"):GetChildren()) do
		if arm:IsA("BasePart") then
			table.insert(animated.Arrows, arm)
		end
	end
	if ZoneConfig.Zones[zoneId].AccessCost ~= nil then
		bindGate(zoneId, folder:WaitForChild("Gate"))
	end
	return animated
end

function PortalController.Start()
	local style = StyleConfig.Portal
	local hub = Workspace:WaitForChild("Hub")
	local portals: { Animated } = {}
	for _, zoneId in ipairs(ZoneConfig.ZoneOrder) do
		local animated = collect(zoneId, hub:WaitForChild("Portal_" .. zoneId))
		if animated then
			table.insert(portals, animated)
		end
	end

	local ringSpeed = math.rad(style.Ring.SpinDegreesPerSecond)
	local vortexSpeed = math.rad(style.Vortex.SpinDegreesPerSecond)
	local crystalSpeed = math.rad(style.CrystalSpinDegreesPerSecond)
	local pulse = style.ArrowTransparency
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local rock = math.sin(t * style.SignRockHz * 2 * math.pi) * math.rad(style.SignRockDegrees)
		local wave = (math.sin(t * style.ArrowPulseHz * 2 * math.pi) + 1) / 2
		for _, portal in ipairs(portals) do
			local center = portal.Trigger.CFrame
			local spin = center * CFrame.Angles(0, 0, t * ringSpeed)
			for _, bead in ipairs(portal.Beads) do
				bead.Part.CFrame = spin * bead.Offset
			end
			if portal.Vortex then
				portal.Vortex.CFrame = center * CFrame.Angles(0, 0, t * vortexSpeed)
			end
			for i, crystal in ipairs(portal.Crystals) do
				-- Вращение вокруг вертикали, в разные стороны у двух колонн
				local direction = if i % 2 == 0 then -1 else 1
				crystal.Part.CFrame = CFrame.new(crystal.Base.Position) * CFrame.Angles(0, direction * t * crystalSpeed, 0) * crystal.Base.Rotation
			end
			if portal.Sign then
				portal.Sign.CFrame = portal.SignBase * CFrame.Angles(0, 0, rock)
			end
			for _, arm in ipairs(portal.Arrows) do
				arm.Transparency = pulse.Min + (pulse.Max - pulse.Min) * wave
			end
		end
	end)
end

return PortalController
