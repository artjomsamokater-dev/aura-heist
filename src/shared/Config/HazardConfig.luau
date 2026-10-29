--!strict
-- HazardConfig: ловушки в опасной части зоны — урон, тайминги, места.
-- Позиции — смещения от центра верхней грани пола зоны (X на восток, Z на юг).
-- Опасная часть начинается с MapConfig.Zone.DangerFromX = 10; площадка EXTRACT — на X = 60, радиус 12.
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

-- Лазерная планка: ездит по дорожке туда-обратно. У каждого конца стоит и мигает — это сигнал,
-- что сейчас поедет. Перепрыгнуть можно: планка низко.
HazardConfig.Laser = {
	Damage = 25,
	HitCooldownSeconds = 1, -- один игрок получает урон от планки не чаще раза в столько секунд
	SweepSeconds = 4, -- проезд от одного конца дорожки до другого
	DwellSeconds = 1.2, -- стоит у конца и мигает перед следующим проездом
	Size = Vector3.new(32, 1, 1), -- планка лежит поперёк дорожки (вдоль X)
	TrackStart = Vector3.new(30, 2.5, -55), -- центр планки в начале дорожки
	TrackEnd = Vector3.new(30, 2.5, 55), -- центр планки в конце дорожки
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
		Vector3.new(28, 0, -18),
		Vector3.new(28, 0, 18),
		Vector3.new(45, 0, -45),
		Vector3.new(45, 0, 45),
	},
}

return deepFreeze(HazardConfig)
