--!strict
-- SecurityConfig: пределы для проверок запросов игрока (RemoteGuard, RateLimiter).

-- table.freeze замораживает только верхний уровень, поэтому замораживаем всё дерево
local function deepFreeze<T>(t: T): T
	for _, value in t :: any do
		if type(value) == "table" and not table.isfrozen(value) then
			deepFreeze(value)
		end
	end
	return table.freeze(t :: any) :: any
end

local SecurityConfig = {}

SecurityConfig.MaxIdLength = 32 -- ID длиннее этого — точно мусор
SecurityConfig.DistanceToleranceStuds = 2 -- запас к дистанциям из ZoneConfig на задержку сети

-- Не больше MaxRequests запросов за WindowSeconds секунд на одного игрока
SecurityConfig.RateLimits = {
	Pickup = { MaxRequests = 4, WindowSeconds = 1 },
}

return deepFreeze(SecurityConfig)
