--!strict
-- Тесты Rebirth (задача 5.6): цена растёт, доход растёт, доступен только при всех улучшениях и хватке Aura.

local RebirthMath = require("../src/shared/Util/RebirthMath")
local EconomyConfig = require("../src/shared/Config/EconomyConfig")
local TestKit = require("./TestKit")

local test, equal, near = TestKit.test, TestKit.equal, TestKit.near

local cfg = EconomyConfig.Rebirth

print("RebirthMath")

test("первый rebirth стоит BaseCost, каждый следующий дороже", function()
	equal(RebirthMath.Cost(0, cfg.BaseCost, cfg.CostGrowth), cfg.BaseCost)
	local previous = RebirthMath.Cost(0, cfg.BaseCost, cfg.CostGrowth)
	for n = 1, 5 do
		local cost = RebirthMath.Cost(n, cfg.BaseCost, cfg.CostGrowth)
		equal(cost > previous, true, "rebirth " .. n)
		previous = cost
	end
end)

test("цена — целое число", function()
	local cost = RebirthMath.Cost(3, 1000, 1.5)
	equal(cost, math.floor(cost))
	equal(cost, 3375)
end)

test("доход: +25% за каждый rebirth, без rebirth — как было", function()
	near(RebirthMath.IncomeMultiplier(0, cfg.IncomeBonusPercent), 1)
	near(RebirthMath.IncomeMultiplier(1, 25), 1.25)
	near(RebirthMath.IncomeMultiplier(4, 25), 2)
end)

test("rebirth только когда всё куплено и Aura хватает", function()
	equal(RebirthMath.CanRebirth(true, 50000, 50000), true)
	equal(RebirthMath.CanRebirth(true, 49999, 50000), false, "не хватает Aura")
	equal(RebirthMath.CanRebirth(false, 999999, 50000), false, "куплено не всё")
end)

return nil
