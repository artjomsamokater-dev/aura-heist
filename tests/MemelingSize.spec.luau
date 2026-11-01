--!strict
-- Тесты размера мемлинга по редкости (задача 5.4b).

local MemelingSize = require("../src/shared/Util/MemelingSize")
local TestKit = require("./TestKit")

local test, equal = TestKit.test, TestKit.equal

-- Те же множители, что в StyleConfig.Memeling.RarityScale (StyleConfig без Roblox не загрузить)
local SCALES = { Common = 1, Rare = 1.1, Epic = 1.2, Legendary = 1.4 }
local HEIGHT = 6 -- StyleConfig.Memeling.Size.Y
local CARRIED = 3.6 -- высота в руках: 6 × CarryScale 0.6

local function near(actual: number, expected: number)
	equal(math.floor(actual * 1000 + 0.5) / 1000, expected)
end

print("MemelingSize")

test("множители редкостей, неизвестная — 1", function()
	equal(MemelingSize.Scale(SCALES, "Common"), 1)
	equal(MemelingSize.Scale(SCALES, "Legendary"), 1.4)
	equal(MemelingSize.Scale(SCALES, "Mythic"), 1)
	equal(MemelingSize.Scale(SCALES, nil), 1)
end)

test("низ остаётся на полу: Common не поднимается, Legendary — на 1,2", function()
	equal(MemelingSize.Lift(HEIGHT, 1), 0)
	near(MemelingSize.Lift(HEIGHT, 1.4), 1.2)
end)

test("дальность подбора растёт на прибавку к половине ширины", function()
	equal(MemelingSize.Reach(10, HEIGHT, 1), 10)
	near(MemelingSize.Reach(10, HEIGHT, 1.4), 11.2)
	equal(MemelingSize.Reach(10, HEIGHT, 0.5), 10) -- меньше обычного — дальность не уменьшаем
end)

test("стопка обычных — прежние места 4,4 и 8,2", function()
	local heights = { CARRIED, CARRIED }
	near(MemelingSize.StackCenterY(heights, 1, 2.6, 0.2), 4.4)
	near(MemelingSize.StackCenterY(heights, 2, 2.6, 0.2), 8.2)
end)

test("крупный внизу стопки поднимает следующего", function()
	local heights = { CARRIED * 1.4, CARRIED }
	near(MemelingSize.StackCenterY(heights, 1, 2.6, 0.2), 5.12)
	near(MemelingSize.StackCenterY(heights, 2, 2.6, 0.2), 9.64)
end)

return nil
