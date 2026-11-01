--!strict
-- EnemyConfig: враги в опасной части зоны (виды — Kinds, по зонам — Zones, общее поведение — Chaser).
-- Позиции — смещения от центра верхней грани пола зоны.
-- Опасная часть: X от MapConfig.Zone.DangerFromX (14) до края (112); площадка EXTRACT — X = 90, радиус 12.
-- Урон умеренный: здоровье персонажа Roblox 100, от одного касания не умирают.

-- table.freeze замораживает только верхний уровень, поэтому замораживаем всё дерево
local function deepFreeze<T>(t: T): T
	for _, value in t :: any do
		if type(value) == "table" and not table.isfrozen(value) then
			deepFreeze(value)
		end
	end
	return table.freeze(t :: any) :: any
end

local EnemyConfig = {}

-- Виды врагов (задача 7.7): у каждого свои скорость, урон, размер и замах; поведение (патруль, погоня,
-- охрана, замах перед ударом) у всех одинаковое — EnemyConfig.Chaser. Вид модели — MemelingBuilders.BuildEnemy,
-- цвета — StyleConfig.Characters[Id вида]
export type EnemyKind = {
	WalkSpeed: number, -- в погоне
	PatrolWalkSpeed: number, -- в патруле
	Damage: number,
	HitCooldownSeconds: number, -- один враг бьёт одного игрока не чаще
	-- Телеграф удара: игрок ближе WindupRadius — враг WindupSeconds раздувается и краснеет,
	-- и только потом бьёт, если игрок всё ещё в HitRadius (от центра врага до центра персонажа)
	WindupRadius: number,
	WindupSeconds: number,
	HitRadius: number,
	BodySize: number, -- диаметр тела в студах
}

EnemyConfig.Kinds = {
	-- Grumblob: ворчливый желейный шар. Игрок бегает 16, с Epic — 14, с Legendary — 11: убежать можно всегда.
	-- Без добычи отрываешься на 6 студов/с (из зоны ChaseRadius за ~7 с), с Legendary — медленно, на 1 студ/с
	Grumblob = {
		WalkSpeed = 10,
		PatrolWalkSpeed = 6,
		Damage = 20,
		HitCooldownSeconds = 1.5,
		WindupRadius = 5.5,
		WindupSeconds = 0.5,
		HitRadius = 4.5,
		BodySize = 5,
	},
	-- GummyBrute (Candy Chaos): мармеладный громила — медленный, но бьёт вдвое сильнее; замах длиннее,
	-- поэтому от удара можно отскочить. Крупнее Grumblob — достаёт дальше
	GummyBrute = {
		WalkSpeed = 7,
		PatrolWalkSpeed = 4,
		Damage = 40,
		HitCooldownSeconds = 2,
		WindupRadius = 7,
		WindupSeconds = 0.8,
		HitRadius = 6,
		BodySize = 7,
	},
} :: { [string]: EnemyKind }

-- Сколько врагов, какого вида и где их дома — по зонам (Id — ZoneConfig.ZoneOrder). Count не больше,
-- чем SpawnPoints; точки — по всей опасной части, в стороне от EXTRACT
EnemyConfig.Zones = {
	Meme = {
		Kind = "Grumblob",
		Count = 5,
		SpawnPoints = {
			Vector3.new(30, 0, -100),
			Vector3.new(30, 0, 100),
			Vector3.new(70, 0, -100),
			Vector3.new(70, 0, 100),
			Vector3.new(105, 0, -60),
			Vector3.new(105, 0, 60),
		},
	},
	-- Golden Zone: врагов чуть больше (7)
	Golden = {
		Kind = "Grumblob",
		Count = 7,
		SpawnPoints = {
			Vector3.new(30, 0, -100),
			Vector3.new(30, 0, 100),
			Vector3.new(70, 0, -100),
			Vector3.new(70, 0, 100),
			Vector3.new(105, 0, -60),
			Vector3.new(105, 0, 60),
			Vector3.new(45, 0, -35),
			Vector3.new(45, 0, 35),
		},
	},
	-- Candy Chaos: мармеладные громилы вместо Grumblob — их меньше, они медленные, но бьют сильнее
	Candy = {
		Kind = "GummyBrute",
		Count = 6,
		SpawnPoints = {
			Vector3.new(30, 0, -100),
			Vector3.new(30, 0, 100),
			Vector3.new(70, 0, -100),
			Vector3.new(70, 0, 100),
			Vector3.new(105, 0, -60),
			Vector3.new(105, 0, 60),
		},
	},
} :: { [string]: { Kind: string, Count: number, SpawnPoints: { Vector3 } } }

-- Поведение одинаковое во всех зонах и у всех видов (скорость, урон и размер — EnemyConfig.Kinds)
EnemyConfig.Chaser = {
	-- Вокруг EXTRACT круг такого радиуса (от центра площадки), куда враги не заходят — как в безопасную часть:
	-- эвакуацию караулить нельзя (площадка — 12 студов, до врага у края круга ещё 8)
	ExtractionKeepOut = 20,
	ChaseRadius = 45, -- замечает игрока ближе этого (в опасной части)
	-- Охрана: игрок подобрал мемлинга — все враги ближе AggroRadius сразу гонятся за ним («!» и звук).
	-- Гонятся, пока игрок не дальше LeashRadius, в опасной части и не у EXTRACT (круг ExtractionKeepOut)
	AggroRadius = 45,
	LeashRadius = 70,
	-- Спит (стоит и ничего не считает) только когда в вылазке нет никого ближе WakeRadius.
	-- 200 — почти вся зона: пока в зоне есть игрок, враги не стоят, а патрулируют
	WakeRadius = 200,
	-- Без цели — патруль: ходит к случайным точкам не дальше PatrolRadius от дома, медленнее, с паузами
	PatrolRadius = 22,
	PatrolPauseSeconds = NumberRange.new(1, 3),
	PatrolGiveUpSeconds = 10, -- не дошёл до точки за это время — выбирает другую
	AlertSeconds = 1, -- сколько висит «!» над врагом при агро
	StatusLogSeconds = 5, -- раз в столько секунд в Output — состояние каждого врага и причина
	ThinkSeconds = 0.75, -- путь пересчитываем не чаще раза в столько секунд
	DamageTickSeconds = 0.1, -- как часто проверяем касание
	AreaMargin = 4, -- не подходит к границе опасной части и к стенам ближе
	PerfReportSeconds = 30, -- раз в столько секунд пишет в Output, сколько времени сервера уходит на врагов
}

return deepFreeze(EnemyConfig)
