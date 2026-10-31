--!strict
-- Extraction: точка эвакуации в зоне.
-- Игрок InRaid стоит на точке ZoneConfig.EvacuationSeconds секунд подряд —
-- он возвращается в хаб, а всё, что было в руках, переходит на витрину.
-- Ушёл с точки или умер — отсчёт сбрасывается. Награда — ровно один раз (флаг в Raid).
-- Бонус отряда: эвакуировались рядом и почти одновременно — принесённые обоими дороже при продаже.
-- Всё решает сервер по позиции персонажа; клиент ничего не присылает.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local SquadRule = require(ReplicatedStorage.Shared.Util.SquadRule)
local MapBuilder = require(script.Parent.MapBuilder)
local Announcer = require(script.Parent.Announcer)
local Raid = require(script.Parent.Raid)
local Studio = require(script.Parent.Studio)
local PlayerData = require(script.Parent.PlayerData)
local Tutorial = require(script.Parent.Tutorial)
local Analytics = require(script.Parent.Analytics)
local MemelingConfig = require(ReplicatedStorage.Shared.Config.MemelingConfig)
local RemoteGuard = require(ServerScriptService.Server.Security.RemoteGuard)

local Extraction = {}

local holdStartedAt: { [Player]: number } = {} -- когда игрок встал на точку (os.clock)
local lastLabelText = ""

-- Стоит ли персонаж на площадке: по горизонтали в радиусе, по высоте — не выше прыжка
local function isOnPoint(root: BasePart): boolean
	local offset = root.Position - MapConfig.Zone.ExtractionPosition
	local flatDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
	return flatDistance <= ZoneConfig.EvacuationDistance
		and offset.Y >= 0
		and offset.Y <= MapConfig.Zone.ExtractionMaxHeight
end

type Brought = {
	Player: Player,
	Entries: { Studio.BroughtEntry },
}

-- Недавние эвакуации (за последние SquadBonus.WindowSeconds) — для бонуса отряда
local recent: { SquadRule.Extraction } = {}
local broughtBy: { [SquadRule.Extraction]: Brought } = setmetatable({}, { __mode = "k" }) :: any

-- Бонус отряда: эвакуировались рядом и почти одновременно — оба получают +% к цене продажи
-- принесённых мемлингов. Каждая эвакуация — не больше одного раза (флаг Bonus до выдачи)
-- Вернёт true, если эта эвакуация уже получила бонус (игрок эвакуировался вторым в отряде)
local function applySquadBonus(player: Player, position: Vector3, entries: { Studio.BroughtEntry }): boolean
	local cfg = EconomyConfig.SquadBonus
	local now = os.clock()
	SquadRule.Prune(recent, now, cfg.WindowSeconds)

	local mine: SquadRule.Extraction = { OwnerId = player.UserId, X = position.X, Z = position.Z, Time = now, Bonus = false }
	broughtBy[mine] = { Player = player, Entries = entries }
	local partners = SquadRule.FindPartners(mine, recent, cfg.Radius, cfg.WindowSeconds)
	table.insert(recent, mine)
	if #partners == 0 then
		return false
	end

	local winners: { Player } = {}
	local function grant(extraction: SquadRule.Extraction)
		local brought = broughtBy[extraction]
		if extraction.Bonus or brought == nil or brought.Player.Parent == nil then
			return
		end
		extraction.Bonus = true -- флаг до выдачи: второй раз этой эвакуации бонус не дадут
		Studio.ApplySquadBonus(brought.Player, brought.Entries)
		local data = PlayerData.GetData(brought.Player)
		if data then
			data.stats.squadBonuses += 1
		end
		table.insert(winners, brought.Player)
	end
	grant(mine)
	for _, index in ipairs(partners) do
		grant(recent[index])
	end

	if #winners > 0 then
		Announcer.SquadBonus(winners)
		local names = {}
		for _, winner in ipairs(winners) do
			table.insert(names, winner.Name)
		end
		print(string.format("[Extraction] Бонус отряда: %s", table.concat(names, ", ")))
	end
	return mine.Bonus
end

-- Самая редкая редкость среди вынесенных ("" — пустые руки) — для аналитики
local function rarestOf(memelingIds: { string }): string
	local best, bestRank = "", 0
	for _, id in ipairs(memelingIds) do
		local memeling = MemelingConfig.Memelings[id]
		local rank = memeling and table.find(MemelingConfig.RarityOrder, memeling.Rarity) or 0
		if memeling and rank > bestRank then
			best, bestRank = memeling.Rarity, rank
		end
	end
	return best
end

local function complete(player: Player)
	-- Где игрок эвакуировался — запоминаем до переноса в хаб (для бонуса отряда)
	local _, root = RemoteGuard.GetAliveCharacter(player)
	local position = if root then root.Position else MapConfig.Zone.ExtractionPosition

	local memelingIds, raidSeconds = Raid.ClaimExtraction(player)
	if memelingIds == nil then
		return -- награда за эту вылазку уже выдана
	end
	local entries = Studio.AddToShowcase(player, memelingIds)
	local squad = applySquadBonus(player, position, entries)
	local data = PlayerData.GetData(player)
	if data then
		data.stats.extractions += 1
		data.stats.memelingsExtracted += #memelingIds
	end
	Raid.ReturnToHub(player)
	Announcer.ExtractionResult(player, memelingIds, raidSeconds, squad)
	Analytics.ExtractionSuccess(player, #memelingIds, rarestOf(memelingIds), squad)
	Tutorial.Notify(player, "Extract")
	print(
		string.format(
			"[Extraction] %s эвакуировался, на витрину: %d (%s)",
			player.Name,
			#memelingIds,
			table.concat(memelingIds, ", ")
		)
	)
end

-- Подпись над точкой: сколько секунд осталось у того, кто ближе всех к успеху
local function updateLabel(now: number)
	local bestRemaining: number? = nil
	for _, startedAt in holdStartedAt do
		local remaining = ZoneConfig.EvacuationSeconds - (now - startedAt)
		if bestRemaining == nil or remaining < bestRemaining then
			bestRemaining = remaining
		end
	end

	local text = TextConfig.Extraction
	if bestRemaining ~= nil then
		text = string.format(TextConfig.ExtractionProgress, math.max(1, math.ceil(bestRemaining)))
	end
	if text ~= lastLabelText then
		lastLabelText = text
		MapBuilder.SetLabelText(MapBuilder.GetExtractionPad(), text)
	end
end

local function check()
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local _, root = RemoteGuard.GetAliveCharacter(player)
		local onPoint = root ~= nil and Raid.GetState(player) == Raid.State.InRaid and isOnPoint(root)
		local startedAt = holdStartedAt[player]

		if onPoint then
			if startedAt == nil then
				holdStartedAt[player] = now
				print(string.format("[Extraction] %s встал на точку эвакуации", player.Name))
			elseif now - startedAt >= ZoneConfig.EvacuationSeconds then
				holdStartedAt[player] = nil
				complete(player)
			end
		elseif startedAt ~= nil then
			-- Ушёл с точки, умер или уже не в вылазке — отмена
			holdStartedAt[player] = nil
			print(string.format("[Extraction] %s: эвакуация отменена", player.Name))
		end
	end
	updateLabel(now)
end

function Extraction.Start()
	Players.PlayerRemoving:Connect(function(player)
		holdStartedAt[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(ZoneConfig.EvacuationCheckSeconds)
			check()
		end
	end)
end

return Extraction
