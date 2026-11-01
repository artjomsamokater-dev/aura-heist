--!strict
-- ZoneRule: правила зон вылазок (задача 7.2). Чистые функции — их проверяют тесты.

local ZoneRule = {}

-- Id мемлингов зоны zoneId нужной редкости, по алфавиту (порядок не зависит от словаря)
function ZoneRule.MemelingsOf(memelings: { [string]: { Rarity: string, Zone: string } }, zoneId: string, rarity: string): { string }
	local ids = {}
	for id, memeling in memelings do
		if memeling.Zone == zoneId and memeling.Rarity == rarity then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

-- Можно ли войти: зона бесплатная (accessCost = nil) или доступ куплен (owned[zoneId] = true)
function ZoneRule.HasAccess(accessCost: number?, owned: { [string]: boolean }?, zoneId: string): boolean
	if accessCost == nil then
		return true
	end
	return owned ~= nil and owned[zoneId] == true
end

-- Множитель дохода мемлинга (нет поля — ×1)
function ZoneRule.IncomeMultiplier(memeling: { IncomeMultiplier: number? }?): number
	return if memeling and memeling.IncomeMultiplier then memeling.IncomeMultiplier else 1
end

return ZoneRule
