--!strict
-- SpawnPointBook: журнал точек спавна — что на каждой точке сейчас. Чистая логика без Roblox,
-- её проверяют тесты (tests/SpawnPointBook.spec.luau): на одной точке не бывает двух мемлингов.
--
-- Состояния точки:
--   свободна   — можно поставить нового мемлинга (ресток);
--   "Occupied" — на точке стоит мемлинг;
--   "Returning"— мемлинга с этой точки потеряли, через несколько секунд он вернётся сюда.
-- Подобранный мемлинг освобождает точку: её может занять ресток. Если потом его потеряют,
-- а точка уже занята — он не возвращается (иначе было бы два на одной точке).

local SpawnPointBook = {}

SpawnPointBook.Occupied = "Occupied"
SpawnPointBook.Returning = "Returning"

export type Book = {
	Count: number,
	States: { [number]: string? },
}

function SpawnPointBook.new(count: number): Book
	return { Count = count, States = {} }
end

function SpawnPointBook.IsFree(book: Book, index: number): boolean
	return index >= 1 and index <= book.Count and book.States[index] == nil
end

-- Все свободные точки по порядку — их заполняет ресток
function SpawnPointBook.FreePoints(book: Book): { number }
	local free = {}
	for index = 1, book.Count do
		if book.States[index] == nil then
			table.insert(free, index)
		end
	end
	return free
end

-- Поставить мемлинга на свободную точку. Вернёт false, если точка не свободна
function SpawnPointBook.Occupy(book: Book, index: number): boolean
	if not SpawnPointBook.IsFree(book, index) then
		return false
	end
	book.States[index] = SpawnPointBook.Occupied
	return true
end

-- Мемлинга с точки подобрали (или убрали) — точка свободна
function SpawnPointBook.Release(book: Book, index: number)
	if book.States[index] == SpawnPointBook.Occupied then
		book.States[index] = nil
	end
end

-- Мемлинга с этой точки потеряли: держим точку до его возвращения.
-- Вернёт false, если точка уже занята (ресток успел поставить другого) — тогда он не вернётся
function SpawnPointBook.ReserveReturn(book: Book, index: number): boolean
	if not SpawnPointBook.IsFree(book, index) then
		return false
	end
	book.States[index] = SpawnPointBook.Returning
	return true
end

-- Потерянный мемлинг вернулся на свою точку (она была придержана для него)
function SpawnPointBook.FinishReturn(book: Book, index: number): boolean
	if book.States[index] ~= SpawnPointBook.Returning then
		return false
	end
	book.States[index] = SpawnPointBook.Occupied
	return true
end

return SpawnPointBook
