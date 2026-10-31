--!strict
-- PromptController: крупные кнопки вместо стандартных ProximityPrompt (Pick up, Collect, Buy, Sell).
-- Все кнопки игры переводятся в стиль Custom, и клиент рисует свою: скруглённая плашка в мире
-- с действием крупно, предметом мелко и полоской удержания. На телефоне — ещё крупнее.
-- Нажатие пальцем или мышью передаётся самой кнопке (InputHoldBegin/End), клавиша E/F работает как раньше —
-- то есть всё по-прежнему проверяет сервер (RemoteGuard и обработчики), меняется только вид.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)

local PromptController = {}

local HUD = StyleConfig.Hud

local function addCorner(frame: GuiObject, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = frame
end

local function makeCustom(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		instance.Style = Enum.ProximityPromptStyle.Custom
	end
end

-- Название клавиши для подсказки на компьютере: E, F, ...
local function keyName(prompt: ProximityPrompt): string
	local name = prompt.KeyboardKeyCode.Name
	return string.format(TextConfig.KeyHint, name)
end

local function buildButton(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType, playerGui: Instance): (BillboardGui, () -> ())
	local scale = if inputType == Enum.ProximityPromptInputType.Touch then HUD.PromptTouchScale else 1
	local width, height = HUD.PromptWidth * scale, HUD.PromptHeight * scale
	local offset = prompt.UIOffset

	-- Табличка стоит над деталью; второй кнопке на той же детали (Sell) — сдвиг из UIOffset
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Prompt_" .. prompt.Name
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(width, height + math.abs(offset.Y) * 2)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.Adornee = prompt.Parent :: any
	billboard.ResetOnSpawn = false
	billboard.Parent = playerGui

	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
	button.Size = UDim2.fromOffset(width, height)
	button.BackgroundColor3 = HUD.PromptPanel
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = billboard
	addCorner(button, UDim.new(0, HUD.CornerRadius))
	local stroke = Instance.new("UIStroke")
	stroke.Color = HUD.Stroke
	stroke.Thickness = HUD.StrokeThickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button

	-- Полоска удержания (растёт, пока держишь)
	local fill = Instance.new("Frame")
	fill.Name = "Hold"
	fill.BackgroundColor3 = HUD.PromptFill
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = button
	addCorner(fill, UDim.new(0, HUD.CornerRadius))

	local action = Instance.new("TextLabel")
	action.BackgroundTransparency = 1
	action.Font = StyleConfig.Fonts.Hud
	action.TextSize = HUD.PromptActionSize * scale
	action.TextColor3 = HUD.TextDark
	action.Text = prompt.ActionText
	action.Size = UDim2.new(1, 0, 0.62, 0)
	action.Parent = button

	local object = Instance.new("TextLabel")
	object.BackgroundTransparency = 1
	object.Font = StyleConfig.Fonts.Hud
	object.TextSize = HUD.PromptObjectSize * scale
	object.TextColor3 = HUD.TextDark
	object.TextTransparency = 0.2
	local showKey = inputType == Enum.ProximityPromptInputType.Keyboard
	object.Text = if showKey then keyName(prompt) .. "  " .. prompt.ObjectText else prompt.ObjectText
	object.Position = UDim2.fromScale(0, 0.58)
	object.Size = UDim2.new(1, 0, 0.38, 0)
	object.Parent = button

	-- Палец или мышь: держим кнопку — держим ProximityPrompt
	local holding = false
	button.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1 then
			holding = true
			prompt:InputHoldBegin()
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if holding and (kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1) then
			holding = false
			prompt:InputHoldEnd()
		end
	end)

	local tween: Tween? = nil
	local holdBegan = prompt.PromptButtonHoldBegan:Connect(function()
		if prompt.HoldDuration > 0 then
			fill.Size = UDim2.fromScale(0, 1)
			tween = TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
			;(tween :: Tween):Play()
		end
	end)
	local holdEnded = prompt.PromptButtonHoldEnded:Connect(function()
		if tween then
			tween:Cancel()
		end
		fill.Size = UDim2.fromScale(0, 1)
	end)
	-- Текст кнопки меняет сервер (цена, предмет) — обновляем
	local changed = prompt.Changed:Connect(function()
		action.Text = prompt.ActionText
		object.Text = if showKey then keyName(prompt) .. "  " .. prompt.ObjectText else prompt.ObjectText
	end)

	local function cleanup()
		holdBegan:Disconnect()
		holdEnded:Disconnect()
		changed:Disconnect()
		if holding then
			prompt:InputHoldEnd()
		end
		billboard:Destroy()
	end
	return billboard, cleanup
end

function PromptController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- Все кнопки игры — в свой стиль (и те, что появятся позже: мемлинги после рестока)
	for _, instance in ipairs(Workspace:GetDescendants()) do
		makeCustom(instance)
	end
	Workspace.DescendantAdded:Connect(makeCustom)

	local active: { [ProximityPrompt]: () -> () } = {}
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		local old = active[prompt]
		if old then
			old()
		end
		local _, cleanup = buildButton(prompt, inputType, playerGui)
		active[prompt] = cleanup
		prompt.PromptHidden:Once(function()
			if active[prompt] == cleanup then
				active[prompt] = nil
				cleanup()
			end
		end)
	end)
end

return PromptController
