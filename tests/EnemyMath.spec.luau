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

test("расстояние по полу без высоты", function()
	near(EnemyMath.FlatDistance(0, 0, 3, 4), 5)
end)

return nil
