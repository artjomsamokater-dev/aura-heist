--!strict
-- Тесты выбора редкости (задача 3.1): на 10 000 спавнов распределение близко к ZoneConfig.

local RarityRoll = require("../src/shared/Util/RarityRoll")
local ZoneConfig = require("../src/shared/Config/ZoneConfig")
local MemelingConfig = require("../src/shared/Config/MemelingConfig")
local TestKit = require("./TestKit")

local test, equal = TestKit.test, TestKit.equal

local SPAWNS = 10_000
local TOLERANCE_PERCENT = 1.5 -- допуск: при 10 000 бросках разброс около 0,5 процентного пункта

print("RarityRoll")

for _, part in ipairs({ "Safe", "Danger" }) do
	local chances = ZoneConfig.SpawnChances[part]

	test(part .. ": шансы в сумме 100%", function()
		local total = 0
		for _, rarity in ipairs(MemelingConfig.RarityOrder) do
			total += chances[rarity] or 0
		end
		equal(total, 100)
	end)

	test(part .. ": 10 000 спавнов — распределение близко к Config", function()
		math.randomseed(42)
		local counts: { [string]: number } = {}
		for _ = 1, SPAWNS do
			local rarity = RarityRoll.Pick(chances, MemelingConfig.RarityOrder, math.random()) :: string
			counts[rarity] = (counts[rarity] or 0) + 1
		end
		for _, rarity in ipairs(MemelingConfig.RarityOrder) do
			local expected = chances[rarity] or 0
			local actual = (counts[rarity] or 0) / SPAWNS * 100
			if expected == 0 then
				equal(counts[rarity] or 0, 0, rarity .. " с шансом 0 выпал")
			elseif math.abs(actual - expected) > TOLERANCE_PERCENT then
				error(string.format("%s: ожидали ~%d%%, получили %.2f%%", rarity, expected, actual))
			end
		end
	end)

	test(part .. ": у каждой выпадающей редкости есть мемлинги", function()
		for rarity, chance in chances do
			if chance > 0 then
				local found = false
				for _, memeling in MemelingConfig.Memelings do
					if memeling.Rarity == rarity then
						found = true
					end
				end
				equal(found, true, rarity)
			end
		end
	end)
end

test("края броска: 0 — первая редкость, почти 1 — последняя ненулевая", function()
	local danger = ZoneConfig.SpawnChances.Danger
	equal(RarityRoll.Pick(danger, MemelingConfig.RarityOrder, 0), "Rare")
	equal(RarityRoll.Pick(danger, MemelingConfig.RarityOrder, 0.9999999), "Legendary")
end)

test("все шансы нулевые — nil", function()
	equal(RarityRoll.Pick({ Common = 0 }, { "Common" }, 0.5), nil)
end)

test("часть зоны по X: граница DangerFromX уже опасная", function()
	equal(RarityRoll.ZonePart(-40, 10), "Safe")
	equal(RarityRoll.ZonePart(9.9, 10), "Safe")
	equal(RarityRoll.ZonePart(10, 10), "Danger")
	equal(RarityRoll.ZonePart(35, 10), "Danger")
end)

return nil
