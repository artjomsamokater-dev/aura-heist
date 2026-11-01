--!strict
-- Тесты коллекции (задача 7.8): строки атрибутов туда и обратно, счётчик «N/M», разделы по зонам.

local CollectionRule = require("../src/shared/Util/CollectionRule")
local MemelingConfig = require("../src/shared/Config/MemelingConfig")
local ZoneConfig = require("../src/shared/Config/ZoneConfig")
local TestKit = require("./TestKit")

local test, equal = TestKit.test, TestKit.equal

print("CollectionRule")

test("открытые и количество: строка туда и обратно", function()
	local set = CollectionRule.DecodeSet(CollectionRule.EncodeSet({ ToastPaw = true, ChocoKing = true, RoboDuck = false }))
	equal(set.ToastPaw, true)
	equal(set.ChocoKing, true)
	equal(set.RoboDuck, nil, "false не попадает в строку")
	equal(next(CollectionRule.DecodeSet(nil)), nil, "пусто — ничего не открыто")
	local counts = CollectionRule.DecodeCounts(CollectionRule.EncodeCounts({ ToastPaw = 3, ChocoKing = 1, RoboDuck = 0 }))
	equal(counts.ToastPaw, 3)
	equal(counts.ChocoKing, 1)
	equal(counts.RoboDuck, nil)
end)

test("счётчик: открыто из всех мемлингов игры", function()
	local opened, total = CollectionRule.Progress({ ToastPaw = true, ChocoKing = true, NotAMemeling = true }, MemelingConfig.Memelings :: any)
	equal(opened, 2, "несуществующий Id не считается")
	equal(total, 27, "13 Meme + 8 Golden + 5 Candy + 1 Secret")
end)

test("разделы: зоны по порядку, Secret в конце, внутри от Common к Legendary", function()
	local sections = CollectionRule.Sections(MemelingConfig.Memelings :: any, ZoneConfig.ZoneOrder, MemelingConfig.RarityOrder)
	equal(#sections, #ZoneConfig.ZoneOrder + 1)
	equal(sections[1].Zone, "Meme")
	equal(#sections[1].Ids, 13)
	equal(MemelingConfig.Memelings[sections[1].Ids[1]].Rarity, "Common")
	equal(MemelingConfig.Memelings[sections[1].Ids[#sections[1].Ids]].Rarity, "Legendary")
	equal(sections[#sections].Zone, nil)
	equal(sections[#sections].Ids[1], "Error404Kitten")
	local count = 0
	for _, section in ipairs(sections) do
		count += #section.Ids
	end
	equal(count, 27, "каждый мемлинг — ровно в одном разделе")
end)

return nil
