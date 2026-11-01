--!strict
-- EnemyConfig: враги в опасной части зоны. Позиции — смещения от центра верхней грани пола зоны.
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

-- Grumblob: ворчливый желейный шар, гонится за игроками в опасной части
EnemyConfig.Chaser = {
	Count = 5, -- сколько врагов в зоне (не больше, чем SpawnPoints)
	SpawnPoints = { -- по всей опасной части, в стороне от EXTRACT
		Vector3.new(30, 0, -100),
		Vector3.new(30, 0, 100),
		Vector3.new(70, 0, -100),
		Vector3.new(70, 0, 100),
		Vector3.new(105, 0, -60),
		Vector3.new(105, 0, 60),
	},
	-- Вокруг EXTRACT круг такого радиуса (от центра площадки), куда враги не заходят — как в безопасную часть:
	-- эвакуацию караулить нельзя (площадка — 12 студов, до врага у края круга ещё 8)
	ExtractionKeepOut = 20,
	-- Игрок бегает 16, с Epic — 14, с Legendary — 11: убежать можно всегда.
	-- Без добычи отрываешься на 6 студов/с (из зоны ChaseRadius за ~7 с), с Legendary — медленно, на 1 студ/с
	WalkSpeed = 10,
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
	PatrolWalkSpeed = 6,
	PatrolPauseSeconds = NumberRange.new(1, 3),
	PatrolGiveUpSeconds = 10, -- не дошёл до точки за это время — выбирает другую
	AlertSeconds = 1, -- сколько висит «!» над врагом при агро
	StatusLogSeconds = 5, -- раз в столько секунд в Output — состояние каждого врага и причина
	ThinkSeconds = 0.75, -- путь пересчитываем не чаще раза в столько секунд
	DamageTickSeconds = 0.1, -- как часто проверяем касание
	HitRadius = 4.5, -- касание: от центра врага до центра персонажа не дальше
	-- Телеграф удара: игрок ближе WindupRadius — враг WindupSeconds раздувается и краснеет,
	-- и только потом бьёт, если игрок всё ещё в HitRadius. Успел отбежать — промах (перезарядка та же)
	WindupRadius = 5.5,
	WindupSeconds = 0.5,
	Damage = 20,
	HitCooldownSeconds = 1.5, -- один враг бьёт одного игрока не чаще
	AreaMargin = 4, -- не подходит к границе опасной части и к стенам ближе
	BodySize = 5, -- диаметр тела в студах
	PerfReportSeconds = 30, -- раз в столько секунд пишет в Output, сколько времени сервера уходит на врагов
}

return deepFreeze(EnemyConfig)
