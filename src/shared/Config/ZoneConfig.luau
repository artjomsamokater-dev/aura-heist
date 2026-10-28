--!strict
-- ZoneConfig: числа Meme Zone — шансы появления, ресток, дистанции подбора и эвакуации.

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

-- Шанс редкости при появлении мемлинга, в процентах (сумма в каждой части = 100)
ZoneConfig.SpawnChances = {
	Safe = { Common = 80, Rare = 20, Epic = 0, Legendary = 0 },
	Danger = { Common = 0, Rare = 55, Epic = 38, Legendary = 7 },
}

ZoneConfig.RestockSeconds = 180 -- через сколько секунд зона заново наполняется мемлингами
ZoneConfig.EvacuationSeconds = 3 -- сколько секунд длится эвакуация
ZoneConfig.PickupDistance = 10 -- максимум студов до мемлинга, чтобы его подобрать
ZoneConfig.EvacuationDistance = 12 -- максимум студов до точки эвакуации
ZoneConfig.EvacuationCheckSeconds = 0.1 -- как часто сервер проверяет, кто стоит на точке эвакуации
ZoneConfig.LostRespawnSeconds = 10 -- через сколько секунд потерянный мемлинг возвращается на свою точку спавна

return deepFreeze(ZoneConfig)
