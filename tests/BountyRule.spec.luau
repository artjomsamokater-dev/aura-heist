--!strict
-- Тесты «Охоты» (задача 7.5): BOUNTY — не Secret, не повторяется подряд, доход ×2 только с флагом.

local BountyRule = require("../src/shared/Util/BountyRule")
local MemelingConfig = require("../src/shared/Config/MemelingConfig")
local EconomyConfig = require("../src/shared/Config/EconomyConfig")
local TestKit = require("./TestKit")

local test, equal = TestKit.test, TestKit.equal

print("BountyRule")

test("кандидаты — все мемлинги зон, Secret никогда", function()
	local candidates = BountyRule.Candidates(MemelingConfig.Memelings :: any, "Secret")
	equal(#candidates, 21, "13 Meme Zone + 8 Golden Zone")
	equal(table.find(candidates, "Error404Kitten"), nil, "Secret не охотятся")
end)

test("10 000 выборов: не Secret, не тот же подряд, каждый кандидат встречается", function()
	local candidates = BountyRule.Candidates(MemelingConfig.Memelings :: any, "Secret")
	local seen: { [string]: number } = {}
	math.randomseed(7)
	local previous: string? = nil
	for _ = 1, 10000 do
		local id = BountyRule.Pick(candidates, previous, math.random())
		assert(id, "кандидат есть всегда")
		equal(id ~= previous, true, "не повторяется подряд")
		equal(MemelingConfig.Memelings[id].Rarity ~= "Secret", true)
		seen[id] = (seen[id] or 0) + 1
		previous = id
	end
	for _, id in ipairs(candidates) do
		equal((seen[id] or 0) > 300, true, id .. " выпадает") -- в среднем ~476 из 10 000
	end
	equal(BountyRule.Pick({ "Solo" }, "Solo", 0.5), "Solo", "один кандидат — он же")
	equal(BountyRule.Pick({}, nil, 0.5), nil, "кандидатов нет")
end)

test("доход: x2 только у вынесенного во время охоты, 10 минут на охоту", function()
	equal(BountyRule.IncomeMultiplier(EconomyConfig.Bounty.IncomeMultiplier, true), 2)
	equal(BountyRule.IncomeMultiplier(EconomyConfig.Bounty.IncomeMultiplier, false), 1)
	equal(EconomyConfig.Bounty.IntervalSeconds, 600)
end)

return nil
