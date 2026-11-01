--!strict
-- Тесты второй точки эвакуации (задача 6.0) на числах из ZoneConfig.

local ExtractionRule = require("../src/shared/Util/ExtractionRule")
local ZoneConfig = require("../src/shared/Config/ZoneConfig")
local TestKit = require("./TestKit")

local test, equal = TestKit.test, TestKit.equal

local BLOCKED = ZoneConfig.SideEvacuation.BlockedRarities

print("ExtractionRule")

test("вторая точка: 8 секунд против 3 у основной", function()
	equal(ZoneConfig.SideEvacuation.Seconds, 8)
	equal(ZoneConfig.EvacuationSeconds, 3)
end)

test("пустые руки, Common и Rare — можно через вторую точку", function()
	equal(ExtractionRule.SideAllowed(BLOCKED, {}), true)
	equal(ExtractionRule.SideAllowed(BLOCKED, { "Common", "Rare" }), true)
end)

test("хоть один Epic или Legendary в руках — нельзя", function()
	equal(ExtractionRule.SideAllowed(BLOCKED, { "Common", "Epic" }), false)
	equal(ExtractionRule.SideAllowed(BLOCKED, { "Legendary" }), false)
end)

test("ближайшая доступная точка", function()
	local points = {
		{ X = 90, Z = 0, Allowed = true }, -- основной EXTRACT
		{ X = -95, Z = -28, Allowed = true }, -- у входа
	}
	equal(ExtractionRule.Nearest(points, -80, 0), 2)
	equal(ExtractionRule.Nearest(points, 50, 0), 1)
	points[2].Allowed = false
	equal(ExtractionRule.Nearest(points, -80, 0), 1, "вторая закрыта — к основной")
	points[1].Allowed = false
	equal(ExtractionRule.Nearest(points, 0, 0), nil)
end)

return nil
