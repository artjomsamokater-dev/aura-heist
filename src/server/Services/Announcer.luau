--!strict
-- Announcer: объявления игрокам (сервер → клиенты).
-- • «A LEGENDARY appeared in the DANGER zone!» — всем, когда при спавне или рестоке появился
--   мемлинг редкости из ZoneConfig.AnnounceRarities. Одно объявление на один спавн — только про самого редкого.
-- • «SQUAD BONUS!» — двум игрокам, которые эвакуировались вместе (сервис Extraction).
-- Клиенту уходят только Id редкости и части зоны; текст и цвет он берёт из TextConfig и StyleConfig.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MemelingConfig = require(ReplicatedStorage.Shared.Config.MemelingConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local RarityRoll = require(ReplicatedStorage.Shared.Util.RarityRoll)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(game:GetService("ServerScriptService").Server.Security.RemoteGuard)

local Announcer = {}

local announcement: RemoteEvent? = nil
local squadBonus: RemoteEvent? = nil

-- Плашка «SQUAD BONUS!» этим игрокам (оба участника отряда)
function Announcer.SquadBonus(players: { Player })
	local event = squadBonus
	if event == nil then
		return
	end
	for _, player in ipairs(players) do
		if player.Parent then
			event:FireClient(player)
		end
	end
end

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
	announcement = RemoteGuard.CreateRemote(Remotes.Announcement)
	squadBonus = RemoteGuard.CreateRemote(Remotes.SquadBonus)
	-- OnServerEvent не подключаем: эти события только от сервера к клиентам
end

return Announcer
