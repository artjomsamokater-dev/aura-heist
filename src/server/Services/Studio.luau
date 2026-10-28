--!strict
-- Studio: участки баз (студии), постаменты и витрина.
-- Вошёл — получил первый свободный участок, вышел — участок снова свободен.
-- Если свободных нет, игрок просто играет без участка.
-- Вынесенные мемлинги встают на свободные постаменты своего участка, остальные — «в запас».
-- Постамент копит Aura по доходу редкости, но не больше UpgradeConfig.Storage.StartSeconds секунд дохода.
-- Собранная Aura начисляется только через Economy. Всё пока в памяти сервера (сохранение — задача 2.1).

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
local formatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local MapBuilder = require(script.Parent.MapBuilder)
local Economy = require(script.Parent.Economy)
local RemoteGuard = require(ServerScriptService.Server.Security.RemoteGuard)
local RateLimiter = require(ServerScriptService.Server.Security.RateLimiter)

local Studio = {}

-- Мемлинг на постаменте
type Slot = {
	MemelingId: string,
	StartedAt: number, -- с какого момента (время сервера) копится Aura; сбор сдвигает его вперёд
	Cube: Part,
}

local plotOwners: { [number]: Player? } = {} -- [номер участка] = Player
local playerPlots: { [Player]: number } = {} -- [Player] = номер участка
local slots: { [Player]: { [number]: Slot } } = {} -- [Player][номер постамента] = Slot
local reserves: { [Player]: { string } } = {} -- [Player] = MemelingId «в запасе» (не хватило постаментов)

local collectLimiter =
	RateLimiter.new(SecurityConfig.RateLimits.Collect.MaxRequests, SecurityConfig.RateLimits.Collect.WindowSeconds)

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Сколько постаментов игрок может занять (улучшения — задача 2.2)
local function getPedestalCount(): number
	return math.min(UpgradeConfig.Pedestals.StartCount, #MapConfig.Plots.PedestalOffsets)
end

local function getRate(memelingId: string): number
	local memeling = MemelingConfig.Memelings[memelingId]
	local rarity = memeling and MemelingConfig.Rarities[memeling.Rarity]
	return if rarity then rarity.AuraPerSecond else 0
end

local function getCapacity(memelingId: string): number
	return getRate(memelingId) * UpgradeConfig.Storage.StartSeconds
end

-- Сколько Aura накоплено на постаменте сейчас (может быть дробным; игроку показываем вниз)
local function getStored(slot: Slot, at: number): number
	local stored = (at - slot.StartedAt) * getRate(slot.MemelingId)
	return math.clamp(stored, 0, getCapacity(slot.MemelingId))
end

local function getPedestal(plotIndex: number, pedestalIndex: number): Part?
	local plot = MapBuilder.GetPlots()[plotIndex]
	local folder = plot and plot:FindFirstChild("Pedestals")
	local pedestal = folder and folder:FindFirstChild("Pedestal" .. pedestalIndex)
	if pedestal and pedestal:IsA("Part") then
		return pedestal
	end
	return nil
end

local function setPromptEnabled(pedestal: Part, enabled: boolean)
	local prompt = pedestal:FindFirstChild("CollectPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = enabled
	end
end

local function publishCounts(player: Player)
	local placed = 0
	local playerSlots = slots[player]
	if playerSlots then
		for _ in playerSlots do
			placed += 1
		end
	end
	player:SetAttribute("PedestalMemelings", placed)
	player:SetAttribute("ReserveCount", #(reserves[player] or {}))
end

local function updatePedestalLabel(pedestal: Part, slot: Slot, at: number)
	local stored = getStored(slot, at)
	local format = if stored >= getCapacity(slot.MemelingId) then TextConfig.PedestalFull else TextConfig.PedestalStored
	MapBuilder.SetLabelText(pedestal, string.format(format, formatNumber(stored)))
end

-- Ставит мемлинга на постамент: серый куб с именем и доходом, над ним — накоплено
local function placeOnPedestal(player: Player, plotIndex: number, pedestalIndex: number, memelingId: string)
	local pedestal = getPedestal(plotIndex, pedestalIndex)
	if pedestal == nil then
		return
	end

	local size = MapConfig.Memeling.Size
	local cube = MapBuilder.MakePart(
		"Memeling",
		size,
		pedestal.CFrame * CFrame.new(0, pedestal.Size.Y / 2 + size.Y / 2, 0),
		MapConfig.Colors.Memeling,
		pedestal
	)
	cube:SetAttribute("MemelingId", memelingId)
	local name = TextConfig.MemelingNames[memelingId] or memelingId
	MapBuilder.AddLabel(cube, string.format(TextConfig.PedestalMemeling, name, getRate(memelingId)))

	-- Подпись «накоплено» висит над подписью куба
	MapBuilder.AddLabel(pedestal, "", pedestal.Size.Y / 2 + size.Y + MapConfig.Label.HeightStuds * 1.5)

	local slot: Slot = { MemelingId = memelingId, StartedAt = now(), Cube = cube }
	slots[player] = slots[player] or {}
	slots[player][pedestalIndex] = slot
	updatePedestalLabel(pedestal, slot, now())
	setPromptEnabled(pedestal, true)
end

-- Убирает всё с постаментов игрока (при выходе)
local function clearPedestals(player: Player, plotIndex: number?)
	local playerSlots = slots[player]
	slots[player] = nil
	reserves[player] = nil
	if playerSlots == nil or plotIndex == nil then
		return
	end
	for pedestalIndex, slot in playerSlots do
		slot.Cube:Destroy()
		local pedestal = getPedestal(plotIndex, pedestalIndex)
		if pedestal then
			local label = pedestal:FindFirstChild("Label")
			if label then
				label:Destroy()
			end
			setPromptEnabled(pedestal, false)
		end
	end
end

-- Игрок нажал «Collect» на постаменте. Все проверки — на сервере.
local function tryCollect(player: Player, plotIndex: number, pedestalIndex: number)
	if not collectLimiter.Allow(player) then
		return
	end
	if playerPlots[player] ~= plotIndex then
		return -- чужой участок
	end
	local _, root = RemoteGuard.GetAliveCharacter(player)
	if root == nil then
		return
	end
	local pedestal = getPedestal(plotIndex, pedestalIndex)
	local slot = slots[player] and slots[player][pedestalIndex]
	if pedestal == nil or slot == nil then
		return
	end
	if not RemoteGuard.IsNear(root, pedestal.Position, EconomyConfig.CollectDistance) then
		return
	end

	local at = now()
	local stored = getStored(slot, at)
	local amount = math.floor(stored)
	if amount < 1 then
		return
	end

	-- Сначала забираем Aura с постамента (дробный остаток остаётся копиться), потом начисляем
	slot.StartedAt = at - (stored - amount) / getRate(slot.MemelingId)
	updatePedestalLabel(pedestal, slot, at)
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
			publishCounts(player)
			print(string.format("[Studio] %s получил участок %d", player.Name, index))
			return
		end
	end

	publishCounts(player)
	warn(string.format("[Studio] Свободных участков нет, %s играет без участка", player.Name))
end

local function releasePlot(player: Player)
	local index = playerPlots[player]
	clearPedestals(player, index)
	if not index then
		return
	end

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

-- Вынесенные мемлинги: на свободные постаменты, остальные — в запас (вызывает Extraction)
function Studio.AddToShowcase(player: Player, memelingIds: { string })
	local plotIndex = playerPlots[player]
	local playerSlots = slots[player] or {}
	local reserve = reserves[player] or {}
	reserves[player] = reserve

	for _, memelingId in ipairs(memelingIds) do
		local freeIndex: number? = nil
		if plotIndex then
			for pedestalIndex = 1, getPedestalCount() do
				if playerSlots[pedestalIndex] == nil then
					freeIndex = pedestalIndex
					break
				end
			end
		end

		if plotIndex and freeIndex then
			placeOnPedestal(player, plotIndex, freeIndex, memelingId)
			playerSlots = slots[player] or playerSlots
			print(string.format("[Studio] %s: %s на постаменте %d", player.Name, memelingId, freeIndex))
		else
			table.insert(reserve, memelingId)
			print(string.format("[Studio] %s: %s в запасе (нет свободного постамента)", player.Name, memelingId))
		end
	end
	publishCounts(player)
end

local function updateAllLabels()
	local at = now()
	for player, playerSlots in slots do
		local plotIndex = playerPlots[player]
		if plotIndex then
			for pedestalIndex, slot in playerSlots do
				local pedestal = getPedestal(plotIndex, pedestalIndex)
				if pedestal then
					updatePedestalLabel(pedestal, slot, at)
				end
			end
		end
	end
end

function Studio.Start()
	addCollectPrompts()

	Players.PlayerAdded:Connect(assignPlot)
	Players.PlayerRemoving:Connect(releasePlot)

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
