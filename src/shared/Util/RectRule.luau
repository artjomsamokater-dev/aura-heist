--!strict
-- RectRule: пересекаются ли прямоугольники элементов интерфейса (задача после 7.8 — проверка раскладки HUD).
-- Чистые функции — их проверяют тесты. Прямоугольник — левый верхний угол (X, Y) и размер (W, H) в пикселях.

local RectRule = {}

export type Rect = { X: number, Y: number, W: number, H: number }

-- Касание краями — не пересечение (между элементами может не быть зазора)
function RectRule.Overlaps(a: Rect, b: Rect): boolean
	if a.W <= 0 or a.H <= 0 or b.W <= 0 or b.H <= 0 then
		return false
	end
	return a.X < b.X + b.W and b.X < a.X + a.W and a.Y < b.Y + b.H and b.Y < a.Y + a.H
end

-- Все пересекающиеся пары из списка (по номерам)
function RectRule.OverlappingPairs(rects: { Rect }): { { number } }
	local pairs: { { number } } = {}
	for i = 1, #rects do
		for j = i + 1, #rects do
			if RectRule.Overlaps(rects[i], rects[j]) then
				table.insert(pairs, { i, j })
			end
		end
	end
	return pairs
end

return RectRule
