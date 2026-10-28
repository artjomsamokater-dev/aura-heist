--!strict
-- RateLimiter: «не больше N запросов за T секунд» отдельно для каждого игрока.
-- Пример: local limiter = RateLimiter.new(4, 1); if not limiter.Allow(player) then return end

local RateLimiter = {}

type Window = {
	startedAt: number,
	count: number,
}

export type Limiter = {
	Allow: (player: Player) -> boolean,
}

function RateLimiter.new(maxRequests: number, windowSeconds: number): Limiter
	-- Слабые ключи: когда игрок вышел и объект Player удалён, запись исчезает сама
	local windows: { [Player]: Window } = setmetatable({}, { __mode = "k" }) :: any

	local function allow(player: Player): boolean
		local now = os.clock()
		local window = windows[player]
		if window == nil or now - window.startedAt >= windowSeconds then
			windows[player] = { startedAt = now, count = 1 }
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
