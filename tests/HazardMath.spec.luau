--!strict
-- Тесты ловушек (задача 3.4): сигнал перед каждым ударом, удар один раз за цикл, попадание по коробке.
-- HazardConfig здесь не загрузить (в нём Vector3, которого нет в консольном luau), поэтому числа
-- взяты как в нём; правила самого конфига (урон < здоровья, сигнал ≥ 1 с) проверяет сервер при старте.

local HazardMath = require("../src/shared/Util/HazardMath")
local TestKit = require("./TestKit")

local test, equal, near = TestKit.test, TestKit.equal, TestKit.near

local LASER = { SweepSeconds = 4, DwellSeconds = 1.2 } -- как HazardConfig.Laser
local SLAM = { CycleSeconds = 4, WarnSeconds = 1, StaggerSeconds = 1 } -- как HazardConfig.Slam

print("HazardMath")

test("лазер: едет от начала к концу, стоит и мигает, едет обратно", function()
	local sweep, dwell = 4, 1
	near((HazardMath.Laser(0, sweep, dwell)), 0)
	near((HazardMath.Laser(2, sweep, dwell)), 0.5)
	local u, blinking = HazardMath.Laser(4.5, sweep, dwell)
	near(u, 1)
	equal(blinking, true, "у конца мигает")
	near((HazardMath.Laser(7, sweep, dwell)), 0.5) -- обратно: 2 с после паузы
	local u2, blinking2 = HazardMath.Laser(9.5, sweep, dwell)
	near(u2, 0)
	equal(blinking2, true, "у начала мигает")
	near((HazardMath.Laser(10 + 2, sweep, dwell)), 0.5) -- новый цикл
end)

test("лазер: перед каждым проездом мигает ровно DwellSeconds", function()
	local cfg = LASER
	local blinkTime = 0
	local step = 0.01
	local cycle = 2 * (cfg.SweepSeconds + cfg.DwellSeconds)
	for i = 0, math.floor(cycle / step) - 1 do
		local _, blinking = HazardMath.Laser(i * step, cfg.SweepSeconds, cfg.DwellSeconds)
		if blinking then
			blinkTime += step
		end
	end
	near(math.floor(blinkTime * 10 + 0.5) / 10, 2 * cfg.DwellSeconds) -- две паузы за цикл
end)

test("плита: предупреждение горит последние WarnSeconds перед каждым ударом", function()
	local cycle, warn = 4, 1
	local index0, warn0 = HazardMath.Slam(0.5, cycle, warn, 0)
	equal(index0, 0)
	equal(warn0, false)
	local _, warnLate = HazardMath.Slam(3.2, cycle, warn, 0)
	equal(warnLate, true, "за 0,8 с до удара горит")
	local _, warnEdge = HazardMath.Slam(2.99, cycle, warn, 0)
	equal(warnEdge, false, "за 1,01 с до удара ещё не горит")
	local index1, warn1 = HazardMath.Slam(4.01, cycle, warn, 0)
	equal(index1, 1, "на 4-й секунде случился удар — номер цикла вырос")
	equal(warn1, false, "после удара подсветка гаснет")
end)

test("плита: за 10 секунд ровно 2 удара (номер цикла растёт по одному)", function()
	local strikes = 0
	local last = HazardMath.Slam(0, 4, 1, 0)
	for i = 1, 1000 do
		local index = HazardMath.Slam(i * 0.01, 4, 1, 0)
		if index > last then
			strikes += 1
			equal(index, last + 1, "удар не пропускается и не повторяется")
			last = index
		end
	end
	equal(strikes, 2)
end)

test("плиты бьют по очереди: сдвиг StaggerSeconds", function()
	local cfg = SLAM
	local first = HazardMath.Slam(cfg.CycleSeconds - 0.01, cfg.CycleSeconds, cfg.WarnSeconds, 0)
	local second = HazardMath.Slam(cfg.CycleSeconds + 0.01, cfg.CycleSeconds, cfg.WarnSeconds, cfg.StaggerSeconds)
	equal(first, 0)
	equal(second, 0, "вторая плита ещё не ударила, когда ударила первая")
end)

test("попадание по коробке: внутри — да, рядом — нет", function()
	equal(HazardMath.InBox(0, 0, 0, 1, 1, 1), true)
	equal(HazardMath.InBox(1, -1, 0.5, 1, 1, 1), true, "на границе считается")
	equal(HazardMath.InBox(1.01, 0, 0, 1, 1, 1), false)
	equal(HazardMath.InBox(0, 5, 0, 1, 2.6, 1), false, "перепрыгнул")
end)

return nil
