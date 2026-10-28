--!strict
-- Studio: ÑƒÑ‡Ð°ÑÑ‚ÐºÐ¸ Ð±Ð°Ð· (ÑÑ‚ÑƒÐ´Ð¸Ð¸), Ð¿Ð¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚Ñ‹ Ð¸ Ð²Ð¸Ñ‚Ñ€Ð¸Ð½Ð°.
-- Ð’Ð¾ÑˆÑ‘Ð» â€” Ð¿Ð¾Ð»ÑƒÑ‡Ð¸Ð» Ð¿ÐµÑ€Ð²Ñ‹Ð¹ ÑÐ²Ð¾Ð±Ð¾Ð´Ð½Ñ‹Ð¹ ÑƒÑ‡Ð°ÑÑ‚Ð¾Ðº, Ð²Ñ‹ÑˆÐµÐ» â€” ÑƒÑ‡Ð°ÑÑ‚Ð¾Ðº ÑÐ½Ð¾Ð²Ð° ÑÐ²Ð¾Ð±Ð¾Ð´ÐµÐ½.
-- Ð•ÑÐ»Ð¸ ÑÐ²Ð¾Ð±Ð¾Ð´Ð½Ñ‹Ñ… Ð½ÐµÑ‚, Ð¸Ð³Ñ€Ð¾Ðº Ð¿Ñ€Ð¾ÑÑ‚Ð¾ Ð¸Ð³Ñ€Ð°ÐµÑ‚ Ð±ÐµÐ· ÑƒÑ‡Ð°ÑÑ‚ÐºÐ°.
--
-- Ð’Ð¸Ñ‚Ñ€Ð¸Ð½Ð° Ð¸ Ð·Ð°Ð¿Ð°Ñ Ð¶Ð¸Ð²ÑƒÑ‚ Ð² Ð¿Ñ€Ð¾Ñ„Ð¸Ð»Ðµ Ð¸Ð³Ñ€Ð¾ÐºÐ° (PlayerData): data.showcase Ð¸ data.reserve.
-- Ð—Ð´ÐµÑÑŒ Ð² Ð¿Ð°Ð¼ÑÑ‚Ð¸ Ñ‚Ð¾Ð»ÑŒÐºÐ¾ Ñ‚Ð¾, Ñ‡Ñ‚Ð¾ Ð½Ð°Ñ€Ð¸ÑÐ¾Ð²Ð°Ð½Ð¾ Ð² Ð¼Ð¸Ñ€Ðµ (Ð¼ÐµÐ¼Ð»Ð¸Ð½Ð³Ð¸ Ð½Ð° Ð¿Ð¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚Ð°Ñ…).
-- ÐŸÐ¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚ ÐºÐ¾Ð¿Ð¸Ñ‚ Aura Ð¾Ñ‚ lastCollect (PedestalMath), Ð¿Ð¾ÑÑ‚Ð¾Ð¼Ñƒ Ð¾Ñ„Ð»Ð°Ð¹Ð½-Ð´Ð¾Ñ…Ð¾Ð´ ÑÑ‡Ð¸Ñ‚Ð°ÐµÑ‚ÑÑ ÑÐ°Ð¼
-- Ð¸ ÑƒÐ¿Ð¸Ñ€Ð°ÐµÑ‚ÑÑ Ð² Ð»Ð¸Ð¼Ð¸Ñ‚ Ñ…Ñ€Ð°Ð½Ð¸Ð»Ð¸Ñ‰Ð°. Ð¡Ð¾Ð±Ñ€Ð°Ð½Ð½Ð°Ñ Aura Ð½Ð°Ñ‡Ð¸ÑÐ»ÑÐµÑ‚ÑÑ Ñ‚Ð¾Ð»ÑŒÐºÐ¾ Ñ‡ÐµÑ€ÐµÐ· Economy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local MemelingConfig = require(ReplicatedStorage.Shared.Config.MemelingConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local SecurityConfig = require(ReplicatedStorage.Shared.Config.SecurityConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local formatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local PedestalMath = require(ReplicatedStorage.Shared.Util.PedestalMath)
local UpgradeValues = require(ReplicatedStorage.Shared.Util.UpgradeValues)
local MapBuilder = require(script.Parent.MapBuilder)
local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local Raid = require(script.Parent.Raid)
local RemoteGuard = require(ServerScriptService.Server.Security.RemoteGuard)
local RateLimiter = require(ServerScriptService.Server.Security.RateLimiter)

local Studio = {}

type ShowcaseEntry = PlayerData.ShowcaseEntry
type UpgradeId = UpgradeValues.UpgradeId

-- ÐœÐµÐ¼Ð»Ð¸Ð½Ð³, Ð½Ð°Ñ€Ð¸ÑÐ¾Ð²Ð°Ð½Ð½Ñ‹Ð¹ Ð½Ð° Ð¿Ð¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚Ðµ: ÑÑ‚Ñ€Ð¾ÐºÐ° Ð¿Ñ€Ð¾Ñ„Ð¸Ð»Ñ + ÐµÐ³Ð¾ Ð¼Ð¾Ð´ÐµÐ»ÑŒ Ð² Ð¼Ð¸Ñ€Ðµ
type Slot = {
	Entry: ShowcaseEntry,
	Body: Part,
}

local plotOwners: { [number]: Player? } = {} -- [Ð½Ð¾Ð¼ÐµÑ€ ÑƒÑ‡Ð°ÑÑ‚ÐºÐ°] = Player
local playerPlots: { [Player]: number } = {} -- [Player] = Ð½Ð¾Ð¼ÐµÑ€ ÑƒÑ‡Ð°ÑÑ‚ÐºÐ°
local rendered: { [Player]: { [number]: Slot } } = {} -- [Player][Ð½Ð¾Ð¼ÐµÑ€ Ð¿Ð¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚Ð°] = Slot

local lastPurchaseAt: { [Player]: number } = {} -- ÐºÐ¾Ð³Ð´Ð° Ð¸Ð³Ñ€Ð¾Ðº Ð¿Ð¾ÑÐ»ÐµÐ´Ð½Ð¸Ð¹ Ñ€Ð°Ð· ÐºÑƒÐ¿Ð¸Ð» ÑƒÐ»ÑƒÑ‡ÑˆÐµÐ½Ð¸Ðµ (os.clock)

local collectLimiter =
	RateLimiter.new(SecurityConfig.RateLimits.Collect.MaxRequests, SecurityConfig.RateLimits.Collect.WindowSeconds)
local buyLimiter = RateLimiter.new(SecurityConfig.RateLimits.Buy.MaxRequests, SecurityConfig.RateLimits.Buy.WindowSeconds)

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- â”€â”€ Ð£Ñ€Ð¾Ð²Ð½Ð¸ ÑƒÐ»ÑƒÑ‡ÑˆÐµÐ½Ð¸Ð¹ â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

local function getLevel(data: PlayerData.Data, id: UpgradeId): number
	if id == "pedestals" then
		return data.upgrades.pedestals
	elseif id == "carrySlots" then
		return data.upgrades.carrySlots
	elseif id == "storage" then
		return data.upgrades.storage
	end
	return 0
end

local function setLevel(data: PlayerData.Data, id: UpgradeId, level: number)
	if id == "pedestals" then
		data.upgrades.pedestals = level
	elseif id == "carrySlots" then
		data.upgrades.carrySlots = level
	elseif id == "storage" then
		data.upgrades.storage = level
	end
end

-- Ð¡ÐºÐ¾Ð»ÑŒÐºÐ¾ Ð¿Ð¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚Ð¾Ð² Ð¸Ð³Ñ€Ð¾Ðº Ð¼Ð¾Ð¶ÐµÑ‚ Ð·Ð°Ð½ÑÑ‚ÑŒ (Ð½Ðµ Ð±Ð¾Ð»ÑŒÑˆÐµ, Ñ‡ÐµÐ¼ Ð¼ÐµÑÑ‚ Ð½Ð° ÑƒÑ‡Ð°ÑÑ‚ÐºÐµ)
local function getPedestalCount(data: PlayerData.Data?): number
	local level = if data then data.upgrades.pedestals else 0
	return math.min(UpgradeValues.PedestalCount(level), #MapConfig.Plots.PedestalOffsets)
end

-- Ð›Ð¸Ð¼Ð¸Ñ‚ Ñ…Ñ€Ð°Ð½Ð¸Ð»Ð¸Ñ‰Ð° Ð² ÑÐµÐºÑƒÐ½Ð´Ð°Ñ… Ð´Ð¾Ñ…Ð¾Ð´Ð°
local function getStorageSeconds(data: PlayerData.Data): number
	return UpgradeValues.StorageSeconds(data.upgrades.storage)
end

local function getRate(memelingId: string): number
	local memeling = MemelingConfig.Memelings[memelingId]
	local rarity = memeling and MemelingConfig.Rarities[memeling.Rarity]
	return if rarity then rarity.AuraPerSecond else 0
end

-- â”€â”€ ÐœÐ¸Ñ€: Ð¿Ð¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚Ñ‹ ÑƒÑ‡Ð°ÑÑ‚ÐºÐ° â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

-- ÐÐµÐºÑƒÐ¿Ð»ÐµÐ½Ð½Ñ‹Ðµ Ð¿Ð¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚Ñ‹ â€” Ð¿Ð¾Ð»ÑƒÐ¿Ñ€Ð¾Ð·Ñ€Ð°Ñ‡Ð½Ñ‹Ðµ Â«Ð¿Ñ€Ð¸Ð·Ñ€Ð°ÐºÐ¸Â», ÑÐºÐ²Ð¾Ð·ÑŒ Ð½Ð¸Ñ… Ð¼Ð¾Ð¶Ð½Ð¾ Ð¿Ñ€Ð¾Ð¹Ñ‚Ð¸
local function refreshPedestalLocks(plotIndex: number, data: PlayerData.Data?)
	local unlocked = getPedestalCount(data)
	for pedestalIndex = 1, #MapConfig.Plots.PedestalOffsets do
		local pedestal = getPedestal(plotIndex, pedestalIndex)
		if pedestal then
			local isUnlocked = pedestalIndex <= unlocked
			pedestal.Transparency = if isUnlocked then 0 else StyleConfig.PlotParts.LockedPedestalTransparency
			pedestal.CanCollide = isUnlocked
		end
	end
end

local function getButton(plotIndex: number, id: UpgradeId): Part?
	local plot = MapBuilder.GetPlots()[plotIndex]
	local folder = plot and plot:FindFirstChild("Buttons")
	local button = folder and folder:FindFirstChild("Upgrade_" .. id)
	if button and button:IsA("Part") then
		return button
	end
	return nil
end

-- ÐŸÐ¾Ð´Ð¿Ð¸ÑÐ¸ ÐºÐ½Ð¾Ð¿Ð¾Ðº: Ñ‡Ñ‚Ð¾ Ð´Ð°ÑÑ‚ ÑÐ»ÐµÐ´ÑƒÑŽÑ‰Ð¸Ð¹ ÑƒÑ€Ð¾Ð²ÐµÐ½ÑŒ Ð¸ Ñ†ÐµÐ½Ð° (Ñƒ ÑÐ²Ð¾Ð±Ð¾Ð´Ð½Ð¾Ð³Ð¾ ÑƒÑ‡Ð°ÑÑ‚ÐºÐ° â€” ÑÑ‚Ð°Ñ€Ñ‚Ð¾Ð²Ñ‹Ðµ)
local function refreshButtons(plotIndex: number, data: PlayerData.Data?)
	for _, id in ipairs(UpgradeValues.GetIds()) do
		local button = getButton(plotIndex, id)
		if button then
			local level = if data then getLevel(data, id) else 0
			local cost = UpgradeValues.NextCost(id, level)
			local prompt = button:FindFirstChild("BuyPrompt")
			if cost then
				local text = string.format(TextConfig.UpgradeLabels[id], UpgradeValues.NextValue(id, level), formatNumber(cost))
				MapBuilder.SetLabelText(button, text)
			else
				MapBuilder.SetLabelText(button, TextConfig.UpgradeMaxed[id])
			end
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Enabled = cost ~= nil
				prompt.ObjectText = if cost then string.format(TextConfig.PriceTag, formatNumber(cost)) else ""
			end
		end
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

-- Ð Ð¸ÑÑƒÐµÑ‚ Ð¼ÐµÐ¼Ð»Ð¸Ð½Ð³Ð° Ð½Ð° Ð¿Ð¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚Ðµ: Ð¼ÐµÐ¼Ð»Ð¸Ð½Ð³ Ñ Ð¸Ð¼ÐµÐ½ÐµÐ¼ Ð¸ Ð´Ð¾Ñ…Ð¾Ð´Ð¾Ð¼, Ð½Ð°Ð´ Ð½Ð¸Ð¼ â€” Ð½Ð°ÐºÐ¾Ð¿Ð»ÐµÐ½Ð¾
local function renderEntry(player: Player, plotIndex: number, entry: ShowcaseEntry, data: PlayerData.Data)
	local pedestal = getPedestal(plotIndex, entry.pedestal)
	if pedestal == nil or MemelingConfig.Memelings[entry.memelingId] == nil then
		return
	end

	local size = StyleConfig.Memeling.Size
	local labelStyle = StyleConfig.Label
	-- ÐŸÐ¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚ Ð¿Ð¾Ð²Ñ‘Ñ€Ð½ÑƒÑ‚ ÐºÐ°Ðº ÑƒÑ‡Ð°ÑÑ‚Ð¾Ðº: -Z ÑÐ¼Ð¾Ñ‚Ñ€Ð¸Ñ‚ Ð½Ð° Ñ…Ð°Ð±, Ñ‚ÑƒÐ´Ð° Ð¶Ðµ ÑÐ¼Ð¾Ñ‚Ñ€Ð¸Ñ‚ Ð¸ Ð¼ÐµÐ¼Ð»Ð¸Ð½Ð³
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

	-- ÐŸÐ¾Ð´Ð¿Ð¸ÑÑŒ Â«Ð½Ð°ÐºÐ¾Ð¿Ð»ÐµÐ½Ð¾Â» Ð²Ð¸ÑÐ¸Ñ‚ Ð²Ñ‹ÑˆÐµ Ð¿Ð¾Ð´Ð¿Ð¸ÑÐ¸ Ð¼ÐµÐ¼Ð»Ð¸Ð½Ð³Ð°, Ñ Ð·Ð°Ð·Ð¾Ñ€Ð¾Ð¼
	MapBuilder.AddLabel(pedestal, "", {
		Height = pedestal.Size.Y / 2 + size.Y + labelStyle.HeightStuds * 1.5 + labelStyle.PedestalAuraGap,
	})

	rendered[player] = rendered[player] or {}
	rendered[player][entry.pedestal] = { Entry = entry, Body = body }
	updatePedestalLabel(pedestal, entry, data, now())
	setPromptEnabled(pedestal, "CollectPrompt", true)
end

-- Ð£Ð±Ð¸Ñ€Ð°ÐµÑ‚ Ð¼ÐµÐ¼Ð»Ð¸Ð½Ð³Ð° Ñ Ð¿Ð¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚Ð° Ð² Ð¼Ð¸Ñ€Ðµ (Ð¿Ñ€Ð¾Ñ„Ð¸Ð»ÑŒ Ð½Ðµ Ñ‚Ñ€Ð¾Ð³Ð°ÐµÑ‚)
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

-- Ð Ð¸ÑÑƒÐµÑ‚ Ð²ÑÑŽ Ð²Ð¸Ñ‚Ñ€Ð¸Ð½Ñƒ Ð¸Ð³Ñ€Ð¾ÐºÐ° Ð½Ð° ÐµÐ³Ð¾ ÑƒÑ‡Ð°ÑÑ‚ÐºÐµ (Ð¿Ð¾ÑÐ»Ðµ Ð·Ð°Ð³Ñ€ÑƒÐ·ÐºÐ¸ Ð¿Ñ€Ð¾Ñ„Ð¸Ð»Ñ)
local function renderShowcase(player: Player)
	local plotIndex = playerPlots[player]
	local data = PlayerData.GetData(player)
	if plotIndex == nil or data == nil then
		return
	end
	refreshPedestalLocks(plotIndex, data)
	refreshButtons(plotIndex, data)
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

-- â”€â”€ Ð¡Ð±Ð¾Ñ€ Aura â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

-- Ð˜Ð³Ñ€Ð¾Ðº Ð½Ð°Ð¶Ð°Ð» Â«CollectÂ» Ð½Ð° Ð¿Ð¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚Ðµ. Ð’ÑÐµ Ð¿Ñ€Ð¾Ð²ÐµÑ€ÐºÐ¸ â€” Ð½Ð° ÑÐµÑ€Ð²ÐµÑ€Ðµ.
local function tryCollect(player: Player, plotIndex: number, pedestalIndex: number)
	if not collectLimiter.Allow(player) then
		return
	end
	if playerPlots[player] ~= plotIndex then
		return -- Ñ‡ÑƒÐ¶Ð¾Ð¹ ÑƒÑ‡Ð°ÑÑ‚Ð¾Ðº
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

	-- Ð¡Ð½Ð°Ñ‡Ð°Ð»Ð° Ð·Ð°Ð±Ð¸Ñ€Ð°ÐµÐ¼ Aura Ñ Ð¿Ð¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚Ð°, Ð¿Ð¾Ñ‚Ð¾Ð¼ Ð½Ð°Ñ‡Ð¸ÑÐ»ÑÐµÐ¼: Ð¿Ð¾Ð²Ñ‚Ð¾Ñ€Ð½Ð¾Ðµ Ð½Ð°Ð¶Ð°Ñ‚Ð¸Ðµ ÑƒÐ¶Ðµ Ð½Ð¸Ñ‡ÐµÐ³Ð¾ Ð½Ðµ Ð½Ð°Ð¹Ð´Ñ‘Ñ‚
	entry.lastCollect = newLastCollect
	updatePedestalLabel(pedestal, entry, data, at)
	Economy.AddBankedAura(player, amount, "ÑÐ±Ð¾Ñ€ Ñ Ð¿Ð¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚Ð° " .. pedestalIndex)
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
				prompt.Enabled = false -- Ð²ÐºÐ»ÑŽÑ‡Ð°ÐµÑ‚ÑÑ, ÐºÐ¾Ð³Ð´Ð° Ð½Ð° Ð¿Ð¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚Ðµ ÑÑ‚Ð¾Ð¸Ñ‚ Ð¼ÐµÐ¼Ð»Ð¸Ð½Ð³
				prompt.Parent = pedestal
				prompt.Triggered:Connect(function(player: Player)
					tryCollect(player, plotIndex, pedestalIndex)
				end)
			end
		end
	end
end

-- â”€â”€ Ð£Ñ‡Ð°ÑÑ‚ÐºÐ¸ â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
			print(string.format("[Studio] %s Ð¿Ð¾Ð»ÑƒÑ‡Ð¸Ð» ÑƒÑ‡Ð°ÑÑ‚Ð¾Ðº %d", player.Name, index))
			renderShowcase(player) -- ÐµÑÐ»Ð¸ Ð¿Ñ€Ð¾Ñ„Ð¸Ð»ÑŒ ÑƒÐ¶Ðµ Ð·Ð°Ð³Ñ€ÑƒÐ¶ÐµÐ½
			return
		end
	end

	warn(string.format("[Studio] Ð¡Ð²Ð¾Ð±Ð¾Ð´Ð½Ñ‹Ñ… ÑƒÑ‡Ð°ÑÑ‚ÐºÐ¾Ð² Ð½ÐµÑ‚, %s Ð¸Ð³Ñ€Ð°ÐµÑ‚ Ð±ÐµÐ· ÑƒÑ‡Ð°ÑÑ‚ÐºÐ°", player.Name))
end

local function releasePlot(player: Player)
	local index = playerPlots[player]
	if not index then
		rendered[player] = nil
		return
	end
	clearPlot(player, index)
	refreshPedestalLocks(index, nil)
	refreshButtons(index, nil)
	lastPurchaseAt[player] = nil

	playerPlots[player] = nil
	plotOwners[index] = nil

	local plot = MapBuilder.GetPlots()[index]
	if plot then
		plot:SetAttribute("OwnerUserId", 0)
		MapBuilder.SetLabelText(plot:FindFirstChild("Sign"), TextConfig.FreePlot)
	end
	print(string.format("[Studio] Ð£Ñ‡Ð°ÑÑ‚Ð¾Ðº %d Ð¾ÑÐ²Ð¾Ð±Ð¾Ð¶Ð´Ñ‘Ð½ (%s Ð²Ñ‹ÑˆÐµÐ»)", index, player.Name))
end

-- Model ÑƒÑ‡Ð°ÑÑ‚ÐºÐ° Ð¸Ð³Ñ€Ð¾ÐºÐ° Ð¸Ð»Ð¸ nil, ÐµÑÐ»Ð¸ ÑƒÑ‡Ð°ÑÑ‚ÐºÐ° Ð½ÐµÑ‚
function Studio.GetPlot(player: Player): Model?
	local index = playerPlots[player]
	return index and MapBuilder.GetPlots()[index] or nil
end

-- â”€â”€ Ð’Ð¸Ñ‚Ñ€Ð¸Ð½Ð° â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

-- ÐŸÐµÑ€Ð²Ñ‹Ð¹ ÑÐ²Ð¾Ð±Ð¾Ð´Ð½Ñ‹Ð¹ Ð¿Ð¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚ Ð¸Ð· Ð´Ð¾ÑÑ‚ÑƒÐ¿Ð½Ñ‹Ñ… Ð¸Ð³Ñ€Ð¾ÐºÑƒ Ð¸Ð»Ð¸ nil
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

-- Ð’Ñ‹Ð½ÐµÑÐµÐ½Ð½Ñ‹Ðµ Ð¼ÐµÐ¼Ð»Ð¸Ð½Ð³Ð¸: Ð½Ð° ÑÐ²Ð¾Ð±Ð¾Ð´Ð½Ñ‹Ðµ Ð¿Ð¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚Ñ‹, Ð¾ÑÑ‚Ð°Ð»ÑŒÐ½Ñ‹Ðµ â€” Ð² Ð·Ð°Ð¿Ð°Ñ (Ð²Ñ‹Ð·Ñ‹Ð²Ð°ÐµÑ‚ Extraction)
function Studio.AddToShowcase(player: Player, memelingIds: { string })
	local data = PlayerData.GetData(player)
	if data == nil then
		warn(string.format("[Studio] ÐŸÑ€Ð¾Ñ„Ð¸Ð»ÑŒ %s Ð½Ðµ Ð·Ð°Ð³Ñ€ÑƒÐ¶ÐµÐ½ â€” Ð¼ÐµÐ¼Ð»Ð¸Ð½Ð³Ð¸ Ð½Ðµ ÑÐ¾Ñ…Ñ€Ð°Ð½ÐµÐ½Ñ‹", player.Name))
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
			print(string.format("[Studio] %s: %s Ð½Ð° Ð¿Ð¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚Ðµ %d", player.Name, memelingId, freeIndex))
		else
			table.insert(data.reserve, memelingId)
			print(string.format("[Studio] %s: %s Ð² Ð·Ð°Ð¿Ð°ÑÐµ (Ð½ÐµÑ‚ ÑÐ²Ð¾Ð±Ð¾Ð´Ð½Ð¾Ð³Ð¾ Ð¿Ð¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚Ð°)", player.Name, memelingId))
		end
	end
	publishCounts(player)
end

-- ÐœÐµÐ¼Ð»Ð¸Ð½Ð³Ð¸ Ð¸Ð· Ð·Ð°Ð¿Ð°ÑÐ° Ð²ÑÑ‚Ð°ÑŽÑ‚ Ð½Ð° ÑÐ²Ð¾Ð±Ð¾Ð´Ð½Ñ‹Ðµ Ð¿Ð¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚Ñ‹ (Ð¿Ð¾ÑÐ»Ðµ Ð¿Ð¾ÐºÑƒÐ¿ÐºÐ¸ Ð¿Ð¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚Ð°)
local function fillFromReserve(player: Player, data: PlayerData.Data)
	local plotIndex = playerPlots[player]
	while #data.reserve > 0 do
		local freeIndex = findFreePedestal(data)
		if freeIndex == nil then
			break
		end
		local memelingId = table.remove(data.reserve, 1) :: string
		local entry: ShowcaseEntry = { pedestal = freeIndex, memelingId = memelingId, lastCollect = now() }
		table.insert(data.showcase, entry)
		if plotIndex then
			renderEntry(player, plotIndex, entry, data)
		end
		print(string.format("[Studio] %s: %s Ð¸Ð· Ð·Ð°Ð¿Ð°ÑÐ° Ð½Ð° Ð¿Ð¾ÑÑ‚Ð°Ð¼ÐµÐ½Ñ‚ %d", player.Name, memelingId, freeIndex))
	end
	publishCounts(player)
end

-- â”€â”€ Ð£Ð»ÑƒÑ‡ÑˆÐµÐ½Ð¸Ñ â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

-- Ð˜Ð³Ñ€Ð¾Ðº Ð½Ð°Ð¶Ð°Ð» Â«BuyÂ» Ð½Ð° ÐºÐ½Ð¾Ð¿ÐºÐµ ÑƒÐ»ÑƒÑ‡ÑˆÐµÐ½Ð¸Ñ. Ð¦ÐµÐ½Ð° Ð¸ ÑƒÑ€Ð¾Ð²ÐµÐ½ÑŒ â€” Ñ‚Ð¾Ð»ÑŒÐºÐ¾ Ñ ÑÐµÑ€Ð²ÐµÑ€Ð°.
local function tryBuy(player: Player, plotIndex: number, id: UpgradeId)
	if not buyLimiter.Allow(player) then
		return
	end
	local last = lastPurchaseAt[player]
	if last and os.clock() - last < SecurityConfig.PurchaseCooldownSeconds then
		return -- Ð´Ð²Ð¾Ð¹Ð½Ð¾Ð¹ ÐºÐ»Ð¸Ðº: Ð²Ñ‚Ð¾Ñ€Ð¾Ð¹ Ñ€Ð°Ð· Ð½Ðµ Ð¿Ð¾ÐºÑƒÐ¿Ð°ÐµÐ¼
	end
	if playerPlots[player] ~= plotIndex then
		return -- Ñ‡ÑƒÐ¶Ð¾Ð¹ ÑƒÑ‡Ð°ÑÑ‚Ð¾Ðº
	end
	local _, root = RemoteGuard.GetAliveCharacter(player)
	local data = PlayerData.GetData(player)
	local button = getButton(plotIndex, id)
	if root == nil or data == nil or button == nil then
		return
	end
	if not RemoteGuard.IsNear(root, button.Position, EconomyConfig.ButtonDistance) then
		return
	end

	local level = getLevel(data, id)
	local cost = UpgradeValues.NextCost(id, level)
	if cost == nil then
		return -- ÑƒÐ¶Ðµ Ð¼Ð°ÐºÑÐ¸Ð¼ÑƒÐ¼
	end

	-- Ð¡Ð¿Ð¸ÑÐ°Ð½Ð¸Ðµ Ð¸ Ð½Ð¾Ð²Ñ‹Ð¹ ÑƒÑ€Ð¾Ð²ÐµÐ½ÑŒ â€” Ð¿Ð¾Ð´Ñ€ÑÐ´, Ð±ÐµÐ· Ð¾Ð¶Ð¸Ð´Ð°Ð½Ð¸Ð¹: Ð¼ÐµÐ¶Ð´Ñƒ Ð½Ð¸Ð¼Ð¸ Ð½Ð¸Ñ‡ÐµÐ³Ð¾ Ð½Ðµ Ð¼Ð¾Ð¶ÐµÑ‚ Ð²ÐºÐ»Ð¸Ð½Ð¸Ñ‚ÑŒÑÑ
	if not Economy.TrySpend(player, cost, "ÑƒÐ»ÑƒÑ‡ÑˆÐµÐ½Ð¸Ðµ " .. id) then
		return -- Ð½Ðµ Ñ…Ð²Ð°Ñ‚Ð°ÐµÑ‚ Aura
	end
	setLevel(data, id, level + 1)
	lastPurchaseAt[player] = os.clock()
	print(string.format("[Studio] %s ÐºÑƒÐ¿Ð¸Ð» %s, ÑƒÑ€Ð¾Ð²ÐµÐ½ÑŒ %d", player.Name, id, level + 1))

	if id == "pedestals" then
		refreshPedestalLocks(plotIndex, data)
		fillFromReserve(player, data)
	elseif id == "carrySlots" then
		Raid.RefreshCarrySlots(player)
	end
	refreshButtons(plotIndex, data)
end

local function addBuyPrompts()
	for plotIndex = 1, #MapBuilder.GetPlots() do
		for _, id in ipairs(UpgradeValues.GetIds()) do
			local button = getButton(plotIndex, id)
			if button then
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "BuyPrompt"
				prompt.ActionText = TextConfig.BuyAction
				prompt.MaxActivationDistance = EconomyConfig.ButtonDistance
				prompt.HoldDuration = StyleConfig.Prompts.BuyHoldSeconds
				prompt.RequiresLineOfSight = false
				prompt.Parent = button
				prompt.Triggered:Connect(function(player: Player)
					tryBuy(player, plotIndex, id)
				end)
			end
		end
		refreshPedestalLocks(plotIndex, nil)
		refreshButtons(plotIndex, nil)
	end
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
	addBuyPrompts()

	Players.PlayerAdded:Connect(assignPlot)
	Players.PlayerRemoving:Connect(releasePlot)
	PlayerData.OnLoaded(function(player)
		renderShowcase(player)
	end)

	-- Ð˜Ð³Ñ€Ð¾ÐºÐ¸, ÐºÐ¾Ñ‚Ð¾Ñ€Ñ‹Ðµ ÑƒÑÐ¿ÐµÐ»Ð¸ Ð·Ð°Ð¹Ñ‚Ð¸ Ð´Ð¾ Ð·Ð°Ð¿ÑƒÑÐºÐ° ÑÐµÑ€Ð²Ð¸ÑÐ°
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
