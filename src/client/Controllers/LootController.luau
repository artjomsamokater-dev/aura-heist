--!strict
-- LootController: выпавший после смерти лут (задача 6.0).
-- Сервер ставит на ядро выпавшего мемлинга тег StyleConfig.Loot.Tag и атрибуты LootOwnerUserId /
-- LootExpiresAt (время сервера). Этот клиент:
--   • у своего лута — подпись «YOUR LOOT» и обратный отсчёт (видна сквозь стены);
--   • у чужого — прячет у себя кнопку подбора (поднять его всё равно не даст сервер).
-- Золотую подсветку своего лута рисует OutlineController.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)

local LootController = {}

local player = Players.LocalPlayer
local style = StyleConfig.Loot
local LABEL_NAME = "LootLabel"

-- 15.2 секунды → "0:16"
local function formatClock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function isMine(part: Instance): boolean
	return part:GetAttribute("LootOwnerUserId") == player.UserId
end

local function makeLabel(part: Instance): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = LABEL_NAME
	gui.Size = UDim2.fromOffset(style.LabelWidth, style.LabelTextSize * 2 + 8)
	gui.StudsOffsetWorldSpace = Vector3.new(0, style.LabelHeight, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = math.huge
	gui.Parent = part
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = StyleConfig.Fonts.Hud
	text.TextSize = style.LabelTextSize
	text.TextColor3 = style.Color
	text.TextStrokeColor3 = StyleConfig.Label.Stroke
	text.TextStrokeTransparency = 0
	text.Parent = gui
	return text
end

local function refresh()
	local now = Workspace:GetServerTimeNow()
	for _, part in ipairs(CollectionService:GetTagged(style.Tag)) do
		if isMine(part) then
			local gui = part:FindFirstChild(LABEL_NAME)
			local text = if gui then gui:FindFirstChildOfClass("TextLabel") else makeLabel(part)
			local expiresAt = tonumber(part:GetAttribute("LootExpiresAt")) or now
			if text then
				text.Text = string.format(TextConfig.LootLabel, formatClock(expiresAt - now))
			end
		else
			local prompt = part:FindFirstChild("PickupPrompt")
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Enabled = false
			end
		end
	end
end

function LootController.Start()
	-- Лут подняли: тег снят — подпись убираем сразу
	CollectionService:GetInstanceRemovedSignal(style.Tag):Connect(function(part: Instance)
		local gui = part:FindFirstChild(LABEL_NAME)
		if gui then
			gui:Destroy()
		end
	end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(0.2)
		end
	end)
end

return LootController
