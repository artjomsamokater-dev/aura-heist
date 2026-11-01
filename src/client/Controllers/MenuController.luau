--!strict
-- MenuController: меню (задача 7.8). Круглая кнопка-иконка в верхней полосе Roblox — справа от системных
-- кнопок (меню, чат, микрофон), того же размера и на той же линии; место считается от GuiService.TopbarInset
-- (свободная часть полосы) и не пересекается с HUD, таймером рестока и плашкой BOUNTY. Открывает панель: Base, Collection, Upgrades, Rebirth, Shop; Quests и Daily rewards —
-- закрытые пункты с замком «Soon». Base / Upgrades / Rebirth — панели только для чтения: покупки и Rebirth
-- по-прежнему на кнопках участка (механика не менялась). Данные — атрибуты игрока от сервера
-- (StudioIndex, PedestalMemelings, ReserveCount, BaseIncome / BaseStored / BaseStorageCap, UpgradeLevel_<id>,
-- Rebirths, BankedAura); цены и значения клиент считает теми же общими формулами (UpgradeValues, RebirthMath).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local UpgradeValues = require(ReplicatedStorage.Shared.Util.UpgradeValues)
local RebirthMath = require(ReplicatedStorage.Shared.Util.RebirthMath)
local formatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Icons = require(ReplicatedStorage.Shared.Ui.Icons)
local Windows = require(script.Parent.Parent.Ui.Windows)

local MenuController = {}

local player = Players.LocalPlayer
local UI = StyleConfig.MenuUi
local HUD = StyleConfig.Hud

-- Пункты меню по порядку: окно, иконка; Locked — «скоро»
local ITEMS: { { Id: string, Icon: string, Locked: boolean? } } = {
	{ Id = "Base", Icon = "Home" },
	{ Id = "Collection", Icon = "Book" },
	{ Id = "Upgrades", Icon = "ArrowUp" },
	{ Id = "Rebirth", Icon = "Star" },
	{ Id = "Shop", Icon = "Shop" },
	{ Id = "Quests", Icon = "Scroll", Locked = true },
	{ Id = "Daily", Icon = "Gift", Locked = true },
}

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
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function readNumber(name: string): number
	return tonumber(player:GetAttribute(name)) or 0
end

local function level(id: string): number
	return readNumber("UpgradeLevel_" .. id)
end

-- На маленьком экране панели уменьшаются, чтобы влезть
local function addFit(target: GuiObject, width: number, height: number)
	local scale = Instance.new("UIScale")
	scale.Parent = target
	local function fit()
		local camera = Workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			scale.Scale = math.min(1, (viewport.X - 24) / width, (viewport.Y - 24) / height)
		end
	end
	fit()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
end

-- Значение улучшения на уровне (для подписи): постаменты, слоты или множитель хранилища
local function upgradeValue(id: string, at: number): number
	if id == "pedestals" then
		return UpgradeValues.PedestalCount(at)
	elseif id == "carrySlots" then
		return UpgradeValues.CarrySlots(at)
	end
	return math.floor(UpgradeValues.StorageSeconds(at) / UpgradeConfig.Storage.StartSeconds)
end

-- Панель-окно для чтения: заголовок, строки текста, кнопка X. Вернёт (setOpen, функция строк)
type InfoPanel = { Gui: ScreenGui, Lines: Frame }
local function makeInfoPanel(playerGui: Instance, name: string, title: string): InfoPanel
	local gui = Instance.new("ScreenGui")
	gui.Name = "Menu" .. name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 15
	gui.Enabled = false
	gui.Parent = playerGui
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(UI.InfoWidth, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = UI.Panel
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, HUD.CornerRadius))
	stroke(panel, HUD.Stroke, HUD.StrokeThickness)
	addFit(panel, UI.InfoWidth, 380)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingBottom = UDim.new(0, 14)
	padding.Parent = panel

	local header = Instance.new("Frame")
	header.LayoutOrder = 0
	header.Size = UDim2.new(1, 0, 0, 48)
	header.BackgroundColor3 = UI.Header
	header.BorderSizePixel = 0
	header.Parent = panel
	corner(header, UDim.new(0, HUD.CornerRadius))
	local titleLabel = label(header, title, 26, UI.HeaderText)
	titleLabel.Position = UDim2.fromOffset(16, 0)
	titleLabel.Size = UDim2.new(1, -70, 1, 0)
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -8, 0.5, 0)
	close.Size = UDim2.fromOffset(36, 36)
	close.BackgroundColor3 = HUD.IconBubble
	close.Font = StyleConfig.Fonts.Hud
	close.TextSize = 20
	close.TextColor3 = HUD.TextDark
	close.Text = "X"
	close.Parent = header
	corner(close, UDim.new(1, 0))
	stroke(close, HUD.Stroke, 2)
	close.Activated:Connect(function()
		Windows.Close(name)
	end)

	local lines = Instance.new("Frame")
	lines.LayoutOrder = 1
	lines.BackgroundTransparency = 1
	lines.Size = UDim2.new(1, 0, 0, 0)
	lines.AutomaticSize = Enum.AutomaticSize.Y
	lines.Parent = panel
	local linePadding = Instance.new("UIPadding")
	linePadding.PaddingLeft = UDim.new(0, 18)
	linePadding.PaddingRight = UDim.new(0, 18)
	linePadding.Parent = lines
	local lineLayout = Instance.new("UIListLayout")
	lineLayout.SortOrder = Enum.SortOrder.LayoutOrder
	lineLayout.Padding = UDim.new(0, 4)
	lineLayout.Parent = lines
	return { Gui = gui, Lines = lines }
end

-- Перерисовать строки панели: список { текст, размер, цвет }
local function setLines(panel: InfoPanel, rows: { { Text: string, Size: number?, Color: Color3? } })
	for _, child in ipairs(panel.Lines:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for i, row in ipairs(rows) do
		local size = row.Size or 20
		local line = label(panel.Lines, row.Text, size, row.Color or HUD.TextDark)
		line.LayoutOrder = i
		line.Size = UDim2.new(1, 0, 0, size + 8)
		line.TextWrapped = true
	end
end

local function baseRows(): { { Text: string, Size: number?, Color: Color3? } }
	local plot = readNumber("StudioIndex")
	return {
		{ Text = if plot > 0 then string.format(TextConfig.BasePlot, plot) else TextConfig.BaseNoPlot, Size = 24 },
		{ Text = string.format(TextConfig.BasePedestals, readNumber("PedestalMemelings"), UpgradeValues.PedestalCount(level("pedestals"))) },
		{ Text = string.format(TextConfig.BaseReserve, readNumber("ReserveCount")) },
		{ Text = string.format(TextConfig.BaseIncome, formatNumber(readNumber("BaseIncome"))) },
		{ Text = string.format(TextConfig.BaseStorage, formatNumber(readNumber("BaseStored")), formatNumber(readNumber("BaseStorageCap"))) },
		{ Text = TextConfig.BaseHint, Size = 16, Color = UI.Hint },
	}
end

local function upgradeRows(): { { Text: string, Size: number?, Color: Color3? } }
	local rows: { { Text: string, Size: number?, Color: Color3? } } = {}
	for _, id in ipairs(UpgradeValues.GetIds()) do
		local at = level(id)
		local nextCost = UpgradeValues.NextCost(id, at)
		table.insert(rows, { Text = TextConfig.UpgradeNames[id] or id, Size = 24 })
		table.insert(rows, {
			Text = string.format(TextConfig.UpgradeValues[id] or "%d", upgradeValue(id, at))
				.. " · "
				.. string.format(TextConfig.UpgradeLevel, at, UpgradeValues.MaxLevel(id)),
			Size = 18,
		})
		table.insert(rows, {
			Text = if nextCost then string.format(TextConfig.UpgradeNext, formatNumber(nextCost)) else TextConfig.UpgradeMaxed,
			Size = 18,
			Color = if nextCost then UI.Hint else UI.Good,
		})
	end
	table.insert(rows, { Text = TextConfig.UpgradesHint, Size = 16, Color = UI.Hint })
	return rows
end

local function rebirthRows(): { { Text: string, Size: number?, Color: Color3? } }
	local cfg = EconomyConfig.Rebirth
	local rebirths = readNumber("Rebirths")
	local cost = RebirthMath.Cost(rebirths, cfg.BaseCost, cfg.CostGrowth)
	local allMaxed = true
	for _, id in ipairs(UpgradeValues.GetIds()) do
		if UpgradeValues.NextCost(id, level(id)) ~= nil then
			allMaxed = false
		end
	end
	local status = if not allMaxed
		then TextConfig.RebirthNeedMax
		elseif readNumber("BankedAura") < cost then TextConfig.RebirthNeedAura
		else TextConfig.RebirthReady
	local ready = RebirthMath.CanRebirth(allMaxed, readNumber("BankedAura"), cost)
	return {
		{ Text = string.format(TextConfig.RebirthCount, rebirths), Size = 24 },
		{ Text = string.format(TextConfig.RebirthBonus, rebirths * cfg.IncomeBonusPercent) },
		{ Text = string.format(TextConfig.RebirthCost, formatNumber(cost)) },
		{ Text = status, Color = if ready then UI.Good else UI.Hint },
		{ Text = TextConfig.RebirthHint, Size = 16, Color = UI.Hint },
	}
end

function MenuController.Start()
	local playerGui = player:WaitForChild("PlayerGui")

	-- Панели для чтения: строки обновляются при открытии и когда меняются атрибуты
	local panels: { [string]: { Panel: InfoPanel, Rows: () -> { { Text: string, Size: number?, Color: Color3? } } } } = {
		Base = { Panel = makeInfoPanel(playerGui, "Base", TextConfig.BaseTitle), Rows = baseRows },
		Upgrades = { Panel = makeInfoPanel(playerGui, "Upgrades", TextConfig.UpgradesTitle), Rows = upgradeRows },
		Rebirth = { Panel = makeInfoPanel(playerGui, "Rebirth", TextConfig.RebirthTitle), Rows = rebirthRows },
	}
	for name, entry in panels do
		Windows.Register(name, function(open: boolean)
			entry.Panel.Gui.Enabled = open
			if open then
				setLines(entry.Panel, entry.Rows())
			end
		end)
	end
	local watched = { "StudioIndex", "PedestalMemelings", "ReserveCount", "BaseIncome", "BaseStored", "BaseStorageCap", "Rebirths", "BankedAura" }
	for _, id in ipairs(UpgradeValues.GetIds()) do
		table.insert(watched, "UpgradeLevel_" .. id)
	end
	for _, attribute in ipairs(watched) do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			for _, entry in panels do
				if entry.Panel.Gui.Enabled then
					setLines(entry.Panel, entry.Rows())
				end
			end
		end)
	end

	-- Кнопка меню слева по центру высоты и панель пунктов рядом с ней
	local gui = Instance.new("ScreenGui")
	gui.Name = "Menu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None -- координаты от края экрана: так же считается TopbarInset
	gui.DisplayOrder = 10
	gui.Parent = playerGui

	local toggle = Instance.new("TextButton")
	toggle.Name = "MenuButton"
	toggle.Text = ""
	toggle.BackgroundColor3 = UI.ButtonColor
	toggle.Parent = gui
	corner(toggle, UDim.new(1, 0))
	stroke(toggle, HUD.Stroke, 2)
	local icon = Icons.Make("Menu", toggle)
	icon.Size = UDim2.fromScale(0.62, 0.62)

	local listHeight = #ITEMS * (UI.ItemHeight + 6) + 62
	local list = Instance.new("Frame")
	list.Name = "MenuPanel"
	list.Size = UDim2.fromOffset(UI.PanelWidth, listHeight)
	list.BackgroundColor3 = UI.Panel
	list.BorderSizePixel = 0
	list.Visible = false
	list.Parent = gui
	corner(list, UDim.new(0, HUD.CornerRadius))
	stroke(list, HUD.Stroke, HUD.StrokeThickness)
	addFit(list, UI.PanelWidth + HUD.Margin, listHeight + 80)

	-- Кнопка — в свободной части верхней полосы Roblox (TopbarInset: справа от системных кнопок), размер —
	-- как у системных кнопок (доля высоты полосы), по центру полосы по высоте, отступ слева TopbarGap.
	-- Панель пунктов открывается под кнопкой. Полосы нет (скрыта) — верх экрана с отступом HUD.Margin
	local function placeButton()
		local inset = GuiService.TopbarInset
		local height = if inset.Height > 0 then inset.Height else GuiService:GetGuiInset().Y
		local size = math.floor(height * UI.TopbarButtonShare)
		if height <= 0 then
			height, size = UI.ButtonSize + HUD.Margin * 2, UI.ButtonSize
		end
		local left = if inset.Width > 0 then inset.Min.X else HUD.Margin
		local top = inset.Min.Y + math.floor((height - size) / 2)
		toggle.Size = UDim2.fromOffset(size, size)
		toggle.Position = UDim2.fromOffset(left + UI.TopbarGap, top)
		list.Position = UDim2.fromOffset(left + UI.TopbarGap, inset.Min.Y + height + UI.TopbarGap)
	end
	placeButton()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeButton)
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(placeButton)
	end
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 6)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Parent = list
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 8)
	listPadding.Parent = list
	local title = label(list, TextConfig.MenuTitle, 24, UI.HeaderText)
	title.LayoutOrder = 0
	title.Size = UDim2.new(1, -24, 0, 36)
	title.TextXAlignment = Enum.TextXAlignment.Center

	local function setMenuOpen(open: boolean)
		list.Visible = open
	end
	toggle.Activated:Connect(function()
		setMenuOpen(not list.Visible)
	end)

	for i, item in ipairs(ITEMS) do
		local button = Instance.new("TextButton")
		button.LayoutOrder = i
		button.Text = ""
		button.Size = UDim2.new(1, -20, 0, UI.ItemHeight)
		button.BackgroundColor3 = if item.Locked then UI.ItemLocked else UI.Item
		button.AutoButtonColor = not item.Locked
		button.Parent = list
		corner(button, UDim.new(0, 12))
		stroke(button, HUD.Stroke, 2)
		local iconSlot = Instance.new("Frame")
		iconSlot.BackgroundTransparency = 1
		iconSlot.Position = UDim2.fromOffset(6, 3)
		iconSlot.Size = UDim2.fromOffset(UI.ItemHeight - 6, UI.ItemHeight - 6)
		iconSlot.Parent = button
		Icons.Make(if item.Locked then "Lock" else item.Icon, iconSlot)
		local text = label(button, TextConfig.MenuItems[item.Id] or item.Id, 20, HUD.TextDark)
		text.Position = UDim2.fromOffset(UI.ItemHeight + 4, 0)
		text.Size = UDim2.new(1, -UI.ItemHeight - 8, 1, 0)
		if item.Locked then
			text.TextTransparency = 0.35
			local soon = label(button, TextConfig.MenuSoon, 16, HUD.TextDark)
			soon.AnchorPoint = Vector2.new(1, 0)
			soon.Position = UDim2.new(1, -10, 0, 0)
			soon.Size = UDim2.new(0, 60, 1, 0)
			soon.TextXAlignment = Enum.TextXAlignment.Right
		else
			button.Activated:Connect(function()
				setMenuOpen(false)
				Windows.Open(item.Id)
			end)
		end
	end
end

return MenuController
