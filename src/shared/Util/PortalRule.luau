--!strict
-- PortalRule: можно ли войти в портал и стоит ли игрок в нём. Чистые функции — их проверяют тесты.
-- Причины отказа — короткие ключи; текст для Output по-русски — в сервисе Raid.

local PortalRule = {}

export type Decision = "ok" | "busy" | "notInHub" | "noProfile" | "dead"

-- Решение по одному касанию: порядок проверок как в Raid (сначала дешёвые)
function PortalRule.Decide(busy: boolean, inHub: boolean, hasProfile: boolean, alive: boolean): Decision
	if busy then
		return "busy"
	end
	if not inHub then
		return "notInHub"
	end
	if not hasProfile then
		return "noProfile"
	end
	if not alive then
		return "dead"
	end
	return "ok"
end

-- Стоит ли точка (x, y, z в системе координат портала) внутри «коробки» портала
-- (половины размера hx, hy, hz) с запасом margin по каждой оси
function PortalRule.IsInside(x: number, y: number, z: number, hx: number, hy: number, hz: number, margin: number): boolean
	return math.abs(x) <= hx + margin and math.abs(y) <= hy + margin and math.abs(z) <= hz + margin
end

return PortalRule
