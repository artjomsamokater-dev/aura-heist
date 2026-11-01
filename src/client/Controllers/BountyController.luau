--!strict
-- BountyController: «Охота» на этом клиенте (задача 7.5) — только картинка. Кто сейчас BOUNTY и до какого
-- времени, сервер пишет в атрибуты ReplicatedStorage (BountyMemelingId, BountyEndsAt — время сервера).
--   • табличка над вывеской портала той зоны, где живёт этот мемлинг (имя, ×N, сколько осталось);
--   • плашка под таймером рестока — только в зоне (RaidState = InRaid);
--   • метка «BOUNTY xN» над такими мемлингами на полу зон.
-- Флаг на вынесенном мемлинге и доход считает только сервер.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local MemelingConfig = require(ReplicatedStorage.Shared.Config.MemelingConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local BountyController = {}

local HUD = StyleConfig.Hud
local UPDATE_SECONDS = 0.25 -- как часто обновляем таймер и метки (не баланс — частота картинки)

local function formatClock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function makeText(parent: Instance, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = StyleConfig.Fonts.Hud
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = parent
	return label
end

-- Скруглённая плашка цвета BOUNTY с обводкой (HUD и метки в мире выглядят одинаково)
local function makePill(parent: Instance): (Frame, TextLabel)
	local panel = Instance.new("Frame")
	panel.BackgroundColor3 = HUD.BountyPanel
	panel.BorderSizePixel = 0
	panel.Size = UDim2.fromScale(1, 1)
	panel.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = HUD.Stroke
	stroke.Thickness = HUD.StrokeThickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = panel
	return panel, makeText(panel, HUD.BountyText)
end

local function current(): (string?, number)
	local id = ReplicatedStorage:GetAttribute("BountyMemelingId")
	local endsAt = tonumber(ReplicatedStorage:GetAttribute("BountyEndsAt")) or 0
	return if type(id) == "string" then id else nil, endsAt - Workspace:GetServerTimeNow()
end

local function nameOf(memelingId: string): string
	return TextConfig.MemelingNames[memelingId] or memelingId
end

function BountyController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local multiplier = EconomyConfig.Bounty.IncomeMultiplier

	-- Плашка в HUD под таймером рестока
	local gui = Instance.new("ScreenGui")
	gui.Name = "BountyHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui
	local holder = Instance.new("Frame")
	holder.Name = "Panel" -- по этому имени раскладку проверяет client/Util/LayoutCheck
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, GuiService:GetGuiInset().Y + HUD.TimerTop + HUD.TimerHeight + HUD.BountyGap)
	holder.Size = UDim2.fromOffset(HUD.BountyWidth, HUD.TimerHeight)
	holder.Visible = false
	holder.Parent = gui
	local _, hudText = makePill(holder)

	-- Метки в мире — в своей папке на клиенте, у каждой Adornee = мемлинг
	local markerFolder = Instance.new("Folder")
	markerFolder.Name = "BountyMarkers"
	markerFolder.Parent = playerGui
	local markers: { [BasePart]: BillboardGui } = {}

	local function makeBillboard(adornee: BasePart, size: UDim2, offset: Vector3, maxDistance: number): (BillboardGui, TextLabel)
		local billboard = Instance.new("BillboardGui")
		billboard.Adornee = adornee
		billboard.Size = size
		billboard.StudsOffsetWorldSpace = offset
		billboard.MaxDistance = maxDistance
		billboard.LightInfluence = 0
		billboard.Parent = markerFolder
		local _, text = makePill(billboard)
		return billboard, text
	end

	local portalSign: BillboardGui? = nil
	local portalText: TextLabel? = nil
	local portalZone: string? = nil

	local function updatePortal(memelingId: string?, left: number)
		local memeling = memelingId and MemelingConfig.Memelings[memelingId]
		local zoneId = if memeling then memeling.Zone else nil
		if zoneId ~= portalZone then
			if portalSign then
				portalSign:Destroy()
				portalSign, portalText = nil, nil
			end
			portalZone = zoneId
		end
		if zoneId == nil or memelingId == nil then
			return
		end
		if portalSign == nil then
			local hub = Workspace:FindFirstChild("Hub")
			local portal = hub and hub:FindFirstChild("Portal_" .. zoneId)
			local sign = portal and portal:FindFirstChild("Sign", true)
			if sign == nil or not sign:IsA("BasePart") then
				portalZone = nil -- хаб ещё не загрузился — попробуем в следующий раз
				return
			end
			portalSign, portalText = makeBillboard(
				sign,
				UDim2.fromOffset(HUD.BountyWidth, HUD.TimerHeight * 1.8),
				Vector3.new(0, sign.Size.Y / 2 + HUD.BountyPortalOffset, 0),
				HUD.BountyPortalMaxDistance
			)
		end
		if portalText then
			portalText.Text = string.format(TextConfig.BountyPortal, nameOf(memelingId), multiplier, formatClock(left))
		end
	end

	local function updateMarkers(memelingId: string?)
		local alive: { [BasePart]: boolean } = {}
		if memelingId then
			for _, zoneId in ipairs(ZoneConfig.ZoneOrder) do
				local zone = Workspace:FindFirstChild("RaidZone_" .. zoneId)
				local folder = zone and zone:FindFirstChild("Memelings")
				for _, part in ipairs(if folder then folder:GetChildren() else {}) do
					if part:IsA("BasePart") and part:GetAttribute("MemelingId") == memelingId then
						alive[part] = true
						if not markers[part] then
							local billboard, text = makeBillboard(
								part,
								UDim2.fromOffset(130, 30),
								Vector3.new(0, StyleConfig.Memeling.Size.Y * 1.6, 0),
								HUD.BountyMarkerMaxDistance
							)
							billboard.AlwaysOnTop = true
							text.Text = string.format(TextConfig.BountyMarker, multiplier)
							markers[part] = billboard
						end
					end
				end
			end
		end
		-- Подобран, вынесен, пропал или охота сменилась — метку убираем
		for part, billboard in markers do
			if not alive[part] then
				billboard:Destroy()
				markers[part] = nil
			end
		end
	end

	while gui.Parent do
		local memelingId, left = current()
		local inRaid = player:GetAttribute("RaidState") == "InRaid"
		holder.Visible = memelingId ~= nil and inRaid
		if memelingId then
			hudText.Text = string.format(TextConfig.BountyHud, nameOf(memelingId), multiplier, formatClock(left))
		end
		updatePortal(memelingId, left)
		updateMarkers(memelingId)
		task.wait(UPDATE_SECONDS)
	end
end

return BountyController
