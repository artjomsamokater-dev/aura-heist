--!strict
-- Announcer: объявления всем игрокам на сервере (сервер → клиенты).
-- Сейчас одно: «A LEGENDARY appeared in the DANGER zone!» — когда при спавне или рестоке появился
-- мемлинг редкости из ZoneConfig.AnnounceRarities. Одно объявление на один спавн — только про самого редкого.
-- Клиенту уходят только Id редкости и части зоны; текст и цвет он берёт из TextConfig и StyleConfig.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MemelingConfig = require(ReplicatedStorage.Shared.Config.MemelingConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local RarityRoll = require(ReplicatedStorage.Shared.Util.RarityRoll)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Announcer = {}

local announcement: RemoteEvent? = nil

-- Объявить о самом редком из одного спавна (если он достоин объявления)
function Announcer.AnnounceSpawn(spawned: { RarityRoll.Spawned })
	local event = announcement
	if event == nil then
		return
	end
	local index = RarityRoll.Rarest(spawned, MemelingConfig.RarityOrder, ZoneConfig.AnnounceRarities)
	if index == nil then
		return
	end
	local rarest = spawned[index]
	event:FireAllClients(rarest.Rarity, rarest.Part)
	print(string.format("[Announcer] Объявление всем: %s в части %s", rarest.Rarity, rarest.Part))
end

function Announcer.Start()
	local folder = ReplicatedStorage:FindFirstChild(Remotes.Folder)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = Remotes.Folder
		folder.Parent = ReplicatedStorage
	end
	local event = Instance.new("RemoteEvent")
	event.Name = Remotes.Announcement
	event.Parent = folder
	announcement = event
	-- OnServerEvent не подключаем: это событие только от сервера к клиентам
end

return Announcer
