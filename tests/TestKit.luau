--!strict
-- TestKit: крошечный набор для тестов чистой логики (без Roblox).
-- Тесты запускает консольный luau из scripts/check.ps1: luau tests/run.luau

local TestKit = {}

local passed = 0
local failed = 0

local function describe(value: any): string
	return if type(value) == "string" then string.format("%q", value) else tostring(value)
end

-- Один тест: название и функция; ошибка внутри функции = тест провален
function TestKit.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  ok    " .. name)
	else
		failed += 1
		print("  FAIL  " .. name .. "\n        " .. tostring(err))
	end
end

function TestKit.equal(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(string.format("%sожидали %s, получили %s", if message then message .. ": " else "", describe(expected), describe(actual)), 2)
	end
end

-- Сравнение дробных чисел с допуском
function TestKit.near(actual: number, expected: number, message: string?)
	if math.abs(actual - expected) > 1e-6 then
		error(string.format("%sожидали %s, получили %s", if message then message .. ": " else "", tostring(expected), tostring(actual)), 2)
	end
end

-- Итог: сколько прошло и провалилось. Вернёт true, если всё прошло
function TestKit.summary(): boolean
	print(string.format("Тесты: прошло %d, провалено %d", passed, failed))
	return failed == 0
end

return TestKit
