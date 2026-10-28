--!strict
-- HudController: HUD слева сверху и указатель на точку эвакуации.
-- Клиент только ЧИТАЕТ атрибуты игрока, которые выставляет сервер:
-- BankedAura (Economy), CarriedCount / CarrySlots / RaidState (Raid). Никаких RemoteEvent.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local formatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)

local HudController = {}

local player = Players.LocalPlayer

-- Все размеры и цвета HUD — в StyleConfig.Hud
local HUD = StyleConfig.Hud
local CARD_WIDTH = HUD.CardWidth
local CAPTION_SIZE = HUD.CaptionSize
local VALUE_SIZE = HUD.ValueSize
local BASE_COLOR = HUD.BaseCard
local HANDS_COLOR = HUD.HandsCard
local TEXT_DARK = HUD.TextDark
local TEXT_LIGHT = HUD.TextLight

local function readNumber(name: string): number
	return tonumber(player:GetAttribute(name)) or 0
end

local function makeLabel(parent: Instance, text: string, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = StyleConfig.Fonts.Hud
	label.TextSize = size
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = UDim2.new(1, 0, 0, size + 4)
	label.Text = text
	label.Parent = parent
	return label
end

-- Цветная карточка: мелкая подпись сверху, крупное значение снизу
local function makeCard(parent: Instance, order: number, color: Color3, textColor: Color3, caption: string): TextLabel
	local card = Instance.new("Frame")
	card.LayoutOrder = order
	card.BackgroundColor3 = color
	card.Size = UDim2.fromOffset(CARD_WIDTH, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = card

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = card

	local captionLabel = makeLabel(card, caption, CAPTION_SIZE, textColor)
	captionLabel.LayoutOrder = 1
	captionLabel.TextTransparency = 0.25
	local valueLabel = makeLabel(card, "", VALUE_SIZE, textColor)
	valueLabel.LayoutOrder = 2
	return valueLabel
end

local function buildHud(playerGui: Instance)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- отступ от панели Roblox считаем сами (см. placeColumn)
	gui.Parent = playerGui

	local column = Instance.new("Frame")
	column.Name = "TopLeft"
	column.BackgroundTransparency = 1
	column.Size = UDim2.fromOffset(CARD_WIDTH, 0)
	column.AutomaticSize = Enum.AutomaticSize.Y
	column.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Parent = column

	-- Ниже панели Roblox и окна чата слева сверху; на маленьком экране HUD чуть меньше
	local function placeColumn()
		local topInset = GuiService:GetGuiInset()
		local chatReserve = if UserInputService.TouchEnabled then HUD.ChatReserveTouch else HUD.ChatReserveDesktop
		column.Position = UDim2.fromOffset(HUD.Margin, topInset.Y + chatReserve)

		local camera = Workspace.CurrentCamera
		local small = camera ~= nil and camera.ViewportSize.Y < HUD.SmallScreenHeight
		scale.Scale = if small then HUD.SmallScreenScale else 1
	end
	placeColumn()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(placeColumn)
	end

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = column

	local baseValue = makeCard(column, 1, BASE_COLOR, TEXT_DARK, TextConfig.HudBaseCaption)
	local handsValue = makeCard(column, 2, HANDS_COLOR, TEXT_LIGHT, TextConfig.HudHandsCaption)

	local function refresh()
		baseValue.Text = string.format(TextConfig.HudBaseValue, formatNumber(readNumber("BankedAura")))
		handsValue.Text =
			string.format(TextConfig.HudHandsValue, readNumber("CarriedCount"), readNumber("CarrySlots"))
	end

	for _, name in ipairs({ "BankedAura", "CarriedCount", "CarrySlots" }) do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
end

-- Указатель на EXTRACT: маркер высоко над площадкой (виден сквозь стены, единственный «поверх всего»)
-- и стрелка у края экрана, когда площадка за кадром. Только в состоянии InRaid.
-- Вблизи маркер прячется, чтобы не закрывать имена мемлингов: площадку и так видно.
local function buildExtractPointer(playerGui: Instance)
	local target = MapConfig.Zone.ExtractionPosition + Vector3.new(0, HUD.MarkerHeight, 0)

	-- Невидимая точка-якорь только на этом клиенте: не зависит от того, загружена ли зона (streaming)
	local anchor = Instance.new("Part")
	anchor.Name = "ExtractMarkerAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = target
	anchor.Parent = Workspace

	local marker = Instance.new("BillboardGui")
	marker.Name = "ExtractMarker"
	marker.Adornee = anchor
	marker.AlwaysOnTop = true
	marker.MaxDistance = math.huge
	marker.Size = UDim2.fromOffset(220, 80) -- в пикселях: одинаково крупно на любом расстоянии
	marker.Enabled = false
	marker.ResetOnSpawn = false
	marker.Parent = playerGui

	local markerLayout = Instance.new("UIListLayout")
	markerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	markerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	markerLayout.Parent = marker

	local title = makeLabel(marker, TextConfig.ExtractMarker, HUD.MarkerTitleSize, TEXT_LIGHT)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextStrokeTransparency = 0
	title.LayoutOrder = 1
	local distance = makeLabel(marker, "", HUD.MarkerDistanceSize, TEXT_LIGHT)
	distance.TextXAlignment = Enum.TextXAlignment.Center
	distance.TextStrokeTransparency = 0
	distance.LayoutOrder = 2

	local edgeGui = Instance.new("ScreenGui")
	edgeGui.Name = "ExtractEdgeArrow"
	edgeGui.IgnoreGuiInset = true -- координаты совпадают с координатами камеры
	edgeGui.ResetOnSpawn = false
	edgeGui.Parent = playerGui

	local arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(HUD.EdgeArrowSize + 14, HUD.EdgeArrowSize + 14)
	arrow.Font = StyleConfig.Fonts.Hud
	arrow.TextSize = HUD.EdgeArrowSize
	arrow.TextColor3 = TEXT_LIGHT
	arrow.TextStrokeTransparency = 0
	arrow.Text = TextConfig.ExtractEdgeArrow
	arrow.Visible = false
	arrow.Parent = edgeGui

	RunService.RenderStepped:Connect(function()
		local inRaid = player:GetAttribute("RaidState") == "InRaid"
		local camera = Workspace.CurrentCamera
		if not inRaid or camera == nil then
			marker.Enabled = false
			arrow.Visible = false
			return
		end

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local far = true
		if root and root:IsA("BasePart") then
			local flatOffset = root.Position - MapConfig.Zone.ExtractionPosition
			local flatDistance = Vector3.new(flatOffset.X, 0, flatOffset.Z).Magnitude
			far = flatDistance > HUD.MarkerHideDistance
			distance.Text = string.format(TextConfig.ExtractMarkerDistance, formatNumber(flatDistance))
		end
		marker.Enabled = far

		local screenPoint, onScreen = camera:WorldToViewportPoint(target)
		if onScreen then
			arrow.Visible = false
			return
		end

		-- Точка за кадром: ставим стрелку на край экрана в её сторону
		local viewport = camera.ViewportSize
		local center = viewport / 2
		local direction = Vector2.new(screenPoint.X, screenPoint.Y) - center
		if screenPoint.Z < 0 then
			direction = -direction -- точка позади камеры: экранные координаты перевёрнуты
		end
		if direction.Magnitude < 1 then
			direction = Vector2.new(0, -1)
		end
		direction = direction.Unit

		local radius = math.min(viewport.X, viewport.Y) / 2 - HUD.EdgePadding
		local position = center + direction * radius
		arrow.Position = UDim2.fromOffset(position.X, position.Y)
		arrow.Rotation = math.deg(math.atan2(direction.Y, direction.X)) + 90 -- «▲» смотрит вверх при 0°
		arrow.Visible = true
	end)
end

function HudController.Start()
	local playerGui = player:WaitForChild("PlayerGui")
	buildHud(playerGui)
	buildExtractPointer(playerGui)
end

return HudController
