--!strict
-- StyleConfig: ВЕСЬ внешний вид в одном месте — палитра, материалы, частицы, свет, шрифты,
-- облик мемлингов, раскладка HUD. Позиции карты — в MapConfig, тексты — в TextConfig.
--
-- Арт-правила (задача 1.8):
-- • Палитра — 5 основных цветов (крем, коралл, солнце, мята, слива) и их оттенки. Других цветов нет.
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

-- Деталь облика мемлинга. Offset — от центра мемлинга (−Z = вперёд, к лицу; +Y = вверх).
-- Kind: "Ball" | "Block" | "Cylinder" | "Wedge". Цилиндр лежит вдоль X; Rotation — градусы по X, Y, Z.
-- Color: ключ палитры или "Body" / "BodyShade" — цвет редкости. Glow — неоновая (светится).
export type Feature = {
	Kind: string,
	Size: Vector3,
	Offset: Vector3,
	Rotation: Vector3?,
	Color: string,
	Glow: boolean?,
}

-- Облик мемлинга: Core — основная деталь (ей пользуются подбор, подписи и переноска),
-- она всегда без поворота; Hidden — ядро невидимое, а форму дают детали.
export type Look = {
	Core: { Kind: string, Size: Vector3, Color: string, Hidden: boolean? },
	Features: { Feature },
}

export type RarityStyle = {
	Body: Color3, -- цвет тела: по нему читается редкость
	Shade: Color3, -- более тёмный оттенок тела (лапки, уши, полоски)
	Outline: Color3?, -- контур (Highlight): светлое тело не теряется на светлом полу
	Light: { Brightness: number, Range: number }?, -- свечение вокруг мемлинга
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
	MemelingMaxDistance = 35, -- имена мемлингов видны только вблизи, чтобы не было каши из надписей
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
	LockedPedestalTransparency = 0.75, -- некупленный постамент — полупрозрачный «призрак»
	PedestalRim = Palette.CreamLight, -- светлый ободок сверху постамента
}

-- Кнопки ProximityPrompt
StyleConfig.Prompts = {
	BuyHoldSeconds = 0.3, -- короткое удержание, чтобы не купить случайно
	SellHoldSeconds = 0.6, -- продажу держать дольше: её не отменить
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

-- Враг Grumblob: тёмный коралл со сливовыми бровями — не похож ни на одну редкость мемлингов
StyleConfig.Enemy = {
	Body = Palette.CoralDark,
	Brow = Palette.PlumDark, -- сердитые брови
	BrowSize = v3(1.6, 0.35, 0.4),
	BrowOffsets = { -- от центра тела; брови наклонены к центру
		{ Position = v3(-0.9, 1.45, -2.2), Tilt = -20 },
		{ Position = v3(0.9, 1.45, -2.2), Tilt = 20 },
	},
	EyeSize = 1.4,
	PupilSize = 0.7,
	EyeOffsets = {
		v3(-0.9, 0.6, -2.0),
		v3(0.9, 0.6, -2.0),
	},
	PupilForward = 0.5,
	LabelMaxDistance = 60,
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

-- Два глаза: белок + зрачок. x — расстояние от середины, y — высота, z — глубина лица (обычно минус)
local function eyes(x: number, y: number, z: number, size: number): { Feature }
	local pupil = size * 0.5
	local forward = size * 0.35
	return {
		{ Kind = "Ball", Size = v3(size, size, size), Offset = v3(-x, y, z), Color = "CreamLight" },
		{ Kind = "Ball", Size = v3(size, size, size), Offset = v3(x, y, z), Color = "CreamLight" },
		{ Kind = "Ball", Size = v3(pupil, pupil, pupil), Offset = v3(-x, y, z - forward), Color = "Ink" },
		{ Kind = "Ball", Size = v3(pupil, pupil, pupil), Offset = v3(x, y, z - forward), Color = "Ink" },
	}
end

local function join(...: { Feature }): { Feature }
	local result: { Feature } = {}
	for _, list in ipairs({ ... }) do
		for _, feature in ipairs(list) do
			table.insert(result, feature)
		end
	end
	return result
end

-- Вертикальный цилиндр (у Roblox цилиндр лежит вдоль X — поворачиваем на 90° вокруг Z)
local UP = v3(0, 0, 90)
-- Цилиндр вдоль Z (вперёд-назад)
local ALONG_Z = v3(0, 90, 0)

StyleConfig.Memeling = {
	-- «Габарит» мемлинга: центр — в середине, низ — на 3 ниже, верх — около 3 выше (шляпы чуть выше).
	-- По нему ставим мемлинга на пол и на постамент и считаем высоту подписей.
	Size = v3(6, 6, 6),
	LabelHeight = 6.5, -- подпись с именем — на столько выше центра (над шляпами и хохолками)
	-- Где мемлинги висят, когда их несут: относительно HumanoidRootPart (-Z = перед персонажем).
	-- Первый — перед грудью, остальные — стопкой на голове, чтобы не закрывать обзор спереди
	CarrySlotOffsets = {
		v3(0, 0.5, -4.5), -- в руках
		v3(0, 6, 0), -- на голове
		v3(0, 12.2, 0), -- на голове, сверху на втором
	},
	CarryStackStep = v3(0, 6.2, 0), -- если слотов больше, чем мест выше, — ещё выше по стопке

	-- Редкость читается по цвету тела и свечению: Common — без света, Rare — мягкий свет,
	-- Epic — свет и искры, Legendary — яркий свет и много искр
	Rarities = {
		Common = { Body = Palette.CreamGray, Shade = Palette.CreamDark, Outline = Palette.Coral },
		Rare = { Body = Palette.Mint, Shade = Palette.MintDark, Light = { Brightness = 1, Range = 9 } },
		Epic = {
			Body = Palette.Plum,
			Shade = Palette.PlumDark,
			Light = { Brightness = 2, Range = 13 },
			Particles = {
				Color = Palette.PlumLight,
				Rate = 2,
				Lifetime = NumberRange.new(0.8, 1.2),
				Speed = NumberRange.new(1, 2),
				Size = 0.8,
				SpreadAngle = 180,
				LightEmission = 1,
			},
		},
		Legendary = {
			Body = Palette.Sun,
			Shade = Palette.SunDark,
			Light = { Brightness = 3, Range = 18 },
			Particles = {
				Color = Palette.SunLight,
				Rate = 5,
				Lifetime = NumberRange.new(0.8, 1.4),
				Speed = NumberRange.new(1, 2.5),
				Size = 1,
				SpreadAngle = 180,
				LightEmission = 1,
			},
		},
	} :: { [string]: RarityStyle },

	-- У каждого из 8 свой силуэт и характер. Ключ — Id из MemelingConfig
	Looks = {
		-- Toast Paw: тост-котик — ломтик с круглым верхом, кошачьи ушки, лапки и кусочек масла
		ToastPaw = {
			Core = { Kind = "Block", Size = v3(5, 3.6, 2.6), Color = "Body" },
			Features = join({
				{ Kind = "Cylinder", Size = v3(2.6, 5, 5), Offset = v3(0, 1.3, 0), Rotation = ALONG_Z, Color = "Body" },
				{ Kind = "Wedge", Size = v3(0.6, 1.3, 1.3), Offset = v3(-1.6, 4.2, 0), Color = "BodyShade" },
				{ Kind = "Wedge", Size = v3(0.6, 1.3, 1.3), Offset = v3(1.6, 4.2, 0), Color = "BodyShade" },
				{ Kind = "Block", Size = v3(1.6, 0.4, 1.6), Offset = v3(0.9, 3.85, 0), Rotation = v3(0, 20, 0), Color = "SunLight" },
				{ Kind = "Ball", Size = v3(1.5, 1.5, 1.5), Offset = v3(-1.4, -1.9, -1.1), Color = "CreamLight" },
				{ Kind = "Ball", Size = v3(1.5, 1.5, 1.5), Offset = v3(1.4, -1.9, -1.1), Color = "CreamLight" },
				{ Kind = "Block", Size = v3(0.9, 0.25, 0.25), Offset = v3(0, 0.2, -1.35), Color = "Ink" },
			}, eyes(1.1, 1.3, -1.25, 1.1)),
		},

		-- Sir Wobbleton: яйцо-рыцарь — шлем с прорезью, коралловый плюмаж, усы и деревянный меч
		SirWobbleton = {
			Core = { Kind = "Ball", Size = v3(5, 5, 5), Color = "Body" },
			Features = join({
				{ Kind = "Cylinder", Size = v3(1.6, 4.4, 4.4), Offset = v3(0, 2.1, 0), Rotation = UP, Color = "PlumLight" },
				{ Kind = "Block", Size = v3(2.6, 0.3, 0.4), Offset = v3(0, 2.1, -2.15), Color = "Ink" },
				{ Kind = "Ball", Size = v3(1.3, 1.3, 1.3), Offset = v3(0, 3.3, 0.4), Color = "Coral" },
				{ Kind = "Ball", Size = v3(1.1, 1.1, 1.1), Offset = v3(0, 4, 1.1), Color = "Coral" },
				{ Kind = "Ball", Size = v3(0.9, 0.9, 0.9), Offset = v3(0, 4.4, 1.9), Color = "CoralLight" },
				{ Kind = "Ball", Size = v3(0.8, 0.8, 0.8), Offset = v3(-0.45, -0.2, -2.3), Color = "CreamDark" },
				{ Kind = "Ball", Size = v3(0.8, 0.8, 0.8), Offset = v3(0.45, -0.2, -2.3), Color = "CreamDark" },
				{ Kind = "Cylinder", Size = v3(3.2, 0.35, 0.35), Offset = v3(2.7, -0.4, -0.8), Rotation = v3(0, 0, 70), Color = "SunDark" },
				{ Kind = "Ball", Size = v3(1.2, 1.2, 1.2), Offset = v3(-1.3, -2.4, -0.3), Color = "BodyShade" },
				{ Kind = "Ball", Size = v3(1.2, 1.2, 1.2), Offset = v3(1.3, -2.4, -0.3), Color = "BodyShade" },
			}, eyes(0.9, 0.7, -2.1, 1)),
		},

		-- Grumbloaf: ворчливый батон — низкий и широкий, надрезы сверху, сердитые брови, ручки
		Grumbloaf = {
			Core = { Kind = "Block", Size = v3(6, 3, 4), Color = "Body" },
			Features = join({
				{ Kind = "Cylinder", Size = v3(6, 4, 4), Offset = v3(0, 0.6, 0), Color = "Body" },
				{ Kind = "Block", Size = v3(0.35, 0.3, 2.8), Offset = v3(-1.6, 2.6, 0), Rotation = v3(0, 30, 0), Color = "BodyShade" },
				{ Kind = "Block", Size = v3(0.35, 0.3, 2.8), Offset = v3(0, 2.65, 0), Rotation = v3(0, 30, 0), Color = "BodyShade" },
				{ Kind = "Block", Size = v3(0.35, 0.3, 2.8), Offset = v3(1.6, 2.6, 0), Rotation = v3(0, 30, 0), Color = "BodyShade" },
				{ Kind = "Block", Size = v3(1.2, 0.3, 0.3), Offset = v3(-1.1, 1.35, -2.05), Rotation = v3(0, 0, -15), Color = "Ink" },
				{ Kind = "Block", Size = v3(1.2, 0.3, 0.3), Offset = v3(1.1, 1.35, -2.05), Rotation = v3(0, 0, 15), Color = "Ink" },
				{ Kind = "Block", Size = v3(1.4, 0.25, 0.25), Offset = v3(0, -0.6, -2.05), Color = "Ink" },
				{ Kind = "Ball", Size = v3(1.1, 1.1, 1.1), Offset = v3(-3.2, -0.4, 0), Color = "BodyShade" },
				{ Kind = "Ball", Size = v3(1.1, 1.1, 1.1), Offset = v3(3.2, -0.4, 0), Color = "BodyShade" },
			}, eyes(1.1, 0.55, -1.95, 1)),
		},

		-- Noodle Ninja: стаканчик лапши в повязке ниндзя — лапша сверху, палочки, хвостики повязки
		NoodleNinja = {
			Core = { Kind = "Ball", Size = v3(4, 4, 4), Color = "Body", Hidden = true },
			Features = join({
				{ Kind = "Cylinder", Size = v3(4.6, 4.4, 4.4), Offset = v3(0, -0.7, 0), Rotation = UP, Color = "Body" },
				{ Kind = "Cylinder", Size = v3(1, 4.6, 4.6), Offset = v3(0, -1.6, 0), Rotation = UP, Color = "CreamLight" },
				{ Kind = "Cylinder", Size = v3(0.7, 4.6, 4.6), Offset = v3(0, 1.1, 0), Rotation = UP, Color = "Coral" },
				{ Kind = "Block", Size = v3(0.3, 0.5, 2.2), Offset = v3(-0.5, 1, 2.9), Rotation = v3(20, -15, 0), Color = "Coral" },
				{ Kind = "Block", Size = v3(0.3, 0.5, 2.2), Offset = v3(0.5, 1, 2.9), Rotation = v3(20, 15, 0), Color = "Coral" },
				{ Kind = "Ball", Size = v3(1.5, 1.5, 1.5), Offset = v3(-0.8, 2, -0.5), Color = "SunLight" },
				{ Kind = "Ball", Size = v3(1.5, 1.5, 1.5), Offset = v3(0.8, 2.1, 0.4), Color = "SunLight" },
				{ Kind = "Ball", Size = v3(1.3, 1.3, 1.3), Offset = v3(0, 2.4, -0.1), Color = "Sun" },
				{ Kind = "Cylinder", Size = v3(4, 0.25, 0.25), Offset = v3(1.3, 3.2, 0.5), Rotation = v3(0, 0, 75), Color = "CreamDark" },
				{ Kind = "Cylinder", Size = v3(4, 0.25, 0.25), Offset = v3(1.7, 3, 0.2), Rotation = v3(0, 0, 70), Color = "CreamDark" },
			}, eyes(0.8, 0.25, -2.15, 1)),
		},

		-- Captain Sockbeard: носок-пират — полосатая резинка, борода, треуголка и повязка на глазу
		CaptainSockbeard = {
			Core = { Kind = "Block", Size = v3(3.6, 4.4, 3), Color = "Body" },
			Features = {
				{ Kind = "Ball", Size = v3(3.4, 3.4, 3.4), Offset = v3(0, -1.6, -0.9), Color = "Body" },
				{ Kind = "Cylinder", Size = v3(1, 4, 4), Offset = v3(0, 2.4, 0), Rotation = UP, Color = "CreamLight" },
				{ Kind = "Cylinder", Size = v3(0.4, 3.9, 3.9), Offset = v3(0, 1.6, 0), Rotation = UP, Color = "Coral" },
				{ Kind = "Ball", Size = v3(2.6, 2.6, 2.6), Offset = v3(0, -0.3, -1.5), Color = "CreamDark" },
				{ Kind = "Block", Size = v3(4.6, 0.6, 2.6), Offset = v3(0, 3.2, 0), Color = "PlumDark" },
				{ Kind = "Ball", Size = v3(2.4, 2.4, 2.4), Offset = v3(0, 3.6, 0), Color = "PlumDark" },
				{ Kind = "Ball", Size = v3(0.6, 0.6, 0.6), Offset = v3(0, 3.7, -1.2), Color = "CreamLight" },
				{ Kind = "Ball", Size = v3(1, 1, 1), Offset = v3(-0.8, 1, -1.5), Color = "CreamLight" },
				{ Kind = "Ball", Size = v3(0.5, 0.5, 0.5), Offset = v3(-0.8, 1, -1.85), Color = "Ink" },
				{ Kind = "Block", Size = v3(1.1, 1.1, 0.3), Offset = v3(0.8, 1, -1.6), Color = "Ink" },
			},
		},

		-- Disco Pickle: огурчик-диско — высокая «капсула», пышная причёска, очки и светящийся медальон
		DiscoPickle = {
			Core = { Kind = "Ball", Size = v3(3.6, 3.6, 3.6), Color = "Body" },
			Features = join({
				{ Kind = "Cylinder", Size = v3(3.2, 3.6, 3.6), Offset = v3(0, 0, 0), Rotation = UP, Color = "Body" },
				{ Kind = "Ball", Size = v3(3.6, 3.6, 3.6), Offset = v3(0, 1.6, 0), Color = "Body" },
				{ Kind = "Ball", Size = v3(3.6, 3.6, 3.6), Offset = v3(0, -1.6, 0), Color = "Body" },
				{ Kind = "Ball", Size = v3(0.6, 0.6, 0.6), Offset = v3(-1.7, 0.3, -0.6), Color = "BodyShade" },
				{ Kind = "Ball", Size = v3(0.6, 0.6, 0.6), Offset = v3(1.6, -1, -0.8), Color = "BodyShade" },
				{ Kind = "Ball", Size = v3(4.4, 4.4, 4.4), Offset = v3(0, 3.5, 0.3), Color = "PlumDark" },
				{ Kind = "Block", Size = v3(1.3, 0.8, 0.3), Offset = v3(-0.75, 1.4, -1.85), Color = "Ink" },
				{ Kind = "Block", Size = v3(1.3, 0.8, 0.3), Offset = v3(0.75, 1.4, -1.85), Color = "Ink" },
				{ Kind = "Block", Size = v3(0.5, 0.2, 0.2), Offset = v3(0, 1.5, -1.9), Color = "Ink" },
				{ Kind = "Block", Size = v3(1.2, 0.3, 0.3), Offset = v3(0, 0.3, -1.85), Color = "Coral" },
				{ Kind = "Ball", Size = v3(0.9, 0.9, 0.9), Offset = v3(0, -0.8, -1.9), Color = "Sun", Glow = true },
			}),
		},

		-- Professor Bonk: профессор с шишкой — шапочка выпускника с кисточкой, круглые очки, усы, бабочка
		ProfessorBonk = {
			Core = { Kind = "Ball", Size = v3(5, 5, 5), Color = "Body" },
			Features = join({
				{ Kind = "Cylinder", Size = v3(0.8, 2.8, 2.8), Offset = v3(0, 2.5, 0), Rotation = UP, Color = "PlumDark" },
				{ Kind = "Block", Size = v3(4.6, 0.3, 4.6), Offset = v3(0, 3, 0), Rotation = v3(0, 45, 0), Color = "PlumDark" },
				{ Kind = "Block", Size = v3(0.25, 1.6, 0.25), Offset = v3(1.7, 2.3, -1.7), Color = "Sun" },
				{ Kind = "Ball", Size = v3(0.55, 0.55, 0.55), Offset = v3(1.7, 1.45, -1.7), Color = "Sun" },
				{ Kind = "Cylinder", Size = v3(0.2, 1.5, 1.5), Offset = v3(-0.9, 0.6, -2.35), Rotation = ALONG_Z, Color = "Ink" },
				{ Kind = "Cylinder", Size = v3(0.2, 1.5, 1.5), Offset = v3(0.9, 0.6, -2.35), Rotation = ALONG_Z, Color = "Ink" },
				{ Kind = "Ball", Size = v3(1.1, 1.1, 1.1), Offset = v3(1.5, 1.9, -1.3), Color = "CoralLight" },
				{ Kind = "Ball", Size = v3(0.9, 0.9, 0.9), Offset = v3(-0.5, -0.5, -2.3), Color = "CreamLight" },
				{ Kind = "Ball", Size = v3(0.9, 0.9, 0.9), Offset = v3(0.5, -0.5, -2.3), Color = "CreamLight" },
				{ Kind = "Block", Size = v3(0.7, 0.6, 0.3), Offset = v3(-0.4, -1.8, -2), Rotation = v3(0, 0, 20), Color = "Coral" },
				{ Kind = "Block", Size = v3(0.7, 0.6, 0.3), Offset = v3(0.4, -1.8, -2), Rotation = v3(0, 0, -20), Color = "Coral" },
				{ Kind = "Ball", Size = v3(1.3, 1.3, 1.3), Offset = v3(-1.2, -2.5, -0.4), Color = "BodyShade" },
				{ Kind = "Ball", Size = v3(1.3, 1.3, 1.3), Offset = v3(1.2, -2.5, -0.4), Color = "BodyShade" },
			}, eyes(0.9, 0.6, -2.1, 0.9)),
		},

		-- Mega Snoozeasaurus: сонный динозавр — длинный хвост, шипы на спине, ночной колпак с помпоном,
		-- глаза закрыты (спит!)
		MegaSnoozeasaurus = {
			Core = { Kind = "Ball", Size = v3(5, 5, 5), Color = "Body" },
			Features = {
				{ Kind = "Ball", Size = v3(3, 3, 3), Offset = v3(0, 0.1, -2.3), Color = "Body" },
				{ Kind = "Ball", Size = v3(3.4, 3.4, 3.4), Offset = v3(0, -0.9, -1), Color = "SunLight" },
				{ Kind = "Ball", Size = v3(0.35, 0.35, 0.35), Offset = v3(-0.5, 0.5, -3.75), Color = "Ink" },
				{ Kind = "Ball", Size = v3(0.35, 0.35, 0.35), Offset = v3(0.5, 0.5, -3.75), Color = "Ink" },
				{ Kind = "Block", Size = v3(1.1, 0.22, 0.25), Offset = v3(-1, 1.5, -2.1), Rotation = v3(0, 0, -8), Color = "Ink" },
				{ Kind = "Block", Size = v3(1.1, 0.22, 0.25), Offset = v3(1, 1.5, -2.1), Rotation = v3(0, 0, 8), Color = "Ink" },
				{ Kind = "Wedge", Size = v3(0.5, 1.4, 1.4), Offset = v3(0, 2.7, 0.6), Color = "BodyShade" },
				{ Kind = "Wedge", Size = v3(0.5, 1.3, 1.3), Offset = v3(0, 2.2, 1.8), Color = "BodyShade" },
				{ Kind = "Wedge", Size = v3(0.5, 1.1, 1.1), Offset = v3(0, 1.3, 2.6), Color = "BodyShade" },
				{ Kind = "Ball", Size = v3(2.4, 2.4, 2.4), Offset = v3(0, -1.3, 3), Color = "Body" },
				{ Kind = "Ball", Size = v3(1.8, 1.8, 1.8), Offset = v3(0, -1.9, 4.4), Color = "Body" },
				{ Kind = "Ball", Size = v3(1.2, 1.2, 1.2), Offset = v3(0, -2.3, 5.5), Color = "BodyShade" },
				{ Kind = "Cylinder", Size = v3(0.9, 3, 3), Offset = v3(-0.5, 2.7, -0.2), Rotation = UP, Color = "PlumLight" },
				{ Kind = "Cylinder", Size = v3(0.7, 2, 2), Offset = v3(-0.8, 3.4, 0), Rotation = UP, Color = "PlumLight" },
				{ Kind = "Ball", Size = v3(1, 1, 1), Offset = v3(-1.2, 3.95, 0.2), Color = "CreamLight" },
				{ Kind = "Ball", Size = v3(1.6, 1.6, 1.6), Offset = v3(-1.4, -2.4, -0.7), Color = "BodyShade" },
				{ Kind = "Ball", Size = v3(1.6, 1.6, 1.6), Offset = v3(1.4, -2.4, -0.7), Color = "BodyShade" },
			},
		},
	} :: { [string]: Look },
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
