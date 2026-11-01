--!strict
-- Тесты выбора редкости (задача 3.1): на 10 000 спавнов распределение близко к ZoneConfig.

local RarityRoll = require("../src/shared/Util/RarityRoll")
local ZoneConfig = require("../src/shared/Config/ZoneConfig")
local MemelingConfig = require("../src/shared/Config/MemelingConfig")
local ZoneRule = require("../src/shared/Util/ZoneRule")
local TestKit = require("./TestKit")

local test, equal = TestKit.test, TestKit.equal

local SPAWNS = 10_000
local TOLERANCE_PERCENT = 1.5 -- допуск: при 10 000 бросках разброс около 0,5 процентного пункта

print("RarityRoll")

for _, zoneId in ipairs(ZoneConfig.ZoneOrder) do
for _, zonePart in ipairs({ "Safe", "Danger" }) do
	local chances = ZoneConfig.Zones[zoneId].SpawnChances[zonePart]
	local part = zoneId .. " " .. zonePart

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

	test(part .. ": у каждой выпадающей редкости есть мемлинги этой зоны", function()
		for rarity, chance in chances do
			if chance > 0 then
				equal(#ZoneRule.MemelingsOf(MemelingConfig.Memelings, zoneId, rarity) > 0, true, rarity)
			end
		end
	end)
end
end

test("Meme Zone как раньше: Safe 80/20 Common/Rare, Danger 55/38/7 Rare/Epic/Legendary", function()
	local meme = ZoneConfig.Zones.Meme.SpawnChances
	equal(meme.Safe.Common, 80)
	equal(meme.Safe.Rare, 20)
	equal(meme.Danger.Rare, 55)
	equal(meme.Danger.Epic, 38)
	equal(meme.Danger.Legendary, 7)
	equal(ZoneConfig.FirstZone, "Meme")
	equal(ZoneConfig.Zones.Meme.AccessCost, nil)
	equal(ZoneConfig.Zones.Meme.Tutorial, true)
end)

test("Meme Zone как раньше: те же 8 мемлингов (3 Common, 2 Rare, 2 Epic, 1 Legendary)", function()
	local counts = { Common = 3, Rare = 2, Epic = 2, Legendary = 1 }
	for rarity, count in counts do
		equal(#ZoneRule.MemelingsOf(MemelingConfig.Memelings, "Meme", rarity), count, rarity)
	end
	equal(ZoneRule.MemelingsOf(MemelingConfig.Memelings, "Meme", "Legendary")[1], "MegaSnoozeasaurus")
end)

test("каждая зона из ZoneOrder описана, у мемлинга — существующая зона или никакой (в зонах не появляется)", function()
	for _, zoneId in ipairs(ZoneConfig.ZoneOrder) do
		equal(ZoneConfig.Zones[zoneId] ~= nil, true, zoneId)
	end
	for id, memeling in MemelingConfig.Memelings do
		local zone = memeling.Zone
		equal(zone == nil or ZoneConfig.Zones[zone] ~= nil, true, id)
	end
end)

test("Golden Zone: без Common, вход 25 000 Aura, туториала нет", function()
	local golden = ZoneConfig.Zones.Golden
	equal(golden.SpawnChances.Safe.Common, 0)
	equal(golden.SpawnChances.Danger.Common, 0)
	equal(golden.AccessCost, 25000)
	equal(golden.Tutorial, false)
end)

test("Golden Zone: свои 5 мемлингов (2 Rare, 2 Epic, 1 Legendary), доход ×5, в Meme Zone их нет", function()
	local counts = { Common = 0, Rare = 2, Epic = 2, Legendary = 1 }
	for rarity, count in counts do
		local ids = ZoneRule.MemelingsOf(MemelingConfig.Memelings, "Golden", rarity)
		equal(#ids, count, rarity)
		for _, id in ipairs(ids) do
			equal(ZoneRule.IncomeMultiplier(MemelingConfig.Memelings[id]), 5, id)
			equal(table.find(ZoneRule.MemelingsOf(MemelingConfig.Memelings, "Meme", rarity), id), nil, id)
		end
	end
	equal(ZoneRule.IncomeMultiplier(MemelingConfig.Memelings.ToastPaw), 1, "у мемлингов Meme Zone доход как раньше")
end)

test("доступ: бесплатная зона открыта всем, платная — только купившим", function()
	equal(ZoneRule.HasAccess(nil, nil, "Meme"), true)
	equal(ZoneRule.HasAccess(25000, nil, "Golden"), false)
	equal(ZoneRule.HasAccess(25000, { Golden = false }, "Golden"), false)
	equal(ZoneRule.HasAccess(25000, { Golden = true }, "Golden"), true)
end)

test("края броска: 0 — первая редкость, почти 1 — последняя ненулевая", function()
	local danger = ZoneConfig.Zones.Meme.SpawnChances.Danger
	equal(RarityRoll.Pick(danger, MemelingConfig.RarityOrder, 0), "Rare")
	equal(RarityRoll.Pick(danger, MemelingConfig.RarityOrder, 0.9999999), "Legendary")
end)

test("все шансы нулевые — nil", function()
	equal(RarityRoll.Pick({ Common = 0 }, { "Common" }, 0.5), nil)
end)

test("объявление: из одного спавна — только самый редкий, и только Epic/Legendary", function()
	local order = MemelingConfig.RarityOrder
	local announce = ZoneConfig.AnnounceRarities
	local spawned = {
		{ Rarity = "Common", Part = "Safe" },
		{ Rarity = "Epic", Part = "Danger" },
		{ Rarity = "Legendary", Part = "Danger" },
		{ Rarity = "Epic", Part = "Danger" },
	}
	equal(RarityRoll.Rarest(spawned, order, announce), 3, "Legendary важнее Epic")
	equal(RarityRoll.Rarest({ { Rarity = "Epic", Part = "Danger" } }, order, announce), 1)
	equal(RarityRoll.Rarest({ { Rarity = "Common", Part = "Safe" }, { Rarity = "Rare", Part = "Danger" } }, order, announce), nil, "без редких — молчим")
	equal(RarityRoll.Rarest({}, order, announce), nil, "пустой ресток — молчим")
end)

test("часть зоны по X: граница DangerFromX уже опасная", function()
	equal(RarityRoll.ZonePart(-40, 10), "Safe")
	equal(RarityRoll.ZonePart(9.9, 10), "Safe")
	equal(RarityRoll.ZonePart(10, 10), "Danger")
	equal(RarityRoll.ZonePart(35, 10), "Danger")
end)

return nil
