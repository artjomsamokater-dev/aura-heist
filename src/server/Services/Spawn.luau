--!strict
-- Spawn: ставит мемлингов на точки спавна в зоне и помнит, где какой.
-- Пока только Common и только один раз при старте сервера
-- (все редкости и шансы — задача 3.1, ресток по таймеру — задача 4.1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local MemelingConfig = require(ReplicatedStorage.Shared.Config.MemelingConfig)
local MapBuilder = require(script.Parent.MapBuilder)

local Spawn = {}

-- Где сейчас мемлинг
Spawn.State = table.freeze({
	InZone = "InZone", -- стоит в зоне, его можно подобрать
})

local SPAWN_RARITY = "Common" -- временно, до задачи 3.1

local random = Random.new()
local memelingsFolder = nil
local nextNumber = 0

-- Все живые мемлинги в мире: [InstanceId] = запись.
-- InstanceId — уникальный номер экземпляра ("M1", "M2", ...),
-- MemelingId — какой это мемлинг из MemelingConfig ("ToastPaw", ...).
local memelings = {}

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

local function spawnAt(memelingId: string, floorPosition: Vector3)
	nextNumber += 1
	local instanceId = "M" .. nextNumber
	local size = MapConfig.Memeling.Size

	local part = MapBuilder.MakePart(
		instanceId,
		size,
		CFrame.new(floorPosition + Vector3.new(0, size.Y / 2, 0)),
		MapConfig.Colors.Memeling,
		memelingsFolder
	)
	part:SetAttribute("InstanceId", instanceId)
	part:SetAttribute("MemelingId", memelingId)
	MapBuilder.AddLabel(part, MemelingConfig.Memelings[memelingId].DisplayName)

	local record = {
		InstanceId = instanceId,
		MemelingId = memelingId,
		State = Spawn.State.InZone,
		Part = part,
	}
	memelings[instanceId] = record
	return record
end

-- Запись мемлинга по InstanceId или nil, если такого нет
function Spawn.Get(instanceId)
	return memelings[instanceId]
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
	print(string.format("[Spawn] В зоне появилось мемлингов: %d (%s)", nextNumber, SPAWN_RARITY))
end

return Spawn
