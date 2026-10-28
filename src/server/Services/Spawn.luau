--!strict
-- Spawn: ставит мемлингов на точки спавна в зоне и помнит, где какой.
-- Пока только Common и только один раз при старте сервера
-- (все редкости и шансы — задача 3.1, ресток по таймеру — задача 4.1).
-- Решение «можно ли подобрать» принимает не Spawn, а обработчик подбора (сервис Raid).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local MemelingConfig = require(ReplicatedStorage.Shared.Config.MemelingConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local MapBuilder = require(script.Parent.MapBuilder)

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

local SPAWN_RARITY = "Common" -- временно, до задачи 3.1

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
	prompt.Triggered:Connect(function(player: Player)
		if pickupHandler then
			pickupHandler(player, instanceId)
		end
	end)
end

local function spawnAt(memelingId: string, floorPosition: Vector3): Record
	nextNumber += 1
	local instanceId = "M" .. nextNumber
	local size = MapConfig.Memeling.Size
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
	MapBuilder.AddLabel(part, displayName)
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

	local ids = getIdsOfRarity(SPAWN_RARITY)
	if #ids == 0 then
		warn(string.format("[Spawn] В MemelingConfig нет мемлингов редкости %s", SPAWN_RARITY))
		return
	end

	for _, point in ipairs(MapConfig.Zone.SpawnPoints) do
		spawnAt(ids[random:NextInteger(1, #ids)], point)
	end
	print(string.format("[Spawn] В зоне появилось мемлингов: %d (%s)", #MapConfig.Zone.SpawnPoints, SPAWN_RARITY))
end

return Spawn
