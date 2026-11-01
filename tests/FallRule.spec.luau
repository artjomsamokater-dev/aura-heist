--!strict
-- Тесты мягкого возврата (задача 7.5): кто упал и на какую точку его вернуть.

local FallRule = require("../src/shared/Util/FallRule")
local TestKit = require("./TestKit")

local test, equal = TestKit.test, TestKit.equal

print("FallRule")

test("упал — ниже высоты ловушки", function()
	equal(FallRule.Fallen(3.0, 3.5), true, "уступ или море под хабом")
	equal(FallRule.Fallen(4.0, 3.5), false, "стоит на полу хаба, мостика или участка")
	equal(FallRule.Fallen(-13, 3.5), true, "в море")
end)

test("возврат — на ближайшую точку", function()
	-- Как в хабе: дорожки у мостиков по кругу (радиус 46) и вход участка дальше
	local points: { FallRule.Point } = {}
	for k = 0, 7 do
		local a = math.rad(22.5 + k * 45)
		table.insert(points, { X = math.cos(a) * 46, Z = math.sin(a) * 46 })
	end
	table.insert(points, { X = 70, Z = 30 }) -- вход участка
	equal(FallRule.NearestIndex(52, 4, points), 1, "у края хаба на 0° — дорожка у мостика 22,5°")
	equal(FallRule.NearestIndex(-53, 2, points), 4, "упал у паркура (180°) — дорожка 157,5°")
	equal(FallRule.NearestIndex(72, 33, points), 9, "у участка — вход участка, а не площадь")
	equal(FallRule.NearestIndex(0, 0, {}), nil, "точек нет")
end)

return nil
