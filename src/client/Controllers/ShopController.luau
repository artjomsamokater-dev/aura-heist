--!strict
-- ShopController: окно магазина косметики (задача 7.4). Открывается кнопкой SHOP слева на экране
-- и кнопкой «Open shop» у киоска на площади. Вкладки — категории ShopConfig, карточки — вещи по цене.
-- Клиент только показывает и просит: Remotes.ShopBuy / ShopEquip с Id вещи. Цену проверяет и Aura
-- списывает сервер (сервис Shop); что куплено и надето, клиент читает из атрибутов ShopOwned / ShopEquipped.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local ShopRule = require(ReplicatedStorage.Shared.Util.ShopRule)
local formatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Icons = require(ReplicatedStorage.Shared.Ui.Icons)

local ShopController = {}

local player = Players.LocalPlayer
local UI = StyleConfig.ShopUi
local HUD = StyleConfig.Hud

local function corner(target: GuiObject, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = target
end

local function stroke(target: GuiObject, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = target
end

local function label(parent: Instance, text: string, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = StyleConfig.Fonts.Hud
	l.TextSize = size
	l.TextColor3 = color
	l.Text = text
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, color: Color3, size: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Font = StyleConfig.Fonts.Hud
	b.TextSize = 18
	b.TextColor3 = HUD.TextDark
	b.Text = text
	b.Size = size
	b.Parent = parent
	corner(b, UDim.new(0, 10))
	stroke(b, HUD.Stroke, 2)
	return b
end

local function readList(name: string): { string }
	local value = player:GetAttribute(name)
	return if type(value) == "string" then ShopRule.Split(value) else {}
end

function ShopController.Start()
	local playerGui = player:WaitForChild("PlayerGui")
	local folder = ReplicatedStorage:WaitForChild(Remotes.Folder)
	local buyEvent = folder:WaitForChild(Remotes.ShopBuy)
	local equipEvent = folder:WaitForChild(Remotes.ShopEquip)

	-- Окно
	local gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 15
	gui.Enabled = false
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(UI.Width, UI.Height)
	panel.BackgroundColor3 = UI.Panel
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, HUD.CornerRadius))
	stroke(panel, HUD.Stroke, HUD.StrokeThickness)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function fit()
		local camera = Workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			scale.Scale = math.min(1, (viewport.X - 24) / UI.Width, (viewport.Y - 24) / UI.Height)
		end
	end
	fit()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 48)
	header.BackgroundColor3 = UI.Header
	header.BorderSizePixel = 0
	header.Parent = panel
	corner(header, UDim.new(0, HUD.CornerRadius))
	local title = label(header, TextConfig.ShopTitle, 28, UI.HeaderText)
	title.Position = UDim2.fromOffset(16, 0)
	title.Size = UDim2.new(0, 120, 1, 0)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local auraIcon = Instance.new("Frame")
	auraIcon.BackgroundTransparency = 1
	auraIcon.Position = UDim2.new(1, -230, 0.5, -15)
	auraIcon.Size = UDim2.fromOffset(30, 30)
	auraIcon.Parent = header
	Icons.Make("Aura", auraIcon)
	local balance = label(header, "", 22, UI.HeaderText)
	balance.Position = UDim2.new(1, -195, 0, 0)
	balance.Size = UDim2.new(0, 130, 1, 0)
	balance.TextXAlignment = Enum.TextXAlignment.Left
	local close = button(header, "X", UI.UnequipButton, UDim2.fromOffset(36, 36))
	close.Position = UDim2.new(1, -44, 0.5, -18)

	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.Position = UDim2.fromOffset(12, 56)
	tabs.Size = UDim2.new(1, -24, 0, 36)
	tabs.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabs

	local info = label(panel, "", 14, HUD.TextDark)
	info.Position = UDim2.fromOffset(14, 96)
	info.Size = UDim2.new(1, -28, 0, 18)
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.TextTransparency = 0.25

	local grid = Instance.new("ScrollingFrame")
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(12, 118)
	grid.Size = UDim2.new(1, -24, 1, -128)
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollBarThickness = 6
	grid.Parent = panel
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(UI.CardSize.X, UI.CardSize.Y)
	gridLayout.CellPadding = UDim2.fromOffset(8, 8)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	local current = ShopConfig.CategoryOrder[1]
	local tabButtons: { [string]: TextButton } = {}

	local function itemsOf(category: string): { string }
		local ids = {}
		for id, item in ShopConfig.Items do
			if item.Category == category then
				table.insert(ids, id)
			end
		end
		table.sort(ids, function(a: string, b: string): boolean
			return ShopConfig.Items[a].Price < ShopConfig.Items[b].Price
		end)
		return ids
	end

	local function refresh()
		local owned = readList("ShopOwned")
		local equipped = readList("ShopEquipped")
		local aura = tonumber(player:GetAttribute("BankedAura")) or 0
		balance.Text = formatNumber(aura)
		for category, tab in tabButtons do
			tab.BackgroundColor3 = if category == current then UI.TabActive else UI.Tab
		end
		local onCount = 0
		for _, id in ipairs(equipped) do
			local item = ShopConfig.Items[id]
			if item and item.Category == current then
				onCount += 1
			end
		end
		info.Text = string.format(TextConfig.ShopSlots, onCount, ShopConfig.Categories[current].MaxEquipped) .. " · " .. TextConfig.ShopNote

		for _, child in ipairs(grid:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for order, id in ipairs(itemsOf(current)) do
			local item = ShopConfig.Items[id]
			local isOwned = table.find(owned, id) ~= nil
			local isOn = table.find(equipped, id) ~= nil
			local card = Instance.new("Frame")
			card.LayoutOrder = order
			card.BackgroundColor3 = UI.Card
			card.BorderSizePixel = 0
			card.Parent = grid
			corner(card, UDim.new(0, 12))
			stroke(card, if isOn then UI.TabActive else UI.CardStroke, if isOn then 3 else 2)

			local swatch = Instance.new("Frame")
			swatch.Position = UDim2.fromOffset(8, 8)
			swatch.Size = UDim2.new(1, -16, 0, 34)
			swatch.BackgroundColor3 = (StyleConfig.Cosmetics[id] or { Preview = UI.Tab }).Preview
			swatch.BorderSizePixel = 0
			swatch.Parent = card
			corner(swatch, UDim.new(0, 8))

			local name = label(card, TextConfig.ShopItemNames[id] or id, 16, HUD.TextDark)
			name.Position = UDim2.fromOffset(8, 46)
			name.Size = UDim2.new(1, -16, 0, 20)
			name.TextScaled = true

			local priceText = if isOn then TextConfig.ShopEquippedTag elseif isOwned then TextConfig.ShopOwnedTag else formatNumber(item.Price)
			local price = label(card, priceText, 15, HUD.TextDark)
			price.Position = UDim2.fromOffset(8, 68)
			price.Size = UDim2.new(1, -16, 0, 18)

			local action = if not isOwned then TextConfig.ShopBuy elseif isOn then TextConfig.ShopUnequip else TextConfig.ShopEquip
			local color = if not isOwned then (if aura >= item.Price then UI.BuyButton else UI.DisabledButton)
				elseif isOn then UI.UnequipButton
				else UI.EquipButton
			local press = button(card, action, color, UDim2.new(1, -16, 0, 32))
			press.Position = UDim2.new(0, 8, 1, -40)
			press.Activated:Connect(function()
				local event = if isOwned then equipEvent else buyEvent
				if event:IsA("RemoteEvent") then
					event:FireServer(id) -- только Id: цену и Aura проверяет сервер
				end
			end)
		end
	end

	for order, category in ipairs(ShopConfig.CategoryOrder) do
		local tab = button(tabs, TextConfig.ShopCategoryNames[category] or category, UI.Tab, UDim2.fromOffset(92, 34))
		tab.LayoutOrder = order
		tab.TextSize = 15
		tabButtons[category] = tab
		tab.Activated:Connect(function()
			current = category
			refresh()
		end)
	end

	local function setOpen(open: boolean)
		gui.Enabled = open
		if open then
			refresh()
		end
	end
	close.Activated:Connect(function()
		setOpen(false)
	end)
	for _, name in ipairs({ "ShopOwned", "ShopEquipped", "BankedAura" }) do
		player:GetAttributeChangedSignal(name):Connect(function()
			if gui.Enabled then
				refresh()
			end
		end)
	end

	-- Кнопка SHOP слева на экране (по центру высоты — не мешает джойстику и HUD)
	local hudGui = Instance.new("ScreenGui")
	hudGui.Name = "ShopButton"
	hudGui.ResetOnSpawn = false
	hudGui.IgnoreGuiInset = true
	hudGui.Parent = playerGui
	local open = button(hudGui, TextConfig.ShopHudButton, UI.HudButtonColor, UDim2.fromOffset(UI.HudButtonSize, UI.HudButtonSize))
	open.AnchorPoint = Vector2.new(0, 0.5)
	open.Position = UDim2.new(0, HUD.Margin, 0.5, 0)
	open.TextSize = 16
	corner(open, UDim.new(1, 0))
	open.Activated:Connect(function()
		setOpen(not gui.Enabled)
	end)

	-- Кнопка «Open shop» у киоска: сервер её не обрабатывает, окно открывает этот клиент
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "ShopPrompt" then
			setOpen(true)
		end
	end)
end

return ShopController
