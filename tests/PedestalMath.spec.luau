--!strict
-- Тесты накопления Aura на постаменте и офлайн-дохода (задача 2.4).
-- Числа как в стартовом балансе: Common 1 Aura/с, Legendary 60 Aura/с, хранилище 120 с, ×2 после улучшения.

local PedestalMath = require("../src/shared/Util/PedestalMath")
local TestKit = require("./TestKit")

local test, equal, near = TestKit.test, TestKit.equal, TestKit.near

local COMMON = 1
local LEGENDARY = 60
local STORAGE = 120
local STORAGE_X2 = 240
local T0 = 1_800_000_000 -- какое-то время сервера (секунды Unix)

print("PedestalMath")

test("копит доход × время, пока не дошёл до лимита", function()
	near(PedestalMath.GetStored(COMMON, T0, T0 + 30.5, STORAGE), 30.5)
	near(PedestalMath.GetStored(LEGENDARY, T0, T0 + 10, STORAGE), 600)
end)

test("офлайн 10 минут: Common не больше лимита хранилища (120)", function()
	equal(PedestalMath.GetStored(COMMON, T0, T0 + 600, STORAGE), 120)
end)

test("офлайн 10 минут: Legendary не больше лимита (60 × 120 = 7200)", function()
	equal(PedestalMath.GetStored(LEGENDARY, T0, T0 + 600, STORAGE), 7200)
end)

test("офлайн сутки: всё равно не больше лимита", function()
	equal(PedestalMath.GetStored(COMMON, T0, T0 + 86400, STORAGE), 120)
end)

test("хранилище ×2: лимит 240 секунд дохода", function()
	equal(PedestalMath.GetStored(COMMON, T0, T0 + 600, STORAGE_X2), 240)
	near(PedestalMath.GetStored(COMMON, T0, T0 + 200, STORAGE_X2), 200)
end)

test("время «назад» (часы другого сервера) — ноль, не минус", function()
	equal(PedestalMath.GetStored(COMMON, T0, T0 - 50, STORAGE), 0)
end)

test("доход 0 (неизвестный мемлинг) — ноль", function()
	equal(PedestalMath.GetStored(0, T0, T0 + 600, STORAGE), 0)
end)

test("сбор: начисляет целое, дробный остаток копится дальше", function()
	local amount, newLast = PedestalMath.Collect(COMMON, T0, T0 + 30.5, STORAGE)
	equal(amount, 30)
	near(newLast, T0 + 30) -- остались 0.5 Aura = 0.5 секунды дохода
	near(PedestalMath.GetStored(COMMON, newLast, T0 + 30.5, STORAGE), 0.5)
end)

test("сбор меньше 1 Aura — ничего не начисляет и не сдвигает lastCollect", function()
	local amount, newLast = PedestalMath.Collect(COMMON, T0, T0 + 0.7, STORAGE)
	equal(amount, 0)
	equal(newLast, T0)
end)

test("сбор после офлайна: ровно лимит, отсчёт с нуля", function()
	local amount, newLast = PedestalMath.Collect(COMMON, T0, T0 + 600, STORAGE)
	equal(amount, 120)
	near(newLast, T0 + 600)
	equal(PedestalMath.GetStored(COMMON, newLast, T0 + 600, STORAGE), 0)
end)

test("повторный сбор сразу после сбора ничего не даёт", function()
	local _, newLast = PedestalMath.Collect(LEGENDARY, T0, T0 + 50, STORAGE)
	local again = PedestalMath.Collect(LEGENDARY, newLast, T0 + 50, STORAGE)
	equal(again, 0)
end)

return nil
