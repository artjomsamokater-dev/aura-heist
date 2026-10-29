--!strict
-- HazardMath: где ловушка и когда она бьёт — по времени сервера. Чистые функции без Roblox.
-- Сервер считает по ним урон, клиент — картинку; время у обоих общее (GetServerTimeNow),
-- поэтому планка и подсветка у всех игроков одинаковые. Проверяется тестами в tests/HazardMath.spec.luau.

local HazardMath = {}

-- Лазер: проезд туда → стоит у конца и мигает → проезд обратно → стоит у начала и мигает.
-- Вернёт долю пути от начала дорожки (0..1) и мигает ли сейчас (стоит у конца).
function HazardMath.Laser(t: number, sweepSeconds: number, dwellSeconds: number): (number, boolean)
	local cycle = 2 * (sweepSeconds + dwellSeconds)
	local phase = t % cycle
	if phase < sweepSeconds then
		return phase / sweepSeconds, false
	elseif phase < sweepSeconds + dwellSeconds then
		return 1, true
	elseif phase < 2 * sweepSeconds + dwellSeconds then
		return 1 - (phase - sweepSeconds - dwellSeconds) / sweepSeconds, false
	end
	return 0, true
end

-- Плита: номер текущего цикла и горит ли предупреждение.
-- Удар случается в момент, когда номер цикла увеличивается; предупреждение — последние warnSeconds цикла.
function HazardMath.Slam(t: number, cycleSeconds: number, warnSeconds: number, offsetSeconds: number): (number, boolean)
	local localTime = t - offsetSeconds
	local index = math.floor(localTime / cycleSeconds)
	local phase = localTime - index * cycleSeconds
	return index, phase >= cycleSeconds - warnSeconds
end

-- Точка (в координатах коробки, центр коробки = 0) внутри коробки с такими половинами размеров
function HazardMath.InBox(x: number, y: number, z: number, halfX: number, halfY: number, halfZ: number): boolean
	return math.abs(x) <= halfX and math.abs(y) <= halfY and math.abs(z) <= halfZ
end

return HazardMath
