--!strict
-- Spawn: ставит мемлингов на точки спавна в зоне и помнит, где какой.
-- Редкость каждой точки — по шансам её части зоны (ZoneConfig.SpawnChances, граница MapConfig.Zone.DangerFromX),
-- выбор — чистая функция shared/Util/RarityRoll.
-- Ресток: при старте и каждые ZoneConfig.RestockSeconds все свободные точки получают новых мемлингов.
-- Что на каждой точке, ведёт журнал shared/Util/SpawnPointBook: занятые и ждущие возврата
-- потерянного мемлинга точки ресток не трогает — двух мемлингов на одной точке не бывает.
-- Время следующего рестока — атрибут NextRestockAt на ReplicatedStorage (время сервера):
-- у всех игроков один и тот же таймер, остаток считает клиент.
-- Решение «можно ли подобрать» принимает не Spawn, а обработчик подбора (сервис Raid).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local MemelingConfig = require(ReplicatedStorage.Shared.Config.MemelingConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local RarityRoll = require(ReplicatedStorage.Shared.Util.RarityRoll)
local SpawnPointBook = require(ReplicatedStorage.Shared.Util.SpawnPointBook)
local MapBuilder = require(script.Parent.MapBuilder)
local RemoteGuard = require(ServerScriptService.Server.Security.RemoteGuard)

local Spawn = {}

Spawn.RestockAttribute = "NextRestockAt"

-- Где сейчас мемлинг
Spawn.State = table.freeze({
	InZone = "InZone", -- стоит в зоне, его можно подобрать
	Carried = "Carried", -- его несёт игрок (Owner)
})

export type Record = {
	InstanceId: string, -- уникальный номер экземпляра: "M1", "M2", ...
	MemelingId: string, -- какой это мемлинг из MemelingConfig: "ToastPaw", ...
	State: string,
	Part: Part,
	Owner: Player?,
	SpawnIndex: number, -- номер точки спавна (MapConfig.Zone.SpawnPoints), куда он вернётся, если его потеряют
}

-- Кто появился при одном спавне или рестоке (для объявлений)
export type Spawned = {
	MemelingId: string,
	Rarity: string,
	Part: string, -- "Safe" / "Danger"
}

type PickupHandler = (player: Player, instanceId: string) -> ()

local random = Random.new()
local memelingsFolder: Folder? = nil
local nextNumber = 0
local pickupHandler: PickupHandler? = nil
local book = SpawnPointBook.new(#MapConfig.Zone.SpawnPoints)

-- Все мемлинги в мире: [InstanceId] = запись
local memelings: { [string]: Record } = {}

-- Id мемлингов нужной редкости, отсортированные, чтобы порядок не зависел от словаря
local function getIdsOfRarity(rarity: string): { string }
	local ids = {}
	for id, memeling in MemelingConfig.Memelings do
		if memeling.Rarity == rarity then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

-- Какой мемлинг появится на точке: часть зоны → редкость по шансам → случайный мемлинг этой редкости
local function rollMemeling(floorPosition: Vector3): (string?, string, string?)
	local offsetX = floorPosition.X - MapConfig.Zone.Center.X
	local part = RarityRoll.ZonePart(offsetX, MapConfig.Zone.DangerFromX)
	local rarity = RarityRoll.Pick(ZoneConfig.SpawnChances[part] or {}, MemelingConfig.RarityOrder, random:NextNumber())
	if rarity == nil then
		return nil, part, nil
	end
	local ids = getIdsOfRarity(rarity)
	if #ids == 0 then
		return nil, part, rarity
	end
	return ids[random:NextInteger(1, #ids)], part, rarity
end

local function addPickupPrompt(part: Part, instanceId: string, displayName: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = TextConfig.PickupAction
	prompt.ObjectText = displayName
	prompt.MaxActivationDistance = ZoneConfig.PickupDistance
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	-- Triggered приходит на сервер с игроком, который нажал. Больше клиент ничего не передаёт.
	RemoteGuard.ConnectPrompt(prompt, "подбор", function(player: Player)
		if pickupHandler then
			pickupHandler(player, instanceId)
		end
	end)
end

-- Ставит мемлинга на точку. Точка в журнале уже должна быть отмечена (Occupy / FinishReturn)
local function spawnAt(memelingId: string, spawnIndex: number): Record
	nextNumber += 1
	local instanceId = "M" .. nextNumber
	local size = StyleConfig.Memeling.Size
	local displayName = TextConfig.MemelingNames[memelingId] or memelingId
	local floorPosition = MapConfig.Zone.SpawnPoints[spawnIndex]

	-- Мемлинг смотрит на запад — туда, откуда игрок приходит в зону
	local position = floorPosition + Vector3.new(0, size.Y / 2, 0)
	local part = MapBuilder.MakeMemeling(
		instanceId,
		memelingId,
		CFrame.lookAt(position, position - Vector3.xAxis),
		(assert(memelingsFolder, "Spawn.Start() ещё не вызван"))
	)
	part:SetAttribute("InstanceId", instanceId)
	part:SetAttribute("MemelingId", memelingId)
	MapBuilder.AddLabel(
		part,
		displayName,
		{ MaxDistance = StyleConfig.Label.MemelingMaxDistance, Height = StyleConfig.Memeling.LabelHeight }
	)
	addPickupPrompt(part, instanceId, displayName)

	local record: Record = {
		InstanceId = instanceId,
		MemelingId = memelingId,
		State = Spawn.State.InZone,
		Part = part,
		Owner = nil,
		SpawnIndex = spawnIndex,
	}
	memelings[instanceId] = record
	return record
end

-- Ресток: каждая свободная точка получает нового мемлинга. Вернёт, кто появился
local function restock(): { Spawned }
	local spawned: { Spawned } = {}
	local names: { string } = {}
	for _, index in ipairs(SpawnPointBook.FreePoints(book)) do
		local memelingId, part, rarity = rollMemeling(MapConfig.Zone.SpawnPoints[index])
		if memelingId and rarity and SpawnPointBook.Occupy(book, index) then
			spawnAt(memelingId, index)
			table.insert(spawned, { MemelingId = memelingId, Rarity = rarity, Part = part })
			table.insert(names, string.format("%s:%s", part, memelingId))
		elseif memelingId == nil then
			warn(string.format("[Spawn] Точка %d в части %s: нет мемлинга (редкость %s)", index, part, tostring(rarity)))
		end
	end
	print(string.format("[Spawn] Ресток: появилось %d (%s)", #spawned, if #names > 0 then table.concat(names, ", ") else "все точки заняты"))
	return spawned
end

-- Запись мемлинга по InstanceId или nil, если такого нет
function Spawn.Get(instanceId: string): Record?
	return memelings[instanceId]
end

-- Кто будет решать, можно ли подобрать (вызывается при нажатии кнопки)
function Spawn.SetPickupHandler(handler: PickupHandler)
	pickupHandler = handler
end

-- Помечает мемлинга как подобранного. Вернёт false, если его уже взяли или его нет.
-- Это и есть флаг «подобран»: второй вызов для того же мемлинга всегда получит false.
-- Его точка освобождается: её может занять ресток.
function Spawn.MarkCarried(instanceId: string, owner: Player): boolean
	local record = memelings[instanceId]
	if record == nil or record.State ~= Spawn.State.InZone then
		return false
	end
	record.State = Spawn.State.Carried
	record.Owner = owner
	SpawnPointBook.Release(book, record.SpawnIndex)

	local prompt = record.Part:FindFirstChild("PickupPrompt")
	if prompt then
		prompt:Destroy()
	end
	return true
end

-- Убирает мемлинга из мира насовсем (вынесен из зоны через эвакуацию)
function Spawn.Despawn(instanceId: string)
	local record = memelings[instanceId]
	if record == nil then
		return
	end
	memelings[instanceId] = nil
	if record.State == Spawn.State.InZone then
		SpawnPointBook.Release(book, record.SpawnIndex)
	end
	record.Part:Destroy()
end

-- Мемлинга потеряли (смерть, выход): он пропадает и через ZoneConfig.LostRespawnSeconds
-- появляется снова на своей точке спавна — тот же мемлинг, новый InstanceId.
-- Если ресток уже поставил на эту точку другого, потерянный не возвращается (без дублей).
function Spawn.Lose(instanceId: string)
	local record = memelings[instanceId]
	if record == nil then
		return
	end
	Spawn.Despawn(instanceId)

	local index = record.SpawnIndex
	if not SpawnPointBook.ReserveReturn(book, index) then
		print(string.format("[Spawn] %s не вернётся: на его точке %d уже новый мемлинг", record.MemelingId, index))
		return
	end
	task.delay(ZoneConfig.LostRespawnSeconds, function()
		if SpawnPointBook.FinishReturn(book, index) then
			spawnAt(record.MemelingId, index)
		end
	end)
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

function Spawn.Start()
	local folder = Instance.new("Folder")
	folder.Name = "Memelings"
	folder.Parent = MapBuilder.GetZoneFolder()
	memelingsFolder = folder

	restock()

	-- Таймер рестока: время следующего хранит сервер, у всех игроков оно одно
	local nextRestockAt = now() + ZoneConfig.RestockSeconds
	ReplicatedStorage:SetAttribute(Spawn.RestockAttribute, nextRestockAt)
	task.spawn(function()
		while true do
			task.wait(math.max(0.1, nextRestockAt - now()))
			if now() >= nextRestockAt then
				restock()
				nextRestockAt += ZoneConfig.RestockSeconds
				ReplicatedStorage:SetAttribute(Spawn.RestockAttribute, nextRestockAt)
			end
		end
	end)
end

return Spawn
