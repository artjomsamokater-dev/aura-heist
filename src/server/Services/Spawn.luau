--!strict
-- Spawn: ставит мемлингов на точки спавна в зоне и помнит, где какой.
-- Редкость каждой точки — по шансам её части зоны (ZoneConfig.SpawnChances, граница MapConfig.Zone.DangerFromX),
-- выбор — чистая функция shared/Util/RarityRoll. Пока один раз при старте (ресток по таймеру — задача 4.1).
-- Решение «можно ли подобрать» принимает не Spawn, а обработчик подбора (сервис Raid).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local MemelingConfig = require(ReplicatedStorage.Shared.Config.MemelingConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local RarityRoll = require(ReplicatedStorage.Shared.Util.RarityRoll)
local MapBuilder = require(script.Parent.MapBuilder)
local RemoteGuard = require(ServerScriptService.Server.Security.RemoteGuard)

local Spawn = {}

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
	SpawnPoint: Vector3, -- точка спавна, куда мемлинг вернётся, если его потеряют
}

type PickupHandler = (player: Player, instanceId: string) -> ()

local random = Random.new()
local memelingsFolder: Folder? = nil
local nextNumber = 0
local pickupHandler: PickupHandler? = nil

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

local function spawnAt(memelingId: string, floorPosition: Vector3): Record
	nextNumber += 1
	local instanceId = "M" .. nextNumber
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
	MapBuilder.AddLabel(part, displayName, { MaxDistance = StyleConfig.Label.MemelingMaxDistance })
	addPickupPrompt(part, instanceId, displayName)

	local record: Record = {
		InstanceId = instanceId,
		MemelingId = memelingId,
		State = Spawn.State.InZone,
		Part = part,
		Owner = nil,
		SpawnPoint = floorPosition,
	}
	memelings[instanceId] = record
	return record
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
function Spawn.MarkCarried(instanceId: string, owner: Player): boolean
	local record = memelings[instanceId]
	if record == nil or record.State ~= Spawn.State.InZone then
		return false
	end
	record.State = Spawn.State.Carried
	record.Owner = owner

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
	record.Part:Destroy()
end

-- Мемлинга потеряли (смерть, выход): он пропадает и через ZoneConfig.LostRespawnSeconds
-- появляется снова на своей точке спавна — тот же мемлинг, новый InstanceId
function Spawn.Lose(instanceId: string)
	local record = memelings[instanceId]
	if record == nil then
		return
	end
	Spawn.Despawn(instanceId)

	task.delay(ZoneConfig.LostRespawnSeconds, function()
		spawnAt(record.MemelingId, record.SpawnPoint)
	end)
end

function Spawn.Start()
	local folder = Instance.new("Folder")
	folder.Name = "Memelings"
	folder.Parent = MapBuilder.GetZoneFolder()
	memelingsFolder = folder

	local spawned: { string } = {}
	for _, point in ipairs(MapConfig.Zone.SpawnPoints) do
		local memelingId, part, rarity = rollMemeling(point)
		if memelingId then
			spawnAt(memelingId, point)
			table.insert(spawned, string.format("%s:%s", part, memelingId))
		else
			warn(string.format("[Spawn] Точка в части %s: нет мемлинга (редкость %s)", part, tostring(rarity)))
		end
	end
	print(string.format("[Spawn] В зоне появилось мемлингов: %d (%s)", #spawned, table.concat(spawned, ", ")))
end

return Spawn
