--!strict
-- EventConfig: события в зоне. Позиции — смещения от центра верхней грани пола зоны (X на восток, Z на юг).
-- Опасная часть: X от MapConfig.Zone.DangerFromX (14) до края (112); площадка EXTRACT — X = 90, радиус 12.
-- Урон умеренный: здоровье персонажа Roblox 100, от одного удара не умирают.

-- table.freeze замораживает только верхний уровень, поэтому замораживаем всё дерево
local function deepFreeze<T>(t: T): T
	for _, value in t :: any do
		if type(value) == "table" and not table.isfrozen(value) then
			deepFreeze(value)
		end
	end
	return table.freeze(t :: any) :: any
end

local EventConfig = {}

-- Giant Object: огромное колесо сыра катится по опасной части по заранее заданному маршруту
EventConfig.GiantObject = {
	IntervalMin = 25, -- пауза между событиями — случайно от IntervalMin до IntervalMax секунд
	IntervalMax = 40,
	WarnSeconds = 2, -- маршрут подсвечивается и звучит сигнал перед стартом
	Speed = 20, -- студов в секунду
	Damage = 30,
	HitCooldownSeconds = 1, -- один игрок получает урон от колеса не чаще
	TickSeconds = 0.1, -- как часто сервер проверяет попадание
	Diameter = 10,
	Thickness = 4,
	-- Маршрут: точки по полу опасной части, колесо катится от первой к последней
	Route = {
		Vector3.new(55, 0, -105), -- с юга на север через дорожку лазера…
		Vector3.new(55, 0, 35),
		Vector3.new(104, 0, 35), -- …и на восток мимо EXTRACT (в 23 студах от края площадки)
	},
	RouteHighlightWidth = 3, -- ширина подсвеченной полосы маршрута
}

return deepFreeze(EventConfig)
