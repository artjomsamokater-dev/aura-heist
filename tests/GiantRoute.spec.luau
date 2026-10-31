--!strict
-- Тесты Giant Object (задача 4.4): маршрут и время, качение, запуск только при игроках в зоне.
-- Маршрут — как в EventConfig.GiantObject.Route (там Vector3, которого нет в консольном luau).

local GiantRoute = require("../src/shared/Util/GiantRoute")
local TestKit = require("./TestKit")

local test, equal, near = TestKit.test, TestKit.equal, TestKit.near

local ROUTE = { { X = 34, Z = -72 }, { X = 34, Z = 22 }, { X = 74, Z = 22 } }
local SPEED = 20

print("GiantRoute")

test("длины отрезков маршрута", function()
	local lengths = GiantRoute.SegmentLengths(ROUTE)
	equal(#lengths, 2)
	near(lengths[1], 94)
	near(lengths[2], 40)
end)

test("время отрезков и всего маршрута при скорости 20", function()
	local durations = GiantRoute.SegmentDurations(ROUTE, SPEED)
	near(durations[1], 4.7)
	near(durations[2], 2)
	near(GiantRoute.TotalSeconds(ROUTE, SPEED), 6.7)
end)

test("колесо катится: за длину окружности — ровно один оборот", function()
	local radius = 5
	near(GiantRoute.RollAngle(2 * math.pi * radius, radius), 2 * math.pi)
	near(GiantRoute.RollAngle(0, radius), 0)
end)

test("без игроков в зоне событие не запускается", function()
	equal(GiantRoute.ShouldStart(0), false)
	equal(GiantRoute.ShouldStart(1), true)
end)

return nil
