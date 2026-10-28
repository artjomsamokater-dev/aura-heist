--!strict
-- MapConfig: размеры, позиции и цвета серого прототипа карты.
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

-- Вид мемлинга в сером прототипе: просто куб с подписью-именем
MapConfig.Memeling = {
	Size = Vector3.new(3, 3, 3),
	-- Где куб висит, когда его несут: относительно HumanoidRootPart (-Z = перед персонажем)
	CarryOffset = Vector3.new(0, 0, -2.5),
	CarryStackStep = Vector3.new(0, 3.2, 0), -- каждый следующий куб в руках — выше предыдущего
}

-- Подписи над объектами (BillboardGui), размеры в студах
MapConfig.Label = {
	WidthStuds = 12,
	HeightStuds = 3,
	MaxDistance = 200,
}

-- Тексты подписей в игре
MapConfig.Text = {
	FreePlot = "Free Studio",
	OwnedPlot = "%s's Studio", -- %s заменяется на имя игрока
	Portal = "MEME ZONE",
	Zone = "MEME ZONE",
	Entry = "Entry",
	PickupAction = "Pick up",
	Extraction = "EXTRACT",
	ExtractionProgress = "EXTRACTING... %d", -- %d — сколько секунд осталось
}

-- Серые цвета прототипа
MapConfig.Colors = {
	Hub = Color3.fromRGB(150, 150, 150),
	Spawn = Color3.fromRGB(185, 185, 185),
	Portal = Color3.fromRGB(210, 210, 210),
	Plot = Color3.fromRGB(120, 120, 120),
	Sign = Color3.fromRGB(70, 70, 70),
	Pedestal = Color3.fromRGB(95, 95, 95),
	Zone = Color3.fromRGB(105, 105, 105),
	Entry = Color3.fromRGB(175, 175, 175),
	Memeling = Color3.fromRGB(200, 200, 200),
	Extraction = Color3.fromRGB(230, 230, 230),
}

return deepFreeze(MapConfig)
