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

local CollectionService = game:GetService("CollectionService")
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
local MemelingSize = require(ReplicatedStorage.Shared.Util.MemelingSize)
local MapBuilder = require(script.Parent.MapBuilder)
local Announcer = require(script.Parent.Announcer)
local RemoteGuard = require(ServerScriptService.Server.Security.RemoteGuard)

local Spawn = {}

Spawn.RestockAttribute = "NextRestockAt"

-- Где сейчас мемлинг
Spawn.State = table.freeze({
	InZone = "InZone", -- стоит в зоне, его можно подобрать
	Carried = "Carried", -- его несёт игрок (Owner)
	Dropped = "Dropped", -- выпал при смерти: ZoneConfig.LootSeconds его может поднять только погибший (Owner)
})

export type Record = {
	InstanceId: string, -- уникальный номер экземпляра: "M1", "M2", ...
	MemelingId: string, -- какой это мемлинг из MemelingConfig: "ToastPaw", ...
	State: string,
	Part: Part,
	Owner: Player?,
	SpawnIndex: number, -- номер точки спавна (MapConfig.Zone.SpawnPoints), куда он вернётся, если его потеряют
}

-- Атрибуты выпавшего лута на ядре мемлинга: клиент владельца рисует «YOUR LOOT» и таймер,
-- остальные клиенты прячут у себя кнопку подбора (решает всё равно сервер)
Spawn.LootOwnerAttribute = "LootOwnerUserId"
Spawn.LootExpiresAttribute = "LootExpiresAt" -- время сервера (GetServerTimeNow), когда лут вернётся на спавн

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

local function addPickupPrompt(part: Part, instanceId: string, memelingId: string, displayName: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = TextConfig.PickupAction
	prompt.ObjectText = displayName
	-- Крупного мемлинга можно подобрать с того же расстояния до его края (центр дальше)
	prompt.MaxActivationDistance =
		MemelingSize.Reach(ZoneConfig.PickupDistance, StyleConfig.Memeling.Size.X, MapBuilder.GetMemelingScale(memelingId))
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

-- Мемлинг в мире на полу зоны: модель, подпись с именем и кнопка подбора
local function placeInWorld(instanceId: string, memelingId: string, floorPosition: Vector3): Part
	local size = StyleConfig.Memeling.Size
	local displayName = TextConfig.MemelingNames[memelingId] or memelingId

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
		{
			MaxDistance = StyleConfig.Label.MemelingMaxDistance,
			Height = MapBuilder.GetMemelingLabelHeight(memelingId),
			Scale = StyleConfig.Label.MemelingScale,
		}
	)
	addPickupPrompt(part, instanceId, memelingId, displayName)
	return part
end

-- Ставит мемлинга на точку. Точка в журнале уже должна быть отмечена (Occupy / FinishReturn)
local function spawnAt(memelingId: string, spawnIndex: number): Record
	nextNumber += 1
	local instanceId = "M" .. nextNumber
	local part = placeInWorld(instanceId, memelingId, MapConfig.Zone.SpawnPoints[spawnIndex])

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

-- Ресток: каждая свободная точка получает нового мемлинга. Вернёт редкости и части зоны появившихся
local function restock(): { RarityRoll.Spawned }
	local spawned: { RarityRoll.Spawned } = {}
	local names: { string } = {}
	for _, index in ipairs(SpawnPointBook.FreePoints(book)) do
		local memelingId, part, rarity = rollMemeling(MapConfig.Zone.SpawnPoints[index])
		if memelingId and rarity and SpawnPointBook.Occupy(book, index) then
			spawnAt(memelingId, index)
			table.insert(spawned, { Rarity = rarity, Part = part })
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

-- Можно ли этому игроку поднять мемлинга: стоит в зоне — любому, выпавший лут — только погибшему владельцу
function Spawn.CanPickUp(record: Record, player: Player): boolean
	if record.State == Spawn.State.InZone then
		return true
	end
	return record.State == Spawn.State.Dropped and record.Owner == player
end

-- Помечает мемлинга как подобранного. Вернёт false, если его уже взяли, его нет или он чужой лут.
-- Это и есть флаг «подобран»: второй вызов для того же мемлинга всегда получит false.
-- Его точка освобождается: её может занять ресток (у выпавшего лута она уже свободна).
function Spawn.MarkCarried(instanceId: string, owner: Player): boolean
	local record = memelings[instanceId]
	if record == nil or not Spawn.CanPickUp(record, owner) then
		return false
	end
	if record.State == Spawn.State.InZone then
		SpawnPointBook.Release(book, record.SpawnIndex)
	end
	record.State = Spawn.State.Carried
	record.Owner = owner

	local part = record.Part
	CollectionService:RemoveTag(part, StyleConfig.Loot.Tag)
	part:SetAttribute(Spawn.LootOwnerAttribute, nil)
	part:SetAttribute(Spawn.LootExpiresAttribute, nil)
	local prompt = part:FindFirstChild("PickupPrompt")
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

-- Мемлинга потеряли (падение, выход, лут не подняли вовремя): он пропадает и через ZoneConfig.LostRespawnSeconds
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

-- Смерть с лутом: мемлинг из рук погибшего встаёт на пол у места смерти (floorPosition — точка на полу зоны).
-- ZoneConfig.LootSeconds его может поднять только owner, потом он возвращается на свою точку спавна,
-- как потерянный (Spawn.Lose). Старая модель была приварена к погибшему персонажу — ставим новую
function Spawn.DropAsLoot(instanceId: string, owner: Player, floorPosition: Vector3)
	local record = memelings[instanceId]
	if record == nil or record.State ~= Spawn.State.Carried then
		return
	end
	record.Part:Destroy()
	local part = placeInWorld(instanceId, record.MemelingId, floorPosition)
	record.Part = part
	record.State = Spawn.State.Dropped
	record.Owner = owner
	part:SetAttribute(Spawn.LootOwnerAttribute, owner.UserId)
	part:SetAttribute(Spawn.LootExpiresAttribute, now() + ZoneConfig.LootSeconds)
	CollectionService:AddTag(part, StyleConfig.Loot.Tag)

	task.delay(ZoneConfig.LootSeconds, function()
		-- Тот же лут всё ещё лежит (его не подняли и не убрали) — возвращается на спавн
		if memelings[instanceId] == record and record.State == Spawn.State.Dropped and record.Part == part then
			print(string.format("[Spawn] Лут %s (%s) не подняли — возвращается на точку", record.MemelingId, instanceId))
			Spawn.Lose(instanceId)
		end
	end)
end

-- Игрок вышел: его выпавший лут сразу возвращается на точки спавна
function Spawn.LoseLootOf(player: Player)
	local ids: { string } = {}
	for instanceId, record in memelings do
		if record.State == Spawn.State.Dropped and record.Owner == player then
			table.insert(ids, instanceId)
		end
	end
	for _, instanceId in ipairs(ids) do
		Spawn.Lose(instanceId)
	end
end

function Spawn.Start()
	local folder = Instance.new("Folder")
	folder.Name = "Memelings"
	folder.Parent = MapBuilder.GetZoneFolder()
	memelingsFolder = folder

	Announcer.AnnounceSpawn(restock()) -- при старте игроков ещё нет, но правило одно для всех спавнов

	-- Таймер рестока: время следующего хранит сервер, у всех игроков оно одно
	local nextRestockAt = now() + ZoneConfig.RestockSeconds
	ReplicatedStorage:SetAttribute(Spawn.RestockAttribute, nextRestockAt)
	task.spawn(function()
		while true do
			task.wait(math.max(0.1, nextRestockAt - now()))
			if now() >= nextRestockAt then
				Announcer.AnnounceSpawn(restock()) -- одно объявление на один ресток
				nextRestockAt += ZoneConfig.RestockSeconds
				ReplicatedStorage:SetAttribute(Spawn.RestockAttribute, nextRestockAt)
			end
		end
	end)
end

return Spawn
