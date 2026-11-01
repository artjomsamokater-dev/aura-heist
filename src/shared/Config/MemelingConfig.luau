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
	Zone: string?, -- в какой зоне появляется (Id из ZoneConfig.ZoneOrder); nil — в зонах не появляется
	IncomeMultiplier: number?, -- доход на постаменте × это число от базы редкости (нет — ×1)
}

export type Rarity = {
	AuraPerSecond: number,
	SellPrice: number,
	CarrySpeed: number,
}

local MemelingConfig = {}

-- Порядок редкостей от слабой к сильной (у словаря порядка нет, поэтому отдельный список)
-- Secret — самая редкая: не появляется в зонах, её получают один раз за секретный паркур в хабе
MemelingConfig.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Secret" }

-- AuraPerSecond — сколько Aura в секунду даёт мемлинг на постаменте
-- SellPrice     — сколько Aura получаешь за продажу
-- CarrySpeed    — скорость ходьбы игрока, пока он несёт этого мемлинга
MemelingConfig.Rarities = {
	Common = { AuraPerSecond = 1, SellPrice = 20, CarrySpeed = 16 },
	Rare = { AuraPerSecond = 4, SellPrice = 80, CarrySpeed = 16 },
	Epic = { AuraPerSecond = 15, SellPrice = 300, CarrySpeed = 14 },
	Legendary = { AuraPerSecond = 60, SellPrice = 1200, CarrySpeed = 11 },
	Secret = { AuraPerSecond = 60 * 2, SellPrice = 1200 * 2, CarrySpeed = 11 }, -- как Legendary ×2
} :: { [string]: Rarity }

-- Мемлинги Golden Zone приносят на постаменте в столько раз больше Aura, чем база их редкости
local GOLDEN_INCOME = 5
MemelingConfig.GoldenIncomeMultiplier = GOLDEN_INCOME

-- Мемлинги Meme Zone: 8 из MVP + 5 из задачи 7.6 (5 Common, 3 Rare, 3 Epic, 2 Legendary);
-- Golden Zone: 5 + 3 из задачи 7.6 (3 Rare, 3 Epic, 2 Legendary). В каждой зоне есть хотя бы один Legendary
-- (проверяют тест RarityRoll и сервер при старте).
-- Id никогда не меняем (он попадёт в сохранения). Имена для игрока — в TextConfig.MemelingNames.
MemelingConfig.Memelings = {
	-- Meme Zone. Common
	ToastPaw = { Rarity = "Common", Zone = "Meme" },
	SirWobbleton = { Rarity = "Common", Zone = "Meme" },
	Grumbloaf = { Rarity = "Common", Zone = "Meme" },
	SoggyCereal = { Rarity = "Common", Zone = "Meme" },
	ChonkyDumpling = { Rarity = "Common", Zone = "Meme" },
	-- Rare
	NoodleNinja = { Rarity = "Rare", Zone = "Meme" },
	CaptainSockbeard = { Rarity = "Rare", Zone = "Meme" },
	SpicyNugget = { Rarity = "Rare", Zone = "Meme" },
	-- Epic
	DiscoPickle = { Rarity = "Epic", Zone = "Meme" },
	ProfessorBonk = { Rarity = "Epic", Zone = "Meme" },
	ToiletPaperPrince = { Rarity = "Epic", Zone = "Meme" },
	-- Legendary
	MegaSnoozeasaurus = { Rarity = "Legendary", Zone = "Meme" },
	CosmicBurrito = { Rarity = "Legendary", Zone = "Meme" },

	-- Golden Zone: только там, доход на постаменте ×GOLDEN_INCOME от базы своей редкости
	BubbleTeaBandit = { Rarity = "Rare", Zone = "Golden", IncomeMultiplier = GOLDEN_INCOME },
	CactusCrooner = { Rarity = "Rare", Zone = "Golden", IncomeMultiplier = GOLDEN_INCOME },
	DiamondDonut = { Rarity = "Rare", Zone = "Golden", IncomeMultiplier = GOLDEN_INCOME },
	PizzaPigeon = { Rarity = "Epic", Zone = "Golden", IncomeMultiplier = GOLDEN_INCOME },
	RoboDuck = { Rarity = "Epic", Zone = "Golden", IncomeMultiplier = GOLDEN_INCOME },
	TrophyTurtle = { Rarity = "Epic", Zone = "Golden", IncomeMultiplier = GOLDEN_INCOME },
	KingWaffleton = { Rarity = "Legendary", Zone = "Golden", IncomeMultiplier = GOLDEN_INCOME },
	SirMoneybags = { Rarity = "Legendary", Zone = "Golden", IncomeMultiplier = GOLDEN_INCOME },

	-- Награда за секретный паркур в хабе (в зонах не появляется)
	Error404Kitten = { Rarity = "Secret" },
} :: { [string]: Memeling }

return deepFreeze(MemelingConfig)
