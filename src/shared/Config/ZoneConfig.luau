--!strict
-- ZoneConfig: зоны вылазок (список и правила каждой) и общие числа — ресток, дистанции подбора и эвакуации.
-- Геометрия зон — MapConfig.Zones[Id], ловушки — HazardConfig.Zones[Id], враги — EnemyConfig.Zones[Id].

-- table.freeze замораживает только верхний уровень, поэтому замораживаем всё дерево
local function deepFreeze<T>(t: T): T
	for _, value in t :: any do
		if type(value) == "table" and not table.isfrozen(value) then
			deepFreeze(value)
		end
	end
	return table.freeze(t :: any) :: any
end

local ZoneConfig = {}

export type Zone = {
	-- Шанс редкости при появлении мемлинга, в процентах (сумма в каждой части = 100).
	-- Safe — от входа до MapConfig.Zones[Id].DangerFromX, Danger — восточнее (там же ловушки и враги).
	-- Правило всех зон: Legendary — только в опасной части (в Safe шанс 0; проверяет тест RarityRoll)
	-- Какие мемлинги появляются — те, у кого MemelingConfig.Memelings[].Zone = Id этой зоны
	SpawnChances: { [string]: { [string]: number } },
	AccessCost: number?, -- nil — вход свободный; число — доступ покупается навсегда за столько Aura
	Tutorial: boolean, -- шаги туториала засчитываются только в этой зоне
}

-- Порядок зон (у словаря порядка нет): первая — стартовая
ZoneConfig.ZoneOrder = { "Meme", "Golden", "Candy" }

ZoneConfig.Zones = {
	Meme = {
		SpawnChances = {
			Safe = { Common = 80, Rare = 20, Epic = 0, Legendary = 0 },
			Danger = { Common = 0, Rare = 55, Epic = 38, Legendary = 7 },
		},
		AccessCost = nil,
		Tutorial = true,
	},
	-- Golden Zone: свои 5 мемлингов (доход ×5 — MemelingConfig), Common нет; вход — золотые ворота в хабе
	Golden = {
		SpawnChances = {
			Safe = { Common = 0, Rare = 70, Epic = 30, Legendary = 0 },
			Danger = { Common = 0, Rare = 40, Epic = 45, Legendary = 15 },
		},
		AccessCost = 25000, -- доступ навсегда, покупка через Economy (сервис ZoneAccess)
		Tutorial = false,
	},
	-- Candy Chaos (задача 7.7): свои 5 мемлингов (доход ×20 — MemelingConfig), Common нет; как в других зонах,
	-- Legendary — только в опасной части; враги — мармеладные GummyBrute (EnemyConfig.Zones.Candy)
	Candy = {
		SpawnChances = {
			Safe = { Common = 0, Rare = 60, Epic = 40, Legendary = 0 },
			Danger = { Common = 0, Rare = 35, Epic = 45, Legendary = 20 },
		},
		AccessCost = 250000,
		Tutorial = false,
	},
} :: { [string]: Zone }

ZoneConfig.UnlockHoldSeconds = 1 -- сколько держать кнопку покупки доступа у золотых ворот

ZoneConfig.FirstZone = "Meme" -- стартовая зона: в неё ведёт туториал, по ней считаются подсказки клиента по умолчанию

-- Раз в столько секунд все пустые точки спавна получают новых мемлингов.
-- Для теста с игроками — 90; по документации — 180
ZoneConfig.RestockSeconds = 90

-- О каких редкостях объявлять всем игрокам, когда они появляются (одно объявление на спавн)
ZoneConfig.AnnounceRarities = { "Epic", "Legendary" }
ZoneConfig.EvacuationSeconds = 3 -- сколько секунд длится эвакуация на основном EXTRACT

-- Вторая точка эвакуации — у входа, в безопасной части (MapConfig.Zones[Id].SideExtractionPosition):
-- стоять дольше, и только если в руках нет мемлингов из BlockedRarities
ZoneConfig.SideEvacuation = {
	Seconds = 8,
	Distance = 7, -- радиус площадки, студов
	BlockedRarities = { "Epic", "Legendary" },
}
ZoneConfig.PickupDistance = 10 -- максимум студов до мемлинга, чтобы его подобрать
ZoneConfig.EvacuationDistance = 12 -- максимум студов до точки эвакуации
ZoneConfig.EvacuationCheckSeconds = 0.1 -- как часто сервер проверяет, кто стоит на точке эвакуации
ZoneConfig.LostRespawnSeconds = 10 -- через сколько секунд потерянный мемлинг возвращается на свою точку спавна

-- Смерть с лутом: всё из рук выпадает на пол у места смерти. Столько секунд его может поднять
-- только погибший, потом лут возвращается на точки спавна (как потерянный). Падение из зоны — без лута
ZoneConfig.LootSeconds = 20
ZoneConfig.LootSpreadStuds = 5 -- несколько мемлингов раскладываются кругом такого радиуса

return deepFreeze(ZoneConfig)
