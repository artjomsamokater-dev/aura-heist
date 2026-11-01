--!strict
-- EconomyConfig: общие правила экономики.
-- Доход и цены по редкостям — в MemelingConfig, цены улучшений — в UpgradeConfig.

-- table.freeze замораживает только верхний уровень, поэтому замораживаем всё дерево
local function deepFreeze<T>(t: T): T
	for _, value in t :: any do
		if type(value) == "table" and not table.isfrozen(value) then
			deepFreeze(value)
		end
	end
	return table.freeze(t :: any) :: any
end

local EconomyConfig = {}

-- Бонус отряда: два игрока завершили эвакуацию рядом и почти одновременно — принесённые
-- мемлинги обоих навсегда приносят больше Aura на постаменте (флаг на мемлинге в профиле,
-- выдаётся один раз). Цену продажи бонус не меняет
EconomyConfig.SquadBonus = {
	IncomeBonusPercent = 50, -- +50% к доходу мемлинга на постаменте
	Radius = 15, -- не дальше 15 студов друг от друга (по полу)
	WindowSeconds = 5, -- с разницей не больше 5 секунд
}

-- «Охота» (задача 7.5): раз в IntervalSeconds сервер выбирает одного мемлинга из зон (не Secret) — BOUNTY.
-- Вынесенный через эвакуацию, пока он BOUNTY, навсегда приносит больше Aura (флаг bounty на мемлинге в профиле)
EconomyConfig.Bounty = {
	IntervalSeconds = 600, -- 10 минут на одну охоту
	IncomeMultiplier = 2, -- ×2 к доходу на постаменте
}

EconomyConfig.AutosaveSeconds = 90 -- как часто сохраняем профиль игрока

-- Rebirth: когда куплены ВСЕ улучшения и есть Cost Aura — Aura и улучшения сбрасываются,
-- мемлинги не теряются (на стартовые постаменты — самые доходные, остальные в запас), доход постаментов
-- навсегда выше на IncomeBonusPercent за каждый rebirth.
-- Цена следующего: BaseCost × CostGrowth ^ (сколько rebirth уже сделано)
EconomyConfig.Rebirth = {
	BaseCost = 50000,
	CostGrowth = 2,
	IncomeBonusPercent = 25,
}

-- Секретный паркур в хабе: первый раз — мемлинг Secret на витрину (один раз навсегда),
-- потом — DailyAura за проход, не чаще раза в CooldownSeconds
EconomyConfig.SecretObby = {
	MemelingId = "Error404Kitten",
	DailyAura = 500,
	CooldownSeconds = 24 * 60 * 60,
}

EconomyConfig.CollectDistance = 10 -- максимум студов до постамента, чтобы собрать с него Aura
EconomyConfig.ButtonDistance = 8 -- максимум студов до кнопки улучшения на участке
EconomyConfig.PedestalLabelUpdateSeconds = 0.5 -- как часто обновляем подпись «накоплено» над постаментами

return deepFreeze(EconomyConfig)
