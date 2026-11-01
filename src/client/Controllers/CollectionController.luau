--!strict
-- CollectionController: окно коллекции (задача 7.8). Сетка всех мемлингов по зонам (CollectionRule.Sections):
-- открытые — цветное 3D-превью (ViewportFrame), неоткрытые — тёмный силуэт с замком. Нажатие — карточка:
-- крупная модель медленно вращается на подсвеченном постаменте, имя, редкость, доход, цена продажи, скорость
-- с ним, где водится, сколько у игрока. Вверху счётчик «12/27».
-- Модели — шаблоны сервера в ReplicatedStorage.MemelingPreviews. Кого игрок открыл и сколько у него каждого —
-- атрибуты CollectionDiscovered / CollectionOwned (ставит сервис Studio). Клиент только показывает.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local MemelingConfig = require(ReplicatedStorage.Shared.Config.MemelingConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local CollectionRule = require(ReplicatedStorage.Shared.Util.CollectionRule)
local ZoneRule = require(ReplicatedStorage.Shared.Util.ZoneRule)
local formatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Icons = require(ReplicatedStorage.Shared.Ui.Icons)
local Windows = require(script.Parent.Parent.Ui.Windows)

local CollectionController = {}

local player = Players.LocalPlayer
local UI = StyleConfig.CollectionUi
local HUD = StyleConfig.Hud
local FOV = 30 -- угол камеры превью: узкий — меньше искажений

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

local function rarityColor(memelingId: string): Color3
	local memeling = MemelingConfig.Memelings[memelingId]
	local style = memeling and StyleConfig.Memeling.Rarities[memeling.Rarity]
	return if style then style.Color else HUD.TextDark
end

-- 3D-превью: копия шаблона в ViewportFrame и камера спереди (лицо мемлинга смотрит в −Z).
-- Вернёт (ViewportFrame, модель или nil, если шаблона ещё нет)
local function makeViewport(parent: Instance, memelingId: string, extra: Model?): (ViewportFrame, Model?)
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Color3.fromRGB(170, 160, 190)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.LightDirection = Vector3.new(-1, -1.5, 1)
	viewport.Parent = parent
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local previews = ReplicatedStorage:FindFirstChild("MemelingPreviews")
	local template = previews and previews:FindFirstChild(memelingId)
	if template == nil or not template:IsA("Model") then
		return viewport, nil
	end
	local model = template:Clone()
	model:PivotTo(CFrame.new())
	model.Parent = viewport
	if extra then
		extra.Parent = viewport
	end
	local boxCFrame, size = model:GetBoundingBox()
	local center = boxCFrame.Position
	if extra then
		local extraCFrame, extraSize = extra:GetBoundingBox()
		size = Vector3.new(math.max(size.X, extraSize.X), size.Y + extraSize.Y, math.max(size.Z, extraSize.Z))
		center = (center + extraCFrame.Position) / 2
	end
	local radius = math.max(size.X, size.Y, size.Z) / 2
	local distance = radius / math.tan(math.rad(FOV / 2)) * 1.15 + radius
	camera.CFrame = CFrame.lookAt(center + Vector3.new(0, radius * 0.25, -distance), center)
	return viewport, model
end

-- Открыт ли мемлинг: превью цветное или тёмный силуэт (без света — чёрная фигура)
local function setRevealed(viewport: ViewportFrame, revealed: boolean)
	if revealed then
		viewport.Ambient = Color3.fromRGB(170, 160, 190)
		viewport.LightColor = Color3.fromRGB(255, 250, 240)
		viewport.ImageColor3 = Color3.new(1, 1, 1)
	else
		viewport.Ambient = Color3.new(0, 0, 0)
		viewport.LightColor = Color3.new(0, 0, 0)
		viewport.ImageColor3 = UI.Silhouette
	end
end

-- Подсвеченный постамент для карточки: цилиндр и неоновое кольцо цвета редкости под моделью
local function makePedestal(memelingId: string): Model
	local model = Instance.new("Model")
	local bottom = -StyleConfig.Memeling.Size.Y / 2
	local up = CFrame.Angles(0, 0, math.rad(90))
	local base = Instance.new("Part")
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(1.6, 7, 7)
	base.CFrame = CFrame.new(0, bottom - 0.8, 0) * up
	base.Color = UI.PedestalColor
	base.Material = StyleConfig.Material
	base.Anchored = true
	base.Parent = model
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 7.6, 7.6)
	ring.CFrame = CFrame.new(0, bottom - 0.1, 0) * up
	ring.Color = rarityColor(memelingId)
	ring.Material = StyleConfig.GlowMaterial
	ring.Anchored = true
	ring.Parent = model
	return model
end

local function decode(): ({ [string]: boolean }, { [string]: number })
	return CollectionRule.DecodeSet(player:GetAttribute("CollectionDiscovered") :: string?),
		CollectionRule.DecodeCounts(player:GetAttribute("CollectionOwned") :: string?)
end

function CollectionController.Start()
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "Collection"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 15
	gui.Enabled = false
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(UI.Width, UI.Height)
	panel.BackgroundColor3 = UI.Panel
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, HUD.CornerRadius))
	stroke(panel, HUD.Stroke, HUD.StrokeThickness)
	-- На телефоне окно уменьшается, чтобы влезть целиком
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
	header.Size = UDim2.new(1, 0, 0, 50)
	header.BackgroundColor3 = UI.Header
	header.BorderSizePixel = 0
	header.Parent = panel
	corner(header, UDim.new(0, HUD.CornerRadius))
	local title = label(header, TextConfig.CollectionTitle, 28, UI.HeaderText)
	title.Position = UDim2.fromOffset(16, 0)
	title.Size = UDim2.new(0, 220, 1, 0)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local counter = label(header, "", 26, UI.HeaderText)
	counter.AnchorPoint = Vector2.new(1, 0)
	counter.Position = UDim2.new(1, -64, 0, 0)
	counter.Size = UDim2.new(0, 120, 1, 0)
	counter.TextXAlignment = Enum.TextXAlignment.Right
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -10, 0.5, 0)
	close.Size = UDim2.fromOffset(38, 38)
	close.BackgroundColor3 = HUD.IconBubble
	close.Font = StyleConfig.Fonts.Hud
	close.TextSize = 20
	close.TextColor3 = HUD.TextDark
	close.Text = "X"
	close.Parent = header
	corner(close, UDim.new(1, 0))
	stroke(close, HUD.Stroke, 2)

	-- Сетка по зонам
	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.fromOffset(12, 60)
	scroll.Size = UDim2.new(1, -24, 1, -72)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = HUD.Stroke
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = panel
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = scroll

	-- Карточка поверх сетки
	local card = Instance.new("Frame")
	card.Position = UDim2.fromOffset(12, 60)
	card.Size = UDim2.new(1, -24, 1, -72)
	card.BackgroundColor3 = UI.CardBack
	card.BorderSizePixel = 0
	card.Visible = false
	card.Parent = panel
	corner(card, UDim.new(0, HUD.CornerRadius))
	local stage = Instance.new("Frame")
	stage.BackgroundTransparency = 1
	stage.Position = UDim2.fromOffset(8, 8)
	stage.Size = UDim2.new(0.5, -12, 1, -16)
	stage.Parent = card
	local info = Instance.new("Frame")
	info.BackgroundTransparency = 1
	info.Position = UDim2.new(0.5, 8, 0, 12)
	info.Size = UDim2.new(0.5, -20, 1, -24)
	info.Parent = card
	local infoList = Instance.new("UIListLayout")
	infoList.SortOrder = Enum.SortOrder.LayoutOrder
	infoList.Padding = UDim.new(0, 4)
	infoList.Parent = info
	local function infoLine(order: number, size: number): TextLabel
		local line = label(info, "", size, HUD.TextDark)
		line.LayoutOrder = order
		line.Size = UDim2.new(1, 0, 0, size + 6)
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.TextWrapped = true
		return line
	end
	local nameLine = infoLine(1, 28)
	local rarityLine = infoLine(2, 22)
	local incomeLine = infoLine(3, 20)
	local sellLine = infoLine(4, 20)
	local speedLine = infoLine(5, 20)
	local whereLine = infoLine(6, 20)
	local ownedLine = infoLine(7, 20)
	local back = Instance.new("TextButton")
	back.LayoutOrder = 10
	back.Size = UDim2.new(1, 0, 0, 44)
	back.BackgroundColor3 = HUD.BaseCard
	back.Font = StyleConfig.Fonts.Hud
	back.TextSize = 22
	back.TextColor3 = HUD.TextDark
	back.Text = TextConfig.CollectionBack
	back.Parent = info
	corner(back, UDim.new(1, 0))
	stroke(back, HUD.Stroke, 2)

	local spinning: Model? = nil
	local spinAngle = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local model = spinning
		if model and card.Visible and gui.Enabled then
			spinAngle += dt * 2 * math.pi / UI.SpinSeconds
			model:PivotTo(CFrame.Angles(0, spinAngle, 0))
		end
	end)

	local function showCard(memelingId: string)
		local memeling = MemelingConfig.Memelings[memelingId]
		if memeling == nil then
			return
		end
		local discovered, owned = decode()
		local open = discovered[memelingId] == true
		for _, child in ipairs(stage:GetChildren()) do
			child:Destroy()
		end
		local viewport, model = makeViewport(stage, memelingId, makePedestal(memelingId))
		setRevealed(viewport, open)
		spinning = model
		spinAngle = 0

		local rarity = MemelingConfig.Rarities[memeling.Rarity]
		nameLine.Text = if open then TextConfig.MemelingNames[memelingId] or memelingId else TextConfig.CollectionUnknown
		rarityLine.Text = TextConfig.RarityNames[memeling.Rarity] or memeling.Rarity
		rarityLine.TextColor3 = rarityColor(memelingId)
		local income = (if rarity then rarity.AuraPerSecond else 0) * ZoneRule.IncomeMultiplier(memeling)
		incomeLine.Text = string.format(TextConfig.CollectionIncome, formatNumber(income))
		sellLine.Text = string.format(TextConfig.CollectionSell, formatNumber(if rarity then rarity.SellPrice else 0))
		speedLine.Text = string.format(TextConfig.CollectionSpeed, if rarity then rarity.CarrySpeed else 0)
		local zone = memeling.Zone
		whereLine.Text = if zone then string.format(TextConfig.CollectionWhere, TextConfig.ZoneNames[zone] or zone) else TextConfig.CollectionWhereSecret
		ownedLine.Text = if open then string.format(TextConfig.CollectionOwned, owned[memelingId] or 0) else TextConfig.CollectionLocked
		-- У неоткрытого — только редкость и где искать: остальное узнаешь, когда вынесешь
		incomeLine.Visible = open
		sellLine.Visible = open
		speedLine.Visible = open
		card.Visible = true
		scroll.Visible = false
	end

	local function hideCard()
		card.Visible = false
		scroll.Visible = true
		spinning = nil
	end
	back.Activated:Connect(hideCard)

	-- Плитки строятся при первом открытии: 27 превью сразу при входе в игру не нужны
	type Tile = { Viewport: ViewportFrame, Lock: Frame, Name: TextLabel }
	local tiles: { [string]: Tile } = {}
	local built = false

	local function refresh()
		local discovered, _ = decode()
		local opened, total = CollectionRule.Progress(discovered, MemelingConfig.Memelings :: any)
		counter.Text = string.format(TextConfig.CollectionCounter, opened, total)
		for memelingId, tile in tiles do
			local open = discovered[memelingId] == true
			setRevealed(tile.Viewport, open)
			tile.Lock.Visible = not open
			tile.Name.Text = if open then TextConfig.MemelingNames[memelingId] or memelingId else TextConfig.CollectionUnknown
		end
	end

	local function build()
		built = true
		ReplicatedStorage:WaitForChild("MemelingPreviews", 10)
		local sections = CollectionRule.Sections(MemelingConfig.Memelings :: any, ZoneConfig.ZoneOrder, MemelingConfig.RarityOrder)
		for s, section in ipairs(sections) do
			local heading = label(scroll, if section.Zone then TextConfig.ZoneNames[section.Zone] or section.Zone else TextConfig.CollectionSecretSection, 22, UI.Section)
			heading.LayoutOrder = s * 2 - 1
			heading.Size = UDim2.new(1, 0, 0, 28)
			heading.TextXAlignment = Enum.TextXAlignment.Left
			local grid = Instance.new("Frame")
			grid.LayoutOrder = s * 2
			grid.BackgroundTransparency = 1
			grid.Size = UDim2.new(1, 0, 0, 0)
			grid.AutomaticSize = Enum.AutomaticSize.Y
			grid.Parent = scroll
			local layout = Instance.new("UIGridLayout")
			layout.CellSize = UDim2.fromOffset(UI.TileSize, UI.TileSize + 24)
			layout.CellPadding = UDim2.fromOffset(8, 8)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = grid
			for i, memelingId in ipairs(section.Ids) do
				local button = Instance.new("TextButton")
				button.LayoutOrder = i
				button.Text = ""
				button.AutoButtonColor = true
				button.BackgroundColor3 = UI.Tile
				button.Parent = grid
				corner(button, UDim.new(0, 12))
				stroke(button, rarityColor(memelingId), 3)
				local holder = Instance.new("Frame")
				holder.BackgroundTransparency = 1
				holder.Size = UDim2.fromOffset(UI.TileSize, UI.TileSize)
				holder.Parent = button
				local viewport = makeViewport(holder, memelingId, nil)
				local lock = Instance.new("Frame")
				lock.BackgroundTransparency = 1
				lock.AnchorPoint = Vector2.new(0.5, 0.5)
				lock.Position = UDim2.fromScale(0.5, 0.5)
				lock.Size = UDim2.fromOffset(UI.TileSize * 0.4, UI.TileSize * 0.4)
				lock.ZIndex = 3
				lock.Parent = holder
				Icons.Make("Lock", lock)
				local name = label(button, "", 14, HUD.TextDark)
				name.Position = UDim2.fromOffset(4, UI.TileSize)
				name.Size = UDim2.new(1, -8, 0, 22)
				name.TextScaled = true
				tiles[memelingId] = { Viewport = viewport, Lock = lock, Name = name }
				button.Activated:Connect(function()
					showCard(memelingId)
				end)
			end
		end
		refresh()
	end

	local function setOpen(open: boolean)
		gui.Enabled = open
		if open then
			if not built then
				build()
			end
			hideCard()
			refresh()
		else
			spinning = nil
		end
	end
	Windows.Register("Collection", setOpen)
	close.Activated:Connect(function()
		Windows.Close("Collection")
	end)
	for _, name in ipairs({ "CollectionDiscovered", "CollectionOwned" }) do
		player:GetAttributeChangedSignal(name):Connect(function()
			if gui.Enabled then
				refresh()
			end
		end)
	end
end

return CollectionController
