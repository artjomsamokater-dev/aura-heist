--!strict
-- CarrySpeed: скорость шага с мемлингами в руках. Чистая функция — её проверяют тесты.
-- Скорость = самая низкая из скоростей переноски редкостей в руках (MemelingConfig.Rarities[].CarrySpeed),
-- но никогда не быстрее обычной скорости персонажа. Пустые руки — обычная скорость.

local CarrySpeed = {}

function CarrySpeed.Compute(baseSpeed: number, carrySpeeds: { number }): number
	local speed = baseSpeed
	for _, carrySpeed in ipairs(carrySpeeds) do
		speed = math.min(speed, carrySpeed)
	end
	return speed
end

return CarrySpeed
