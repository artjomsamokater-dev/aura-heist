--!strict
-- OutlineController: толстый тёмный контур (Highlight) у мемлингов и врагов — стиль «D · Микс» (задача 5.4).
-- У Roblox на экране не больше 31 Highlight одновременно, поэтому контур получают не все, а по очереди:
--   1) то, что несёт сам игрок;
--   2) мемлинги на постаментах его участка (атрибут OwnerUserId);
--   3) остальные с тегом StyleConfig.Outline.Tag — ближние, не дальше Outline.Distance.
-- Всего не больше Outline.MaxCount. Highlight создаётся только на этом клиенте, сервер о нём не знает.
-- Тег стоит на невидимом ядре мемлинга; Highlight вешается на модель Figure с видимыми деталями (задача 5.4b).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)

local OutlineController = {}

local player = Players.LocalPlayer
local style = StyleConfig.Outline

local TIER_CARRIED = 0
local TIER_OWN_PEDESTAL = 1
local TIER_NEAR = 2

type Candidate = { Target: Instance, Tier: number, Distance: number }

local outlines: { [Instance]: Highlight } = {}

local function getPosition(target: Instance): Vector3?
	if target:IsA("BasePart") then
		return target.Position
	elseif target:IsA("Model") then
		return target:GetPivot().Position
	end
	return nil
end

-- На что вешать контур: у мемлинга — модель Figure внутри невидимого ядра (Highlight на прозрачной
-- детали ничего не рисует), у врага — сама модель. Без модели контура нет
local function getAdornee(target: Instance): Model?
	if target:IsA("Model") then
		return target
	end
	local figure = target:FindFirstChild(style.Figure)
	if figure and figure:IsA("Model") then
		return figure
	end
	return nil
end

-- Свой выпавший лут (после смерти, тег StyleConfig.Loot.Tag): подсвечивается золотом и сквозь стены
local function isMyLoot(target: Instance): boolean
	return CollectionService:HasTag(target, StyleConfig.Loot.Tag) and target:GetAttribute("LootOwnerUserId") == player.UserId
end

-- Вид контура: обычный тёмный или золотой у своего лута. Ставится при каждом пересчёте —
-- лут могут поднять, и он снова станет обычным
local function applyStyle(outline: Highlight, loot: boolean)
	local lootStyle = StyleConfig.Loot
	outline.OutlineColor = if loot then lootStyle.Color else style.Color
	outline.FillColor = lootStyle.Color
	outline.FillTransparency = if loot then lootStyle.FillTransparency else 1 -- обычный — только контур
	outline.DepthMode = if loot then Enum.HighlightDepthMode.AlwaysOnTop else Enum.HighlightDepthMode.Occluded
end

local function makeOutline(adornee: Model): Highlight
	local outline = Instance.new("Highlight")
	outline.Name = "Outline"
	outline.OutlineTransparency = 0
	applyStyle(outline, false)
	outline.Adornee = adornee
	outline.Parent = adornee
	return outline
end

local lastReported = -1

-- Сколько контуров активно — в Output, только когда число изменилось
local function report()
	local count = 0
	for _ in pairs(outlines) do
		count += 1
	end
	if count ~= lastReported then
		lastReported = count
		print(string.format("[Outline] Активных контуров: %d (не больше %d)", count, style.MaxCount))
	end
end

local function refresh()
	local character = player.Character
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else nil
	local candidates: { Candidate } = {}

	for _, target in ipairs(CollectionService:GetTagged(style.Tag)) do
		local position = getPosition(target)
		if position and target:IsDescendantOf(Workspace) and getAdornee(target) then
			local distance = if eye then (position - eye).Magnitude else 0
			local tier = TIER_NEAR
			if (character and target:IsDescendantOf(character)) or isMyLoot(target) then
				tier = TIER_CARRIED -- в руках или свой выпавший лут — контур всегда
			elseif target:GetAttribute("OwnerUserId") == player.UserId then
				tier = TIER_OWN_PEDESTAL
			end
			if tier ~= TIER_NEAR or distance <= style.Distance then
				table.insert(candidates, { Target = target, Tier = tier, Distance = distance })
			end
		end
	end

	table.sort(candidates, function(a: Candidate, b: Candidate): boolean
		if a.Tier ~= b.Tier then
			return a.Tier < b.Tier
		end
		return a.Distance < b.Distance
	end)

	local wanted: { [Instance]: boolean } = {}
	for i = 1, math.min(#candidates, style.MaxCount) do
		wanted[candidates[i].Target] = true
	end
	-- Сначала убираем лишние, потом добавляем новые — чтобы не превысить лимит Roblox даже на миг
	for target, outline in pairs(outlines) do
		if not wanted[target] or outline.Parent == nil or outline.Parent ~= getAdornee(target) then
			outline:Destroy()
			outlines[target] = nil
		end
	end
	for target in pairs(wanted) do
		local adornee = getAdornee(target)
		if not outlines[target] and adornee then
			outlines[target] = makeOutline(adornee)
		end
		local outline = outlines[target]
		if outline then
			applyStyle(outline, isMyLoot(target))
		end
	end
	report()
end

function OutlineController.Start()
	task.spawn(function()
		while true do
			refresh()
			task.wait(style.RefreshSeconds)
		end
	end)
end

return OutlineController
