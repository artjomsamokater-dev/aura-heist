--!strict
-- MapConfig: размеры и позиции карты (цвета и материалы — в StyleConfig).
-- Все полы толщиной 1 студ. Хаб и участки стоят верхней гранью на y = 1 (Baseplate кончается на y = 0),
-- зона поднята на ZONE_FLOOR_Y.

-- table.freeze замораживает только верхний уровень, поэтому замораживаем всё дерево
local function deepFreeze<T>(t: T): T
	for _, value in t :: any do
		if type(value) == "table" and not table.isfrozen(value) then
			deepFreeze(value)
		end
	end
	return table.freeze(t :: any) :: any
end

local MapConfig = {}

-- Хаб: центральная площадка, где игроки появляются
MapConfig.Hub = {
	Center = Vector3.new(0, 0.5, 0),
	Size = Vector3.new(80, 1, 80),
}

-- Точка появления в центре хаба
MapConfig.Spawn = {
	Position = Vector3.new(0, 1.5, 0),
	Size = Vector3.new(12, 1, 12),
	ArrivalHeight = 4, -- на сколько студов выше точки появления ставим персонажа после эвакуации
}

-- Портал в зону: стоит на краю хаба, сквозь него можно пройти
MapConfig.Portal = {
	Position = Vector3.new(0, 7, 34),
	Size = Vector3.new(10, 12, 2),
	CooldownSeconds = 2, -- защита от повторного срабатывания для одного игрока
}

-- Участки баз (студии): стоят кольцом вокруг хаба, лицом к нему.
-- Смещения ниже — относительно центра участка: -Z смотрит на хаб, +Z — от хаба.
MapConfig.Plots = {
	Count = 8,
	RingRadius = 120, -- расстояние от центра хаба до центра участка
	Size = Vector3.new(44, 1, 44),
	SignSize = Vector3.new(10, 5, 1),
	SignOffset = Vector3.new(0, 3, -19), -- табличка у края, ближнего к хабу
	PedestalSize = Vector3.new(4, 2, 4),
	PedestalOffsets = {
		Vector3.new(-12, 1.5, 8),
		Vector3.new(0, 1.5, 8),
		Vector3.new(12, 1.5, 8),
	},
}

-- Meme Zone: отдельная площадка в стороне от хаба, поднятая в воздух.
-- Пешком или прыжком туда не попасть, только через портал.
local ZONE_FLOOR_Y = 300 -- высота нижней грани пола зоны
local ZONE_TOP = Vector3.new(500, ZONE_FLOOR_Y + 1, 0) -- центр верхней грани пола зоны; от него считаем точки

MapConfig.Zone = {
	Center = ZONE_TOP - Vector3.new(0, 0.5, 0),
	Size = Vector3.new(160, 1, 160),
	-- Пол делится на две части: от входа (запад) — безопасная, восточнее этой линии — опасная.
	-- Число — смещение по X от центра зоны. Пока это только цвет, правила частей — задача 3.1.
	DangerFromX = 10,
	EntryPosition = ZONE_TOP + Vector3.new(-60, 0, 0), -- точка входа на полу зоны (западный край)
	EntryMarkerSize = Vector3.new(8, 0.2, 8),
	EntrySpawnHeight = 4, -- на сколько студов выше точки входа ставим персонажа

	-- Точка эвакуации на полу зоны (восточный край). Радиус площадки = ZoneConfig.EvacuationDistance
	ExtractionPosition = ZONE_TOP + Vector3.new(60, 0, 0),
	ExtractionPadThickness = 0.2,
	ExtractionMaxHeight = 10, -- выше этого над площадкой (прыжок не в счёт) игрок уже не «на точке»

	-- Граница зоны: невидимые стены по краям пола
	WallHeight = 40,
	WallThickness = 2,

	-- Страховка: игрок InRaid ниже пола зоны на столько студов — возвращаем в хаб
	FallLimitStuds = 20,
	FallCheckSeconds = 0.5,

	-- Точки спавна мемлингов на полу зоны: на каждой появляется один мемлинг
	SpawnPoints = {
		ZONE_TOP + Vector3.new(-40, 0, -30),
		ZONE_TOP + Vector3.new(-40, 0, 30),
		ZONE_TOP + Vector3.new(-10, 0, -55),
		ZONE_TOP + Vector3.new(-10, 0, 0),
		ZONE_TOP + Vector3.new(-10, 0, 55),
		ZONE_TOP + Vector3.new(20, 0, -35),
		ZONE_TOP + Vector3.new(20, 0, 35),
		ZONE_TOP + Vector3.new(35, 0, 0),
	},
}

-- Мемлинг: круглое тело и два глаза (белок + зрачок), смотрит в сторону -Z.
-- Смещения глаз — от центра тела.
MapConfig.Memeling = {
	Size = Vector3.new(3, 3, 3),
	EyeSize = 0.9,
	PupilSize = 0.45,
	EyeOffsets = {
		Vector3.new(-0.6, 0.35, -1.25),
		Vector3.new(0.6, 0.35, -1.25),
	},
	PupilForward = 0.35, -- на сколько зрачок выступает вперёд от центра глаза
	-- Где мемлинг висит, когда его несут: относительно HumanoidRootPart (-Z = перед персонажем)
	CarryOffset = Vector3.new(0, 0, -2.5),
	CarryStackStep = Vector3.new(0, 3.2, 0), -- каждый следующий мемлинг в руках — выше предыдущего
}

-- Подписи над объектами (BillboardGui), размеры в студах
MapConfig.Label = {
	WidthStuds = 12,
	HeightStuds = 3,
	MaxDistance = 200,
	-- Имя владельца на табличке участка — крупнее обычной подписи
	SignWidthStuds = 22,
	SignHeightStuds = 5,
}

return deepFreeze(MapConfig)
