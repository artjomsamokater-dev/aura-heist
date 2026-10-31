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

return nil
