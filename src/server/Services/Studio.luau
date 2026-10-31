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
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local SecurityConfig = require(ReplicatedStorage.Shared.Config.SecurityConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local formatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local PedestalMath = require(ReplicatedStorage.Shared.Util.PedestalMath)
local UpgradeValues = require(ReplicatedStorage.Shared.Util.UpgradeValues)
local SquadRule = require(ReplicatedStorage.Shared.Util.SquadRule)
local RebirthMath = require(ReplicatedStorage.Shared.Util.RebirthMath)
local MapBuilder = require(script.Parent.MapBuilder)
local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local Raid = require(script.Parent.Raid)
local Tutorial = require(script.Parent.Tutorial)
local Analytics = require(script.Parent.Analytics)
local RemoteGuard = require(ServerScriptService.Server.Security.RemoteGuard)
local RateLimiter = require(ServerScriptService.Server.Security.RateLimiter)

local Studio = {}

type ShowcaseEntry = PlayerData.ShowcaseEntry
type UpgradeId = UpgradeValues.UpgradeId

-- Мемлинг, нарисованный на постаменте: строка профиля + его модель в мире
type Slot = {
	Entry: ShowcaseEntry,
	Body: Part,
}

local plotOwners: { [number]: Player? } = {} -- [номер участка] = Player
local playerPlots: { [Player]: number } = {} -- [Player] = номер участка
local rendered: { [Player]: { [number]: Slot } } = {} -- [Player][номер постамента] = Slot

local lastPurchaseAt: { [Player]: number } = {} -- когда игрок последний раз купил улучшение (os.clock)

local collectLimiter =
	RateLimiter.new(SecurityConfig.RateLimits.Collect.MaxRequests, SecurityConfig.RateLimits.Collect.WindowSeconds)
local buyLimiter = RateLimiter.new(SecurityConfig.RateLimits.Buy.MaxRequests, SecurityConfig.RateLimits.Buy.WindowSeconds)
local sellLimiter =
	RateLimiter.new(SecurityConfig.RateLimits.Sell.MaxRequests, SecurityConfig.RateLimits.Sell.WindowSeconds)

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- ── Уровни улучшений ───────────────────────────────────────────────────────

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

-- Сколько постаментов игрок может занять (не больше, чем мест на участке)
local function getPedestalCount(data: PlayerData.Data?): number
	local level = if data then data.upgrades.pedestals else 0
	return math.min(UpgradeValues.PedestalCount(level), #MapConfig.Plots.PedestalOffsets)
end

-- Лимит хранилища в секундах дохода
local function getStorageSeconds(data: PlayerData.Data): number
	return UpgradeValues.StorageSeconds(data.upgrades.storage)
end

-- Доход мемлинга в секунду: по редкости, × бонус за rebirth игрока (RebirthMath)
local function getRate(memelingId: string, data: PlayerData.Data?): number
	local memeling = MemelingConfig.Memelings[memelingId]
	local rarity = memeling and MemelingConfig.Rarities[memeling.Rarity]
	local base = if rarity then rarity.AuraPerSecond else 0
	local rebirths = if data then data.rebirths else 0
	return base * RebirthMath.IncomeMultiplier(rebirths, EconomyConfig.Rebirth.IncomeBonusPercent)
end

-- Все улучшения на максимуме — тогда доступен Rebirth
local function allUpgradesMaxed(data: PlayerData.Data): boolean
	for _, id in ipairs(UpgradeValues.GetIds()) do
		if UpgradeValues.NextCost(id, getLevel(data, id)) ~= nil then
			return false
		end
	end
	return true
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

-- Некупленные постаменты — полупрозрачные «призраки», сквозь них можно пройти.
-- Постамент, на котором стоит мемлинг, открыт всегда: после Rebirth витрина остаётся на месте
-- (новых мемлингов туда не поставить, пока постамент снова не куплен)
local function refreshPedestalLocks(plotIndex: number, data: PlayerData.Data?)
	local unlocked = getPedestalCount(data)
	local occupied: { [number]: boolean } = {}
	if data then
		for _, entry in ipairs(data.showcase) do
			occupied[entry.pedestal] = true
		end
	end
	for pedestalIndex = 1, #MapConfig.Plots.PedestalOffsets do
		local pedestal = getPedestal(plotIndex, pedestalIndex)
		if pedestal then
			local isUnlocked = pedestalIndex <= unlocked or occupied[pedestalIndex] == true
			-- Сама деталь постамента невидимая (логическая), видно круглый Look поверх неё
			MapBuilder.SetLookTransparency(pedestal, if isUnlocked then 0 else StyleConfig.PlotParts.LockedPedestalTransparency)
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

-- Подписи кнопок: что даст следующий уровень и цена (у свободного участка — стартовые)
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

local function rarityOf(memelingId: string): string
	local memeling = MemelingConfig.Memelings[memelingId]
	return if memeling then memeling.Rarity else ""
end

-- Цена продажи — только из MemelingConfig (0, если мемлинга нет в конфиге);
-- принесённые в отряде дороже на EconomyConfig.SquadBonus.SellBonusPercent (SquadRule)
local function getSellPrice(memelingId: string, squadBonus: boolean?): number
	local memeling = MemelingConfig.Memelings[memelingId]
	local rarity = memeling and MemelingConfig.Rarities[memeling.Rarity]
	local base = if rarity then rarity.SellPrice else 0
	return SquadRule.SellPrice(base, EconomyConfig.SquadBonus.SellBonusPercent, squadBonus == true)
end

local function getReservePad(plotIndex: number): Part?
	local plot = MapBuilder.GetPlots()[plotIndex]
	local folder = plot and plot:FindFirstChild("Buttons")
	local pad = folder and folder:FindFirstChild("Reserve")
	if pad and pad:IsA("Part") then
		return pad
	end
	return nil
end

-- Подпись площадки запаса и кнопка «Sell» (продаёт самого старого мемлинга из запаса)
local function refreshReserve(plotIndex: number, data: PlayerData.Data?)
	local pad = getReservePad(plotIndex)
	if pad == nil then
		return
	end
	local count = if data then #data.reserve else 0
	MapBuilder.SetLabelText(pad, string.format(TextConfig.ReserveLabel, count))
	local prompt = pad:FindFirstChild("SellPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = count > 0
		local first = data and data.reserve[1]
		prompt.ObjectText = if first
			then string.format(TextConfig.SellPriceTag, formatNumber(getSellPrice(first.memelingId, first.squadBonus)))
			else ""
	end
end

local function publishCounts(player: Player)
	local data = PlayerData.GetData(player)
	player:SetAttribute("PedestalMemelings", if data then #data.showcase else 0)
	player:SetAttribute("ReserveCount", if data then #data.reserve else 0)
	local plotIndex = playerPlots[player]
	if plotIndex then
		refreshReserve(plotIndex, data)
	end
end

local function updatePedestalLabel(pedestal: Part, entry: ShowcaseEntry, data: PlayerData.Data, at: number)
	local rate = getRate(entry.memelingId, data)
	local storageSeconds = getStorageSeconds(data)
	local stored = PedestalMath.GetStored(rate, entry.lastCollect, at, storageSeconds)
	local full = stored >= rate * storageSeconds
	local format = if full then TextConfig.PedestalFull else TextConfig.PedestalStored
	MapBuilder.SetLabelText(pedestal, string.format(format, formatNumber(stored)))
end

-- Подпись мемлинга на постаменте: имя и доход; у принесённых в отряде — ещё отметка бонуса
local function getMemelingLabel(entry: ShowcaseEntry, data: PlayerData.Data?): string
	local name = TextConfig.MemelingNames[entry.memelingId] or entry.memelingId
	-- Доход показываем целым, округлённым вниз (с бонусом rebirth он бывает дробным)
	local text = string.format(TextConfig.PedestalMemeling, name, math.floor(getRate(entry.memelingId, data)))
	if entry.squadBonus then
		text ..= string.format(TextConfig.SquadTag, EconomyConfig.SquadBonus.SellBonusPercent)
	end
	return text
end

local function updateSellPrompt(pedestal: Part, entry: ShowcaseEntry)
	local sellPrompt = pedestal:FindFirstChild("SellPrompt")
	if sellPrompt and sellPrompt:IsA("ProximityPrompt") then
		sellPrompt.ObjectText =
			string.format(TextConfig.SellPriceTag, formatNumber(getSellPrice(entry.memelingId, entry.squadBonus)))
	end
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
	body:SetAttribute("OwnerUserId", player.UserId) -- клиент рисует контур своим мемлингам на постаментах
	MapBuilder.AddLabel(
		body,
		getMemelingLabel(entry, data),
		{ MaxDistance = labelStyle.MemelingMaxDistance, Height = StyleConfig.Memeling.LabelHeight, Scale = labelStyle.MemelingScale }
	)

	-- Подпись «накоплено» висит выше подписи мемлинга, с зазором
	MapBuilder.AddLabel(pedestal, "", {
		Height = pedestal.Size.Y / 2 + size.Y + labelStyle.HeightStuds * 1.5 + labelStyle.PedestalAuraGap,
	})

	rendered[player] = rendered[player] or {}
	rendered[player][entry.pedestal] = { Entry = entry, Body = body }
	updatePedestalLabel(pedestal, entry, data, now())
	setPromptEnabled(pedestal, "CollectPrompt", true)
	setPromptEnabled(pedestal, "SellPrompt", true)
	updateSellPrompt(pedestal, entry)
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
		setPromptEnabled(pedestal, "SellPrompt", false)
	end
end

-- Рисует всю витрину игрока на его участке (после загрузки профиля)
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
		PedestalMath.Collect(getRate(entry.memelingId, data), entry.lastCollect, at, getStorageSeconds(data))
	if amount < 1 then
		return
	end

	-- Сначала забираем Aura с постамента, потом начисляем: повторное нажатие уже ничего не найдёт
	entry.lastCollect = newLastCollect
	updatePedestalLabel(pedestal, entry, data, at)
	Economy.AddBankedAura(player, amount, "сбор с постамента " .. pedestalIndex)
	Tutorial.Notify(player, "Collect")
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
				RemoteGuard.ConnectPrompt(prompt, "сбор", function(player: Player)
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
	refreshPedestalLocks(index, nil)
	refreshButtons(index, nil)
	refreshReserve(index, nil)
	lastPurchaseAt[player] = nil

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

-- Запись профиля о принесённом мемлинге (на постаменте или в запасе) — на ней ставится бонус отряда
export type BroughtEntry = { squadBonus: boolean? }

-- Мемлинг перешёл из запаса на постамент: [старая запись запаса] = новая запись постамента
-- (слабые ключи — старые записи исчезают сами)
local movedFromReserve: { [any]: ShowcaseEntry } = setmetatable({}, { __mode = "k" }) :: any

-- Вынесенные мемлинги: на свободные постаменты, остальные — в запас (вызывает Extraction).
-- Вернёт созданные записи профиля: по ним Extraction может позже поставить бонус отряда
function Studio.AddToShowcase(player: Player, memelingIds: { string }): { BroughtEntry }
	local brought: { BroughtEntry } = {}
	local data = PlayerData.GetData(player)
	if data == nil then
		warn(string.format("[Studio] Профиль %s не загружен — мемлинги не сохранены", player.Name))
		return brought
	end
	local plotIndex = playerPlots[player]

	for _, memelingId in ipairs(memelingIds) do
		local freeIndex = findFreePedestal(data)
		if freeIndex then
			local entry: ShowcaseEntry = { pedestal = freeIndex, memelingId = memelingId, lastCollect = now() }
			table.insert(data.showcase, entry)
			table.insert(brought, entry)
			if plotIndex then
				renderEntry(player, plotIndex, entry, data)
			end
			print(string.format("[Studio] %s: %s на постаменте %d", player.Name, memelingId, freeIndex))
		else
			local reserveEntry: PlayerData.ReserveEntry = { memelingId = memelingId }
			table.insert(data.reserve, reserveEntry)
			table.insert(brought, reserveEntry)
			print(string.format("[Studio] %s: %s в запасе (нет свободного постамента)", player.Name, memelingId))
		end
	end
	publishCounts(player)
	return brought
end

-- Бонус отряда на принесённых мемлингах: флаг в профиле, подписи и цены продажи обновляются.
-- Записи могли уже перейти из запаса на постамент или быть проданы — тогда отмечаем то, что осталось
function Studio.ApplySquadBonus(player: Player, brought: { BroughtEntry })
	local marked: { BroughtEntry } = {}
	for _, entry in ipairs(brought) do
		entry.squadBonus = true
		table.insert(marked, entry)
		-- Мемлинг мог перейти из запаса на постамент: у него теперь новая запись — отмечаем и её
		local moved = movedFromReserve[entry]
		if moved then
			moved.squadBonus = true
			table.insert(marked, moved)
		end
	end
	local plotIndex = playerPlots[player]
	local playerSlots = rendered[player]
	if plotIndex and playerSlots then
		for pedestalIndex, slot in playerSlots do
			if table.find(marked, slot.Entry :: BroughtEntry) then
				MapBuilder.SetLabelText(slot.Body, getMemelingLabel(slot.Entry, PlayerData.GetData(player)))
				local pedestal = getPedestal(plotIndex, pedestalIndex)
				if pedestal then
					updateSellPrompt(pedestal, slot.Entry)
				end
			end
		end
	end
	publishCounts(player)
end

-- Мемлинги из запаса встают на свободные постаменты (после покупки постамента).
-- Бонус отряда переходит вместе с мемлингом
local function fillFromReserve(player: Player, data: PlayerData.Data)
	local plotIndex = playerPlots[player]
	while #data.reserve > 0 do
		local freeIndex = findFreePedestal(data)
		if freeIndex == nil then
			break
		end
		local reserveEntry = table.remove(data.reserve, 1) :: PlayerData.ReserveEntry
		local entry: ShowcaseEntry = {
			pedestal = freeIndex,
			memelingId = reserveEntry.memelingId,
			lastCollect = now(),
			squadBonus = reserveEntry.squadBonus,
		}
		table.insert(data.showcase, entry)
		movedFromReserve[reserveEntry] = entry
		if plotIndex then
			renderEntry(player, plotIndex, entry, data)
		end
		print(string.format("[Studio] %s: %s из запаса на постамент %d", player.Name, entry.memelingId, freeIndex))
	end
	publishCounts(player)
end

-- ── Продажа ────────────────────────────────────────────────────────────────

-- Общие проверки действия на своём участке: rate limit, свой участок, живой персонаж рядом с деталью.
-- Вернёт данные профиля или nil, если действие нельзя выполнить.
local function checkPlotAction(
	player: Player,
	limiter: RateLimiter.Limiter,
	plotIndex: number,
	target: BasePart?,
	maxDistance: number
): PlayerData.Data?
	if not limiter.Allow(player) then
		return nil
	end
	if playerPlots[player] ~= plotIndex or target == nil then
		return nil -- чужой участок
	end
	local _, root = RemoteGuard.GetAliveCharacter(player)
	local data = PlayerData.GetData(player)
	if root == nil or data == nil or not RemoteGuard.IsNear(root, target.Position, maxDistance) then
		return nil
	end
	return data
end

-- Игрок держит «Sell» на постаменте: мемлинг продаётся, накопленная на постаменте Aura тоже начисляется
local function trySellFromPedestal(player: Player, plotIndex: number, pedestalIndex: number)
	local pedestal = getPedestal(plotIndex, pedestalIndex)
	local data = checkPlotAction(player, sellLimiter, plotIndex, pedestal, EconomyConfig.CollectDistance)
	local slot = rendered[player] and rendered[player][pedestalIndex]
	if data == nil or slot == nil then
		return
	end
	local entry = slot.Entry
	local position = table.find(data.showcase, entry)
	if position == nil then
		return
	end

	local price = getSellPrice(entry.memelingId, entry.squadBonus)
	local collected = PedestalMath.Collect(getRate(entry.memelingId, data), entry.lastCollect, now(), getStorageSeconds(data))

	-- Сначала мемлинг уходит из профиля, потом начисление: повторное нажатие уже ничего не найдёт
	table.remove(data.showcase, position)
	unrenderPedestal(player, plotIndex, pedestalIndex)
	data.stats.memelingsSold += 1
	if price > 0 then
		Economy.AddBankedAura(player, price, "продажа " .. entry.memelingId)
	end
	Analytics.MemelingSold(player, rarityOf(entry.memelingId), price)
	if collected > 0 then
		Economy.AddBankedAura(player, collected, "сбор при продаже")
	end
	print(string.format("[Studio] %s продал %s с постамента %d", player.Name, entry.memelingId, pedestalIndex))

	fillFromReserve(player, data) -- освободившийся постамент занимает мемлинг из запаса
end

-- Игрок держит «Sell» на площадке запаса: продаётся самый старый мемлинг из запаса
local function trySellFromReserve(player: Player, plotIndex: number)
	local data = checkPlotAction(player, sellLimiter, plotIndex, getReservePad(plotIndex), EconomyConfig.ButtonDistance)
	if data == nil or #data.reserve == 0 then
		return
	end

	local reserveEntry = table.remove(data.reserve, 1) :: PlayerData.ReserveEntry
	data.stats.memelingsSold += 1
	local price = getSellPrice(reserveEntry.memelingId, reserveEntry.squadBonus)
	if price > 0 then
		Economy.AddBankedAura(player, price, "продажа из запаса " .. reserveEntry.memelingId)
	end
	Analytics.MemelingSold(player, rarityOf(reserveEntry.memelingId), price)
	print(string.format("[Studio] %s продал %s из запаса", player.Name, reserveEntry.memelingId))
	publishCounts(player)
end

local function addSellPrompt(parent: BasePart, maxDistance: number, onTriggered: (player: Player) -> ())
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SellPrompt"
	prompt.ActionText = TextConfig.SellAction
	prompt.MaxActivationDistance = maxDistance
	prompt.HoldDuration = StyleConfig.Prompts.SellHoldSeconds
	prompt.KeyboardKeyCode = Enum.KeyCode.F -- E занят кнопкой «Collect» на том же постаменте
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.UIOffset = Vector2.new(0, StyleConfig.Prompts.SecondaryOffsetY)
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false -- включается, когда есть что продать
	prompt.Parent = parent
	RemoteGuard.ConnectPrompt(prompt, "продажа", onTriggered)
end

local function addSellPrompts()
	for plotIndex = 1, #MapBuilder.GetPlots() do
		for pedestalIndex = 1, #MapConfig.Plots.PedestalOffsets do
			local pedestal = getPedestal(plotIndex, pedestalIndex)
			if pedestal then
				addSellPrompt(pedestal, EconomyConfig.CollectDistance, function(player)
					trySellFromPedestal(player, plotIndex, pedestalIndex)
				end)
			end
		end
		local pad = getReservePad(plotIndex)
		if pad then
			addSellPrompt(pad, EconomyConfig.ButtonDistance, function(player)
				trySellFromReserve(player, plotIndex)
			end)
		end
		refreshReserve(plotIndex, nil)
	end
end

-- ── Улучшения ──────────────────────────────────────────────────────────────

-- Игрок нажал «Buy» на кнопке улучшения. Цена и уровень — только с сервера.
local function tryBuy(player: Player, plotIndex: number, id: UpgradeId)
	if not buyLimiter.Allow(player) then
		return
	end
	local last = lastPurchaseAt[player]
	if last and os.clock() - last < SecurityConfig.PurchaseCooldownSeconds then
		return -- двойной клик: второй раз не покупаем
	end
	if playerPlots[player] ~= plotIndex then
		return -- чужой участок
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
		return -- уже максимум
	end

	-- Списание и новый уровень — подряд, без ожиданий: между ними ничего не может вклиниться
	if not Economy.TrySpend(player, cost, "улучшение " .. id) then
		return -- не хватает Aura
	end
	setLevel(data, id, level + 1)
	lastPurchaseAt[player] = os.clock()
	print(string.format("[Studio] %s купил %s, уровень %d", player.Name, id, level + 1))
	Tutorial.Notify(player, "BuyUpgrade")
	Analytics.UpgradePurchased(player, id, level + 1, cost)

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
				RemoteGuard.ConnectPrompt(prompt, "покупка", function(player: Player)
					tryBuy(player, plotIndex, id)
				end)
			end
		end
		refreshPedestalLocks(plotIndex, nil)
		refreshButtons(plotIndex, nil)
	end
end

-- ── Rebirth ────────────────────────────────────────────────────────────────

local function getRebirthPad(plotIndex: number): Part?
	local plot = MapBuilder.GetPlots()[plotIndex]
	local folder = plot and plot:FindFirstChild("Buttons")
	local pad = folder and folder:FindFirstChild("Rebirth")
	if pad and pad:IsA("Part") then
		return pad
	end
	return nil
end

local function getRebirthCost(data: PlayerData.Data): number
	local cfg = EconomyConfig.Rebirth
	return RebirthMath.Cost(data.rebirths, cfg.BaseCost, cfg.CostGrowth)
end

-- Подпись площадки Rebirth и кнопка: работает, только когда все улучшения куплены
local function refreshRebirth(plotIndex: number, data: PlayerData.Data?)
	local pad = getRebirthPad(plotIndex)
	if pad == nil then
		return
	end
	local maxed = data ~= nil and allUpgradesMaxed(data)
	local cost = if data then getRebirthCost(data) else RebirthMath.Cost(0, EconomyConfig.Rebirth.BaseCost, EconomyConfig.Rebirth.CostGrowth)
	local text = if maxed then string.format(TextConfig.RebirthLabel, formatNumber(cost)) else TextConfig.RebirthLocked
	MapBuilder.SetLabelText(pad, text)
	local prompt = pad:FindFirstChild("RebirthPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = maxed
		prompt.ObjectText = string.format(TextConfig.PriceTag, formatNumber(cost))
	end
end

-- Счётчик rebirth над именем игрока (атрибут Rebirths — копия для клиента)
local function refreshRebirthTag(player: Player)
	local data = PlayerData.GetData(player)
	local rebirths = if data then data.rebirths else 0
	player:SetAttribute("Rebirths", rebirths)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local old = head:FindFirstChild("RebirthTag")
	if old then
		old:Destroy()
	end
	if rebirths <= 0 then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "RebirthTag"
	tag.Size = UDim2.fromScale(6, 1.2)
	tag.StudsOffsetWorldSpace = Vector3.new(0, StyleConfig.PlotParts.RebirthTagHeight, 0)
	tag.MaxDistance = StyleConfig.Label.MaxDistance
	tag.Parent = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Font = StyleConfig.Fonts.Label
	label.TextColor3 = StyleConfig.PlotParts.RebirthTag
	label.TextStrokeColor3 = StyleConfig.Label.Stroke
	label.TextStrokeTransparency = 0
	label.Text = string.format(TextConfig.RebirthTag, rebirths)
	label.Parent = tag
end

-- Игрок удержал «Rebirth» 2 с (это и есть подтверждение). Всё проверяет сервер:
-- свой участок, рядом, все улучшения куплены, Aura хватает. Витрина и запас остаются
local function tryRebirth(player: Player, plotIndex: number)
	local last = lastPurchaseAt[player]
	if last and os.clock() - last < SecurityConfig.PurchaseCooldownSeconds then
		return
	end
	local data = checkPlotAction(player, buyLimiter, plotIndex, getRebirthPad(plotIndex), EconomyConfig.ButtonDistance)
	if data == nil or not allUpgradesMaxed(data) then
		return
	end
	local cost = getRebirthCost(data)
	-- Сначала Aura (только через Economy), сразу за ней сброс улучшений — без ожиданий между ними
	if not Economy.TrySpendAll(player, cost, "rebirth") then
		return -- не хватает Aura
	end
	data.upgrades.pedestals = 0
	data.upgrades.carrySlots = 0
	data.upgrades.storage = 0
	data.rebirths += 1
	lastPurchaseAt[player] = os.clock()
	print(string.format("[Studio] %s сделал Rebirth №%d, доход ×%.2f", player.Name, data.rebirths, RebirthMath.IncomeMultiplier(data.rebirths, EconomyConfig.Rebirth.IncomeBonusPercent)))

	refreshPedestalLocks(plotIndex, data)
	refreshButtons(plotIndex, data)
	refreshRebirth(plotIndex, data)
	Raid.RefreshCarrySlots(player)
	refreshRebirthTag(player)
	-- Доход мемлингов на витрине вырос — обновляем подписи «+N/s»
	local playerSlots = rendered[player]
	if playerSlots then
		for _, slot in playerSlots do
			MapBuilder.SetLabelText(slot.Body, getMemelingLabel(slot.Entry, data))
		end
	end
end

local function addRebirthPrompts()
	for plotIndex = 1, #MapBuilder.GetPlots() do
		local pad = getRebirthPad(plotIndex)
		if pad then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "RebirthPrompt"
			prompt.ActionText = TextConfig.RebirthAction
			prompt.MaxActivationDistance = EconomyConfig.ButtonDistance
			prompt.HoldDuration = StyleConfig.Prompts.RebirthHoldSeconds
			prompt.RequiresLineOfSight = false
			prompt.Enabled = false
			prompt.Parent = pad
			RemoteGuard.ConnectPrompt(prompt, "rebirth", function(player: Player)
				tryRebirth(player, plotIndex)
			end)
		end
		refreshRebirth(plotIndex, nil)
	end
end

local function updateAllLabels()
	local at = now()
	-- Кнопка Rebirth: Aura меняется постоянно, поэтому доступность обновляем вместе с подписями
	-- (у свободного участка — стартовая подпись)
	for plotIndex = 1, #MapBuilder.GetPlots() do
		local owner = plotOwners[plotIndex]
		refreshRebirth(plotIndex, if owner then PlayerData.GetData(owner) else nil)
	end
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

-- Стоит ли игрок у своего постамента с мемлингом (шаг туториала «подойти к постаменту»)
local function isNearFilledPedestal(player: Player): boolean
	local plotIndex = playerPlots[player]
	local playerSlots = rendered[player]
	local _, root = RemoteGuard.GetAliveCharacter(player)
	if plotIndex == nil or playerSlots == nil or root == nil then
		return false
	end
	for pedestalIndex in playerSlots do
		local pedestal = getPedestal(plotIndex, pedestalIndex)
		if pedestal and RemoteGuard.IsNear(root, pedestal.Position, EconomyConfig.CollectDistance) then
			return true
		end
	end
	return false
end

function Studio.Start()
	addCollectPrompts()
	addBuyPrompts()
	addSellPrompts()
	addRebirthPrompts()
	Tutorial.SetPedestalCheck(isNearFilledPedestal)

	-- Счётчик rebirth над головой: при каждом появлении персонажа
	local function watchCharacter(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			refreshRebirthTag(player)
		end)
	end
	Players.PlayerAdded:Connect(function(player)
		assignPlot(player)
		watchCharacter(player)
	end)
	Players.PlayerRemoving:Connect(releasePlot)
	PlayerData.OnLoaded(function(player)
		renderShowcase(player)
		refreshRebirthTag(player)
	end)

	-- Игроки, которые успели зайти до запуска сервиса
	for _, player in ipairs(Players:GetPlayers()) do
		assignPlot(player)
		watchCharacter(player)
	end

	task.spawn(function()
		while true do
			task.wait(EconomyConfig.PedestalLabelUpdateSeconds)
			updateAllLabels()
		end
	end)
end

return Studio
