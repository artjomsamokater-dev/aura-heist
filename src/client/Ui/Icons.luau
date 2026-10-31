--!strict
-- Icons: простые иконки HUD, нарисованные из рамок (Frame + UICorner + UIStroke) в цветах палитры.
-- Без эмодзи: на всех телефонах и компьютерах выглядят одинаково.
--   "Aura"  — золотой шарик с бликом
--   "Bag"   — мятный рюкзак с ручкой и клапаном
--   "Clock" — циферблат со стрелками
--   "Squad" — два человечка рядом

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)

local Icons = {}

local Palette = StyleConfig.Palette

local function frame(parent: Instance, color: Color3, position: UDim2, size: UDim2, round: UDim?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = position
	f.Size = size
	f.Parent = parent
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = round
		corner.Parent = f
	end
	return f
end

local function stroke(target: GuiObject, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = target
end

local CIRCLE = UDim.new(0.5, 0)

local function aura(holder: Frame)
	local orb = frame(holder, Palette.Sun, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.78, 0.78), CIRCLE)
	stroke(orb, Palette.SunDark, 2)
	frame(orb, Palette.CreamLight, UDim2.fromScale(0.34, 0.32), UDim2.fromScale(0.28, 0.28), CIRCLE)
end

local function bag(holder: Frame)
	local handle = frame(holder, Palette.Mint, UDim2.fromScale(0.5, 0.26), UDim2.fromScale(0.38, 0.3), UDim.new(0.5, 0))
	handle.BackgroundTransparency = 1
	stroke(handle, Palette.MintDark, 3)
	local body = frame(holder, Palette.Mint, UDim2.fromScale(0.5, 0.6), UDim2.fromScale(0.72, 0.62), UDim.new(0.25, 0))
	stroke(body, Palette.MintDark, 2)
	frame(body, Palette.MintDark, UDim2.fromScale(0.5, 0.3), UDim2.fromScale(0.86, 0.14), UDim.new(0.5, 0))
	frame(body, Palette.MintLight, UDim2.fromScale(0.5, 0.62), UDim2.fromScale(0.2, 0.2), CIRCLE)
end

local function clock(holder: Frame)
	local face = frame(holder, Palette.CreamLight, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.8, 0.8), CIRCLE)
	stroke(face, Palette.Ink, 2)
	-- Стрелки: тонкие полоски, повёрнутые вокруг центра
	local minute = frame(face, Palette.Ink, UDim2.fromScale(0.5, 0.32), UDim2.fromScale(0.08, 0.36), CIRCLE)
	minute.AnchorPoint = Vector2.new(0.5, 0.5)
	local hour = frame(face, Palette.Ink, UDim2.fromScale(0.62, 0.5), UDim2.fromScale(0.26, 0.08), CIRCLE)
	hour.AnchorPoint = Vector2.new(0.5, 0.5)
	frame(face, Palette.Coral, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.14, 0.14), CIRCLE)
end

local function squad(holder: Frame)
	for i, x in ipairs({ 0.32, 0.68 }) do
		local color = if i == 1 then Palette.Mint else Palette.Sun
		local dark = if i == 1 then Palette.MintDark else Palette.SunDark
		local head = frame(holder, color, UDim2.fromScale(x, 0.32), UDim2.fromScale(0.3, 0.3), CIRCLE)
		stroke(head, dark, 2)
		local shoulders = frame(holder, color, UDim2.fromScale(x, 0.74), UDim2.fromScale(0.42, 0.34), UDim.new(0.45, 0))
		stroke(shoulders, dark, 2)
	end
end

local DRAW: { [string]: (Frame) -> () } = {
	Aura = aura,
	Bag = bag,
	Clock = clock,
	Squad = squad,
}

-- Иконка kind размером size × size пикселей (или по размеру родителя, если size не задан)
function Icons.Make(kind: string, parent: Instance, size: number?): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Icon_" .. kind
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = if size then UDim2.fromOffset(size, size) else UDim2.fromScale(1, 1)
	holder.Parent = parent
	local draw = DRAW[kind]
	if draw then
		draw(holder)
	end
	return holder
end

return Icons
