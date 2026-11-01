--!strict
-- PromptController: крупные кнопки вместо стандартных ProximityPrompt — все кнопки игры (Pick up, Collect, Sell,
-- Buy, Unlock у ворот зон, Rebirth, Reserve, Open shop у киоска). Все ProximityPrompt переводятся в стиль Custom,
-- и клиент рисует свою: скруглённая плашка над деталью с действием крупно, предметом мелко и полоской удержания.
-- На телефоне — ещё крупнее.
-- Нажатие: плашка — BillboardGui в PlayerGui с Adornee = деталь и Active = true (без Active касания до кнопки
-- не доходят — баг на телефоне после 5.3). Палец или мышь на кнопке → prompt:InputHoldBegin(), отпустил где угодно
-- (в том числе сдвинув палец с кнопки) → InputHoldEnd(). Клавиша E/F работает как раньше. Всё по-прежнему
-- проверяет сервер (RemoteGuard и обработчики), меняется только вид.
-- Запасной путь: StyleConfig.Hud.PromptDefaultOnTouch = true — на телефоне стандартные кнопки Roblox.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
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

-- Телефон без клавиатуры и включён запасной путь — оставляем стандартные кнопки Roblox
local function useDefaultPrompts(): boolean
	return HUD.PromptDefaultOnTouch and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function makeCustom(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		instance.Style = if useDefaultPrompts() then Enum.ProximityPromptStyle.Default else Enum.ProximityPromptStyle.Custom
	end
end

local function isPress(input: InputObject): boolean
	local kind = input.UserInputType
	return kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1
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
	billboard.Active = true -- иначе кнопка внутри не получает касания и клики
	billboard.Parent = playerGui

	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
	button.Size = UDim2.fromOffset(width, height)
	button.BackgroundColor3 = HUD.PromptPanel
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Active = true
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

	-- Палец или мышь: держим кнопку — держим ProximityPrompt. Отпустить можно где угодно: конец касания
	-- ловим и на самой кнопке, и во всей игре (палец часто съезжает с кнопки во время удержания)
	local holding = false
	local holdInput: InputObject? = nil
	local function release()
		if holding then
			holding = false
			holdInput = nil
			prompt:InputHoldEnd()
		end
	end
	button.InputBegan:Connect(function(input: InputObject)
		if isPress(input) and not holding then
			holding = true
			holdInput = input
			prompt:InputHoldBegin()
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if isPress(input) then
			release()
		end
	end)
	local globalEnded = UserInputService.InputEnded:Connect(function(input: InputObject)
		if holding and (input == holdInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
			release()
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
		globalEnded:Disconnect()
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
