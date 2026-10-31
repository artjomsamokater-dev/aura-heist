--!strict
-- DebugCommands: команды для проверки в Studio. В опубликованной игре их НЕТ (RunService:IsStudio()).
--   /aura <число> — добавить себе столько Aura (через Economy, как любое начисление), чтобы быстро
--                   проверять дорогие улучшения и Rebirth. Пример: /aura 100000
--   /memelings    — поставить перед собой ряд из всех 8 мемлингов (от Common к Legendary), чтобы
--                   посмотреть модели. Повторная команда убирает ряд. Это только картинка: подобрать нельзя.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local MemelingConfig = require(ReplicatedStorage.Shared.Config.MemelingConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local Economy = require(script.Parent.Economy)
local MapBuilder = require(script.Parent.MapBuilder)

local DebugCommands = {}

local MAX_AURA = 10_000_000 -- больше за раз не даём даже в Studio, чтобы не сломать подписи опечаткой
local LINEUP_NAME = "DebugMemelingLineup"
local LINEUP_STEP = 7 -- расстояние между мемлингами в ряду, в студах
local LINEUP_DISTANCE = 14 -- на сколько студов перед игроком ряд

-- Все Id мемлингов: от Common к Legendary, внутри редкости — по алфавиту
local function getLineupIds(): { string }
	local rank: { [string]: number } = {}
	for i, rarity in ipairs(MemelingConfig.RarityOrder) do
		rank[rarity] = i
	end
	local ids: { string } = {}
	for id in MemelingConfig.Memelings do
		table.insert(ids, id)
	end
	table.sort(ids, function(a: string, b: string): boolean
		local ra = rank[MemelingConfig.Memelings[a].Rarity] or 0
		local rb = rank[MemelingConfig.Memelings[b].Rarity] or 0
		if ra ~= rb then
			return ra < rb
		end
		return a < b
	end)
	return ids
end

local function toggleLineup(player: Player)
	local old = Workspace:FindFirstChild(LINEUP_NAME)
	if old then
		old:Destroy()
		print("[Debug] Ряд мемлингов убран")
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		print("[Debug] /memelings: нет персонажа")
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = LINEUP_NAME
	folder.Parent = Workspace
	local ids = getLineupIds()
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local forward = if look.Magnitude > 0.01 then look.Unit else -Vector3.zAxis
	local right = forward:Cross(Vector3.yAxis)
	-- Ряд на уровне ног игрока; мемлинги смотрят лицом на игрока
	local floorY = root.Position.Y - (root.Size.Y / 2 + 2)
	local middle = Vector3.new(root.Position.X, floorY + StyleConfig.Memeling.Size.Y / 2, root.Position.Z) + forward * LINEUP_DISTANCE
	for i, id in ipairs(ids) do
		local position = middle + right * ((i - (#ids + 1) / 2) * LINEUP_STEP)
		local core = MapBuilder.MakeMemeling("Lineup" .. i, id, CFrame.lookAt(position, position - forward), folder)
		MapBuilder.AddLabel(core, TextConfig.MemelingNames[id] or id, {
			MaxDistance = StyleConfig.Label.MaxDistance,
			Height = StyleConfig.Memeling.LabelHeight,
			Scale = StyleConfig.Label.MemelingScale,
		})
	end
	print(string.format("[Debug] Ряд из %d мемлингов перед %s (повторите /memelings, чтобы убрать)", #ids, player.Name))
end

local function giveAura(player: Player, text: string)
	local amount = tonumber(string.match(text, "^/aura%s+(%d+)%s*$"))
	if amount == nil or amount < 1 then
		print("[Debug] Формат команды: /aura 100000")
		return
	end
	Economy.AddBankedAura(player, math.min(math.floor(amount), MAX_AURA), "отладка /aura")
end

-- Команды: алиас в чате → что делать
local COMMANDS: { { Name: string, Alias: string, Run: (player: Player, text: string) -> () } } = {
	{ Name = "DebugAura", Alias = "/aura", Run = giveAura },
	{ Name = "DebugMemelings", Alias = "/memelings", Run = function(player: Player, _text: string)
		toggleLineup(player)
	end },
}

function DebugCommands.Start()
	if not RunService:IsStudio() then
		return -- только в Studio
	end

	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		-- Новый чат Roblox: по TextChatCommand на команду
		for _, spec in ipairs(COMMANDS) do
			local command = Instance.new("TextChatCommand")
			command.Name = spec.Name
			command.PrimaryAlias = spec.Alias
			command.Parent = TextChatService
			command.Triggered:Connect(function(source: TextSource, text: string)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player then
					spec.Run(player, text)
				end
			end)
		end
	else
		-- Старый чат: ловим сообщения игроков
		local function watch(player: Player)
			player.Chatted:Connect(function(message: string)
				local word = string.match(message, "^(%S+)")
				for _, spec in ipairs(COMMANDS) do
					if word == spec.Alias then
						spec.Run(player, message)
					end
				end
			end)
		end
		Players.PlayerAdded:Connect(watch)
		for _, player in ipairs(Players:GetPlayers()) do
			watch(player)
		end
	end
	print("[Debug] В Studio доступны команды /aura <число> и /memelings")
end

return DebugCommands
