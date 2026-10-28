--!strict
-- FormatNumber: число для показа игроку — округлено ВНИЗ и с разделителями тысяч.
-- Пример: 12345.9 → "12,345"

local function formatNumber(value: number): string
	local whole = math.floor(value)
	local digits = tostring(math.abs(whole))
	-- Ставим запятую перед каждой тройкой цифр с конца
	local withCommas = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if withCommas:sub(1, 1) == "," then
		withCommas = withCommas:sub(2)
	end
	return (if whole < 0 then "-" else "") .. withCommas
end

return formatNumber
