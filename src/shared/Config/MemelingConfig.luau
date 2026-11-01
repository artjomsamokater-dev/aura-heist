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
	Zone: string, -- в какой зоне появляется (Id из ZoneConfig.ZoneOrder)
	IncomeMultiplier: number?, -- доход на постаменте × это число от базы редкости (нет — ×1)
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

-- Мемлинги Golden Zone приносят на постаменте в столько раз больше Aura, чем база их редкости
local GOLDEN_INCOME = 5
MemelingConfig.GoldenIncomeMultiplier = GOLDEN_INCOME

-- 8 оригинальных мемлингов MVP (Meme Zone): 3 Common, 2 Rare, 2 Epic, 1 Legendary; 5 — Golden Zone.
-- Id никогда не меняем (он попадёт в сохранения). Имена для игрока — в TextConfig.MemelingNames.
MemelingConfig.Memelings = {
	-- Meme Zone. Common
	ToastPaw = { Rarity = "Common", Zone = "Meme" },
	SirWobbleton = { Rarity = "Common", Zone = "Meme" },
	Grumbloaf = { Rarity = "Common", Zone = "Meme" },
	-- Rare
	NoodleNinja = { Rarity = "Rare", Zone = "Meme" },
	CaptainSockbeard = { Rarity = "Rare", Zone = "Meme" },
	-- Epic
	DiscoPickle = { Rarity = "Epic", Zone = "Meme" },
	ProfessorBonk = { Rarity = "Epic", Zone = "Meme" },
	-- Legendary
	MegaSnoozeasaurus = { Rarity = "Legendary", Zone = "Meme" },

	-- Golden Zone: только там, доход на постаменте ×GOLDEN_INCOME от базы своей редкости
	BubbleTeaBandit = { Rarity = "Rare", Zone = "Golden", IncomeMultiplier = GOLDEN_INCOME },
	CactusCrooner = { Rarity = "Rare", Zone = "Golden", IncomeMultiplier = GOLDEN_INCOME },
	PizzaPigeon = { Rarity = "Epic", Zone = "Golden", IncomeMultiplier = GOLDEN_INCOME },
	RoboDuck = { Rarity = "Epic", Zone = "Golden", IncomeMultiplier = GOLDEN_INCOME },
	KingWaffleton = { Rarity = "Legendary", Zone = "Golden", IncomeMultiplier = GOLDEN_INCOME },
} :: { [string]: Memeling }

return deepFreeze(MemelingConfig)
