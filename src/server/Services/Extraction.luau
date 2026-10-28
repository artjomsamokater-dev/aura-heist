--!strict
-- Extraction: точка эвакуации в зоне.
-- Игрок InRaid стоит на точке ZoneConfig.EvacuationSeconds секунд подряд —
-- он возвращается в хаб, а всё, что было в руках, переходит на витрину.
-- Ушёл с точки или умер — отсчёт сбрасывается. Награда — ровно один раз (флаг в Raid).
-- Всё решает сервер по позиции персонажа; клиент ничего не присылает.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local MapBuilder = require(script.Parent.MapBuilder)
local Raid = require(script.Parent.Raid)
local Studio = require(script.Parent.Studio)
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

local function complete(player: Player)
	local memelingIds = Raid.ClaimExtraction(player)
	if memelingIds == nil then
		return -- награда за эту вылазку уже выдана
	end
	Studio.AddToShowcase(player, memelingIds)
	Raid.ReturnToHub(player)
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
