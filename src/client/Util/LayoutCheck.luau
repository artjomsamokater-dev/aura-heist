--!strict
-- LayoutCheck: проверка раскладки HUD на этом клиенте (после 7.8). Берёт реальные экранные прямоугольники
-- постоянных элементов — плашки слева сверху, кнопка меню, таймер рестока, плашка BOUNTY, полоска эвакуации —
-- и пишет предупреждение в Output, если какие-то два пересекаются (shared/Util/RectRule).
-- Скрытые элементы тоже проверяются: в зоне они появятся на тех же местах.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RectRule = require(ReplicatedStorage.Shared.Util.RectRule)

local LayoutCheck = {}

-- Путь в PlayerGui: ScreenGui и имя элемента внутри (ищется в глубину)
local ELEMENTS: { { Name: string, Gui: string, Element: string } } = {
	{ Name = "HUD слева сверху", Gui = "Hud", Element = "TopLeft" },
	{ Name = "кнопка меню", Gui = "Menu", Element = "MenuButton" },
	{ Name = "таймер рестока", Gui = "RestockTimer", Element = "Panel" },
	{ Name = "плашка BOUNTY", Gui = "BountyHud", Element = "Panel" },
	{ Name = "полоска эвакуации", Gui = "ExtractBar", Element = "Panel" },
}

local function rectOf(object: GuiObject): RectRule.Rect
	local position, size = object.AbsolutePosition, object.AbsoluteSize
	-- У ScreenGui с IgnoreGuiInset = false координаты сдвинуты на высоту верхней полосы — приводим к экрану
	local gui = object:FindFirstAncestorOfClass("ScreenGui")
	local shift = if gui and not gui.IgnoreGuiInset then game:GetService("GuiService"):GetGuiInset().Y else 0
	return { X = position.X, Y = position.Y + shift, W = size.X, H = size.Y }
end

function LayoutCheck.Run(): number
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return 0
	end
	local names: { string } = {}
	local rects: { RectRule.Rect } = {}
	for _, spec in ipairs(ELEMENTS) do
		local gui = playerGui:FindFirstChild(spec.Gui)
		local element = gui and gui:FindFirstChild(spec.Element, true)
		if element and element:IsA("GuiObject") then
			table.insert(names, spec.Name)
			table.insert(rects, rectOf(element))
		end
	end
	local found = RectRule.OverlappingPairs(rects)
	for _, pair in ipairs(found) do
		warn(string.format("[HUD] Элементы интерфейса пересекаются: %s и %s — поправь раскладку", names[pair[1]], names[pair[2]]))
	end
	if #found == 0 then
		print(string.format("[HUD] Раскладка в порядке: проверено элементов %d, пересечений нет", #rects))
	end
	return #found
end

return LayoutCheck
