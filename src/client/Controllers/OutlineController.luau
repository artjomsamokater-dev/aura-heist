--!strict
-- OutlineController: толстый тёмный контур (Highlight) у мемлингов и врагов — стиль «D · Микс» (задача 5.4).
-- У Roblox на экране не больше 31 Highlight одновременно, поэтому контур получают не все, а по очереди:
--   1) то, что несёт сам игрок;
--   2) мемлинги на постаментах его участка (атрибут OwnerUserId);
--   3) остальные с тегом StyleConfig.Outline.Tag — ближние, не дальше Outline.Distance.
-- Всего не больше Outline.MaxCount. Highlight создаётся только на этом клиенте, сервер о нём не знает.

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

local function makeOutline(target: Instance): Highlight
	local outline = Instance.new("Highlight")
	outline.Name = "Outline"
	outline.FillTransparency = 1 -- только контур, без заливки
	outline.OutlineColor = style.Color
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded -- сквозь стены не виден
	outline.Adornee = target
	outline.Parent = target
	return outline
end

local function refresh()
	local character = player.Character
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else nil
	local candidates: { Candidate } = {}

	for _, target in ipairs(CollectionService:GetTagged(style.Tag)) do
		local position = getPosition(target)
		if position and target:IsDescendantOf(Workspace) then
			local distance = if eye then (position - eye).Magnitude else 0
			local tier = TIER_NEAR
			if character and target:IsDescendantOf(character) then
				tier = TIER_CARRIED
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
		if not wanted[target] or outline.Parent ~= target then
			outline:Destroy()
			outlines[target] = nil
		end
	end
	for target in pairs(wanted) do
		if not outlines[target] then
			outlines[target] = makeOutline(target)
		end
	end
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
