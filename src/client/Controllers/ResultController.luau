--!strict
-- ResultController: короткий экран результата после эвакуации.
-- Кто принесён (кружок цвета редкости, имя, редкость, доход в секунду), время вылазки, бонус отряда,
-- кнопка «Back to base». Закрывается сам через StyleConfig.Hud.ResultSeconds.
-- Сервер присылает только Id мемлингов, секунды и флаг бонуса (Remotes.ExtractionResult);
-- имена, редкость и доход — из TextConfig и MemelingConfig.
-- Бонус отряда первому в отряде приходит позже (Remotes.SquadBonus) — тогда строка бонуса появляется сама.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local MemelingConfig = require(ReplicatedStorage.Shared.Config.MemelingConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ResultController = {}

local HUD = StyleConfig.Hud
local PADDING = 14

local function addCorner(frame: GuiObject, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = frame
end

local function addStroke(frame: GuiObject)
	local stroke = Instance.new("UIStroke")
	stroke.Color = HUD.Stroke
	stroke.Thickness = HUD.StrokeThickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
end

local function makeText(parent: Instance, text: string, size: number, color: Color3, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = StyleConfig.Fonts.Hud
	label.TextSize = size
	label.TextColor3 = color
	label.Text = text
	label.Size = UDim2.new(1, 0, 0, size + 8)
	label.LayoutOrder = order
	label.Parent = parent
	return label
end

local function formatClock(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- Строка мемлинга: кружок цвета редкости и «имя · редкость · +N/s»
local function makeRow(parent: Instance, memelingId: string, order: number)
	local memeling = MemelingConfig.Memelings[memelingId]
	if memeling == nil then
		return
	end
	local rarity = MemelingConfig.Rarities[memeling.Rarity]
	local style = StyleConfig.Memeling.Rarities[memeling.Rarity]

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, HUD.ResultRowHeight)
	row.LayoutOrder = order
	row.Parent = parent

	local dotSize = HUD.ResultRowHeight - 10
	local dot = Instance.new("Frame")
	dot.BackgroundColor3 = if style then style.Color else HUD.BaseCard
	dot.BorderSizePixel = 0
	dot.Position = UDim2.fromOffset(0, 5)
	dot.Size = UDim2.fromOffset(dotSize, dotSize)
	dot.Parent = row
	addCorner(dot, UDim.new(1, 0))
	addStroke(dot)

	local text = makeText(
		row,
		string.format(
			TextConfig.ResultRow,
			TextConfig.MemelingNames[memelingId] or memelingId,
			TextConfig.RarityNames[memeling.Rarity] or memeling.Rarity,
			if rarity then rarity.AuraPerSecond else 0
		),
		HUD.ResultRowSize,
		HUD.TextDark,
		0
	)
	text.Position = UDim2.fromOffset(dotSize + 10, 0)
	text.Size = UDim2.new(1, -(dotSize + 10), 1, 0)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = HUD.ResultRowSize
	limit.Parent = text
end

function ResultController.Start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "ExtractionResult"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20 -- поверх HUD
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel: Frame? = nil
	local squadLine: TextLabel? = nil
	local showToken = 0

	local function close()
		if panel then
			panel:Destroy()
			panel = nil
			squadLine = nil
		end
	end

	local function showSquad()
		if squadLine then
			squadLine.Visible = true
		end
	end

	local function open(memelingIds: { string }, raidSeconds: number, squad: boolean)
		close()
		showToken += 1
		local token = showToken

		local frame = Instance.new("Frame")
		frame.Name = "Panel"
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.45)
		frame.Size = UDim2.new(0.9, 0, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.BackgroundColor3 = HUD.ResultPanel
		frame.BorderSizePixel = 0
		frame.Parent = gui
		addCorner(frame, UDim.new(0, HUD.CornerRadius))
		addStroke(frame)
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize = Vector2.new(HUD.ResultWidth, math.huge)
		limit.Parent = frame
		local padding = Instance.new("UIPadding")
		for _, side in ipairs({ "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" }) do
			(padding :: any)[side] = UDim.new(0, PADDING)
		end
		padding.Parent = frame
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 6)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Parent = frame

		makeText(frame, TextConfig.ResultTitle, HUD.ResultTitleSize, HUD.ResultTitleColor, 1)
		if #memelingIds == 0 then
			makeText(frame, TextConfig.ResultEmpty, HUD.ResultRowSize, HUD.TextDark, 2)
		end
		for i, memelingId in ipairs(memelingIds) do
			makeRow(frame, memelingId, 1 + i)
		end
		makeText(frame, string.format(TextConfig.ResultTime, formatClock(raidSeconds)), HUD.ResultRowSize - 4, HUD.TextDark, 50).TextTransparency = 0.25
		local squadText = makeText(
			frame,
			string.format(TextConfig.ResultSquad, EconomyConfig.SquadBonus.SellBonusPercent),
			HUD.ResultRowSize,
			HUD.ResultTitleColor,
			51
		)
		squadText.Visible = squad
		squadLine = squadText

		local button = Instance.new("TextButton")
		button.Name = "BackToBase"
		button.LayoutOrder = 60
		button.Size = UDim2.new(1, 0, 0, HUD.ResultButtonHeight)
		button.BackgroundColor3 = HUD.ResultButton
		button.BorderSizePixel = 0
		button.Font = StyleConfig.Fonts.Hud
		button.TextSize = HUD.ResultRowSize
		button.TextColor3 = HUD.TextDark
		button.Text = TextConfig.ResultBack
		button.Parent = frame
		addCorner(button, UDim.new(1, 0))
		addStroke(button)
		button.Activated:Connect(close)

		panel = frame
		task.delay(HUD.ResultSeconds, function()
			if token == showToken then
				close()
			end
		end)
	end

	local folder = ReplicatedStorage:WaitForChild(Remotes.Folder)
	local result = folder:WaitForChild(Remotes.ExtractionResult)
	if result:IsA("RemoteEvent") then
		result.OnClientEvent:Connect(function(memelingIds: unknown, raidSeconds: unknown, squad: unknown)
			if type(memelingIds) ~= "table" or type(raidSeconds) ~= "number" then
				return
			end
			local ids: { string } = {}
			for _, id in ipairs(memelingIds :: { any }) do
				if type(id) == "string" then
					table.insert(ids, id)
				end
			end
			open(ids, raidSeconds, squad == true)
		end)
	end

	-- Бонус отряда пришёл, пока экран открыт (напарник эвакуировался чуть позже)
	local squadBonus = folder:WaitForChild(Remotes.SquadBonus)
	if squadBonus:IsA("RemoteEvent") then
		squadBonus.OnClientEvent:Connect(showSquad)
	end
end

return ResultController
