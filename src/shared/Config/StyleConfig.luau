--!strict
-- StyleConfig: ВЕСЬ внешний вид в одном месте — палитра, материалы, частицы, свет, шрифты,
-- размеры мемлинга и подписей, раскладка HUD. Позиции карты — в MapConfig, тексты — в TextConfig.
-- Правило для телефонов: частиц мало, мелкие детали без теней.

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

export type Particles = {
	Color: Color3,
	Rate: number, -- частиц в секунду: держим маленьким
	Lifetime: NumberRange,
	Speed: NumberRange,
	Size: number,
	SpreadAngle: number,
	LightEmission: number,
}

export type RarityStyle = {
	Body: Color3,
	Outline: Color3?, -- цветная обводка (Highlight), чтобы светлое тело не терялось на светлом полу
	Glow: boolean, -- PointLight и частицы
	Particles: Particles?,
}

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds" -- встроенная текстура Roblox

local StyleConfig = {}

StyleConfig.Material = Enum.Material.SmoothPlastic
StyleConfig.GlowMaterial = Enum.Material.Neon
StyleConfig.ParticleTexture = SPARKLE_TEXTURE

StyleConfig.Fonts = {
	Label = Enum.Font.FredokaOne, -- подписи над объектами и на табличках
	Hud = Enum.Font.FredokaOne,
}

-- Подписи над объектами (BillboardGui), размеры в студах
StyleConfig.Label = {
	Text = rgb(255, 255, 255),
	Stroke = rgb(40, 20, 60),
	WidthStuds = 12,
	HeightStuds = 3,
	MaxDistance = 200, -- обычные подписи (портал, зона, EXTRACT)
	MemelingMaxDistance = 35, -- имена мемлингов видны только вблизи, чтобы не было каши из надписей
	PedestalAuraGap = 2.5, -- насколько подпись «накоплено» выше подписи мемлинга на постаменте
	-- Плотность имени владельца на табличке (SurfaceGui). TextScaled не растит текст больше 100 пикселей,
	-- поэтому при 20 пикселях на студ имя заполняет табличку 10×5 студов по высоте
	SignPixelsPerStud = 20,
	EntryScale = 0.5, -- подпись «Entry» вдвое меньше обычной
}

-- Земля вокруг (Baseplate)
StyleConfig.Ground = rgb(110, 205, 95)

-- Хаб: насыщенный тёплый, не белёсый
StyleConfig.Hub = {
	Floor = rgb(235, 140, 55),
	Spawn = rgb(250, 195, 95),
	SpawnForceFieldSeconds = 0, -- без силового поля при появлении
}

-- Портал: яркий неон и искры
StyleConfig.Portal = {
	Color = rgb(255, 60, 200),
	Transparency = 0.15,
	Particles = {
		Color = rgb(255, 150, 235),
		Rate = 6,
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(2, 4),
		Size = 0.8,
		SpreadAngle = 60,
		LightEmission = 1,
	},
}

-- Участки: у каждого свой цвет. Floor — пол, Accent — табличка и постаменты
StyleConfig.Plots = {
	{ Floor = rgb(255, 140, 150), Accent = rgb(225, 55, 90) }, -- клубничный
	{ Floor = rgb(255, 185, 110), Accent = rgb(240, 120, 30) }, -- апельсин
	{ Floor = rgb(255, 230, 120), Accent = rgb(225, 170, 20) }, -- лимон
	{ Floor = rgb(150, 235, 130), Accent = rgb(60, 175, 70) }, -- лайм
	{ Floor = rgb(120, 225, 225), Accent = rgb(20, 160, 170) }, -- бирюза
	{ Floor = rgb(130, 180, 255), Accent = rgb(45, 105, 230) }, -- небо
	{ Floor = rgb(190, 150, 255), Accent = rgb(125, 70, 225) }, -- виноград
	{ Floor = rgb(255, 160, 220), Accent = rgb(215, 60, 165) }, -- жвачка
}

-- Детали участка
StyleConfig.PlotParts = {
	UpgradeButton = rgb(255, 205, 40), -- кнопки улучшений: золотые, видно, что их можно нажать
	ReservePad = rgb(70, 160, 255), -- площадка запаса: синяя
	LockedPedestalTransparency = 0.75, -- некупленный постамент — полупрозрачный «призрак»
}

-- Кнопки ProximityPrompt
StyleConfig.Prompts = {
	BuyHoldSeconds = 0.3, -- короткое удержание, чтобы не купить случайно
	SellHoldSeconds = 0.6, -- продажу держать дольше: её не отменить
	SecondaryOffsetY = 90, -- вторая кнопка на том же постаменте (Sell) — ниже первой (Collect), в пикселях
}

-- Meme Zone: тёмный спокойный пол с узором плиткой; опасная часть — тёмно-красная
StyleConfig.Zone = {
	SafeFloor = rgb(45, 95, 105),
	DangerFloor = rgb(120, 28, 34),
	Entry = rgb(255, 255, 255),
	-- Узор плиткой поверх пола (Texture на верхней грани)
	FloorTexture = "rbxassetid://6372755229", -- сетка-плитка из стандартного Baseplate Roblox
	FloorTextureStuds = 8, -- размер одной плитки
	FloorTextureTransparency = 0.7,
	FloorTextureColor = rgb(255, 255, 255),
}

-- Площадка EXTRACT: неон и искры вверх
StyleConfig.Extraction = {
	Color = rgb(80, 255, 120),
	Transparency = 0.1,
	Particles = {
		Color = rgb(170, 255, 190),
		Rate = 8,
		Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(4, 7),
		Size = 0.9,
		SpreadAngle = 15,
		LightEmission = 1,
	},
}

-- Мемлинги: круглое тело и два глаза (белок + зрачок), смотрят в сторону -Z.
-- Цвет тела по редкости; у Epic и Legendary — свет и лёгкие искры.
StyleConfig.Memeling = {
	Size = Vector3.new(6, 6, 6),
	EyeSize = 1.7,
	PupilSize = 0.85,
	EyeOffsets = { -- от центра тела, на его поверхности спереди
		Vector3.new(-1.2, 0.7, -2.45),
		Vector3.new(1.2, 0.7, -2.45),
	},
	PupilForward = 0.6, -- на сколько зрачок выступает вперёд от центра глаза
	-- Где мемлинги висят, когда их несут: относительно HumanoidRootPart (-Z = перед персонажем).
	-- Первый — перед грудью, остальные — стопкой на голове, чтобы не закрывать обзор спереди
	CarrySlotOffsets = {
		Vector3.new(0, 0.5, -4.5), -- в руках
		Vector3.new(0, 6, 0), -- на голове
		Vector3.new(0, 12.2, 0), -- на голове, сверху на втором
	},
	CarryStackStep = Vector3.new(0, 6.2, 0), -- если слотов больше, чем мест выше, — ещё выше по стопке

	EyeWhite = rgb(255, 255, 255),
	Pupil = rgb(25, 20, 35),
	Light = { Brightness = 2, Range = 14 },
	Rarities = {
		Common = { Body = rgb(205, 208, 215), Outline = rgb(255, 120, 40), Glow = false },
		Rare = { Body = rgb(40, 125, 255), Glow = false },
		Epic = {
			Body = rgb(165, 70, 255),
			Glow = true,
			Particles = {
				Color = rgb(215, 160, 255),
				Rate = 2,
				Lifetime = NumberRange.new(0.8, 1.2),
				Speed = NumberRange.new(1, 2),
				Size = 0.8,
				SpreadAngle = 180,
				LightEmission = 1,
			},
		},
		Legendary = {
			Body = rgb(255, 195, 30),
			Glow = true,
			Particles = {
				Color = rgb(255, 235, 140),
				Rate = 4,
				Lifetime = NumberRange.new(0.8, 1.4),
				Speed = NumberRange.new(1, 2.5),
				Size = 1,
				SpreadAngle = 180,
				LightEmission = 1,
			},
		},
	} :: { [string]: RarityStyle },
}

-- Свет: яркий день без пересвета
StyleConfig.Lighting = {
	ClockTime = 14,
	Brightness = 2.5,
	Ambient = rgb(130, 115, 110),
	OutdoorAmbient = rgb(145, 135, 135),
	ExposureCompensation = -0.15,
	EnvironmentDiffuseScale = 0.5,
	EnvironmentSpecularScale = 0.5,
	ShadowSoftness = 0.25,
	Atmosphere = {
		Density = 0.25,
		Offset = 0.2,
		Color = rgb(200, 225, 255),
		Decay = rgb(255, 210, 170),
		Glare = 0.2,
		Haze = 0.8,
	},
	Bloom = { Intensity = 0.25, Size = 12, Threshold = 1.3 },
	ColorCorrection = {
		Saturation = 0.25,
		Contrast = 0.1,
		Brightness = -0.02,
		TintColor = rgb(255, 250, 240),
	},
	Sky = { SunAngularSize = 14, StarCount = 0 },
}

-- HUD (клиент)
StyleConfig.Hud = {
	BaseCard = rgb(255, 196, 40), -- «на базе»: золотой, в безопасности
	HandsCard = rgb(60, 150, 255), -- «в руках»: синий, можно потерять
	TextDark = rgb(25, 25, 25),
	TextLight = rgb(255, 255, 255),

	CardWidth = 300,
	CaptionSize = 18,
	ValueSize = 34,
	Margin = 12, -- отступ от левого края
	-- Сверху HUD ставим под панелью Roblox (GuiService:GetGuiInset) и под окном чата
	ChatReserveDesktop = 210, -- высота окна чата на компьютере, в пикселях
	ChatReserveTouch = 12, -- на телефоне окно чата закрыто, пока его не откроют
	SmallScreenHeight = 500, -- экран ниже этого (телефон боком) — HUD чуть меньше
	SmallScreenScale = 0.8,

	MarkerHeight = 14, -- на сколько студов над площадкой висит маркер EXTRACT
	MarkerHideDistance = 45, -- ближе этого маркер прячется: площадку и так видно
	MarkerTitleSize = 30,
	MarkerDistanceSize = 22,
	EdgeArrowSize = 56,
	EdgePadding = 70, -- отступ стрелки от края экрана, в пикселях
}

return deepFreeze(StyleConfig)
