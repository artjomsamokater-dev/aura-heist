--!strict
-- Тесты границ врага (задача 3.5): враг не выходит из опасной части.

local EnemyMath = require("../src/shared/Util/EnemyMath")
local TestKit = require("./TestKit")

local test, equal, near = TestKit.test, TestKit.equal, TestKit.near

-- Опасная часть зоны: X от 514 до 576, Z от −76 до 76 (центр зоны X = 500, граница +10, отступ 4)
local MIN_X, MAX_X, MIN_Z, MAX_Z = 514, 576, -76, 76

print("EnemyMath")

test("цель внутри опасной части — идёт прямо к ней", function()
	local x, z = EnemyMath.ClampToArea(540, 10, MIN_X, MAX_X, MIN_Z, MAX_Z)
	equal(x, 540)
	equal(z, 10)
end)

test("цель убежала в безопасную часть — враг останавливается у границы", function()
	local x, z = EnemyMath.ClampToArea(460, 20, MIN_X, MAX_X, MIN_Z, MAX_Z)
	equal(x, MIN_X)
	equal(z, 20)
	equal(EnemyMath.IsInArea(460, 20, MIN_X, MAX_X, MIN_Z, MAX_Z), false)
end)

test("у стен зоны — не ближе отступа", function()
	local x, z = EnemyMath.ClampToArea(600, -100, MIN_X, MAX_X, MIN_Z, MAX_Z)
	equal(x, MAX_X)
	equal(z, MIN_Z)
end)

test("вокруг EXTRACT: цель внутри круга — враг идёт только к его краю", function()
	-- EXTRACT в (590, 0), круг 20; игрок стоит на площадке в (592, 1)
	local x, z = EnemyMath.PushOutOfCircle(592, 1, 590, 0, 20, 560, 0)
	near(EnemyMath.FlatDistance(x, z, 590, 0), 20)
	equal(EnemyMath.FlatDistance(x, z, 592, 1) >= 20 - 12, true, "до игрока на площадке враг не достаёт")
end)

test("вокруг EXTRACT: цель снаружи круга не трогаем", function()
	local x, z = EnemyMath.PushOutOfCircle(540, 30, 590, 0, 20, 530, 0)
	equal(x, 540)
	equal(z, 30)
end)

test("вокруг EXTRACT: цель ровно в центре — на край со стороны врага", function()
	local x, z = EnemyMath.PushOutOfCircle(590, 0, 590, 0, 20, 550, 0)
	near(x, 570)
	near(z, 0)
end)

test("расстояние по полу без высоты", function()
	near(EnemyMath.FlatDistance(0, 0, 3, 4), 5)
end)

-- Как в EnemyConfig.Chaser (EnemyConfig здесь не загрузить: в нём Vector3)
local AGGRO, LEASH = 45, 70

test("охрана: подбор рядом с врагом — агро", function()
	local distance = EnemyMath.FlatDistance(540, 0, 560, 15) -- 25 студов
	equal(EnemyMath.ShouldAggro(distance, AGGRO, true, false), true)
end)

test("охрана: подбор далеко от врага — нет агро", function()
	local distance = EnemyMath.FlatDistance(540, 0, 600, 40) -- ~72 студа
	equal(EnemyMath.ShouldAggro(distance, AGGRO, true, false), false)
end)

test("охрана: рядом, но в безопасной части или у EXTRACT — нет агро", function()
	equal(EnemyMath.ShouldAggro(10, AGGRO, false, false), false)
	equal(EnemyMath.ShouldAggro(10, AGGRO, true, true), false)
end)

test("погоня прекращается: дальше поводка, в безопасной части, у EXTRACT", function()
	equal(EnemyMath.ChaseBlock(30, LEASH, true, false), nil)
	equal(EnemyMath.ChaseBlock(80, LEASH, true, false), "leash")
	equal(EnemyMath.ChaseBlock(30, LEASH, false, false), "safe")
	equal(EnemyMath.ChaseBlock(30, LEASH, true, true), "extract")
end)

test("точка патруля — не дальше радиуса от дома", function()
	for i = 0, 7 do
		local x, z = EnemyMath.PatrolPoint(540, 0, 20, i * math.pi / 4, 1.5)
		equal(EnemyMath.FlatDistance(x, z, 540, 0) <= 20 + 1e-9, true)
	end
	local x, z = EnemyMath.PatrolPoint(540, 0, 20, 0, 0.5)
	near(x, 550)
	near(z, 0)
end)

return nil
