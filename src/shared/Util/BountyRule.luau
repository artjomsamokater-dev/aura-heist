--!strict
-- BountyRule: «Охота» (задача 7.5). Чистые функции — их проверяют тесты.
--   • кандидаты — мемлинги, которые появляются в зонах (есть Zone), кроме Secret; порядок по Id — одинаковый всегда;
--   • новый BOUNTY — случайный кандидат, не тот же, что был (если есть из кого выбрать);
--   • мемлинг с флагом bounty приносит доход × multiplier.

local BountyRule = {}

type MemelingSpec = { Rarity: string, Zone: string? }

function BountyRule.Candidates(memelings: { [string]: MemelingSpec }, excludedRarity: string): { string }
	local ids: { string } = {}
	for id, memeling in memelings do
		if memeling.Zone ~= nil and memeling.Rarity ~= excludedRarity then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

-- roll — случайное число 0 ≤ roll < 1. Пустой список — nil
function BountyRule.Pick(candidates: { string }, previous: string?, roll: number): string?
	local pool: { string } = {}
	for _, id in ipairs(candidates) do
		if id ~= previous or #candidates == 1 then
			table.insert(pool, id)
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[math.min(#pool, math.floor(roll * #pool) + 1)]
end

function BountyRule.IncomeMultiplier(multiplier: number, bounty: boolean): number
	return if bounty then multiplier else 1
end

return BountyRule
