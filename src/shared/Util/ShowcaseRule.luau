--!strict
-- ShowcaseRule: кто стоит на постаментах, а кто в запасе (баг после Rebirth). Чистые функции — их проверяют тесты.
-- Все мемлинги игрока (с постаментов и из запаса) сортируются по доходу: самые доходные встают на
-- открытые постаменты 1..slots, остальные — в запас (тоже по доходу: при покупке постамента первым
-- встанет самый доходный). Флаг отряда и сам мемлинг (а значит, и его зона) сохраняются.

local ShowcaseRule = {}

export type Candidate = {
	memelingId: string,
	squadBonus: boolean?,
	bounty: boolean?, -- флаг «Охоты» тоже переходит вместе с мемлингом
	rate: number, -- доход в секунду (считает Studio.getRate)
}

-- Вернёт (на постаменты по порядку, в запас по порядку). При равном доходе — прежний порядок
function ShowcaseRule.Reflow(candidates: { Candidate }, slots: number): ({ Candidate }, { Candidate })
	local order: { number } = {}
	for i in ipairs(candidates) do
		table.insert(order, i)
	end
	table.sort(order, function(a: number, b: number): boolean
		local ra, rb = candidates[a].rate, candidates[b].rate
		if ra ~= rb then
			return ra > rb
		end
		return a < b
	end)
	local placed, reserve = {}, {}
	for position, index in ipairs(order) do
		table.insert(if position <= slots then placed else reserve, candidates[index])
	end
	return placed, reserve
end

-- Нужна ли пересборка: кто-то стоит на постаменте за пределами открытых (старые сохранения после Rebirth)
function ShowcaseRule.NeedsReflow(pedestals: { number }, slots: number): boolean
	for _, pedestal in ipairs(pedestals) do
		if pedestal > slots then
			return true
		end
	end
	return false
end

return ShowcaseRule
