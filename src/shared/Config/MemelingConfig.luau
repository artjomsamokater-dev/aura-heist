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

export type Memeling = {
	Rarity: string,
}

export type Rarity = {
	AuraPerSecond: number,
	SellPrice: number,
	CarrySpeed: number,
}

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
} :: { [string]: Rarity }

-- 8 оригинальных мемлингов MVP: 3 Common, 2 Rare, 2 Epic, 1 Legendary.
-- Id никогда не меняем (он попадёт в сохранения). Имена для игрока — в TextConfig.MemelingNames.
MemelingConfig.Memelings = {
	-- Common
	ToastPaw = { Rarity = "Common" },
	SirWobbleton = { Rarity = "Common" },
	Grumbloaf = { Rarity = "Common" },
	-- Rare
	NoodleNinja = { Rarity = "Rare" },
	CaptainSockbeard = { Rarity = "Rare" },
	-- Epic
	DiscoPickle = { Rarity = "Epic" },
	ProfessorBonk = { Rarity = "Epic" },
	-- Legendary
	MegaSnoozeasaurus = { Rarity = "Legendary" },
} :: { [string]: Memeling }

return deepFreeze(MemelingConfig)
