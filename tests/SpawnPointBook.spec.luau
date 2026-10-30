--!strict
-- Тесты рестока (задача 4.1): ресток не создаёт двух мемлингов на одной точке.

local Book = require("../src/shared/Util/SpawnPointBook")
local TestKit = require("./TestKit")

local test, equal = TestKit.test, TestKit.equal

-- Ресток так же, как в сервисе Spawn: занять каждую свободную точку. Вернёт, сколько поставил
local function restock(book: Book.Book): number
	local placed = 0
	for _, index in ipairs(Book.FreePoints(book)) do
		if Book.Occupy(book, index) then
			placed += 1
		end
	end
	return placed
end

local function occupiedCount(book: Book.Book): number
	local count = 0
	for index = 1, book.Count do
		if book.States[index] == Book.Occupied then
			count += 1
		end
	end
	return count
end

print("SpawnPointBook")

test("первый спавн занимает все точки, ресток сразу после — ни одного нового", function()
	local book = Book.new(8)
	equal(restock(book), 8)
	equal(restock(book), 0, "занятые точки не трогаем")
	equal(occupiedCount(book), 8)
end)

test("подобрали двоих — ресток ставит ровно двоих на их точки", function()
	local book = Book.new(8)
	restock(book)
	Book.Release(book, 3)
	Book.Release(book, 7)
	equal(restock(book), 2)
	equal(occupiedCount(book), 8)
end)

test("точку, куда возвращается потерянный мемлинг, ресток не трогает", function()
	local book = Book.new(4)
	restock(book)
	Book.Release(book, 2) -- подобрали
	equal(Book.ReserveReturn(book, 2), true) -- потеряли до рестока — точка ждёт его
	equal(restock(book), 0, "ресток пропускает точку в ожидании")
	equal(Book.FinishReturn(book, 2), true)
	equal(occupiedCount(book), 4)
end)

test("ресток успел занять точку — потерянный мемлинг туда не возвращается", function()
	local book = Book.new(4)
	restock(book)
	Book.Release(book, 1) -- подобрали
	equal(restock(book), 1) -- ресток поставил нового на ту же точку
	equal(Book.ReserveReturn(book, 1), false, "второго на точку не будет")
	equal(occupiedCount(book), 4)
end)

test("второй раз занять занятую точку нельзя", function()
	local book = Book.new(2)
	equal(Book.Occupy(book, 1), true)
	equal(Book.Occupy(book, 1), false)
	equal(Book.Occupy(book, 5), false, "точки за пределами нет")
end)

test("1000 случайных подборов, потерь и рестоков — на точке никогда не больше одного", function()
	math.randomseed(7)
	local book = Book.new(8)
	restock(book)
	for _ = 1, 1000 do
		local index = math.random(1, 8)
		local action = math.random(1, 4)
		if action == 1 then
			Book.Release(book, index)
		elseif action == 2 then
			Book.ReserveReturn(book, index)
		elseif action == 3 then
			Book.FinishReturn(book, index)
		else
			restock(book)
		end
		for i = 1, 8 do
			local state = book.States[i]
			if state ~= nil and state ~= Book.Occupied and state ~= Book.Returning then
				error("непонятное состояние точки " .. i)
			end
		end
		if occupiedCount(book) > 8 then
			error("мемлингов больше, чем точек")
		end
	end
end)

return nil
