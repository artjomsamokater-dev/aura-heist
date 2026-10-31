--!strict
-- GiantRoute: как Giant Object едет по маршруту. Чистые функции без Roblox (маршрут — точки x/z по полу),
-- их проверяют тесты в tests/GiantRoute.spec.luau.

local GiantRoute = {}

export type Point = { X: number, Z: number }

-- Длина каждого отрезка маршрута
function GiantRoute.SegmentLengths(points: { Point }): { number }
	local lengths = {}
	for i = 1, #points - 1 do
		local dx, dz = points[i + 1].X - points[i].X, points[i + 1].Z - points[i].Z
		table.insert(lengths, math.sqrt(dx * dx + dz * dz))
	end
	return lengths
end

-- Сколько секунд едет каждый отрезок при скорости speed (студов в секунду)
function GiantRoute.SegmentDurations(points: { Point }, speed: number): { number }
	local durations = {}
	for _, length in ipairs(GiantRoute.SegmentLengths(points)) do
		table.insert(durations, length / speed)
	end
	return durations
end

function GiantRoute.TotalSeconds(points: { Point }, speed: number): number
	local total = 0
	for _, seconds in ipairs(GiantRoute.SegmentDurations(points, speed)) do
		total += seconds
	end
	return total
end

-- На сколько радиан повернётся колесо радиуса radius, проехав distance (катится без проскальзывания)
function GiantRoute.RollAngle(distance: number, radius: number): number
	return distance / radius
end

-- Запускать ли событие: только если в зоне есть хотя бы один игрок
function GiantRoute.ShouldStart(playersInZone: number): boolean
	return playersInZone > 0
end

return GiantRoute
