--!strict
-- StyleConfig: ВЕСЬ внешний вид в одном месте — палитра, материалы, частицы, свет, шрифты,
-- облик мемлингов, раскладка HUD. Позиции карты — в MapConfig, тексты — в TextConfig.
--
-- Арт-правила (задача 1.8, смысл цветов — задача 6.1):
-- • Палитра — 5 основных цветов (крем, коралл, солнце, мята, слива) и их оттенки: мир и интерфейс.
--   Исключение (задача 5.4): у мемлингов и врага свои цвета персонажа — StyleConfig.Characters.
-- • У цвета есть смысл, и он не нарушается:
--   солнце (жёлтый) — ВСЁ, с чем можно что-то сделать: кнопки, рамка портала, SLOW EXIT, точки покупки и продажи;
--   коралл (красный) + чернила (чёрные полосы) — ТОЛЬКО опасность: ловушки, граница и ворота опасной части;
--   мята и светлая слива — фон мира (полы, ограды, декор); крем — мелкие нейтральные детали.
--   Цвета редкостей (Memeling.Rarities) — только у редкости: кольцо, плашки объявлений, строки результата.
-- • Один материал — SmoothPlastic; Neon только для того, что светится (портал, EXTRACT, лазер, искры).
-- • Мягкие скруглённые формы: шары и цилиндры, острых коробок — минимум.
-- • Все участки в одном стиле, отличаются только акцентным цветом.
-- • Для телефонов: частиц мало, у мелких деталей и плоских площадок нет теней.

-- table.freeze замораживает только верхний уровень, поэтому замораживаем всё дерево
local function deepFreeze<T>(t: T): T
	for _, value in t :: any do
		if type(value) == "table" and not table.isfrozen(value) then
			deepFreeze(value)
		end
	end
	return table.freeze(t :: any) :: any
end

local rgb = Color3.fromRGB
local v3 = Vector3.new

-- ── Палитра ────────────────────────────────────────────────────────────────
-- Ключи палитры — это и имена цветов в облике мемлингов (поле Color у деталей)
local Palette = {
	-- 1. Крем — нейтральные мелочи: белки глаз, текст, ободки
	Cream = rgb(250, 236, 210),
	CreamLight = rgb(255, 249, 238),
	CreamDark = rgb(214, 194, 166),
	CreamGray = rgb(226, 218, 206), -- тело Common: светлое, но не белое
	-- 2. Коралл — ТОЛЬКО опасность (вместе с чёрными полосами Ink)
	Coral = rgb(235, 64, 64),
	CoralLight = rgb(255, 128, 112),
	CoralDark = rgb(150, 30, 40),
	-- 3. Солнце — ТОЛЬКО интерактивное: кнопки, рамка портала, SLOW EXIT, покупка/продажа, Aura
	Sun = rgb(255, 214, 64),
	SunLight = rgb(255, 234, 150),
	SunDark = rgb(222, 170, 30),
	-- 4. Мята — фон мира: полы, безопасность, EXTRACT
	Mint = rgb(98, 200, 172),
	MintLight = rgb(176, 232, 210),
	MintDark = rgb(48, 124, 118),
	MintGrass = rgb(132, 194, 146),
	MintTile = rgb(150, 218, 192), -- второй оттенок плитки на площади хаба
	-- 5. Слива — фон мира: светло-фиолетовые полы участков, ограды, тени, обводки
	Plum = rgb(134, 100, 176),
	PlumLight = rgb(190, 166, 226),
	PlumPale = rgb(228, 218, 246), -- самый светлый фиолетовый: полы участков
	PlumDark = rgb(66, 48, 92),
	-- Служебные оттенки сливы: почти чёрный для зрачков, текста и полос опасности
	Ink = rgb(30, 22, 40),
}

export type Particles = {
	Color: Color3,
	Rate: number, -- частиц в секунду: держим маленьким
	Lifetime: NumberRange,
	Speed: NumberRange,
	Size: number,
	SpreadAngle: number,
	LightEmission: number,
}

-- Редкость видна по кольцу-подставке под мемлингом (тело — цвет персонажа, а не редкости)
export type RarityStyle = {
	Color: Color3, -- цвет кольца; им же красятся плашки объявлений и строки экрана результата
	Glow: boolean?, -- кольцо светится (Neon)
	-- Мягкое сияние: вокруг кольца полупрозрачный неоновый ореол шире кольца на Grow студов
	Halo: { Grow: number, Transparency: number }?,
	Light: { Brightness: number, Range: number }?, -- свет вокруг мемлинга (только Epic и Legendary)
	Particles: Particles?,
}

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds" -- встроенная текстура Roblox

local StyleConfig = {}

StyleConfig.Palette = Palette
StyleConfig.Material = Enum.Material.SmoothPlastic
StyleConfig.GlowMaterial = Enum.Material.Neon
StyleConfig.ParticleTexture = SPARKLE_TEXTURE

StyleConfig.Fonts = {
	Label = Enum.Font.FredokaOne, -- подписи над объектами и на табличках
	Hud = Enum.Font.FredokaOne,
}

-- Подписи над объектами (BillboardGui), размеры в студах
StyleConfig.Label = {
	Text = Palette.CreamLight,
	Stroke = Palette.PlumDark,
	WidthStuds = 12,
	HeightStuds = 3,
	MaxDistance = 200, -- обычные подписи (портал, зона, EXTRACT)
	MemelingMaxDistance = 25, -- имена мемлингов видны только вблизи, чтобы не было каши из надписей
	MemelingScale = 0.5, -- имя мемлинга вдвое меньше обычной подписи
	BestHaulScale = 0.7, -- имя и ник на витрине BEST HAUL — крупнее, видно с площади
	PedestalAuraGap = 2.5, -- насколько подпись «накоплено» выше подписи мемлинга на постаменте
	-- Плотность имени владельца на табличке (SurfaceGui). TextScaled не растит текст больше 100 пикселей,
	-- поэтому при 20 пикселях на студ имя заполняет табличку по высоте
	SignPixelsPerStud = 20,
	EntryScale = 0.5, -- подпись «Entry» вдвое меньше обычной
}

-- Фон: лавандовое «море» вместо земли, светлая пена по краю хаба и участков, мостики, парящие острова
StyleConfig.Background = {
	Sea = Color3.fromRGB(150, 140, 214), -- голубовато-лавандовое море
	Foam = Palette.CreamLight, -- кайма по краю хаба и участков
	FoamWidth = 3, -- на сколько студов пена шире площадки с каждой стороны
	Bridge = Palette.PlumLight,
	BridgeRail = Palette.Plum, -- бортики мостика
	IslandGrass = Palette.MintLight,
	IslandEarth = Palette.Plum,
	IslandEarthDark = Palette.PlumDark,
	TreeTrunk = Palette.CreamDark,
	TreeCrown = Palette.Mint,
	MushroomStem = Palette.CreamLight,
	MushroomCap = Palette.PlumLight,
	Crystal = Palette.MintLight,
}

-- Хаб: светлый мятный пол (фон); портал — самое яркое в хабе
StyleConfig.Hub = {
	Floor = Palette.MintLight,
	FloorTile = Palette.MintTile, -- шахматная плитка поверх пола (второй оттенок)
	Path = Palette.CreamLight, -- дорожки и круг вокруг фонтана
	Spawn = Palette.PlumLight,
	-- Витрина «BEST HAUL»: подиум в фоновых цветах (на него не нажимают)
	PodiumTiers = { Palette.PlumLight, Palette.Plum },
	PodiumRim = Palette.CreamLight,
	-- Гигантские мемные предметы: свои цвета предмета (как цвета персонажей), без жёлтого и красного
	Mug = { Body = Palette.PlumLight, Band = Palette.Mint, Coffee = Color3.fromHex("6B4226"), Steam = Palette.CreamLight },
	Cheese = { Body = Color3.fromHex("FFE08A"), Holes = Color3.fromHex("E8B850") },
	Donut = { Dough = Color3.fromHex("D9A866"), Frosting = Palette.PlumLight, Sprinkles = { Palette.Mint, Palette.CreamLight, Palette.PlumDark } },
	Phone = { Body = Palette.PlumDark, Screen = Palette.CreamLight, Apps = { Palette.Mint, Palette.PlumLight, Palette.MintDark, Palette.Plum }, Button = Palette.PlumLight },
	Banana = { Peel = Color3.fromHex("FFE9A8"), Tips = Color3.fromHex("8B5A2B") }, -- бледная, не «интерактивный» жёлтый
	Duck = { Body = Color3.fromHex("FFF0B3"), Beak = Color3.fromHex("FFB070"), Eye = Palette.Ink }, -- пастельная уточка
	Headphones = { Band = Palette.PlumDark, Cups = Palette.Mint, Cushions = Palette.CreamLight },
	-- Декор площади (server/Visual/HubDecor): только фоновые цвета, без жёлтого и красного
	Decor = {
		TreeTrunk = Palette.CreamDark,
		TreeCrown = Palette.Mint,
		TreeCrownLight = Palette.MintLight,
		Bush = Palette.MintDark,
		BushLight = Palette.Mint,
		BedSoil = Palette.PlumDark,
		BedRim = Palette.PlumLight,
		Petals = { Palette.PlumLight, Palette.CreamLight, Palette.Plum }, -- лепестки цветов по очереди
		FlowerCenter = Palette.CreamLight,
		Stem = Palette.MintDark,
		LampPost = Palette.PlumDark,
		LampGlow = Palette.CreamLight, -- светящийся шар фонаря (Neon)
		Bench = Palette.CreamDark,
		BenchLegs = Palette.PlumDark,
		SignPost = Palette.PlumDark,
		SignBoard = Palette.CreamLight,
		SignText = Palette.Ink,
		FountainRim = Palette.PlumLight,
		FountainStone = Palette.CreamLight,
		Water = Palette.Mint,
		WaterTransparency = 0.25,
		Splash = { -- брызги фонтана: мало частиц, без света
			Color = Palette.MintLight,
			Rate = 18,
			Lifetime = NumberRange.new(0.9, 1.2),
			Speed = NumberRange.new(8, 11),
			Size = 0.5,
			SpreadAngle = 18,
			LightEmission = 0.3,
		},
		SplashGravity = 28,
		GarlandPole = Palette.PlumDark,
		GarlandString = Palette.CreamLight,
		Flags = { Palette.Mint, Palette.PlumLight, Palette.CreamLight, Palette.Plum },
		FlagStep = 1.8, -- расстояние между флажками
	},
	-- Как бродят декоративные мемлинги (только клиент): шагают к случайной точке, стоят, иногда прыгают или машут
	Wanderers = {
		Speed = 4, -- студов в секунду
		PauseSeconds = NumberRange.new(1, 2.5),
		HopChance = 0.35, -- после шага: шанс подпрыгнуть
		WaveChance = 0.35, -- после шага: шанс помахать (покачаться)
		HopHeight = 1.8,
		HopSeconds = 0.45, -- один прыжок
		Hops = 2,
		WaveDegrees = 18,
		WaveSeconds = 1.2,
		WaveHz = 2.5,
	},
	SpawnForceFieldSeconds = 0, -- без силового поля при появлении
}

-- Портал — круглая воронка цвета сливы: контраст со светлым мятным полом хаба.
-- Рамка жёлтая — в портал можно войти (жёлтый = интерактивное).
-- Вокруг крутится кольцо из бусин, в середину затягивает вихрь искр, рядом слышен гул.
-- Кольцо и вихрь вращает клиент (client/Controllers/PortalController) — по сети вращение не идёт
StyleConfig.Portal = {
	Color = Palette.Plum,
	Core = Palette.PlumDark, -- тёмная середина воронки: кажется глубокой
	Transparency = 0.15,
	Frame = Palette.Sun, -- рамка портала
	FrameCaps = Palette.SunDark,
	BeaconTransparency = 0.55, -- столб света над порталом: видно от любого участка
	Light = { Brightness = 3, Range = 26 },
	Ring = {
		Segments = 12,
		Radius = 5.4, -- от центра портала до бусин
		SegmentSize = v3(0.6, 2, 0.6), -- бусина вытянута вдоль кольца
		Colors = { Palette.Sun, Palette.PlumLight }, -- чередуются: видно, что кольцо крутится
		SpinDegreesPerSecond = 50,
	},
	Vortex = { -- искры с края воронки летят к центру и крутятся
		Color = Palette.PlumLight,
		Rate = 30,
		Lifetime = NumberRange.new(0.9, 1.3),
		Speed = NumberRange.new(3, 5),
		Size = 0.7,
		SpreadAngle = 0,
		LightEmission = 1,
		SpinDegreesPerSecond = -140, -- в другую сторону, чем кольцо
	},
	-- Гул рядом с порталом: встроенный звук Roblox (ветер), замедленный до низкого гула.
	-- Можно заменить на любой SoundId из Toolbox
	Hum = {
		SoundId = "rbxasset://sounds/action_falling.mp3",
		Volume = 0.5,
		PlaybackSpeed = 0.45,
		MinDistance = 6, -- ближе — на полную громкость
		MaxDistance = 45, -- дальше — не слышно
	},
	-- Оформление вокруг: подиум со ступенями и жёлтой каймой, колонны с крутящимися кристаллами,
	-- вывеска (покачивается), тусклые статуи, пульсирующая стрелка на полу, табличка-подсказка.
	-- Крутит, качает и мигает клиент (PortalController)
	PodiumTiers = { Palette.PlumLight, Palette.Plum, Palette.PlumLight },
	PodiumRim = Palette.Sun,
	Column = Palette.PlumLight,
	ColumnCap = Palette.CreamLight,
	Crystals = { Palette.MintLight, Palette.PlumLight },
	CrystalSpinDegreesPerSecond = 90,
	SignBoard = Palette.PlumDark,
	SignBorder = Palette.Sun,
	SignText = Palette.Sun,
	SignTextStroke = Palette.Ink,
	SignRockDegrees = 2,
	SignRockHz = 0.35,
	StatueStone = Color3.fromRGB(176, 170, 186), -- статуи: цвета мемлинга сильно смешаны с камнем
	StatueBlend = 0.75,
	Arrow = Palette.Sun, -- «иди сюда»: жёлтый = интерактивное
	ArrowTransparency = NumberRange.new(0.05, 0.65), -- пульс между этими значениями
	ArrowPulseHz = 1.2,
	InfoBoard = Palette.CreamLight,
	InfoText = Palette.Ink,
	Particles = {
		Color = Palette.CreamLight,
		Rate = 6,
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(2, 4),
		Size = 0.8,
		SpreadAngle = 60,
		LightEmission = 1,
	},
}

-- Участки: один стиль (светло-фиолетовый пол, арка, ограда, коврик), отличаются только акцентом.
-- Акценты — только фоновые цвета (мята и слива): жёлтый и красный на участке значат другое
StyleConfig.Plot = {
	Floor = Palette.PlumPale,
	Rail = Palette.PlumLight, -- перекладины ограды
	Rug = Palette.MintLight, -- коврик от арки к постаментам (кайма — акцент)
	Accents = { -- по номеру участка: арка, табличка, столбики ограды, постаменты, кайма коврика
		Palette.Mint,
		Palette.Plum,
		Palette.MintDark,
		Palette.PlumDark,
		Palette.Mint,
		Palette.Plum,
		Palette.MintDark,
		Palette.PlumDark,
	},
	ArchCaps = Palette.MintLight, -- шары на столбах арки
}

-- Детали участка: всё, на что можно нажать (кнопки улучшений, запас, Rebirth), — жёлтое
StyleConfig.PlotParts = {
	UpgradeButton = Palette.Sun, -- кнопки улучшений
	ButtonRim = Palette.SunDark,
	ReservePad = Palette.Sun, -- площадка запаса (на ней кнопка Sell)
	ReserveRim = Palette.MintDark, -- ободок отличает её от кнопок улучшений
	RebirthPad = Palette.Sun, -- площадка Rebirth
	RebirthRim = Palette.PlumDark,
	RebirthTag = Palette.PlumLight, -- счётчик rebirth над именем игрока
	RebirthTagHeight = 3.2, -- на сколько студов над головой (выше имени Roblox)
	LockedPedestalTransparency = 0.75, -- некупленный постамент — полупрозрачный «призрак»
	PedestalRim = Palette.Sun, -- жёлтый ободок: на постаменте есть кнопки Collect и Sell
	-- Подписи над кнопками: иконка + коротко (цена / количество) на тёмной плашке, крупно
	ButtonIcons = { pedestals = "Pedestal", carrySlots = "Bag", storage = "Clock" } :: { [string]: string },
	ReserveIcon = "Box",
	RebirthIcon = "Star",
	ButtonLabelWidth = 6.5, -- студов
	ButtonLabelHeight = 2.2,
	ButtonLabelLift = 2.4, -- на сколько студов над кнопкой
	ButtonLabelPanel = Palette.PlumDark,
	ButtonLabelPanelTransparency = 0.2,
}

-- Кнопки ProximityPrompt
StyleConfig.Prompts = {
	BuyHoldSeconds = 0.3, -- короткое удержание, чтобы не купить случайно
	SellHoldSeconds = 0.6, -- продажу держать дольше: её не отменить
	RebirthHoldSeconds = 2, -- Rebirth сбрасывает Aura и улучшения — подтверждение долгим удержанием
	SecondaryOffsetY = 90, -- вторая кнопка на том же постаменте (Sell) — ниже первой (Collect), в пикселях
}

-- Meme Zone: спокойный тёмный пол с узором; опасная часть — тёмная слива, граница — коралл
StyleConfig.Zone = {
	SafeFloor = Palette.MintDark,
	DangerFloor = Color3.fromRGB(44, 22, 40), -- темнее прежнего: почти чёрно-фиолетовый с красным
	DangerStripes = { Palette.Coral, Palette.Ink }, -- лента и полосы на воротах: красный + чёрный = опасно
	-- Туман и свет опасной части — локально (частицы и PointLight), общий Lighting не трогаем
	DangerFog = {
		Texture = "rbxasset://textures/particles/smoke_main.dds", -- встроенная текстура дыма Roblox
		Color = Color3.fromRGB(150, 60, 120),
		Rate = 1.2, -- мало: крупные частицы дороги на телефоне
		Lifetime = NumberRange.new(5, 7),
		Speed = NumberRange.new(0.3, 0.8),
		Size = 14,
		Transparency = 0.78, -- в начале жизни; к концу — совсем прозрачные
	},
	DangerLight = { Color = Color3.fromRGB(210, 60, 150), Brightness = 1.3, Range = 45 },
	DangerTile = Palette.Plum, -- светящиеся плиты-узор: фиолетовые (не красные — это не ловушка)
	DangerTileTransparency = 0.55,
	Skull = { Bone = Palette.CreamLight, Holes = Palette.Ink },
	Entry = Palette.CreamLight,
	Path = Palette.MintLight, -- дорожка от входа к EXTRACT
	PathTransparency = 0.15,
	EntryGate = Palette.Mint, -- ворота у входа
	DangerGate = Palette.Coral, -- ворота в опасную часть
	GateCaps = Palette.MintLight,
	MushroomStem = Palette.CreamLight, -- ориентиры безопасной части — грибы-великаны
	MushroomCap = Palette.Plum,
	MushroomDots = Palette.CreamLight,
	Crystal = Palette.PlumLight, -- ориентиры опасной части — кристаллы
	-- Узор плиткой поверх пола (Texture на верхней грани)
	FloorTexture = "rbxassetid://6372755229", -- сетка-плитка из стандартного Baseplate Roblox
	FloorTextureStuds = 8, -- размер одной плитки
	FloorTextureTransparency = 0.8,
	FloorTextureColor = Palette.CreamLight,
}

-- Ловушки: только красный и чёрный. Тёмно-красная плита = опасно, ярко-красная = сейчас ударит
StyleConfig.Hazards = {
	Laser = Palette.Coral,
	LaserBlinkTransparency = 0.7, -- мигание у конца дорожки перед проездом
	LaserBlinkHz = 4, -- сколько раз в секунду мигает
	Rail = Palette.CoralDark, -- рельсы дорожки лазера на полу
	RailWidth = 0.6,
	SlamIdle = Palette.CoralDark,
	SlamWarn = Palette.Coral,
	SlamStrike = Palette.CoralLight,
	-- Плита всегда отличается от пола: чёрные трещины от центра и чёрная кайма (SurfaceGui на верхней грани).
	-- Точки — доли стороны плиты: (0, 0) — угол, (0.5, 0.5) — центр
	SlamCrackColor = Palette.Ink,
	SlamCrackThickness = 5, -- в пикселях на поверхности
	SlamCrackPixelsPerStud = 20,
	SlamCracks = {
		{ From = Vector2.new(0.5, 0.5), To = Vector2.new(0.18, 0.12) },
		{ From = Vector2.new(0.5, 0.5), To = Vector2.new(0.88, 0.22) },
		{ From = Vector2.new(0.5, 0.5), To = Vector2.new(0.8, 0.86) },
		{ From = Vector2.new(0.5, 0.5), To = Vector2.new(0.12, 0.7) },
		{ From = Vector2.new(0.18, 0.12), To = Vector2.new(0.05, 0.3) },
		{ From = Vector2.new(0.88, 0.22), To = Vector2.new(0.96, 0.45) },
		{ From = Vector2.new(0.8, 0.86), To = Vector2.new(0.58, 0.96) },
		{ From = Vector2.new(0.12, 0.7), To = Vector2.new(0.3, 0.92) },
		{ From = Vector2.new(0.66, 0.5), To = Vector2.new(0.7, 0.68) },
	},
	SlamBorderThickness = 8, -- чёрная кайма по краю плиты, в пикселях
	SlamPopHeight = 0.8, -- плита подпрыгивает при ударе
	SlamPopSeconds = 0.15,
}

-- Событие Giant Object: колесо сыра с дырками и глупой рожицей.
-- Сыр — цвет персонажа (как у мемлингов), но бока красные, а маршрут мигает красным: это опасность
StyleConfig.Event = {
	Cheese = Color3.fromHex("FFE08A"),
	Holes = Color3.fromHex("E8B850"),
	Rind = Palette.Coral, -- красные бока колеса: опасно
	Face = Palette.Ink,
	RouteHighlight = Palette.Coral, -- подсветка маршрута перед стартом
	RouteBlinkHz = 3, -- сколько раз в секунду мигает подсветка
	RouteBlinkTransparency = 0.6,
	-- Сигнал перед стартом: встроенный звук Roblox (если его нет — просто тишина, подсветка остаётся)
	WarnSound = "rbxasset://sounds/electronicpingshort.wav",
	WarnSoundVolume = 0.8,
	LabelHeight = 9, -- подпись над колесом
}

-- Площадка EXTRACT: неон, искры вверх и столб света — видно из любого места зоны
StyleConfig.Extraction = {
	Color = Palette.Mint,
	SideColor = Palette.Sun, -- вторая, медленная точка у входа — солнце, чтобы не спутать с главной
	Transparency = 0.1,
	BeaconTransparency = 0.35, -- плотнее: столб виден сквозь дымку с другого конца зоны
	Particles = {
		Color = Palette.MintLight,
		Rate = 8,
		Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(4, 7),
		Size = 0.9,
		SpreadAngle = 15,
		LightEmission = 1,
	},
}

-- ── Мемлинги ───────────────────────────────────────────────────────────────

-- Стиль «D · Микс» (задача 5.4): толстый тёмный контур, глянцевый блик сверху-слева,
-- гранёная тень справа, крупные глаза разного размера с белой точкой-бликом, румянец.
-- Модели собирает кодом server/Visual/MemelingBuilders; форма и места деталей — там,
-- здесь — все цвета и общие размеры.
local hex = Color3.fromHex

-- Цвета персонажей: тело — цвет самого персонажа (тост остаётся тостом), редкость — кольцо под ним
StyleConfig.Characters = {
	ToastPaw = { Crust = hex("D07C33"), Crumb = hex("F2B25C"), Tongue = hex("FF6F8E"), Pads = hex("FF9DB5") },
	SirWobbleton = {
		Body = hex("F4E3B5"),
		Feet = hex("E2C98E"),
		Helmet = hex("C9CED8"),
		Plume = hex("FF5A5A"),
		Blade = hex("E4E8EF"),
		Guard = hex("FFC83D"),
	},
	Grumbloaf = { Body = hex("C98A4B"), Cuts = hex("F0C890"), Legs = hex("9C6331"), Sticker = hex("FF6F8E") },
	NoodleNinja = {
		Cup = hex("E84A4A"),
		Rim = hex("FF8C8C"),
		Noodles = hex("F7D488"),
		Band = hex("2A1638"),
		Sticks = hex("D9A866"),
	},
	CaptainSockbeard = {
		Sock = hex("3C8DFF"),
		Stripes = hex("FFFFFF"),
		Hat = hex("231C2B"),
		HatDot = hex("FFD93D"),
		Patch = hex("231C2B"),
		Beard = hex("FFFFFF"),
		Earring = hex("FFD93D"),
	},
	DiscoPickle = {
		Body = hex("6CBF3E"),
		Bumps = hex("4E9A2A"),
		Glasses = hex("FF4FA3"),
		DiscoBall = hex("D8DCE6"),
		String = hex("FFFFFF"),
	},
	ProfessorBonk = {
		Handle = hex("8B5A2B"),
		Head = hex("B0B6C4"),
		Glasses = hex("2A1638"),
		Mustache = hex("3B2414"), -- темнее, чтобы усы читались на сером бойке
		Cap = hex("2A1638"),
		Tassel = hex("FFC83D"),
		Bump = hex("FF9E9E"),
	},
	MegaSnoozeasaurus = {
		Body = hex("FFC83D"),
		Belly = hex("FFF3C9"),
		Spikes = hex("FF8A3D"),
		Crown = hex("FFE27A"),
		Jewel = hex("FF4FA3"),
		Bubble = hex("BFE6FF"),
	},
	Grumblob = { Body = hex("7BD13A"), Brow = hex("2A1638") }, -- враг: зелёный желейный шар
}

-- Контур: Highlight только у ближних, у того, что в руках, и на своих постаментах.
-- У Roblox на экране не больше 31 Highlight одновременно — держим запас.
-- Ставит контур клиент (client/Controllers/OutlineController) всем с тегом Tag.
StyleConfig.Outline = {
	Tag = "Outlined", -- тег CollectionService: мемлинги и враги
	-- Видимые детали мемлинга лежат в Model с этим именем внутри ядра: Highlight ставится на неё.
	-- Само ядро невидимое (Transparency = 1), а Highlight на прозрачной детали ничего не рисует
	Figure = "Figure",
	Color = hex("2A1638"),
	MaxCount = 25, -- сколько контуров сразу, не больше
	Distance = 70, -- дальше этого контура нет (кроме своих: в руках и на своих постаментах)
	RefreshSeconds = 0.3, -- как часто клиент пересчитывает, кому нужен контур
}

-- Эвакуация на клиенте (client/Controllers/ExtractFxController): пока стоишь на точке, вокруг ног
-- загорается круг из сегментов, писк ускоряется; в конце — вспышка экрана и конфетти.
-- Звуки — встроенные Roblox, можно заменить на любой SoundId из Toolbox
StyleConfig.ExtractFx = {
	RingSegments = 24,
	RingRadius = 4.5,
	SegmentSize = v3(0.5, 0.25, 1.1),
	EmptyTransparency = 0.8, -- ещё не заполненный сегмент — еле виден
	ChargeSound = {
		SoundId = "rbxasset://sounds/electronicpingshort.wav", -- повторяется по кругу, всё выше и громче
		FromSpeed = 0.8,
		ToSpeed = 1.9,
		FromVolume = 0.25,
		ToVolume = 0.8,
	},
	DoneSound = { SoundId = "rbxasset://sounds/electronicpingshort.wav", Speed = 2.4, Volume = 1 },
	FlashColor = Palette.CreamLight,
	FlashTransparency = 0.25, -- самая яркая точка вспышки
	FlashSeconds = 0.5,
	Confetti = {
		Colors = { Palette.Mint, Palette.PlumLight, Palette.CreamLight, Palette.Plum },
		Count = 60,
		Speed = NumberRange.new(16, 26),
		Lifetime = NumberRange.new(1.4, 2),
		Size = 0.7,
		Gravity = 35,
		SpreadAngle = 55,
	},
}

-- Замах Grumblob (client/Controllers/HitFxController): вокруг врага растёт красный полупрозрачный шар —
-- враг «раздувается и краснеет» за WindupSeconds до удара
StyleConfig.EnemyWindup = {
	Color = Palette.Coral,
	Transparency = 0.45,
	Grow = 0.35, -- к моменту удара шар больше тела на 35%
}

-- Свой выпавший лут (после смерти): золотая подсветка сквозь стены и подпись «YOUR LOOT» с таймером.
-- Видит только погибший (client/Controllers/LootController и OutlineController)
StyleConfig.Loot = {
	Tag = "Loot", -- тег CollectionService на ядре выпавшего мемлинга
	Color = Palette.Sun,
	FillTransparency = 0.6,
	LabelHeight = 7, -- подпись — на столько студов выше центра мемлинга
	LabelWidth = 200, -- в пикселях: одинаково крупно на любом расстоянии
	LabelTextSize = 24,
}

StyleConfig.Memeling = {
	-- «Габарит» мемлинга: центр — в середине, низ — на 3 ниже, верх — около 3 выше (шляпы чуть выше).
	-- По нему ставим мемлинга на пол и на постамент и считаем высоту подписей.
	Size = v3(6, 6, 6),
	LabelHeight = 5.5, -- подпись с именем — на столько выше центра (над шляпами и хохолками)
	-- Размер по редкости: весь мемлинг (габарит, детали, подписи, дальность подбора) × множитель.
	-- Низ остаётся на полу — мемлинг растёт вверх
	RarityScale = { Common = 1, Rare = 1.1, Epic = 1.2, Legendary = 1.4 } :: { [string]: number },
	-- В руках мемлинг уменьшается (весь, с деталями), подпись над ним скрыта — не закрывает обзор
	CarryScale = 0.6,
	-- Где мемлинги висят, когда их несут: относительно HumanoidRootPart (-Z = перед персонажем).
	-- Первый — перед грудью (крупный — чуть дальше вперёд), остальные — стопкой на голове:
	-- низ стопки на высоте CarryHeadTop, между мемлингами зазор CarryStackGap. Высота каждого — по его размеру
	CarryFront = v3(0, 0.5, -3.4), -- центр первого при обычном размере (тело в руках ≈ 3,6)
	CarryHeadTop = 2.6,
	CarryStackGap = 0.2,

	-- Невидимое ядро: к нему приварены все детали, на нём кнопка подбора и подпись
	CoreSize = v3(4, 5.6, 4),
	-- Кольцо-подставка цвета редкости: низ кольца — низ габарита, мемлинг стоит на нём (верх кольца — −2,6)
	RingDiameter = 5.2,
	RingHeight = 0.4,

	-- Общие детали лица и стиля
	Face = {
		EyeWhite = hex("FFFFFF"),
		Pupil = hex("2A1638"),
		Glint = hex("FFFFFF"), -- белая точка-блик в зрачке
		PupilScale = 0.55, -- зрачок от размера глаза
		GlintScale = 0.2,
		Blush = hex("FF8A8A"),
		BlushTransparency = 0.35,
		Gloss = hex("FFFFFF"), -- глянцевый блик сверху-слева
		GlossTransparency = 0.4,
		ShadeDarken = 0.22, -- гранёная тень справа: цвет тела, смешанный с тёмным контуром на столько
		Mouth = hex("2A1638"),
	},

	-- Буквы «Z z z» над Mega Snoozeasaurus (BillboardGui)
	Snooze = {
		Text = hex("FFFFFF"),
		Stroke = hex("2A1638"),
		Offset = v3(1.2, 3.6, 0), -- от центра мемлинга
		WidthStuds = 3.2,
		HeightStuds = 1.4,
		MaxDistance = 60,
	},

	-- Редкость — кольцо-подставка: Common и Rare без света, Epic и Legendary — неон, свет и искры.
	-- Цвета редкостей не совпадают ни с одним цветом палитры (задача 6.1): синий, ярко-пурпурный и оранжевый
	-- не спутать ни с жёлтым «интерактивным», ни со светло-фиолетовым фоном
	Rarities = {
		Common = { Color = hex("D6D6D0") },
		Rare = { Color = hex("3D9BFF") },
		Epic = {
			Color = hex("D63CFF"),
			Glow = true,
			Light = { Brightness = 1.5, Range = 12 },
			Particles = {
				Color = hex("EFA6FF"),
				Rate = 2,
				Lifetime = NumberRange.new(0.8, 1.2),
				Speed = NumberRange.new(1, 2),
				Size = 0.8,
				SpreadAngle = 180,
				LightEmission = 1,
			},
		},
		-- Legendary без пересвета: кольцо обычное, мягкое сияние даёт полупрозрачный ореол вокруг него
		Legendary = {
			Color = hex("FF8A1F"),
			Halo = { Grow = 0.8, Transparency = 0.8 },
			Light = { Brightness = 0.8, Range = 10 },
			Particles = {
				Color = hex("FFC48A"),
				Rate = 3,
				Lifetime = NumberRange.new(0.8, 1.4),
				Speed = NumberRange.new(1, 2),
				Size = 0.7,
				SpreadAngle = 180,
				LightEmission = 0.4,
			},
		},
	} :: { [string]: RarityStyle },
}

-- ── Свет ───────────────────────────────────────────────────────────────────
-- Солнце под углом (широта + время дня дают длинные мягкие тени), мягкая цветокоррекция.
-- Тени включены в default.project.json: Lighting.Technology = ShadowMap (скриптом её не поменять).
-- Небо — стандартное Roblox (своих картинок нет), розово-фиолетовый тон дают Atmosphere и ColorCorrection.
StyleConfig.Lighting = {
	ClockTime = 16, -- вторая половина дня: солнце сбоку, тени видны, свет теплее
	GeographicLatitude = 38, -- наклон пути солнца
	Brightness = 2.2,
	Ambient = rgb(120, 100, 132),
	OutdoorAmbient = rgb(150, 128, 162),
	ExposureCompensation = -0.1,
	EnvironmentDiffuseScale = 0.4,
	EnvironmentSpecularScale = 0.3,
	ShadowSoftness = 0.35,
	Atmosphere = { -- мягкая розово-фиолетовая дымка у горизонта
		Density = 0.32,
		Offset = 0.2,
		Color = rgb(236, 206, 240),
		Decay = rgb(255, 172, 206),
		Glare = 0.15,
		Haze = 1.6,
	},
	Bloom = { Intensity = 0.2, Size = 16, Threshold = 1.4 },
	ColorCorrection = {
		Saturation = 0.1,
		Contrast = 0.05,
		Brightness = 0,
		TintColor = rgb(255, 238, 250), -- лёгкий розово-сиреневый оттенок
	},
	Sky = { SunAngularSize = 16, StarCount = 0 },
}

-- ── HUD (клиент) ───────────────────────────────────────────────────────────
StyleConfig.Hud = {
	BaseCard = Palette.Sun, -- «на базе»: золото, в безопасности
	HandsCard = Palette.Mint, -- «в руках»: мята, можно потерять
	Stroke = Palette.PlumDark, -- обводка панелей
	StrokeThickness = 3,
	Shadow = Palette.Ink, -- тень под панелями
	ShadowTransparency = 0.65,
	ShadowOffset = 5, -- на сколько пикселей тень ниже панели
	IconBubble = Palette.CreamLight, -- кружок под иконкой
	TextDark = Palette.Ink,
	TextLight = Palette.CreamLight,
	CornerRadius = 16,

	-- Две карточки слева сверху — компактные (высота ≈ 49 пикселей: в 1,5 раза ниже прежних 74)
	CardWidth = 210,
	CardPadding = 4,
	IconSize = 36,
	ValueSize = 26, -- главное число — крупно
	CaptionSize = 11, -- пояснение — мелко
	IconBadgeSize = 10, -- подпись «AURA» под иконкой Aura
	IconBadge = Palette.PlumDark,
	Margin = 12, -- отступ от левого края
	-- Сверху HUD ставим под панелью Roblox (GuiService:GetGuiInset) и под окном чата
	ChatReserveDesktop = 210, -- высота окна чата на компьютере, в пикселях
	ChatReserveTouch = 12, -- на телефоне окно чата закрыто, пока его не откроют
	SmallScreenHeight = 500, -- экран ниже этого (телефон боком) — HUD чуть меньше
	SmallScreenScale = 0.8,

	-- Таймер рестока вверху по центру
	TimerPanel = Palette.PlumDark,
	TimerText = Palette.CreamLight,
	TimerWidth = 300,
	TimerHeight = 36,
	TimerTextSize = 20,
	TimerTop = 8, -- отступ от панели Roblox сверху, в пикселях

	-- Объявление о редком спавне: плашка цвета редкости у самого верха экрана
	-- (в зоне — сразу под таймером рестока, в хабе таймера нет — на его месте)
	AnnounceSeconds = 3.5, -- сколько держится на экране
	AnnounceFadeSeconds = 0.3, -- появление и исчезание
	AnnounceWidth = 480,
	AnnounceHeight = 46,
	AnnounceTextSize = 24,
	AnnounceGap = 6, -- отступ под таймером рестока, в пикселях

	-- Крупные кнопки ProximityPrompt (свой стиль вместо стандартного): удобно нажимать пальцем
	PromptWidth = 180,
	PromptHeight = 64,
	PromptTouchScale = 1.25, -- на телефоне ещё крупнее
	PromptPanel = Palette.CreamLight,
	PromptFill = Palette.Mint, -- полоска удержания
	PromptActionSize = 26,
	PromptObjectSize = 16,

	-- Кнопки действий справа над кнопкой прыжка (Drop, Extract)
	ActionButtonSize = 92, -- диаметр, в пикселях
	ActionButtonGap = 12,
	ActionDrop = Palette.Sun, -- кнопки — жёлтые, как всё интерактивное
	ActionExtract = Palette.Sun,
	ActionTextSize = 20,
	ExtractButtonRange = 45, -- кнопка Extract появляется, когда до площадки ближе, в студах

	-- Экран результата эвакуации: короткий, закрывается сам
	ResultSeconds = 6,
	ResultPanel = Palette.CreamLight,
	ResultTitleColor = Palette.MintDark,
	ResultWidth = 400,
	ResultTitleSize = 36,
	ResultRowSize = 22,
	ResultRowHeight = 34,
	ResultButton = Palette.Sun,
	ResultButtonHeight = 48,

	-- Туториал: подсказка внизу по центру (между джойстиком и кнопкой прыжка) и стрелка к цели
	TutorialPanel = Palette.CreamLight,
	TutorialAccent = Palette.Sun, -- стрелка и номер шага: показывает, куда нажать/идти
	TutorialWidth = 330,
	TutorialHeight = 52,
	TutorialTextSize = 24,
	TutorialBottom = 150, -- отступ подсказки от низа экрана (выше джойстика и кнопки прыжка)
	TutorialSkipWidth = 64,
	TutorialSkipDelaySeconds = 10, -- кнопка Skip появляется через столько секунд после первой подсказки
	TutorialArrowSize = 64, -- стрелка над целью, в пикселях
	TutorialArrowHeight = 8, -- на сколько студов над целью висит стрелка
	TutorialArrowBob = 1.2, -- на сколько студов стрелка покачивается вверх-вниз
	TutorialArrowBobHz = 1.5,

	MarkerHeight = 14, -- на сколько студов над площадкой висит маркер EXTRACT
	MarkerHideDistance = 45, -- ближе этого маркер прячется: площадку и так видно
	MarkerTitleSize = 30,
	MarkerDistanceSize = 22,
	EdgeArrowSize = 56,
	EdgePadding = 70, -- отступ стрелки от края экрана, в пикселях
}

return deepFreeze(StyleConfig)
