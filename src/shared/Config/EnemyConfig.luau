--!strict
-- EnemyConfig: враги в опасной части зоны. Позиции — смещения от центра верхней грани пола зоны.
-- Опасная часть: X от MapConfig.Zone.DangerFromX (10) до края (80); площадка EXTRACT — X = 60, радиус 12.
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
	Count = 3, -- сколько врагов в зоне (не больше, чем SpawnPoints)
	SpawnPoints = {
		Vector3.new(40, 0, -65),
		Vector3.new(40, 0, 65),
		Vector3.new(70, 0, -55),
		Vector3.new(70, 0, 55),
		Vector3.new(22, 0, -70),
		Vector3.new(22, 0, 70),
	},
	WalkSpeed = 13, -- игрок бегает 16 — убежать можно, но с тяжёлой добычей (11) уже нет
	ChaseRadius = 45, -- замечает игрока ближе этого
	WakeRadius = 90, -- если ни одного игрока в вылазке ближе — спит и ничего не считает
	ThinkSeconds = 0.75, -- путь пересчитываем не чаще раза в столько секунд
	DamageTickSeconds = 0.1, -- как часто проверяем касание
	HitRadius = 4.5, -- касание: от центра врага до центра персонажа не дальше
	Damage = 20,
	HitCooldownSeconds = 1.5, -- один враг бьёт одного игрока не чаще
	AreaMargin = 4, -- не подходит к границе опасной части и к стенам ближе
	BodySize = 5, -- диаметр тела в студах
	PerfReportSeconds = 30, -- раз в столько секунд пишет в Output, сколько времени сервера уходит на врагов
}

return deepFreeze(EnemyConfig)
