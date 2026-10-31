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

-- Первые уровни — из документации; дальше каждый уровень дороже предыдущего примерно в 2,5 раза.
-- Когда куплено всё — доступен Rebirth (EconomyConfig.Rebirth).

-- Постаменты: старт 3, дальше покупаются по порядку (мест на участке — MapConfig.Plots.PedestalOffsets)
UpgradeConfig.Pedestals = {
	StartCount = 3,
	Levels = {
		{ Count = 4, Cost = 100 },
		{ Count = 5, Cost = 300 },
		{ Count = 6, Cost = 900 },
		{ Count = 7, Cost = 2250 },
		{ Count = 8, Cost = 5600 },
		{ Count = 9, Cost = 14000 },
		{ Count = 10, Cost = 35000 },
	},
}

-- Слоты переноски (рюкзак): старт 1
UpgradeConfig.CarrySlots = {
	StartCount = 1,
	Levels = {
		{ Count = 2, Cost = 150 },
		{ Count = 3, Cost = 500 },
		{ Count = 4, Cost = 1250 },
		{ Count = 5, Cost = 3100 },
	},
}

-- Хранилище: вмещает столько Aura, сколько база приносит за StartSeconds секунд (× Multiplier)
UpgradeConfig.Storage = {
	StartSeconds = 120,
	Levels = {
		{ Multiplier = 2, Cost = 250 },
		{ Multiplier = 3, Cost = 625 },
		{ Multiplier = 4, Cost = 1560 },
	},
}

return deepFreeze(UpgradeConfig)
