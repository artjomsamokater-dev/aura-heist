--!strict
-- Windows: окна интерфейса на этом клиенте (задача 7.8) — магазин, коллекция, панели меню.
-- Одновременно открыто не больше одного окна: открытие нового закрывает прежнее.
-- Каждый контроллер регистрирует своё окно функцией setOpen(open); меню открывает окна по имени.

local Windows = {}

local registry: { [string]: (open: boolean) -> () } = {}
local current: string? = nil

function Windows.Register(name: string, setOpen: (open: boolean) -> ())
	registry[name] = setOpen
end

function Windows.Open(name: string)
	if current and current ~= name and registry[current] then
		registry[current](false)
	end
	local setOpen = registry[name]
	if setOpen then
		current = name
		setOpen(true)
	end
end

-- Окно закрылось само (кнопка X): забываем, что оно открыто
function Windows.Closed(name: string)
	if current == name then
		current = nil
	end
end

function Windows.Close(name: string)
	local setOpen = registry[name]
	if setOpen then
		setOpen(false)
	end
	Windows.Closed(name)
end

function Windows.IsOpen(name: string): boolean
	return current == name
end

return Windows
