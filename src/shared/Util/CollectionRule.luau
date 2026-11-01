--!strict
-- CollectionRule: коллекция мемлингов (задача 7.8). Чистые функции — их проверяют тесты.
--   • «открыт» — игрок хоть раз выносил этого мемлинга (профиль, data.discovered);
--   • сервер передаёт клиенту открытых и сколько у игрока каждого строками в атрибутах игрока:
--     CollectionDiscovered = "Id,Id,…", CollectionOwned = "Id=2,Id=1,…" (Id — латиница без запятых и «=»);
--   • порядок в окне: по зонам (ZoneOrder), потом те, кого нет в зонах (Secret); внутри — по редкости и Id.

local CollectionRule = {}

export type Section = { Zone: string?, Ids: { string } } -- Zone = nil — мемлинги вне зон (Secret)

type MemelingSpec = { Rarity: string, Zone: string? }

function CollectionRule.EncodeSet(set: { [string]: boolean }): string
	local ids: { string } = {}
	for id, on in set do
		if on then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return table.concat(ids, ",")
end

function CollectionRule.DecodeSet(text: string?): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for id in string.gmatch(text or "", "[^,]+") do
		set[id] = true
	end
	return set
end

function CollectionRule.EncodeCounts(counts: { [string]: number }): string
	local ids: { string } = {}
	for id, count in counts do
		if count > 0 then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	local parts: { string } = {}
	for _, id in ipairs(ids) do
		table.insert(parts, id .. "=" .. counts[id])
	end
	return table.concat(parts, ",")
end

function CollectionRule.DecodeCounts(text: string?): { [string]: number }
	local counts: { [string]: number } = {}
	for id, count in string.gmatch(text or "", "([^,=]+)=(%d+)") do
		counts[id] = tonumber(count) or 0
	end
	return counts
end

-- Сколько открыто из скольких (считаются только существующие мемлинги)
function CollectionRule.Progress(discovered: { [string]: boolean }, memelings: { [string]: MemelingSpec }): (number, number)
	local opened, total = 0, 0
	for id in memelings do
		total += 1
		if discovered[id] then
			opened += 1
		end
	end
	return opened, total
end

-- Разделы окна коллекции: зоны по порядку, в конце — мемлинги вне зон; внутри — по редкости, потом по Id
function CollectionRule.Sections(memelings: { [string]: MemelingSpec }, zoneOrder: { string }, rarityOrder: { string }): { Section }
	local rank: { [string]: number } = {}
	for i, rarity in ipairs(rarityOrder) do
		rank[rarity] = i
	end
	local function collect(zone: string?): { string }
		local ids: { string } = {}
		for id, memeling in memelings do
			if memeling.Zone == zone then
				table.insert(ids, id)
			end
		end
		table.sort(ids, function(a: string, b: string): boolean
			local ra, rb = rank[memelings[a].Rarity] or 0, rank[memelings[b].Rarity] or 0
			if ra ~= rb then
				return ra < rb
			end
			return a < b
		end)
		return ids
	end
	local sections: { Section } = {}
	for _, zone in ipairs(zoneOrder) do
		table.insert(sections, { Zone = zone, Ids = collect(zone) })
	end
	local outside = collect(nil)
	if #outside > 0 then
		table.insert(sections, { Zone = nil, Ids = outside })
	end
	return sections
end

return CollectionRule
