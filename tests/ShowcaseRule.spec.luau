--!strict
-- Тесты витрины после Rebirth: постаментов снова 3, лишние мемлинги — в запас, самые доходные — на постаментах.

local ShowcaseRule = require("../src/shared/Util/ShowcaseRule")
local UpgradeConfig = require("../src/shared/Config/UpgradeConfig")
local MemelingConfig = require("../src/shared/Config/MemelingConfig")
local TestKit = require("./TestKit")

local test, equal = TestKit.test, TestKit.equal

local function rateOf(memelingId: string, squad: boolean?): number
	local memeling = MemelingConfig.Memelings[memelingId]
	local base = MemelingConfig.Rarities[memeling.Rarity].AuraPerSecond * (memeling.IncomeMultiplier or 1)
	return if squad then base * 1.5 else base
end

print("ShowcaseRule")

test("10 мемлингов, Rebirth → 3 самых доходных на постаментах, 7 в запасе, кнопка постамента — 100", function()
	-- Как было до Rebirth: 10 постаментов заняты (порядок — как покупались)
	local ids = {
		"ToastPaw", "SirWobbleton", "Grumbloaf", "NoodleNinja", "CaptainSockbeard",
		"DiscoPickle", "ProfessorBonk", "MegaSnoozeasaurus", "BubbleTeaBandit", "KingWaffleton",
	}
	local candidates: { ShowcaseRule.Candidate } = {}
	for i, id in ipairs(ids) do
		local squad = i == 4 -- у Noodle Ninja флаг отряда
		table.insert(candidates, { memelingId = id, squadBonus = squad, rate = rateOf(id, squad) })
	end

	local level = 0 -- Rebirth сбросил улучшение постаментов
	local slots = UpgradeConfig.Pedestals.StartCount
	equal(slots, 3)
	local placed, reserve = ShowcaseRule.Reflow(candidates, slots)
	equal(#placed, 3)
	equal(#reserve, 7)
	-- Самые доходные: King Waffleton (60×5), Mega Snoozeasaurus (60), Bubble Tea Bandit (4×5)
	equal(placed[1].memelingId, "KingWaffleton")
	equal(placed[2].memelingId, "MegaSnoozeasaurus")
	equal(placed[3].memelingId, "BubbleTeaBandit")
	-- Никто не потерялся, флаг отряда сохранился
	local seen: { [string]: boolean } = {}
	for _, list in ipairs({ placed, reserve }) do
		for _, c in ipairs(list) do
			seen[c.memelingId] = true
			if c.memelingId == "NoodleNinja" then
				equal(c.squadBonus, true, "флаг отряда сохранился")
			end
		end
	end
	for _, id in ipairs(ids) do
		equal(seen[id], true, id)
	end
	-- Запас по доходу: первым из запаса встанет самый доходный
	for i = 2, #reserve do
		equal(reserve[i - 1].rate >= reserve[i].rate, true)
	end
	-- Кнопка постамента после Rebirth: следующий уровень (1) стоит 100
	equal(UpgradeConfig.Pedestals.Levels[level + 1].Cost, 100)
end)

test("пересборка нужна, если кто-то стоит за пределами открытых постаментов", function()
	equal(ShowcaseRule.NeedsReflow({ 1, 2, 3 }, 3), false)
	equal(ShowcaseRule.NeedsReflow({ 1, 2, 7 }, 3), true)
end)

return nil
