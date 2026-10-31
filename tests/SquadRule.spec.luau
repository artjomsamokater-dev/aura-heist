--!strict
-- Тесты бонуса отряда (задача 4.3): только рядом, только вовремя, только разные игроки, один раз.

local SquadRule = require("../src/shared/Util/SquadRule")
local EconomyConfig = require("../src/shared/Config/EconomyConfig")
local TestKit = require("./TestKit")

local test, equal = TestKit.test, TestKit.equal

local RADIUS = EconomyConfig.SquadBonus.Radius
local WINDOW = EconomyConfig.SquadBonus.WindowSeconds
local PERCENT = EconomyConfig.SquadBonus.SellBonusPercent

local function extraction(ownerId: number, x: number, z: number, time: number): SquadRule.Extraction
	return { OwnerId = ownerId, X = x, Z = z, Time = time, Bonus = false }
end

print("SquadRule")

test("рядом и вовремя — отряд", function()
	equal(SquadRule.IsSquad(extraction(1, 0, 0, 100), extraction(2, 5, 5, 103), RADIUS, WINDOW), true)
end)

test("ровно на границе радиуса и окна — ещё отряд", function()
	equal(SquadRule.IsSquad(extraction(1, 0, 0, 100), extraction(2, RADIUS, 0, 100 + WINDOW), RADIUS, WINDOW), true)
end)

test("далеко — не отряд, даже если одновременно", function()
	equal(SquadRule.IsSquad(extraction(1, 0, 0, 100), extraction(2, RADIUS + 0.5, 0, 100), RADIUS, WINDOW), false)
end)

test("поздно — не отряд, даже если рядом", function()
	equal(SquadRule.IsSquad(extraction(1, 0, 0, 100), extraction(2, 1, 1, 100 + WINDOW + 0.1), RADIUS, WINDOW), false)
end)

test("один и тот же игрок сам с собой не отряд", function()
	equal(SquadRule.IsSquad(extraction(1, 0, 0, 100), extraction(1, 0, 0, 101), RADIUS, WINDOW), false)
end)

test("поиск напарников: находит только подходящих", function()
	local recent = {
		extraction(2, 3, 0, 98), -- рядом, вовремя
		extraction(3, 50, 0, 99), -- далеко
		extraction(4, 2, 2, 90), -- давно
		extraction(1, 0, 1, 99), -- это я сам
	}
	local partners = SquadRule.FindPartners(extraction(1, 0, 0, 100), recent, RADIUS, WINDOW)
	equal(#partners, 1)
	equal(partners[1], 1)
end)

test("старые эвакуации убираются, свежие остаются", function()
	local recent = { extraction(1, 0, 0, 90), extraction(2, 0, 0, 97), extraction(3, 0, 0, 100) }
	SquadRule.Prune(recent, 100, WINDOW)
	equal(#recent, 2)
	equal(recent[1].OwnerId, 2)
end)

test("цена с бонусом: +25%, округление вниз; без бонуса — без изменений", function()
	equal(SquadRule.SellPrice(20, PERCENT, true), 25)
	equal(SquadRule.SellPrice(80, PERCENT, true), 100)
	equal(SquadRule.SellPrice(1200, PERCENT, true), 1500)
	equal(SquadRule.SellPrice(30, 25, true), 37, "37.5 → 37")
	equal(SquadRule.SellPrice(300, PERCENT, false), 300)
end)

return nil
