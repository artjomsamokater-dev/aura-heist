--!strict
-- Тесты проверки раскладки HUD: пересечения прямоугольников элементов.

local RectRule = require("../src/shared/Util/RectRule")
local TestKit = require("./TestKit")

local test, equal = TestKit.test, TestKit.equal

print("RectRule")

test("пересечение, касание краями и пустой элемент", function()
	local hud = { X = 12, Y = 100, W = 230, H = 80 }
	equal(RectRule.Overlaps(hud, { X = 12, Y = 150, W = 64, H = 64 }), true, "кнопка поверх плашки Aura")
	equal(RectRule.Overlaps(hud, { X = 242, Y = 100, W = 40, H = 40 }), false, "касание краем справа")
	equal(RectRule.Overlaps(hud, { X = 300, Y = 7, W = 44, H = 44 }), false, "кнопка в верхней полосе")
	equal(RectRule.Overlaps(hud, { X = 20, Y = 120, W = 0, H = 30 }), false, "пустой элемент не мешает")
end)

test("список пар", function()
	local found = RectRule.OverlappingPairs({
		{ X = 0, Y = 0, W = 10, H = 10 },
		{ X = 5, Y = 5, W = 10, H = 10 },
		{ X = 50, Y = 50, W = 10, H = 10 },
	})
	equal(#found, 1)
	equal(found[1][1], 1)
	equal(found[1][2], 2)
end)

return nil
