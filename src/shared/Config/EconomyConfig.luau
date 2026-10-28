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

-- Бонус отряда: если рядом с продающим есть союзники, цена продажи выше
EconomyConfig.SquadBonus = {
	SellBonusPercent = 25, -- +25% к цене продажи
	Radius = 15, -- в радиусе 15 студов
}

EconomyConfig.AutosaveSeconds = 90 -- как часто сохраняем профиль игрока

EconomyConfig.CollectDistance = 10 -- максимум студов до постамента, чтобы собрать с него Aura
EconomyConfig.ButtonDistance = 8 -- максимум студов до кнопки улучшения на участке
EconomyConfig.PedestalLabelUpdateSeconds = 0.5 -- как часто обновляем подпись «накоплено» над постаментами

return deepFreeze(EconomyConfig)
