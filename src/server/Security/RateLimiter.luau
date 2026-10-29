--!strict
-- RateLimiter: «не больше N запросов за T секунд» отдельно для каждого игрока.
-- Пример: local limiter = RateLimiter.new(4, 1); if not limiter.Allow(player) then return end
-- Модуль без Roblox-зависимостей: его проверяют тесты в tests/RateLimiter.spec.luau.

local RateLimiter = {}

type Window = {
	startedAt: number,
	count: number,
}

export type Limiter = {
	Allow: (key: any) -> boolean, -- key — обычно Player
}

-- clock — откуда брать время; по умолчанию os.clock (тесты подставляют свои часы)
function RateLimiter.new(maxRequests: number, windowSeconds: number, clock: (() -> number)?): Limiter
	local getTime = clock or os.clock
	-- Слабые ключи: когда игрок вышел и объект Player удалён, запись исчезает сама
	local windows: { [any]: Window } = setmetatable({}, { __mode = "k" }) :: any

	local function allow(key: any): boolean
		local now = getTime()
		local window = windows[key]
		if window == nil or now - window.startedAt >= windowSeconds then
			windows[key] = { startedAt = now, count = 1 }
			return true
		end
		if window.count >= maxRequests then
			return false
		end
		window.count += 1
		return true
	end

	return { Allow = allow }
end

return RateLimiter
