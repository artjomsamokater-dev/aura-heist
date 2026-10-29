--!strict
-- EnemyMath: где враг может ходить. Чистые функции без Roblox — их проверяют тесты.
-- Враг живёт только в прямоугольнике опасной части (minX..maxX, minZ..maxZ по полу зоны).

local EnemyMath = {}

-- Ближайшая к (x, z) точка внутри прямоугольника: туда враг и пойдёт, если цель за его краем
function EnemyMath.ClampToArea(x: number, z: number, minX: number, maxX: number, minZ: number, maxZ: number): (number, number)
	return math.clamp(x, minX, maxX), math.clamp(z, minZ, maxZ)
end

function EnemyMath.IsInArea(x: number, z: number, minX: number, maxX: number, minZ: number, maxZ: number): boolean
	return x >= minX and x <= maxX and z >= minZ and z <= maxZ
end

-- Расстояние по полу (высоту не считаем)
function EnemyMath.FlatDistance(ax: number, az: number, bx: number, bz: number): number
	local dx, dz = ax - bx, az - bz
	return math.sqrt(dx * dx + dz * dz)
end

return EnemyMath
