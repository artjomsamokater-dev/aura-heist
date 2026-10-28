--!strict
-- UpgradeConfig: стартовые значения базы и цены улучшений (в Aura).

-- table.freeze замораживает только верхний уровень, поэтому замораживаем всё дерево
local function deepFreeze<T>(t: T): T
	for _, value in t :: any do
		if type(value) == "table" and not table.isfrozen(value) then
			deepFreeze(value)
		end
	end
	return table.freeze(t :: any) :: any
end

local UpgradeConfig = {}

-- Постаменты: старт 3, дальше покупаются по порядку
UpgradeConfig.Pedestals = {
	StartCount = 3,
	Levels = {
		{ Count = 4, Cost = 100 },
		{ Count = 5, Cost = 300 },
		{ Count = 6, Cost = 900 },
	},
}

-- Слоты переноски (рюкзак): старт 1
UpgradeConfig.CarrySlots = {
	StartCount = 1,
	Levels = {
		{ Count = 2, Cost = 150 },
		{ Count = 3, Cost = 500 },
	},
}

-- Хранилище: вмещает столько Aura, сколько база приносит за StartSeconds секунд
UpgradeConfig.Storage = {
	StartSeconds = 120,
	Levels = {
		{ Multiplier = 2, Cost = 250 },
	},
}

return deepFreeze(UpgradeConfig)
