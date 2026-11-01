--!strict
-- Тесты входа в портал: решение по касанию и «стоит ли игрок в портале».

local PortalRule = require("../src/shared/Util/PortalRule")
local TestKit = require("./TestKit")

local test, equal = TestKit.test, TestKit.equal

-- Половина размера портала из MapConfig.Portal.Size (10, 12, 2); MapConfig здесь не загрузить (Vector3)
local function inside(x: number, y: number, z: number): boolean
	return PortalRule.IsInside(x, y, z, 5, 6, 1, 1)
end

print("PortalRule")

test("в хабе, профиль загружен, жив, не на паузе, доступ есть — пускаем", function()
	equal(PortalRule.Decide(false, true, true, true, true), "ok")
end)

test("каждая причина отказа называется своим ключом", function()
	equal(PortalRule.Decide(true, true, true, true, true), "busy")
	equal(PortalRule.Decide(false, false, true, true, true), "notInHub")
	equal(PortalRule.Decide(false, true, false, true, true), "noProfile")
	equal(PortalRule.Decide(false, true, true, false, true), "dead")
	equal(PortalRule.Decide(false, true, true, true, false), "noAccess")
end)

test("игрок в середине портала — внутри; рядом с ним — нет", function()
	equal(inside(0, -3, 0), true)
	equal(inside(4.5, 0, 1.8), true, "запас 1 студ по толщине")
	equal(inside(0, 0, 3), false)
	equal(inside(7, 0, 0), false)
end)

return nil
