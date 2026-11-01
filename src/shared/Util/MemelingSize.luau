--!strict
-- MemelingSize: размер мемлинга по редкости (задача 5.4b). Чистые функции — их проверяют тесты.
-- Множители — StyleConfig.Memeling.RarityScale, габарит — StyleConfig.Memeling.Size.

local MemelingSize = {}

-- Множитель размера редкости; неизвестная редкость — обычный размер
function MemelingSize.Scale(rarityScales: { [string]: number }, rarity: string?): number
	local scale = if rarity then rarityScales[rarity] else nil
	if scale == nil or scale <= 0 then
		return 1
	end
	return scale
end

-- На сколько поднять центр, чтобы низ увеличенного мемлинга остался там же (на полу, на постаменте)
function MemelingSize.Lift(height: number, scale: number): number
	return height * (scale - 1) / 2
end

-- Дальность подбора от центра: обычная дальность + насколько крупный мемлинг шире обычного.
-- Так до большого мемлинга можно дотянуться с того же расстояния до его края
function MemelingSize.Reach(baseDistance: number, width: number, scale: number): number
	return baseDistance + math.max(0, width * (scale - 1) / 2)
end

-- Высота центра мемлинга номер index в стопке на голове. heights — высоты мемлингов стопки снизу вверх:
-- низ первого — на headTop, каждый следующий стоит на предыдущем с зазором gap
function MemelingSize.StackCenterY(heights: { number }, index: number, headTop: number, gap: number): number
	local bottom = headTop
	for i = 1, index - 1 do
		bottom += heights[i] + gap
	end
	return bottom + heights[index] / 2
end

return MemelingSize
