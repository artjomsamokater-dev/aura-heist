--!strict
-- Studio: участки баз (студии), постаменты и витрина.
-- Вошёл — получил первый свободный участок, вышел — участок снова свободен.
-- Если свободных нет, игрок просто играет без участка.
--
-- Витрина и запас живут в профиле игрока (PlayerData): data.showcase и data.reserve.
-- Здесь в памяти только то, что нарисовано в мире (мемлинги на постаментах).
-- Постамент копит Aura от lastCollect (PedestalMath), поэтому офлайн-доход считается сам
-- и упирается в лимит хранилища. Собранная Aura начисляется только через Economy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local MemelingConfig = require(ReplicatedStorage.Shared.Config.MemelingConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local SecurityConfig = require(ReplicatedStorage.Shared.Config.SecurityConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local formatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local PedestalMath = require(ReplicatedStorage.Shared.Util.PedestalMath)
local MapBuilder = require(script.Parent.MapBuilder)
local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local RemoteGuard = require(ServerScriptService.Server.Security.RemoteGuard)
local RateLimiter = require(ServerScriptService.Server.Security.RateLimiter)

local Studio = {}

type ShowcaseEntry = PlayerData.ShowcaseEntry

-- Мемлинг, нарисованный на постаменте: строка профиля + его модель в мире
type Slot = {
	Entry: ShowcaseEntry,
	Body: Part,
}

local plotOwners: { [number]: Player? } = {} -- [номер участка] = Player
local playerPlots: { [Player]: number } = {} -- [Player] = номер участка
local rendered: { [Player]: { [number]: Slot } } = {} -- [Player][номер постамента] = Slot

local collectLimiter =
	RateLimiter.new(SecurityConfig.RateLimits.Collect.MaxRequests, SecurityConfig.RateLimits.Collect.WindowSeconds)

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- ── Числа постаментов ──────────────────────────────────────────────────────

-- Сколько постаментов игрок может занять (улучшения — задача 2.2)
local function getPedestalCount(_data: PlayerData.Data): number
	return math.min(UpgradeConfig.Pedestals.StartCount, #MapConfig.Plots.PedestalOffsets)
end

-- Лимит хранилища в секундах дохода (улучшение — задача 2.2)
local function getStorageSeconds(_data: PlayerData.Data): number
	return UpgradeConfig.Storage.StartSeconds
end

local function getRate(memelingId: string): number
	local memeling = MemelingConfig.Memelings[memelingId]
	local rarity = memeling and MemelingConfig.Rarities[memeling.Rarity]
	return if rarity then rarity.AuraPerSecond else 0
end

-- ── Мир: постаменты участка ────────────────────────────────────────────────

local function getPedestal(plotIndex: number, pedestalIndex: number): Part?
	local plot = MapBuilder.GetPlots()[plotIndex]
	local folder = plot and plot:FindFirstChild("Pedestals")
	local pedestal = folder and folder:FindFirstChild("Pedestal" .. pedestalIndex)
	if pedestal and pedestal:IsA("Part") then
		return pedestal
	end
	return nil
end

local function setPromptEnabled(pedestal: Part, name: string, enabled: boolean)
	local prompt = pedestal:FindFirstChild(name)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = enabled
	end
end

local function publishCounts(player: Player)
	local data = PlayerData.GetData(player)
	player:SetAttribute("PedestalMemelings", if data then #data.showcase else 0)
	player:SetAttribute("ReserveCount", if data then #data.reserve else 0)
end

local function updatePedestalLabel(pedestal: Part, entry: ShowcaseEntry, data: PlayerData.Data, at: number)
	local rate = getRate(entry.memelingId)
	local storageSeconds = getStorageSeconds(data)
	local stored = PedestalMath.GetStored(rate, entry.lastCollect, at, storageSeconds)
	local full = stored >= rate * storageSeconds
	local format = if full then TextConfig.PedestalFull else TextConfig.PedestalStored
	MapBuilder.SetLabelText(pedestal, string.format(format, formatNumber(stored)))
end

-- Рисует мемлинга на постаменте: мемлинг с именем и доходом, над ним — накоплено
local function renderEntry(player: Player, plotIndex: number, entry: ShowcaseEntry, data: PlayerData.Data)
	local pedestal = getPedestal(plotIndex, entry.pedestal)
	if pedestal == nil or MemelingConfig.Memelings[entry.memelingId] == nil then
		return
	end

	local size = StyleConfig.Memeling.Size
	local labelStyle = StyleConfig.Label
	-- Постамент повёрнут как участок: -Z смотрит на хаб, туда же смотрит и мемлинг
	local body = MapBuilder.MakeMemeling(
		"Memeling",
		entry.memelingId,
		pedestal.CFrame * CFrame.new(0, pedestal.Size.Y / 2 + size.Y / 2, 0),
		pedestal
	)
	body:SetAttribute("MemelingId", entry.memelingId)
	local name = TextConfig.MemelingNames[entry.memelingId] or entry.memelingId
	MapBuilder.AddLabel(
		body,
		string.format(TextConfig.PedestalMemeling, name, getRate(entry.memelingId)),
		{ MaxDistance = labelStyle.MemelingMaxDistance }
	)

	-- Подпись «накоплено» висит выше подписи мемлинга, с зазором
	MapBuilder.AddLabel(pedestal, "", {
		Height = pedestal.Size.Y / 2 + size.Y + labelStyle.HeightStuds * 1.5 + labelStyle.PedestalAuraGap,
	})

	rendered[player] = rendered[player] or {}
	rendered[player][entry.pedestal] = { Entry = entry, Body = body }
	updatePedestalLabel(pedestal, entry, data, now())
	setPromptEnabled(pedestal, "CollectPrompt", true)
end

-- Убирает мемлинга с постамента в мире (профиль не трогает)
local function unrenderPedestal(player: Player, plotIndex: number, pedestalIndex: number)
	local playerSlots = rendered[player]
	local slot = playerSlots and playerSlots[pedestalIndex]
	if slot then
		slot.Body:Destroy()
		playerSlots[pedestalIndex] = nil
	end
	local pedestal = getPedestal(plotIndex, pedestalIndex)
	if pedestal then
		local label = pedestal:FindFirstChild("Label")
		if label then
			label:Destroy()
		end
		setPromptEnabled(pedestal, "CollectPrompt", false)
	end
end

-- Рисует всю витрину игрока на его участке (после загрузки профиля)
local function renderShowcase(player: Player)
	local plotIndex = playerPlots[player]
	local data = PlayerData.GetData(player)
	if plotIndex == nil or data == nil then
		return
	end
	for _, entry in ipairs(data.showcase) do
		if rendered[player] == nil or rendered[player][entry.pedestal] == nil then
			renderEntry(player, plotIndex, entry, data)
		end
	end
	publishCounts(player)
end

local function clearPlot(player: Player, plotIndex: number)
	local playerSlots = rendered[player]
	if playerSlots then
		for pedestalIndex in playerSlots do
			unrenderPedestal(player, plotIndex, pedestalIndex)
		end
	end
	rendered[player] = nil
end

-- ── Сбор Aura ──────────────────────────────────────────────────────────────

-- Игрок нажал «Collect» на постаменте. Все проверки — на сервере.
local function tryCollect(player: Player, plotIndex: number, pedestalIndex: number)
	if not collectLimiter.Allow(player) then
		return
	end
	if playerPlots[player] ~= plotIndex then
		return -- чужой участок
	end
	local _, root = RemoteGuard.GetAliveCharacter(player)
	local data = PlayerData.GetData(player)
	local pedestal = getPedestal(plotIndex, pedestalIndex)
	local slot = rendered[player] and rendered[player][pedestalIndex]
	if root == nil or data == nil or pedestal == nil or slot == nil then
		return
	end
	if not RemoteGuard.IsNear(root, pedestal.Position, EconomyConfig.CollectDistance) then
		return
	end

	local at = now()
	local entry = slot.Entry
	local amount, newLastCollect =
		PedestalMath.Collect(getRate(entry.memelingId), entry.lastCollect, at, getStorageSeconds(data))
	if amount < 1 then
		return
	end

	-- Сначала забираем Aura с постамента, потом начисляем: повторное нажатие уже ничего не найдёт
	entry.lastCollect = newLastCollect
	updatePedestalLabel(pedestal, entry, data, at)
	Economy.AddBankedAura(player, amount, "сбор с постамента " .. pedestalIndex)
end

local function addCollectPrompts()
	for plotIndex = 1, #MapBuilder.GetPlots() do
		for pedestalIndex = 1, #MapConfig.Plots.PedestalOffsets do
			local pedestal = getPedestal(plotIndex, pedestalIndex)
			if pedestal then
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "CollectPrompt"
				prompt.ActionText = TextConfig.CollectAction
				prompt.MaxActivationDistance = EconomyConfig.CollectDistance
				prompt.HoldDuration = 0
				prompt.RequiresLineOfSight = false
				prompt.Enabled = false -- включается, когда на постаменте стоит мемлинг
				prompt.Parent = pedestal
				prompt.Triggered:Connect(function(player: Player)
					tryCollect(player, plotIndex, pedestalIndex)
				end)
			end
		end
	end
end

-- ── Участки ────────────────────────────────────────────────────────────────

local function assignPlot(player: Player)
	if playerPlots[player] then
		return
	end

	for index, plot in ipairs(MapBuilder.GetPlots()) do
		if plotOwners[index] == nil then
			plotOwners[index] = player
			playerPlots[player] = index
			plot:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("StudioIndex", index)
			MapBuilder.SetLabelText(plot:FindFirstChild("Sign"), string.format(TextConfig.OwnedPlot, player.DisplayName))
			print(string.format("[Studio] %s получил участок %d", player.Name, index))
			renderShowcase(player) -- если профиль уже загружен
			return
		end
	end

	warn(string.format("[Studio] Свободных участков нет, %s играет без участка", player.Name))
end

local function releasePlot(player: Player)
	local index = playerPlots[player]
	if not index then
		rendered[player] = nil
		return
	end
	clearPlot(player, index)

	playerPlots[player] = nil
	plotOwners[index] = nil

	local plot = MapBuilder.GetPlots()[index]
	if plot then
		plot:SetAttribute("OwnerUserId", 0)
		MapBuilder.SetLabelText(plot:FindFirstChild("Sign"), TextConfig.FreePlot)
	end
	print(string.format("[Studio] Участок %d освобождён (%s вышел)", index, player.Name))
end

-- Model участка игрока или nil, если участка нет
function Studio.GetPlot(player: Player): Model?
	local index = playerPlots[player]
	return index and MapBuilder.GetPlots()[index] or nil
end

-- ── Витрина ────────────────────────────────────────────────────────────────

-- Первый свободный постамент из доступных игроку или nil
local function findFreePedestal(data: PlayerData.Data): number?
	local taken: { [number]: boolean } = {}
	for _, entry in ipairs(data.showcase) do
		taken[entry.pedestal] = true
	end
	for pedestalIndex = 1, getPedestalCount(data) do
		if not taken[pedestalIndex] then
			return pedestalIndex
		end
	end
	return nil
end

-- Вынесенные мемлинги: на свободные постаменты, остальные — в запас (вызывает Extraction)
function Studio.AddToShowcase(player: Player, memelingIds: { string })
	local data = PlayerData.GetData(player)
	if data == nil then
		warn(string.format("[Studio] Профиль %s не загружен — мемлинги не сохранены", player.Name))
		return
	end
	local plotIndex = playerPlots[player]

	for _, memelingId in ipairs(memelingIds) do
		local freeIndex = findFreePedestal(data)
		if freeIndex then
			local entry: ShowcaseEntry = { pedestal = freeIndex, memelingId = memelingId, lastCollect = now() }
			table.insert(data.showcase, entry)
			if plotIndex then
				renderEntry(player, plotIndex, entry, data)
			end
			print(string.format("[Studio] %s: %s на постаменте %d", player.Name, memelingId, freeIndex))
		else
			table.insert(data.reserve, memelingId)
			print(string.format("[Studio] %s: %s в запасе (нет свободного постамента)", player.Name, memelingId))
		end
	end
	publishCounts(player)
end

local function updateAllLabels()
	local at = now()
	for player, playerSlots in rendered do
		local plotIndex = playerPlots[player]
		local data = PlayerData.GetData(player)
		if plotIndex and data then
			for pedestalIndex, slot in playerSlots do
				local pedestal = getPedestal(plotIndex, pedestalIndex)
				if pedestal then
					updatePedestalLabel(pedestal, slot.Entry, data, at)
				end
			end
		end
	end
end

function Studio.Start()
	addCollectPrompts()

	Players.PlayerAdded:Connect(assignPlot)
	Players.PlayerRemoving:Connect(releasePlot)
	PlayerData.OnLoaded(function(player)
		renderShowcase(player)
	end)

	-- Игроки, которые успели зайти до запуска сервиса
	for _, player in ipairs(Players:GetPlayers()) do
		assignPlot(player)
	end

	task.spawn(function()
		while true do
			task.wait(EconomyConfig.PedestalLabelUpdateSeconds)
			updateAllLabels()
		end
	end)
end

return Studio
