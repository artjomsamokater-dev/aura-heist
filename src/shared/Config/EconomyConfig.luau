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

-- Бонус отряда: два игрока завершили эвакуацию рядом и почти одновременно — у принесённых
-- мемлингов обоих цена продажи выше (флаг на мемлинге в профиле, выдаётся один раз)
EconomyConfig.SquadBonus = {
	SellBonusPercent = 25, -- +25% к цене продажи
	Radius = 15, -- не дальше 15 студов друг от друга (по полу)
	WindowSeconds = 5, -- с разницей не больше 5 секунд
}

EconomyConfig.AutosaveSeconds = 90 -- как часто сохраняем профиль игрока

-- Rebirth: когда куплены ВСЕ улучшения и есть Cost Aura — Aura и улучшения сбрасываются,
-- витрина и запас остаются, доход постаментов навсегда выше на IncomeBonusPercent за каждый rebirth.
-- Цена следующего: BaseCost × CostGrowth ^ (сколько rebirth уже сделано)
EconomyConfig.Rebirth = {
	BaseCost = 50000,
	CostGrowth = 2,
	IncomeBonusPercent = 25,
}

EconomyConfig.CollectDistance = 10 -- максимум студов до постамента, чтобы собрать с него Aura
EconomyConfig.ButtonDistance = 8 -- максимум студов до кнопки улучшения на участке
EconomyConfig.PedestalLabelUpdateSeconds = 0.5 -- как часто обновляем подпись «накоплено» над постаментами

return deepFreeze(EconomyConfig)
