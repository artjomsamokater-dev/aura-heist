--!strict
-- ActionButtonsController: крупные круглые кнопки действий — справа, над кнопкой прыжка,
-- поэтому не перекрывают ни джойстик (слева), ни прыжок. Появляются только когда нужны:
--   Drop    — в зоне, если в руках есть мемлинги: отпустить последнего (клавиша G на компьютере).
--             Решает сервер (Remotes.DropCarried через RemoteGuard), мемлинг вернётся на свою точку.
--   Extract — в зоне, когда площадка EXTRACT рядом: персонаж сам идёт на неё.
--             Эвакуацию по-прежнему засчитывает сервер по позиции; на площадке кнопка показывает «Hold...».

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ActionButtonsController = {}

local HUD = StyleConfig.Hud
local DROP_KEY = Enum.KeyCode.G
local MARGIN = 24 -- отступ от края экрана, если кнопки прыжка нет (компьютер)

local player = Players.LocalPlayer

local function getRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function makeButton(parent: Instance, color: Color3, order: number): TextButton
	local button = Instance.new("TextButton")
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(HUD.ActionButtonSize, HUD.ActionButtonSize)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = StyleConfig.Fonts.Hud
	button.TextSize = HUD.ActionTextSize
	button.TextColor3 = HUD.TextDark
	button.TextWrapped = true
	button.Visible = false
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = HUD.Stroke
	stroke.Thickness = HUD.StrokeThickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	return button
end

-- Кнопка прыжка Roblox на телефоне (если есть): над ней и ставим свои
local function findJumpButton(playerGui: Instance): GuiObject?
	local touchGui = playerGui:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	local jump = frame and frame:FindFirstChild("JumpButton")
	if jump and jump:IsA("GuiObject") and jump.Visible then
		return jump
	end
	return nil
end

function ActionButtonsController.Start()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "ActionButtons"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local column = Instance.new("Frame")
	column.Name = "Column"
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(1, 1)
	column.Size = UDim2.fromOffset(HUD.ActionButtonSize, HUD.ActionButtonSize * 2 + HUD.ActionButtonGap)
	column.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, HUD.ActionButtonGap)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = column

	local extract = makeButton(column, HUD.ActionExtract, 1)
	local drop = makeButton(column, HUD.ActionDrop, 2)
	local isTouch = UserInputService.TouchEnabled
	drop.Text = if isTouch then TextConfig.ActionDrop else TextConfig.ActionDrop .. "\n" .. string.format(TextConfig.KeyHint, DROP_KEY.Name)

	local dropEvent = ReplicatedStorage:WaitForChild(Remotes.Folder):WaitForChild(Remotes.DropCarried)
	local function sendDrop()
		if dropEvent:IsA("RemoteEvent") and drop.Visible then
			dropEvent:FireServer()
		end
	end
	drop.Activated:Connect(sendDrop)
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if not gameProcessed and input.KeyCode == DROP_KEY then
			sendDrop()
		end
	end)

	extract.Activated:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:MoveTo(MapConfig.Zone.ExtractionPosition) -- персонаж сам идёт на площадку
		end
	end)

	-- Место колонки: над кнопкой прыжка на телефоне, иначе в правом нижнем углу
	local function place()
		local jump = findJumpButton(playerGui)
		if jump then
			local jumpGui = jump:FindFirstAncestorOfClass("ScreenGui")
			gui.IgnoreGuiInset = if jumpGui then jumpGui.IgnoreGuiInset else true
			local right = jump.AbsolutePosition.X + jump.AbsoluteSize.X
			local top = jump.AbsolutePosition.Y
			column.Position = UDim2.fromOffset(right, top - HUD.ActionButtonGap)
		else
			gui.IgnoreGuiInset = true
			column.Position = UDim2.new(1, -MARGIN, 1, -MARGIN)
		end
	end

	local sinceUpdate = math.huge
	RunService.RenderStepped:Connect(function(dt: number)
		sinceUpdate += dt
		if sinceUpdate < 0.2 then
			return
		end
		sinceUpdate = 0
		place()

		local inRaid = player:GetAttribute("RaidState") == "InRaid"
		local carried = tonumber(player:GetAttribute("CarriedCount")) or 0
		drop.Visible = inRaid and carried > 0

		local root = getRoot()
		local nearPad = false
		local onPad = false
		if inRaid and root then
			local offset = root.Position - MapConfig.Zone.ExtractionPosition
			local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
			nearPad = flat <= HUD.ExtractButtonRange
			onPad = flat <= ZoneConfig.EvacuationDistance
		end
		extract.Visible = nearPad
		extract.Text = if onPad then TextConfig.ActionExtracting else TextConfig.ActionExtract
		extract.Active = not onPad
		extract.AutoButtonColor = not onPad
	end)
end

return ActionButtonsController
