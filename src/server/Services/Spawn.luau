--!strict
-- Spawn: ставит мемлингов на точки спавна во всех зонах (ZoneConfig.ZoneOrder) и помнит, где какой.
-- Редкость каждой точки — по шансам её части зоны (ZoneConfig.Zones[Id].SpawnChances, граница
-- MapConfig.Zones[Id].DangerFromX), мемлинг — из тех, кто живёт в этой зоне (ZoneRule.MemelingsOf).
-- Выбор — чистые функции shared/Util/RarityRoll и ZoneRule. У каждой зоны свой журнал точек.
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
local ZoneRule = require(ReplicatedStorage.Shared.Util.ZoneRule)
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
	ZoneId: string, -- в какой зоне
	SpawnIndex: number, -- номер точки спавна (MapConfig.Zones[ZoneId].SpawnPoints), куда он вернётся, если его потеряют
}

-- Атрибуты выпавшего лута на ядре мемлинга: клиент владельца рисует «YOUR LOOT» и таймер,
-- остальные клиенты прячут у себя кнопку подбора (решает всё равно сервер)
Spawn.LootOwnerAttribute = "LootOwnerUserId"
Spawn.LootExpiresAttribute = "LootExpiresAt" -- время сервера (GetServerTimeNow), когда лут вернётся на спавн

type PickupHandler = (player: Player, instanceId: string) -> ()

local random = Random.new()
local memelingsFolders: { [string]: Folder } = {} -- по Id зоны
local nextNumber = 0
local pickupHandler: PickupHandler? = nil
local books: { [string]: SpawnPointBook.Book } = {} -- журнал точек каждой зоны
for _, zoneId in ipairs(ZoneConfig.ZoneOrder) do
	books[zoneId] = SpawnPointBook.new(#MapConfig.Zones[zoneId].SpawnPoints)
end

-- Все мемлинги в мире: [InstanceId] = запись
local memelings: { [string]: Record } = {}

-- Какой мемлинг появится на точке зоны: часть зоны → редкость по шансам зоны → случайный мемлинг
-- этой редкости из живущих в этой зоне
local function rollMemeling(zoneId: string, floorPosition: Vector3): (string?, string, string?)
	local zone = MapConfig.Zones[zoneId]
	local offsetX = floorPosition.X - zone.Center.X
	local part = RarityRoll.ZonePart(offsetX, zone.DangerFromX)
	local rarity = RarityRoll.Pick(ZoneConfig.Zones[zoneId].SpawnChances[part] or {}, MemelingConfig.RarityOrder, random:NextNumber())
	if rarity == nil then
		return nil, part, nil
	end
	local ids = ZoneRule.MemelingsOf(MemelingConfig.Memelings :: any, zoneId, rarity)
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

-- Мемлинг в мире на полу зоны zoneId: модель, подпись с именем и кнопка подбора
local function placeInWorld(zoneId: string, instanceId: string, memelingId: string, floorPosition: Vector3): Part
	local size = StyleConfig.Memeling.Size
	local displayName = TextConfig.MemelingNames[memelingId] or memelingId

	-- Мемлинг смотрит на запад — туда, откуда игрок приходит в зону
	local position = floorPosition + Vector3.new(0, size.Y / 2, 0)
	local part = MapBuilder.MakeMemeling(
		instanceId,
		memelingId,
		CFrame.lookAt(position, position - Vector3.xAxis),
		(assert(memelingsFolders[zoneId], "Spawn.Start() ещё не вызван"))
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

-- Ставит мемлинга на точку зоны. Точка в журнале уже должна быть отмечена (Occupy / FinishReturn)
local function spawnAt(zoneId: string, memelingId: string, spawnIndex: number): Record
	nextNumber += 1
	local instanceId = "M" .. nextNumber
	local part = placeInWorld(zoneId, instanceId, memelingId, MapConfig.Zones[zoneId].SpawnPoints[spawnIndex])

	local record: Record = {
		InstanceId = instanceId,
		MemelingId = memelingId,
		State = Spawn.State.InZone,
		Part = part,
		Owner = nil,
		ZoneId = zoneId,
		SpawnIndex = spawnIndex,
	}
	memelings[instanceId] = record
	return record
end

-- Ресток: каждая свободная точка каждой зоны получает нового мемлинга.
-- Вернёт редкости, части и зоны появившихся (для одного общего объявления)
local function restock(): { RarityRoll.Spawned }
	local spawned: { RarityRoll.Spawned } = {}
	for _, zoneId in ipairs(ZoneConfig.ZoneOrder) do
		local book = books[zoneId]
		local names: { string } = {}
		for _, index in ipairs(SpawnPointBook.FreePoints(book)) do
			local memelingId, part, rarity = rollMemeling(zoneId, MapConfig.Zones[zoneId].SpawnPoints[index])
			if memelingId and rarity and SpawnPointBook.Occupy(book, index) then
				spawnAt(zoneId, memelingId, index)
				table.insert(spawned, { Rarity = rarity, Part = part, Zone = zoneId })
				table.insert(names, string.format("%s:%s", part, memelingId))
			elseif memelingId == nil then
				warn(string.format("[Spawn] %s, точка %d в части %s: нет мемлинга (редкость %s)", zoneId, index, part, tostring(rarity)))
			end
		end
		print(string.format("[Spawn] Ресток %s: появилось %d (%s)", zoneId, #names, if #names > 0 then table.concat(names, ", ") else "все точки заняты"))
	end
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
		SpawnPointBook.Release(books[record.ZoneId], record.SpawnIndex)
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
		SpawnPointBook.Release(books[record.ZoneId], record.SpawnIndex)
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
	local book = books[record.ZoneId]
	if not SpawnPointBook.ReserveReturn(book, index) then
		print(string.format("[Spawn] %s не вернётся: на его точке %d (%s) уже новый мемлинг", record.MemelingId, index, record.ZoneId))
		return
	end
	task.delay(ZoneConfig.LostRespawnSeconds, function()
		if SpawnPointBook.FinishReturn(book, index) then
			spawnAt(record.ZoneId, record.MemelingId, index)
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
	local part = placeInWorld(record.ZoneId, instanceId, record.MemelingId, floorPosition)
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
	for _, zoneId in ipairs(ZoneConfig.ZoneOrder) do
		local folder = Instance.new("Folder")
		folder.Name = "Memelings"
		folder.Parent = MapBuilder.GetZoneFolder(zoneId)
		memelingsFolders[zoneId] = folder
	end

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
