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

-- Запретный круг (вокруг EXTRACT): точку внутри выталкиваем на его край, снаружи — оставляем.
-- Точку ровно в центре выталкиваем в сторону from (откуда идёт враг), чтобы направление было понятно
function EnemyMath.PushOutOfCircle(
	x: number,
	z: number,
	centerX: number,
	centerZ: number,
	radius: number,
	fromX: number,
	fromZ: number
): (number, number)
	local dx, dz = x - centerX, z - centerZ
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance >= radius then
		return x, z
	end
	if distance < 1e-6 then
		dx, dz = fromX - centerX, fromZ - centerZ
		distance = math.sqrt(dx * dx + dz * dz)
		if distance < 1e-6 then
			dx, dz, distance = -1, 0, 1 -- совсем в центре: на запад
		end
	end
	return centerX + dx / distance * radius, centerZ + dz / distance * radius
end

-- Расстояние по полу (высоту не считаем)
function EnemyMath.FlatDistance(ax: number, az: number, bx: number, bz: number): number
	local dx, dz = ax - bx, az - bz
	return math.sqrt(dx * dx + dz * dz)
end

-- Почему погоня невозможна или прекращается: nil — можно гнаться
export type DropReason = "leash" | "safe" | "extract"

-- Можно ли гнаться за игроком: он не дальше leash от врага, стоит в опасной части и не у EXTRACT
function EnemyMath.ChaseBlock(distance: number, leash: number, targetInDanger: boolean, targetAtExtract: boolean): DropReason?
	if not targetInDanger then
		return "safe"
	end
	if targetAtExtract then
		return "extract"
	end
	if distance > leash then
		return "leash"
	end
	return nil
end

-- Охрана: игрок подобрал мемлинга. Враг ближе aggroRadius сразу гонится — если погоня вообще возможна
function EnemyMath.ShouldAggro(distance: number, aggroRadius: number, targetInDanger: boolean, targetAtExtract: boolean): boolean
	return distance <= aggroRadius and EnemyMath.ChaseBlock(distance, aggroRadius, targetInDanger, targetAtExtract) == nil
end

-- Точка патруля около дома: угол (радианы) и доля радиуса 0..1 — случайные, их передаёт сервис
function EnemyMath.PatrolPoint(homeX: number, homeZ: number, radius: number, angle: number, fraction: number): (number, number)
	local distance = radius * math.clamp(fraction, 0, 1)
	return homeX + math.cos(angle) * distance, homeZ + math.sin(angle) * distance
end

return EnemyMath
