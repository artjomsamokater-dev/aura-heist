--!strict
-- Тесты скорости при переноске (задача 3.2) на числах из MemelingConfig.

local CarrySpeed = require("../src/shared/Util/CarrySpeed")
local MemelingConfig = require("../src/shared/Config/MemelingConfig")
local TestKit = require("./TestKit")

local test, equal = TestKit.test, TestKit.equal

local BASE = 16 -- обычная скорость персонажа Roblox
local function speedOf(rarity: string): number
	return MemelingConfig.Rarities[rarity].CarrySpeed
end

print("CarrySpeed")

test("пустые руки — обычная скорость", function()
	equal(CarrySpeed.Compute(BASE, {}), BASE)
end)

test("Common и Rare не замедляют (16)", function()
	equal(CarrySpeed.Compute(BASE, { speedOf("Common"), speedOf("Rare") }), 16)
end)

test("Epic — 14, Legendary — 11", function()
	equal(CarrySpeed.Compute(BASE, { speedOf("Epic") }), 14)
	equal(CarrySpeed.Compute(BASE, { speedOf("Legendary") }), 11)
end)

test("несколько в руках — берётся самая медленная редкость", function()
	equal(CarrySpeed.Compute(BASE, { speedOf("Common"), speedOf("Legendary"), speedOf("Epic") }), 11)
end)

test("никогда не быстрее обычной скорости", function()
	equal(CarrySpeed.Compute(12, { speedOf("Common") }), 12)
end)

return nil
