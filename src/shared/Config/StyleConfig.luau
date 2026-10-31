--!strict
-- StyleConfig: ВЕСЬ внешний вид в одном месте — палитра, материалы, частицы, свет, шрифты,
-- облик мемлингов, раскладка HUD. Позиции карты — в MapConfig, тексты — в TextConfig.
--
-- Арт-правила (задача 1.8):
-- • Палитра — 5 основных цветов (крем, коралл, солнце, мята, слива) и их оттенки: мир и интерфейс.
--   Исключение (задача 5.4): у мемлингов и врага свои цвета персонажа — StyleConfig.Characters.
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
	-- 1. Крем — спокойный фон: полы участков, дорожки, белки глаз
	Cream = rgb(250, 236, 210),
	CreamLight = rgb(255, 249, 238),
	CreamDark = rgb(214, 194, 166),
	CreamGray = rgb(226, 218, 206), -- тело Common: светлое, но не белое
	-- 2. Коралл — тёплый акцент: портал, лазер, враг
	Coral = rgb(255, 122, 100),
	CoralLight = rgb(255, 176, 156),
	CoralDark = rgb(192, 80, 72),
	-- 3. Солнце — Aura, золото, кнопки
	Sun = rgb(255, 198, 88),
	SunLight = rgb(255, 228, 156),
	SunDark = rgb(220, 148, 56),
	-- 4. Мята — природа, безопасность, EXTRACT
	Mint = rgb(98, 200, 172),
	MintLight = rgb(166, 228, 204),
	MintDark = rgb(48, 124, 118),
	MintGrass = rgb(132, 194, 146), -- земля вокруг
	-- 5. Слива — глубина: тени, обводки, опасная часть
	Plum = rgb(134, 100, 176),
	PlumLight = rgb(190, 166, 226),
	PlumDark = rgb(66, 48, 92),
	-- Служебные оттенки сливы: почти чёрный для зрачков и текста
	Ink = rgb(42, 32, 56),
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
	PedestalAuraGap = 2.5, -- насколько подпись «накоплено» выше подписи мемлинга на постаменте
	-- Плотность имени владельца на табличке (SurfaceGui). TextScaled не растит текст больше 100 пикселей,
	-- поэтому при 20 пикселях на студ имя заполняет табличку по высоте
	SignPixelsPerStud = 20,
	EntryScale = 0.5, -- подпись «Entry» вдвое меньше обычной
}

-- Земля вокруг (Baseplate)
StyleConfig.Ground = Palette.MintGrass

-- Хаб: насыщенный тёплый пол; портал — самое яркое в хабе
StyleConfig.Hub = {
	Floor = Palette.SunDark,
	Spawn = Palette.SunLight,
	Path = Palette.Cream, -- дорожка от точки появления к порталу
	SpawnForceFieldSeconds = 0, -- без силового поля при появлении
}

StyleConfig.Portal = {
	Color = Palette.Coral,
	Transparency = 0.1,
	Frame = Palette.Plum, -- рамка портала
	FrameCaps = Palette.Sun,
	BeaconTransparency = 0.55, -- столб света над порталом: видно от любого участка
	Light = { Brightness = 3, Range = 26 },
	Particles = {
		Color = Palette.CoralLight,
		Rate = 6,
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(2, 4),
		Size = 0.8,
		SpreadAngle = 60,
		LightEmission = 1,
	},
}

-- Участки: один стиль (кремовый пол, арка, ограда, коврик), отличаются только акцентом
StyleConfig.Plot = {
	Floor = Palette.Cream,
	Rail = Palette.CreamDark, -- перекладины ограды
	Rug = Palette.CreamLight, -- коврик от арки к постаментам (кайма — акцент)
	Accents = { -- по номеру участка: арка, табличка, столбики ограды, постаменты, кайма коврика
		Palette.Coral,
		Palette.Sun,
		Palette.Mint,
		Palette.Plum,
		Palette.CoralDark,
		Palette.SunDark,
		Palette.MintDark,
		Palette.PlumLight,
	},
	ArchCaps = Palette.Sun, -- шары на столбах арки
}

-- Детали участка
StyleConfig.PlotParts = {
	UpgradeButton = Palette.Sun, -- кнопки улучшений: золотые диски
	ButtonRim = Palette.SunDark,
	ReservePad = Palette.Mint, -- площадка запаса
	ReserveRim = Palette.MintDark,
	RebirthPad = Palette.Plum, -- площадка Rebirth: слива
	RebirthRim = Palette.PlumLight,
	RebirthTag = Palette.PlumLight, -- счётчик rebirth над именем игрока
	RebirthTagHeight = 3.2, -- на сколько студов над головой (выше имени Roblox)
	LockedPedestalTransparency = 0.75, -- некупленный постамент — полупрозрачный «призрак»
	PedestalRim = Palette.CreamLight, -- светлый ободок сверху постамента
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
	DangerFloor = Palette.PlumDark,
	DangerBorder = Palette.Coral, -- полоса на полу по границе опасной части
	Entry = Palette.CreamLight,
	Path = Palette.SunLight, -- дорожка от входа к EXTRACT
	PathTransparency = 0.15,
	EntryGate = Palette.Mint, -- ворота у входа
	DangerGate = Palette.Coral, -- ворота в опасную часть
	GateCaps = Palette.Sun,
	MushroomStem = Palette.CreamLight, -- ориентиры безопасной части — грибы-великаны
	MushroomCap = Palette.Coral,
	MushroomDots = Palette.CreamLight,
	Crystal = Palette.PlumLight, -- ориентиры опасной части — кристаллы
	-- Узор плиткой поверх пола (Texture на верхней грани)
	FloorTexture = "rbxassetid://6372755229", -- сетка-плитка из стандартного Baseplate Roblox
	FloorTextureStuds = 8, -- размер одной плитки
	FloorTextureTransparency = 0.8,
	FloorTextureColor = Palette.CreamLight,
}

-- Ловушки: коралл = опасно, солнце = сейчас ударит
StyleConfig.Hazards = {
	Laser = Palette.Coral,
	LaserBlinkTransparency = 0.7, -- мигание у конца дорожки перед проездом
	LaserBlinkHz = 4, -- сколько раз в секунду мигает
	Rail = Palette.CoralDark, -- рельсы дорожки лазера на полу
	RailWidth = 0.6,
	SlamIdle = Palette.Plum,
	SlamWarn = Palette.Sun,
	SlamStrike = Palette.CreamLight,
	SlamPopHeight = 0.8, -- плита подпрыгивает при ударе
	SlamPopSeconds = 0.15,
}

-- Событие Giant Object: колесо сыра с дырками и глупой рожицей
StyleConfig.Event = {
	Cheese = Palette.Sun,
	Holes = Palette.SunDark,
	Rind = Palette.SunLight, -- светлые бока колеса
	Face = Palette.Ink,
	RouteHighlight = Palette.Sun, -- подсветка маршрута перед стартом
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
	Transparency = 0.1,
	BeaconTransparency = 0.6,
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
	Grumbloaf = { Body = hex("C98A4B"), Cuts = hex("F0C890"), Legs = hex("9C6331") },
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
		Mustache = hex("5A3A22"),
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
	Color = hex("2A1638"),
	MaxCount = 25, -- сколько контуров сразу, не больше
	Distance = 70, -- дальше этого контура нет (кроме своих: в руках и на своих постаментах)
	RefreshSeconds = 0.3, -- как часто клиент пересчитывает, кому нужен контур
}

StyleConfig.Memeling = {
	-- «Габарит» мемлинга: центр — в середине, низ — на 3 ниже, верх — около 3 выше (шляпы чуть выше).
	-- По нему ставим мемлинга на пол и на постамент и считаем высоту подписей.
	Size = v3(6, 6, 6),
	LabelHeight = 5.5, -- подпись с именем — на столько выше центра (над шляпами и хохолками)
	-- В руках мемлинг уменьшается (весь, с деталями), подпись над ним скрыта — не закрывает обзор
	CarryScale = 0.6,
	-- Где мемлинги висят, когда их несут: относительно HumanoidRootPart (-Z = перед персонажем).
	-- Первый — перед грудью, остальные — стопкой на голове. Числа — под уменьшенный размер (тело ≈ 3,6)
	CarrySlotOffsets = {
		v3(0, 0.5, -3.4), -- в руках
		v3(0, 4.4, 0), -- на голове
		v3(0, 8.2, 0), -- на голове, сверху на втором
	},
	CarryStackStep = v3(0, 3.8, 0), -- если слотов больше, чем мест выше, — ещё выше по стопке

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

	-- Редкость — кольцо-подставка: Common и Rare без света, Epic и Legendary — неон, свет и искры
	Rarities = {
		Common = { Color = hex("D6D6D0") },
		Rare = { Color = hex("6FB2FF") },
		Epic = {
			Color = hex("B98CFF"),
			Glow = true,
			Light = { Brightness = 1.5, Range = 12 },
			Particles = {
				Color = hex("D9C2FF"),
				Rate = 2,
				Lifetime = NumberRange.new(0.8, 1.2),
				Speed = NumberRange.new(1, 2),
				Size = 0.8,
				SpreadAngle = 180,
				LightEmission = 1,
			},
		},
		Legendary = {
			Color = hex("FFC83D"),
			Glow = true,
			Light = { Brightness = 2.5, Range = 16 },
			Particles = {
				Color = hex("FFE7A0"),
				Rate = 5,
				Lifetime = NumberRange.new(0.8, 1.4),
				Speed = NumberRange.new(1, 2.5),
				Size = 1,
				SpreadAngle = 180,
				LightEmission = 1,
			},
		},
	} :: { [string]: RarityStyle },
}

-- ── Свет ───────────────────────────────────────────────────────────────────
-- Солнце под углом (широта + время дня дают длинные мягкие тени), мягкая цветокоррекция.
-- Тени включены в default.project.json: Lighting.Technology = ShadowMap (скриптом её не поменять).
StyleConfig.Lighting = {
	ClockTime = 15.3, -- вторая половина дня: солнце сбоку, тени видны
	GeographicLatitude = 38, -- наклон пути солнца
	Brightness = 2.2,
	Ambient = rgb(112, 100, 116),
	OutdoorAmbient = rgb(132, 122, 134),
	ExposureCompensation = -0.1,
	EnvironmentDiffuseScale = 0.4,
	EnvironmentSpecularScale = 0.3,
	ShadowSoftness = 0.35,
	Atmosphere = {
		Density = 0.3,
		Offset = 0.25,
		Color = rgb(214, 222, 238),
		Decay = rgb(248, 210, 182),
		Glare = 0.1,
		Haze = 1,
	},
	Bloom = { Intensity = 0.2, Size = 16, Threshold = 1.4 },
	ColorCorrection = {
		Saturation = 0.08,
		Contrast = 0.06,
		Brightness = 0,
		TintColor = rgb(255, 245, 232), -- чуть тёплый оттенок
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

	CardWidth = 250,
	IconSize = 54,
	ValueSize = 40, -- главное число — крупно
	CaptionSize = 14, -- пояснение — мелко
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

	-- Объявление о редком спавне: крупная плашка цвета редкости под таймером рестока
	AnnounceSeconds = 3.5, -- сколько держится на экране
	AnnounceFadeSeconds = 0.3, -- появление и исчезание
	AnnounceWidth = 560,
	AnnounceHeight = 64,
	AnnounceTextSize = 30,
	AnnounceGap = 10, -- отступ под таймером рестока, в пикселях

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
	ActionDrop = Palette.Coral,
	ActionExtract = Palette.Mint,
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
	ResultButton = Palette.Mint,
	ResultButtonHeight = 48,

	-- Туториал: подсказка внизу по центру (между джойстиком и кнопкой прыжка) и стрелка к цели
	TutorialPanel = Palette.CreamLight,
	TutorialAccent = Palette.Coral, -- стрелка и номер шага
	TutorialWidth = 330,
	TutorialHeight = 52,
	TutorialTextSize = 24,
	TutorialBottom = 150, -- отступ подсказки от низа экрана (выше джойстика и кнопки прыжка)
	TutorialSkipWidth = 64,
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
