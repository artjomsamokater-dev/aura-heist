--!strict
-- Запуск всех тестов чистой логики: luau tests/run.luau (это делает scripts/check.ps1).
-- Провален хоть один тест — скрипт падает с ошибкой, и проверка не проходит.

local TestKit = require("./TestKit")

require("./PedestalMath.spec")
require("./RateLimiter.spec")
require("./RarityRoll.spec")
require("./CarrySpeed.spec")

if not TestKit.summary() then
	error("есть проваленные тесты")
end
