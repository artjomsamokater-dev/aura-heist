--!strict
-- ExtractionRule: правила точек эвакуации (задача 6.0). Чистые функции — их проверяют тесты.
-- Основной EXTRACT доступен всегда; вторая точка у входа — только без редкостей из BlockedRarities в руках.

local ExtractionRule = {}

export type Point = {
	X: number,
	Z: number,
	Allowed: boolean,
}

-- Можно ли эвакуироваться через вторую точку с такими редкостями в руках
function ExtractionRule.SideAllowed(blockedRarities: { string }, carriedRarities: { string }): boolean
	for _, rarity in ipairs(carriedRarities) do
		if table.find(blockedRarities, rarity) then
			return false
		end
	end
	return true
end

-- Номер ближайшей доступной точки (по полу) или nil, если доступных нет
function ExtractionRule.Nearest(points: { Point }, x: number, z: number): number?
	local best: number? = nil
	local bestDistance = math.huge
	for i, point in ipairs(points) do
		if point.Allowed then
			local dx, dz = point.X - x, point.Z - z
			local distance = dx * dx + dz * dz
			if distance < bestDistance then
				best, bestDistance = i, distance
			end
		end
	end
	return best
end

return ExtractionRule
