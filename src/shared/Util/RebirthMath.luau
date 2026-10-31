--!strict
-- RebirthMath: формулы Rebirth. Чистые функции без Roblox — их проверяют тесты в tests/RebirthMath.spec.luau.
-- Числа — из EconomyConfig.Rebirth (сюда передаются аргументами).

local RebirthMath = {}

-- Цена следующего rebirth, если уже сделано rebirths: baseCost × growth ^ rebirths (целое)
function RebirthMath.Cost(rebirths: number, baseCost: number, growth: number): number
	return math.floor(baseCost * growth ^ rebirths)
end

-- Во сколько раз доход постаментов выше после rebirths: 1 + rebirths × процент / 100
function RebirthMath.IncomeMultiplier(rebirths: number, bonusPercent: number): number
	return 1 + rebirths * bonusPercent / 100
end

-- Можно ли сделать rebirth: все улучшения на максимуме и Aura хватает
function RebirthMath.CanRebirth(allMaxed: boolean, bankedAura: number, cost: number): boolean
	return allMaxed and bankedAura >= cost
end

return RebirthMath
