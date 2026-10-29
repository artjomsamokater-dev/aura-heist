--!strict
-- Тесты RateLimiter (задача 2.5): спам запросами ничего не даёт.
-- Часы подставляем свои, чтобы проверять окна времени без ожидания.

local RateLimiter = require("../src/server/Security/RateLimiter")
local TestKit = require("./TestKit")

local test, equal = TestKit.test, TestKit.equal

-- Ненастоящие часы: время двигаем руками
local function makeClock()
	local now = 100
	return function(): number
		return now
	end, function(seconds: number)
		now += seconds
	end
end

local function countAllowed(limiter: RateLimiter.Limiter, key: any, attempts: number): number
	local allowed = 0
	for _ = 1, attempts do
		if limiter.Allow(key) then
			allowed += 1
		end
	end
	return allowed
end

print("RateLimiter")

test("спам 100 запросов за раз — проходят только первые 4", function()
	local clock = makeClock()
	local limiter = RateLimiter.new(4, 1, clock)
	equal(countAllowed(limiter, {}, 100), 4)
end)

test("после окна снова можно, но опять не больше лимита", function()
	local clock, advance = makeClock()
	local limiter = RateLimiter.new(4, 1, clock)
	local player = {}
	equal(countAllowed(limiter, player, 10), 4)
	advance(0.5)
	equal(countAllowed(limiter, player, 10), 0, "окно ещё не кончилось")
	advance(0.5)
	equal(countAllowed(limiter, player, 10), 4, "новое окно")
end)

test("игроки не мешают друг другу", function()
	local clock = makeClock()
	local limiter = RateLimiter.new(2, 1, clock)
	local alice, bob = {}, {}
	equal(countAllowed(limiter, alice, 50), 2)
	equal(countAllowed(limiter, bob, 50), 2)
end)

test("спам непрерывно 10 секунд: не больше лимита за каждую секунду", function()
	local clock, advance = makeClock()
	local limiter = RateLimiter.new(3, 1, clock)
	local player = {}
	local total = 0
	for _ = 1, 1000 do -- 1000 запросов, по 0.01 с между ними = 10 секунд
		if limiter.Allow(player) then
			total += 1
		end
		advance(0.01)
	end
	equal(total, 30)
end)

return nil
