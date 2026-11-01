--!strict
-- FallRule: мягкий возврат после падения (задача 7.5). Чистые функции — их проверяют тесты.
--   • упал — корень персонажа ниже высоты «ловушки» (в хабе — MapConfig.FallRescue.SeaCatchY,
--     в зоне — пол зоны минус FallLimitStuds);
--   • куда вернуть — ближайшая по полу (X, Z) точка из списка: в хабе — дорожки у мостиков и входы
--     участков, в зоне — точки спавна и вход.

local FallRule = {}

export type Point = { X: number, Z: number }

function FallRule.Fallen(rootY: number, catchY: number): boolean
	return rootY < catchY
end

-- Номер ближайшей точки (по полу); пустой список — nil
function FallRule.NearestIndex(x: number, z: number, points: { Point }): number?
	local best: number? = nil
	local bestDistance = math.huge
	for i, point in ipairs(points) do
		local dx, dz = point.X - x, point.Z - z
		local distance = dx * dx + dz * dz
		if distance < bestDistance then
			best, bestDistance = i, distance
		end
	end
	return best
end

return FallRule
