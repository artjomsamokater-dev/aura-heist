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
	-- Центральная площадь. Смещения от центра хаба по полу (X, Z). Места выбраны между мостиками
	-- (они идут по осям и диагоналям) и в стороне от прохода «точка появления → портал» (X = 0, Z от 0 до 34)
	BestHaul = { -- витрина «BEST HAUL»: подиум с копией самого редкого вынесенного за сессию мемлинга
		Offset = Vector2.new(-25, 11),
		Tiers = { { Height = 1.2, Diameter = 11 }, { Height = 1.2, Diameter = 8.5 } }, -- ступени подиума снизу вверх
		SignHeight = 13, -- подпись «BEST HAUL» над подиумом
	},
	-- Гигантские мемные предметы-декор (по ним не ходят — сквозь них не пройти, но они в стороне)
	Props = {
		{ Kind = "Mug", Offset = Vector2.new(25, 11) },
		{ Kind = "Cheese", Offset = Vector2.new(-25, -11) },
		{ Kind = "Donut", Offset = Vector2.new(25, -11) },
	},
}

-- Фон вокруг хаба и участков: «море» (Baseplate из default.project.json, растянутый до 2048 — предел Roblox),
-- мостики от хаба к участкам и парящие острова-декорации вдали (по ним не ходят)
MapConfig.Background = {
	SeaSize = 2048,
	BridgeWidth = 8,
	BridgeThickness = 0.6,
	-- Острова: центр верхней грани (травы), радиус, высота «земли» под травой и что растёт сверху
	Islands = {
		{ Position = Vector3.new(-290, 55, -160), Radius = 24, Depth = 30, Decor = "Tree" },
		{ Position = Vector3.new(-170, 115, 280), Radius = 18, Depth = 24, Decor = "Mushroom" },
		{ Position = Vector3.new(250, 75, -270), Radius = 20, Depth = 26, Decor = "Crystal" },
		{ Position = Vector3.new(60, 150, -360), Radius = 15, Depth = 20, Decor = "Tree" },
	},
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
	-- Кроме касания (Touched) сервер раз в CheckSeconds сам смотрит, кто стоит внутри портала
	-- (с запасом OverlapMargin студов): вход срабатывает, даже если касание не пришло
	CheckSeconds = 0.2,
	OverlapMargin = 1,
	-- Видимая воронка поверх невидимой детали-«входа» (Size): диск и тёмная середина
	DiscDiameter = 10,
	CoreDiameter = 5.5,
	-- Рамка вокруг портала и столб света над ним (видно от любого участка)
	FramePillarX = 7, -- столбы рамки по бокам портала (снаружи вращающегося кольца)
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
	-- Расстояние от центра хаба до центра участка. 90: до хаба ~11 студов мостика по диагонали,
	-- соседние участки не касаются (центры в 69 студах, «радиус» квадрата 44×44 — 31)
	RingRadius = 90,
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
	-- Два ряда по 5, шаг 8 студов: мемлинг шириной до 7,5 студа соседа не задевает, крайние — внутри ограды.
	-- Первые три (стартовые) — в середине первого ряда. MapBuilder при старте проверяет, что места хватает.
	PedestalOffsets = {
		Vector3.new(-8, 1.5, 4),
		Vector3.new(0, 1.5, 4),
		Vector3.new(8, 1.5, 4),
		Vector3.new(-16, 1.5, 4),
		Vector3.new(16, 1.5, 4),
		Vector3.new(-16, 1.5, 14),
		Vector3.new(-8, 1.5, 14),
		Vector3.new(0, 1.5, 14),
		Vector3.new(8, 1.5, 14),
		Vector3.new(16, 1.5, 14),
	},
	PedestalMinSpacing = 8, -- проверка: ближе этого постаменты стоять не должны
	PedestalEdgeMargin = 4, -- проверка: от центра постамента до края участка не меньше
	-- Кнопки-площадки улучшений: ряд между табличкой и постаментами
	ButtonSize = Vector3.new(5, 0.6, 5),
	UpgradeButtonOffsets = {
		pedestals = Vector3.new(-6, 0.8, -8),
		carrySlots = Vector3.new(6, 0.8, -8),
		storage = Vector3.new(18, 0.8, -8),
	} :: { [string]: Vector3 },
	-- Площадка запаса: мемлинги, которым не хватило постамента (продаются отсюда)
	ReserveOffset = Vector3.new(-18, 0.8, -8),
	-- Площадка Rebirth: между аркой и рядом кнопок, сбоку от коврика
	RebirthOffset = Vector3.new(-12, 0.8, -15),
}

-- Meme Zone: отдельная площадка в стороне от хаба, поднятая в воздух.
-- Пешком или прыжком туда не попасть, только через портал.
local ZONE_FLOOR_Y = 300 -- высота нижней грани пола зоны
local ZONE_TOP = Vector3.new(500, ZONE_FLOOR_Y + 1, 0) -- центр верхней грани пола зоны; от него считаем точки

MapConfig.Zone = {
	Center = ZONE_TOP - Vector3.new(0, 0.5, 0),
	Size = Vector3.new(224, 1, 224), -- смещения X и Z от −112 до 112
	-- Пол делится на две части: от входа (запад) — безопасная, восточнее этой линии — опасная.
	-- Число — смещение по X от центра зоны (шансы редкостей, ловушки и враги — по этой границе).
	-- Доли частей как раньше: безопасная ≈ 56%, опасная ≈ 44% ширины
	DangerFromX = 14,
	EntryPosition = ZONE_TOP + Vector3.new(-90, 0, 0), -- точка входа на полу зоны (западный край)
	EntryMarkerSize = Vector3.new(8, 0.2, 8),
	EntrySpawnHeight = 4, -- на сколько студов выше точки входа ставим персонажа

	-- Точка эвакуации на полу зоны (восточный край). Радиус площадки = ZoneConfig.EvacuationDistance
	ExtractionPosition = ZONE_TOP + Vector3.new(90, 0, 0),
	ExtractionPadThickness = 0.2,
	ExtractionMaxHeight = 10, -- выше этого над площадкой (прыжок не в счёт) игрок уже не «на точке»
	-- Вторая, медленная точка эвакуации — рядом со входом, в безопасной части (правила — ZoneConfig.SideEvacuation)
	SideExtractionPosition = ZONE_TOP + Vector3.new(-95, 0, -28),

	-- Граница зоны: невидимые стены по краям пола
	WallHeight = 40,
	WallThickness = 2,

	-- Страховка: игрок InRaid ниже пола зоны на столько студов — возвращаем в хаб
	FallLimitStuds = 20,
	FallCheckSeconds = 0.5,

	-- Декор зоны: смещения X/Z от центра зоны (по полу). Путь понятен без текста:
	-- ворота у входа → дорожка → ворота в опасную часть → столб света над EXTRACT
	Decor = {
		EntryGateX = -78, -- ворота сразу перед точкой входа: игрок видит их, как только появился
		GatePillarZ = 8,
		GateHeight = 14,
		GatePillarDiameter = 3,
		GateBeamThickness = 2,
		GateCapDiameter = 3.6,
		PathFromX = -90, -- дорожка от входа...
		PathToX = 78, -- ...до края площадки EXTRACT
		PathWidth = 6,
		DangerBorderWidth = 2.4, -- полосатая красно-чёрная лента на полу по границе опасной части
		DangerStripeLength = 4, -- длина одной полосы ленты
		-- Атмосфера опасной части (только там, не через общий Lighting): точки (X, Z) с туманом и
		-- фиолетово-красным светом и светящиеся плиты на полу. В стороне от EXTRACT (X = 90, Z = 0)
		DangerFogPoints = {
			Vector2.new(35, -60),
			Vector2.new(35, 60),
			Vector2.new(65, -75),
			Vector2.new(65, 75),
			Vector2.new(98, -60),
			Vector2.new(98, 60),
		},
		DangerFogAreaSize = 30, -- туман появляется в квадрате такого размера вокруг точки
		DangerLightHeight = 14,
		DangerTiles = { -- светящиеся фиолетовые плиты-узор (декор, не ловушка)
			Vector2.new(24, -100),
			Vector2.new(24, 100),
			Vector2.new(48, -30),
			Vector2.new(48, 30),
			Vector2.new(80, -100),
			Vector2.new(80, 100),
			Vector2.new(106, -20),
			Vector2.new(106, 20),
		},
		DangerTileSize = 7,
		Skull = { Height = 3.4, Size = 3.2 }, -- череп под балкой ворот в опасную часть: ниже балки на Height
		ExtractBeaconDiameter = 6,
		ExtractBeaconHeight = 150, -- выше стен и дымки: виден из любой точки зоны
		SideBeaconHeight = 25, -- столб над второй (медленной) точкой — ниже главного
		-- Ориентиры: грибы-великаны в углах безопасной части, кристаллы — в углах опасной
		Mushrooms = {
			{ Position = Vector2.new(-100, -100), StemHeight = 12, StemDiameter = 3.5, CapDiameter = 14 },
			{ Position = Vector2.new(-100, 100), StemHeight = 9, StemDiameter = 3, CapDiameter = 11 },
			{ Position = Vector2.new(-30, -100), StemHeight = 10, StemDiameter = 3, CapDiameter = 12 },
		},
		Crystals = {
			{ Position = Vector2.new(100, -100), Heights = { 14, 9, 6 } },
			{ Position = Vector2.new(100, 100), Heights = { 12, 8, 5 } },
		},
	},

	-- Точки спавна мемлингов на полу зоны: на каждой появляется один мемлинг.
	-- Разнесены по всей зоне: 12 в безопасной части (X < 14), 8 в опасной (X ≥ 14),
	-- ни одной ближе 30 студов к входу и к EXTRACT
	SpawnPoints = {
		-- Безопасная часть
		ZONE_TOP + Vector3.new(-100, 0, -60),
		ZONE_TOP + Vector3.new(-100, 0, 60),
		ZONE_TOP + Vector3.new(-75, 0, -95),
		ZONE_TOP + Vector3.new(-75, 0, 95),
		ZONE_TOP + Vector3.new(-70, 0, -35),
		ZONE_TOP + Vector3.new(-70, 0, 35),
		ZONE_TOP + Vector3.new(-40, 0, -70),
		ZONE_TOP + Vector3.new(-40, 0, 70),
		ZONE_TOP + Vector3.new(-35, 0, -15),
		ZONE_TOP + Vector3.new(-35, 0, 15),
		ZONE_TOP + Vector3.new(-5, 0, -55),
		ZONE_TOP + Vector3.new(-5, 0, 55),
		-- Опасная часть
		ZONE_TOP + Vector3.new(30, 0, -60),
		ZONE_TOP + Vector3.new(30, 0, 60),
		ZONE_TOP + Vector3.new(48, 0, -100),
		ZONE_TOP + Vector3.new(50, 0, 100),
		ZONE_TOP + Vector3.new(75, 0, -50),
		ZONE_TOP + Vector3.new(75, 0, 55),
		ZONE_TOP + Vector3.new(100, 0, -35),
		ZONE_TOP + Vector3.new(100, 0, 35),
	},
}


return deepFreeze(MapConfig)
