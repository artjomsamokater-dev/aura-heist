--!strict
-- RarityRoll: в какой части зоны точка и какую редкость выбросить по шансам.
-- Чистые функции без Roblox — их проверяют тесты в tests/RarityRoll.spec.luau (10 000 бросков).

local RarityRoll = {}

-- Часть зоны по смещению X от центра зоны: от границы DangerFromX и восточнее — опасная
function RarityRoll.ZonePart(offsetX: number, dangerFromX: number): string
	return if offsetX >= dangerFromX then "Danger" else "Safe"
end

-- Выбор редкости. chances — шансы в процентах по редкостям, order — порядок редкостей,
-- roll — случайное число от 0 до 1 (1 не включая). Вернёт nil, если все шансы нулевые.
-- Редкость с шансом 0 не выпадает никогда.
function RarityRoll.Pick(chances: { [string]: number }, order: { string }, roll: number): string?
	local total = 0
	for _, rarity in ipairs(order) do
		total += math.max(chances[rarity] or 0, 0)
	end
	if total <= 0 then
		return nil
	end

	local target = roll * total
	local accumulated = 0
	local lastPositive: string? = nil
	for _, rarity in ipairs(order) do
		local chance = math.max(chances[rarity] or 0, 0)
		if chance > 0 then
			accumulated += chance
			lastPositive = rarity
			if target < accumulated then
				return rarity
			end
		end
	end
	return lastPositive -- roll ровно у края: погрешность дробных чисел
end

export type Spawned = {
	Rarity: string,
	Part: string,
}

-- Для объявления: самый редкий из появившихся за один спавн, если его редкость есть в announce.
-- order — редкости от простой к редкой. Вернёт индекс в spawned или nil (объявлять нечего).
-- Одно объявление на спавн: даже если появились и Epic, и Legendary — только про Legendary.
function RarityRoll.Rarest(spawned: { Spawned }, order: { string }, announce: { string }): number?
	local best: number? = nil
	local bestRank = 0
	for i, entry in ipairs(spawned) do
		local rank = table.find(order, entry.Rarity) or 0
		if table.find(announce, entry.Rarity) and rank > bestRank then
			best = i
			bestRank = rank
		end
	end
	return best
end

return RarityRoll
