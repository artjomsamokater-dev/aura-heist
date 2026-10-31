--!strict
-- HazardConfig: ловушки в опасной части зоны — урон, тайминги, места.
-- Позиции — смещения от центра верхней грани пола зоны (X на восток, Z на юг).
-- Зона 224 × 224 (смещения X и Z от −112 до 112). Опасная часть — от MapConfig.Zone.DangerFromX = 14;
-- площадка EXTRACT — на X = 90, радиус 12 (ловушки её не задевают).
-- Урон умеренный: здоровье персонажа Roblox 100, от одного попадания не умирают (это проверяет тест).

-- table.freeze замораживает только верхний уровень, поэтому замораживаем всё дерево
local function deepFreeze<T>(t: T): T
	for _, value in t :: any do
		if type(value) == "table" and not table.isfrozen(value) then
			deepFreeze(value)
		end
	end
	return table.freeze(t :: any) :: any
end

local HazardConfig = {}

HazardConfig.TickSeconds = 0.1 -- как часто сервер проверяет попадания
-- Метки CollectionService: по ним клиент находит ловушки, чтобы их анимировать
HazardConfig.Tags = { Laser = "HazardLaser", Slam = "HazardSlam" }
-- «Коробка» персонажа вокруг HumanoidRootPart: попадание = эта коробка пересекла ловушку
HazardConfig.CharacterHalfSize = Vector3.new(1, 2.6, 1)

-- Лазерные планки: ездят по дорожкам туда-обратно. У каждого конца стоят и мигают — это сигнал,
-- что сейчас поедут. Перепрыгнуть можно: планки низко.
-- Общее для всех планок:
HazardConfig.Laser = {
	Damage = 25,
	HitCooldownSeconds = 1, -- один игрок получает урон от планки не чаще раза в столько секунд
	DwellSeconds = 1.2, -- стоит у конца и мигает перед следующим проездом
}
-- Каждая планка: размер (длинная сторона — поперёк дорожки), начало и конец дорожки, время проезда.
-- Планка без поворота: дорожка вдоль Z — планка длинная по X, дорожка вдоль X — длинная по Z
HazardConfig.Lasers = {
	{ Size = Vector3.new(40, 1, 1), TrackStart = Vector3.new(40, 2.5, -100), TrackEnd = Vector3.new(40, 2.5, 100), SweepSeconds = 6 },
	{ Size = Vector3.new(1, 1, 40), TrackStart = Vector3.new(20, 2.5, -65), TrackEnd = Vector3.new(105, 2.5, -65), SweepSeconds = 5 },
}

-- Плиты-«хлопушки»: каждые CycleSeconds бьют снизу. За WarnSeconds до удара подсвечиваются.
-- Соседние плиты бьют не одновременно (StaggerSeconds), чтобы было где пробежать.
HazardConfig.Slam = {
	Damage = 35,
	CycleSeconds = 4, -- от удара до удара у одной плиты
	WarnSeconds = 1, -- подсветка перед ударом
	StaggerSeconds = 1, -- плита N бьёт на (N − 1) × StaggerSeconds позже первой
	Size = Vector3.new(10, 0.4, 10),
	HitHeight = 6, -- удар достаёт до этой высоты над плитой
	Plates = {
		Vector3.new(35, 0, -25),
		Vector3.new(35, 0, 25),
		Vector3.new(62, 0, -30),
		Vector3.new(62, 0, 40),
		Vector3.new(85, 0, -80),
		Vector3.new(85, 0, 75),
	},
}

return deepFreeze(HazardConfig)
