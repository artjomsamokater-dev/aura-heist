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

-- Хаб: круглая площадь, где игроки появляются. Смещения на площади — от её центра по полу (X, Z).
-- Углы: 0° — +X, 90° — +Z (портал). Мостики к участкам — на углах 22,5° + 45°·k (MapConfig.Plots),
-- поэтому всё крупное стоит «в секторах» между ними: на 0°, 45°, 90°, 135° … 315°.
local function polar(angleDegrees: number, radius: number): Vector2
	local a = math.rad(angleDegrees)
	return Vector2.new(math.cos(a) * radius, math.sin(a) * radius)
end

MapConfig.Hub = {
	Center = Vector3.new(0, 0.5, 0),
	Radius = 50, -- круглая площадь; до переднего края участков (58) — короткие мостики
	Size = Vector3.new(100, 1, 100), -- габарит (толщина пола — Y)
	TileSize = 10, -- узор пола: квадраты двух оттенков мяты в шахматном порядке
	PathWidth = 6,
	CenterRadius = 12, -- кремовый круг вокруг фонтана, от него расходятся дорожки
	-- Дорожки от центрального круга: к порталу и витрине (сюда) и к каждому мостику (MapBuilder сам)
	Paths = {
		{ Angle = 90, To = 27 }, -- к подиуму портала
		{ Angle = 0, To = 24.5 }, -- к витрине BEST HAUL
	},
	BestHaul = { -- витрина «BEST HAUL»: подиум с копией самого редкого вынесенного за сессию мемлинга
		Offset = polar(0, 30),
		Tiers = { { Height = 1.2, Diameter = 11 }, { Height = 1.2, Diameter = 8.5 } }, -- ступени подиума снизу вверх
		SignHeight = 13, -- подпись «BEST HAUL» над подиумом
	},
	-- Гигантские мемные предметы-декор в секторах между мостиками (сквозь них не пройти, но они в стороне)
	Props = {
		{ Kind = "Mug", Offset = polar(180, 36) },
		{ Kind = "Cheese", Offset = polar(315, 37) },
		{ Kind = "Donut", Offset = polar(180, 21) },
		{ Kind = "Phone", Offset = polar(45, 38) },
		{ Kind = "Banana", Offset = polar(135, 38) },
		{ Kind = "Duck", Offset = polar(225, 37) },
		{ Kind = "Headphones", Offset = polar(270, 37) },
	},
	-- Декор площади (server/Visual/HubDecor): места — угол (градусы) и расстояние от центра.
	-- Деревья и кусты — у края между мостиками; клумбы и скамейки — вокруг фонтана в секторах 45°/135°/…
	Decor = {
		FountainRadius = 6.5,
		Trees = {
			{ Angle = 31, Radius = 45 },
			{ Angle = 59, Radius = 45 },
			{ Angle = 121, Radius = 45 },
			{ Angle = 149, Radius = 45 },
			{ Angle = 211, Radius = 45 },
			{ Angle = 239, Radius = 45 },
			{ Angle = 301, Radius = 45 },
			{ Angle = 329, Radius = 45 },
		},
		Bushes = {
			{ Angle = 166, Radius = 44 },
			{ Angle = 194, Radius = 44 },
			{ Angle = 256, Radius = 44 },
			{ Angle = 284, Radius = 44 },
			{ Angle = 346, Radius = 44 },
			{ Angle = 14, Radius = 44 },
		},
		FlowerBeds = { -- клумбы: круглая грядка и крупные цветы
			{ Angle = 45, Radius = 17 },
			{ Angle = 135, Radius = 17 },
			{ Angle = 225, Radius = 17 },
			{ Angle = 315, Radius = 17 },
		},
		Benches = { -- лицом к фонтану
			{ Angle = 45, Radius = 24 },
			{ Angle = 135, Radius = 24 },
			{ Angle = 225, Radius = 24 },
			{ Angle = 315, Radius = 24 },
		},
		-- Фонари вдоль дорожек: на этом расстоянии от центра, сбоку от дорожки на Side студов
		LampRadius = 32,
		LampSide = 4.5,
		PortalLamps = { Radius = 23, Side = 7 }, -- пара фонарей у дорожки к порталу (снаружи точки появления)
		Signposts = { -- указатели со стрелками к порталу и витрине
			{ Angle = 45, Radius = 12.5 },
			{ Angle = 225, Radius = 12.5 },
		},
		-- Гирлянды флажков над дорожками: угол дорожки, от и до (расстояние от центра)
		Garlands = {
			{ Angle = 90, From = 21, To = 26.5 }, -- между точкой появления и подиумом портала
			{ Angle = 0, From = 13, To = 23 },
			{ Angle = 202.5, From = 14, To = 46 },
			{ Angle = 337.5, From = 14, To = 46 },
		},
		GarlandHeight = 9,
		GarlandSag = 1.5, -- на сколько провисает середина
	},
	-- Декоративные мемлинги, которые бродят по площади (подобрать нельзя). Ходит каждый вокруг своего «дома»
	-- не дальше WanderRadius; движение считает клиент (client/Controllers/WandererController)
	Wanderers = {
		WanderRadius = 5,
		List = {
			{ MemelingId = "ToastPaw", Angle = 30, Radius = 26 },
			{ MemelingId = "SirWobbleton", Angle = 150, Radius = 26 },
			{ MemelingId = "Grumbloaf", Angle = 240, Radius = 26 },
			{ MemelingId = "NoodleNinja", Angle = 300, Radius = 26 },
			{ MemelingId = "CaptainSockbeard", Angle = 340, Radius = 22 },
		},
	},
}

-- Фон вокруг хаба и участков: «море» (Baseplate из default.project.json, растянутый до 2048 — предел Roblox),
-- мостики от хаба к участкам и парящие острова-декорации вдали (по ним не ходят)
MapConfig.Background = {
	SeaSize = 2048,
	BridgeWidth = 8,
	BridgeThickness = 0.6,
	-- Невидимые стены у моря: по краю хаба и участков (с проходами к мостикам) и вдоль мостиков.
	-- По морю уйти нельзя; прыжок персонажа ~7 студов — стена выше
	SeaWallHeight = 10,
	SeaWallThickness = 1,
	-- Острова: центр верхней грани (травы), радиус, высота «земли» под травой и что растёт сверху
	Islands = {
		{ Position = Vector3.new(-290, 55, -160), Radius = 24, Depth = 30, Decor = "Tree" },
		{ Position = Vector3.new(-170, 115, 280), Radius = 18, Depth = 24, Decor = "Mushroom" },
		{ Position = Vector3.new(250, 75, -270), Radius = 20, Depth = 26, Decor = "Crystal" },
		{ Position = Vector3.new(60, 150, -360), Radius = 15, Depth = 20, Decor = "Tree" },
	},
}

-- Точка появления: на дорожке к порталу, сразу за фонтаном (центр площади занят фонтаном)
MapConfig.Spawn = {
	Position = Vector3.new(0, 1.5, 14),
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
	-- Оформление вокруг портала (задача 6.2). Смещения X/Z — от центра хаба по полу. Триггер (Position/Size)
	-- не двигается: подиум — ступени по 0,4 студа (персонаж поднимается сам), остальное без столкновений
	Podium = {
		Center = Vector2.new(0, 35),
		TierHeight = 0.4,
		Tiers = { Vector2.new(26, 16), Vector2.new(22, 12), Vector2.new(18, 8) }, -- ширина × глубина, снизу вверх
		RimWidth = 0.35, -- жёлтая кайма по краю верхней ступени
	},
	Columns = { X = 11.5, Z = 35, Height = 9, Diameter = 1.8, CrystalSize = 2 }, -- колонны по бокам, на нижней ступени
	Sign = { Size = Vector3.new(18, 4.5, 0.6), Height = 18, Z = 32 }, -- вывеска над рамкой, перед столбом света
	-- Мемлинги-статуи у основания: уменьшенные тусклые копии Common и Rare в первом ряду нижней ступени
	Statues = {
		Scale = 0.6,
		List = {
			{ MemelingId = "ToastPaw", Offset = Vector2.new(-10.5, 28.4) },
			{ MemelingId = "NoodleNinja", Offset = Vector2.new(-6.5, 28.4) },
			{ MemelingId = "CaptainSockbeard", Offset = Vector2.new(6.5, 28.4) },
			{ MemelingId = "Grumbloaf", Offset = Vector2.new(10.5, 28.4) },
		},
	},
	Arrow = { Z = { 22.6, 24.8 }, ArmLength = 2.8, ArmWidth = 0.7 }, -- две «галочки» ^ на полу перед подиумом
	InfoSign = { Size = Vector3.new(6.4, 3.4, 0.3), Height = 7 }, -- табличка на левой колонне, выше статуй
}

-- Участки баз (студии): стоят кольцом вокруг хаба, лицом к нему.
-- Смещения ниже — относительно центра участка: -Z смотрит на хаб, +Z — от хаба.
MapConfig.Plots = {
	Count = 8,
	-- Расстояние от центра хаба до центра участка. 80: передний край участка в 58 студах от центра,
	-- до края площади (50) — мостик 8 студов; соседние участки не касаются (между ними ~3,7 студа)
	RingRadius = 80,
	-- Поворот кольца участков: участок номер 1 — на этом угле. 22,5°: портал (90°) смотрит
	-- в промежуток между участками, а не упирается в участок
	AngleOffsetDegrees = 22.5,
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
	-- Кнопки-площадки: ряд из четырёх между аркой и постаментами, по 9 студов друг от друга (подпись
	-- «иконка + цена» шириной 6,5 студа — соседние не налезают), коврик в середине свободен
	ButtonSize = Vector3.new(5, 0.6, 5),
	UpgradeButtonOffsets = {
		carrySlots = Vector3.new(-18, 0.8, -9),
		pedestals = Vector3.new(-9, 0.8, -9),
		storage = Vector3.new(9, 0.8, -9),
	} :: { [string]: Vector3 },
	-- Площадка запаса: мемлинги, которым не хватило постамента (продаются отсюда)
	ReserveOffset = Vector3.new(18, 0.8, -9),
	-- Площадка Rebirth: на коврике ближе к арке — между столбцами подписей ряда, не под ними
	RebirthOffset = Vector3.new(0, 0.8, -15),
	-- Свободный участок: вместо кнопок — табличка «Join to claim!» и цветы (на занятом их не видно)
	ClaimSignOffset = Vector3.new(0, 0, -9), -- на полу участка, в середине ряда кнопок
	ClaimFlowerOffsets = { Vector3.new(-9, 0, -9), Vector3.new(9, 0, -9), Vector3.new(-18, 0, -9), Vector3.new(18, 0, -9) },
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
