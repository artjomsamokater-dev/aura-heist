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
	-- Дорожка от точки появления к порталу (лежит на полу хаба)
	PathCenter = Vector3.new(0, 1.05, 19),
	PathSize = Vector3.new(8, 0.1, 26),
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
	-- Рамка вокруг портала и столб света над ним (видно от любого участка)
	FramePillarX = 6.5, -- столбы рамки по бокам портала
	FramePillarDiameter = 2.4,
	FrameHeight = 14,
	FrameCapDiameter = 3.2,
	BeaconDiameter = 3,
	BeaconHeight = 70,
}

-- Участки баз (студии): стоят кольцом вокруг хаба, лицом к нему.
-- Смещения ниже — относительно центра участка: -Z смотрит на хаб, +Z — от хаба.
MapConfig.Plots = {
	Count = 8,
	RingRadius = 120, -- расстояние от центра хаба до центра участка
	Size = Vector3.new(44, 1, 44),
	SignSize = Vector3.new(12, 3.4, 0.8),
	SignOffset = Vector3.new(0, 8.6, -21), -- табличка висит под перекладиной арки у входа
	-- Арка входа на краю, ближнем к хабу: два круглых столба, перекладина, шары сверху
	Arch = {
		PillarX = 7,
		Z = -21,
		Height = 10,
		PillarDiameter = 1.6,
		CapDiameter = 2.4,
		BeamSize = Vector3.new(16, 1.6, 1.6),
	},
	-- Низкая ограда: столбики и перекладина по отрезкам (в координатах участка, по полу)
	Fence = {
		PostStep = 7, -- расстояние между столбиками
		PostHeight = 3,
		PostDiameter = 1,
		RailSize = Vector2.new(0.4, 0.4), -- сечение перекладины
		Segments = {
			{ From = Vector2.new(-21.5, -21.5), To = Vector2.new(-21.5, 21.5) },
			{ From = Vector2.new(-21.5, 21.5), To = Vector2.new(21.5, 21.5) },
			{ From = Vector2.new(21.5, 21.5), To = Vector2.new(21.5, -21.5) },
			{ From = Vector2.new(-21.5, -21.5), To = Vector2.new(-8.5, -21.5) },
			{ From = Vector2.new(8.5, -21.5), To = Vector2.new(21.5, -21.5) },
		},
	},
	-- Коврик от арки к постаментам
	RugCenter = Vector3.new(0, 0.55, -9.5),
	RugSize = Vector3.new(6, 0.1, 23),
	RugBorder = 0.6, -- ширина каймы цвета акцента
	PedestalSize = Vector3.new(4, 2, 4),
	-- Все места под постаменты: первые StartCount доступны сразу, остальные открываются улучшением.
	-- Мест должно быть столько, сколько даёт максимальный уровень в UpgradeConfig.Pedestals
	PedestalOffsets = {
		Vector3.new(-12, 1.5, 6),
		Vector3.new(0, 1.5, 6),
		Vector3.new(12, 1.5, 6),
		Vector3.new(-12, 1.5, 16),
		Vector3.new(0, 1.5, 16),
		Vector3.new(12, 1.5, 16),
	},
	-- Кнопки-площадки улучшений: ряд между табличкой и постаментами
	ButtonSize = Vector3.new(5, 0.6, 5),
	UpgradeButtonOffsets = {
		pedestals = Vector3.new(-6, 0.8, -8),
		carrySlots = Vector3.new(6, 0.8, -8),
		storage = Vector3.new(18, 0.8, -8),
	} :: { [string]: Vector3 },
	-- Площадка запаса: мемлинги, которым не хватило постамента (продаются отсюда)
	ReserveOffset = Vector3.new(-18, 0.8, -8),
}

-- Meme Zone: отдельная площадка в стороне от хаба, поднятая в воздух.
-- Пешком или прыжком туда не попасть, только через портал.
local ZONE_FLOOR_Y = 300 -- высота нижней грани пола зоны
local ZONE_TOP = Vector3.new(500, ZONE_FLOOR_Y + 1, 0) -- центр верхней грани пола зоны; от него считаем точки

MapConfig.Zone = {
	Center = ZONE_TOP - Vector3.new(0, 0.5, 0),
	Size = Vector3.new(160, 1, 160),
	-- Пол делится на две части: от входа (запад) — безопасная, восточнее этой линии — опасная.
	-- Число — смещение по X от центра зоны (шансы редкостей, ловушки и враги — по этой границе).
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

	-- Декор зоны: смещения X/Z от центра зоны (по полу). Путь понятен без текста:
	-- ворота у входа → дорожка → ворота в опасную часть → столб света над EXTRACT
	Decor = {
		EntryGateX = -50, -- ворота сразу перед точкой входа: игрок видит их, как только появился
		GatePillarZ = 8,
		GateHeight = 14,
		GatePillarDiameter = 3,
		GateBeamThickness = 2,
		GateCapDiameter = 3.6,
		PathFromX = -60, -- дорожка от входа...
		PathToX = 48, -- ...до края площадки EXTRACT
		PathWidth = 6,
		DangerBorderWidth = 1.2, -- полоса на полу по границе опасной части
		ExtractBeaconDiameter = 4,
		ExtractBeaconHeight = 60,
		-- Ориентиры: грибы-великаны в углах безопасной части, кристаллы — в углах опасной
		Mushrooms = {
			{ Position = Vector2.new(-64, -62), StemHeight = 12, StemDiameter = 3.5, CapDiameter = 14 },
			{ Position = Vector2.new(-64, 62), StemHeight = 9, StemDiameter = 3, CapDiameter = 11 },
		},
		Crystals = {
			{ Position = Vector2.new(68, -68), Heights = { 14, 9, 6 } },
			{ Position = Vector2.new(68, 68), Heights = { 12, 8, 5 } },
		},
	},

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


return deepFreeze(MapConfig)
