--!strict
-- SquadRule: бонус отряда — кто эвакуировался «рядом и вовремя». Чистые функции без Roblox,
-- их проверяют тесты в tests/SquadRule.spec.luau.
--
-- Правило: два разных игрока завершили эвакуацию не дальше radius студов друг от друга (по полу)
-- и с разницей во времени не больше window секунд — оба получают бонус к цене продажи
-- принесённых мемлингов. Каждая эвакуация получает бонус не больше одного раза.

local SquadRule = {}

-- Одна завершённая эвакуация
export type Extraction = {
	OwnerId: number, -- UserId игрока
	X: number,
	Z: number,
	Time: number,
	Bonus: boolean, -- бонус за эту эвакуацию уже выдан
}

-- Рядом и вовремя (и это разные игроки)
function SquadRule.IsSquad(a: Extraction, b: Extraction, radius: number, window: number): boolean
	if a.OwnerId == b.OwnerId then
		return false
	end
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz) <= radius and math.abs(a.Time - b.Time) <= window
end

-- Убирает эвакуации старше окна: с ними отряд уже не собрать
function SquadRule.Prune(recent: { Extraction }, now: number, window: number)
	for i = #recent, 1, -1 do
		if now - recent[i].Time > window then
			table.remove(recent, i)
		end
	end
end

-- Новая эвакуация против недавних: вернёт номера тех, с кем она образует отряд.
-- Если список не пуст — бонус получает новая эвакуация и все найденные, у кого его ещё нет.
function SquadRule.FindPartners(new: Extraction, recent: { Extraction }, radius: number, window: number): { number }
	local partners = {}
	for i, other in ipairs(recent) do
		if SquadRule.IsSquad(new, other, radius, window) then
			table.insert(partners, i)
		end
	end
	return partners
end

-- Цена продажи с бонусом отряда, округлённая вниз (игроку дробей не показываем)
function SquadRule.SellPrice(basePrice: number, bonusPercent: number, hasBonus: boolean): number
	if not hasBonus then
		return basePrice
	end
	return math.floor(basePrice * (100 + bonusPercent) / 100)
end

return SquadRule
