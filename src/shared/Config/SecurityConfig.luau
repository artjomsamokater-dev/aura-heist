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
SecurityConfig.DistanceToleranceStuds = 2 -- запас к дистанциям из Config на задержку сети

-- Не больше MaxRequests запросов за WindowSeconds секунд на одного игрока
SecurityConfig.RateLimits = {
	Pickup = { MaxRequests = 4, WindowSeconds = 1 },
	Collect = { MaxRequests = 4, WindowSeconds = 1 },
	Buy = { MaxRequests = 3, WindowSeconds = 1 },
	Sell = { MaxRequests = 2, WindowSeconds = 1 },
	-- Общий лимит на ЛЮБЫЕ кнопки одного игрока вместе (RemoteGuard.ConnectPrompt)
	AnyAction = { MaxRequests = 8, WindowSeconds = 1 },
}

-- Предупреждение о спаме в Output — не чаще раза в столько секунд на игрока
SecurityConfig.SpamWarnSeconds = 10

-- После покупки улучшения следующая покупка у этого игрока ждёт столько секунд:
-- быстрый двойной клик не купит два уровня подряд
SecurityConfig.PurchaseCooldownSeconds = 1

return deepFreeze(SecurityConfig)
