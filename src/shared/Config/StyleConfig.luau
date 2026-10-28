--!strict
-- StyleConfig: ВЕСЬ внешний вид в одном месте — палитра, материалы, частицы, свет, шрифты, цвета HUD.
-- Формы и размеры — в MapConfig, тексты — в TextConfig.
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
	Glow: boolean, -- PointLight и частицы
	Particles: Particles?,
}

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds" -- встроенная текстура Roblox

local StyleConfig = {}

StyleConfig.Material = Enum.Material.SmoothPlastic
StyleConfig.GlowMaterial = Enum.Material.Neon
StyleConfig.ParticleTexture = SPARKLE_TEXTURE

StyleConfig.Fonts = {
	Label = Enum.Font.FredokaOne, -- подписи над объектами
	Hud = Enum.Font.FredokaOne,
}

-- Подписи над объектами
StyleConfig.Label = {
	Text = rgb(255, 255, 255),
	Stroke = rgb(40, 20, 60),
}

-- Земля вокруг (Baseplate)
StyleConfig.Ground = rgb(110, 205, 95)

-- Хаб: тёплый солнечный
StyleConfig.Hub = {
	Floor = rgb(255, 205, 110),
	Spawn = rgb(255, 245, 215),
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

-- Meme Zone: сразу видно, что это другое место. Опасная часть — тревожная
StyleConfig.Zone = {
	SafeFloor = rgb(70, 200, 185),
	DangerFloor = rgb(235, 70, 55),
	Entry = rgb(255, 255, 255),
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

-- Мемлинги: цвет тела по редкости; у Epic и Legendary — свет и лёгкие искры
StyleConfig.Memeling = {
	EyeWhite = rgb(255, 255, 255),
	Pupil = rgb(25, 20, 35),
	Light = { Brightness = 2, Range = 10 },
	Rarities = {
		Common = { Body = rgb(225, 225, 232), Glow = false },
		Rare = { Body = rgb(40, 125, 255), Glow = false },
		Epic = {
			Body = rgb(165, 70, 255),
			Glow = true,
			Particles = {
				Color = rgb(215, 160, 255),
				Rate = 2,
				Lifetime = NumberRange.new(0.8, 1.2),
				Speed = NumberRange.new(1, 2),
				Size = 0.5,
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
				Size = 0.6,
				SpreadAngle = 180,
				LightEmission = 1,
			},
		},
	} :: { [string]: RarityStyle },
}

-- Свет: яркий солнечный день, сочные цвета
StyleConfig.Lighting = {
	ClockTime = 14,
	Brightness = 3,
	Ambient = rgb(140, 125, 120),
	OutdoorAmbient = rgb(160, 150, 150),
	ExposureCompensation = 0.1,
	EnvironmentDiffuseScale = 0.5,
	EnvironmentSpecularScale = 0.5,
	ShadowSoftness = 0.25,
	Atmosphere = {
		Density = 0.25,
		Offset = 0.2,
		Color = rgb(200, 225, 255),
		Decay = rgb(255, 210, 170),
		Glare = 0.3,
		Haze = 0.8,
	},
	Bloom = { Intensity = 0.6, Size = 24, Threshold = 1.1 },
	ColorCorrection = {
		Saturation = 0.25,
		Contrast = 0.08,
		Brightness = 0.02,
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
}

return deepFreeze(StyleConfig)
