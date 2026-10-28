--!strict
-- MemelingConfig: редкости и список мемлингов.
-- Все числа баланса по редкостям живут здесь (раздел 3 документации).

-- table.freeze замораживает только верхний уровень, поэтому замораживаем всё дерево
local function deepFreeze<T>(t: T): T
	for _, value in t :: any do
		if type(value) == "table" and not table.isfrozen(value) then
			deepFreeze(value)
		end
	end
	return table.freeze(t :: any) :: any
end

local MemelingConfig = {}

-- Порядок редкостей от слабой к сильной (у словаря порядка нет, поэтому отдельный список)
MemelingConfig.RarityOrder = { "Common", "Rare", "Epic", "Legendary" }

-- AuraPerSecond — сколько Aura в секунду даёт мемлинг на постаменте
-- SellPrice     — сколько Aura получаешь за продажу
-- CarrySpeed    — скорость ходьбы игрока, пока он несёт этого мемлинга
MemelingConfig.Rarities = {
	Common = { AuraPerSecond = 1, SellPrice = 20, CarrySpeed = 16 },
	Rare = { AuraPerSecond = 4, SellPrice = 80, CarrySpeed = 16 },
	Epic = { AuraPerSecond = 15, SellPrice = 300, CarrySpeed = 14 },
	Legendary = { AuraPerSecond = 60, SellPrice = 1200, CarrySpeed = 11 },
}

-- 8 оригинальных мемлингов MVP: 3 Common, 2 Rare, 2 Epic, 1 Legendary.
-- Id никогда не меняем (он попадёт в сохранения), DisplayName можно.
MemelingConfig.Memelings = {
	-- Common
	ToastPaw = { DisplayName = "Toast Paw", Rarity = "Common" },
	SirWobbleton = { DisplayName = "Sir Wobbleton", Rarity = "Common" },
	Grumbloaf = { DisplayName = "Grumbloaf", Rarity = "Common" },
	-- Rare
	NoodleNinja = { DisplayName = "Noodle Ninja", Rarity = "Rare" },
	CaptainSockbeard = { DisplayName = "Captain Sockbeard", Rarity = "Rare" },
	-- Epic
	DiscoPickle = { DisplayName = "Disco Pickle", Rarity = "Epic" },
	ProfessorBonk = { DisplayName = "Professor Bonk", Rarity = "Epic" },
	-- Legendary
	MegaSnoozeasaurus = { DisplayName = "Mega Snoozeasaurus", Rarity = "Legendary" },
}

return deepFreeze(MemelingConfig)
