--!strict
-- Shop: магазин косметики за Aura (задача 7.4). Только внешний вид — ни силы, ни дохода.
-- Клиент присылает только Id вещи (Remotes.ShopBuy / ShopEquip через RemoteGuard.ConnectRemoteId).
-- Сервер сам проверяет: вещь есть в ShopConfig, ещё не куплена, Aura хватает (ShopRule.CanBuy);
-- списывает только Economy.TrySpend, потом отмечает вещь купленной навсегда (cosmetics.owned).
-- Надеть/снять — отдельно от покупки (ShopRule.ToggleEquip, лимит категории — ShopConfig.Categories).
-- Rebirth косметику не трогает. Картинку строит server/Visual/CosmeticsBuilder: участок (баннеры, декор,
-- скин постаментов) и персонаж (след, аура, титул). Клиенту — копия в атрибутах ShopOwned / ShopEquipped.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local MemelingConfig = require(ReplicatedStorage.Shared.Config.MemelingConfig)
local SecurityConfig = require(ReplicatedStorage.Shared.Config.SecurityConfig)
local ShopRule = require(ReplicatedStorage.Shared.Util.ShopRule)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local Studio = require(script.Parent.Studio)
local Analytics = require(script.Parent.Analytics)
local CosmeticsBuilder = require(ServerScriptService.Server.Visual.CosmeticsBuilder)
local RemoteGuard = require(ServerScriptService.Server.Security.RemoteGuard)
local RateLimiter = require(ServerScriptService.Server.Security.RateLimiter)

local Shop = {}

local PLOT_CATEGORIES = { Banner = true, Decor = true, PedestalSkin = true }
local DEFAULT_STATUE = "ToastPaw" -- статуя на участке, пока на витрине никого нет

local limiter = RateLimiter.new(SecurityConfig.RateLimits.Buy.MaxRequests, SecurityConfig.RateLimits.Buy.WindowSeconds)
local plotOf: { [Player]: Model } = {} -- на каком участке сейчас стоит косметика игрока

-- Копия для клиента (окно магазина): что куплено и что надето
local function publish(player: Player, data: PlayerData.Data)
	local owned: { string } = {}
	for id in data.cosmetics.owned do
		table.insert(owned, id)
	end
	table.sort(owned)
	local equipped: { string } = {}
	for _, category in ipairs(ShopConfig.CategoryOrder) do
		for _, id in ipairs(data.cosmetics.equipped[category] or {}) do
			table.insert(equipped, id)
		end
	end
	player:SetAttribute("ShopOwned", ShopRule.Join(owned))
	player:SetAttribute("ShopEquipped", ShopRule.Join(equipped))
end

-- Самый редкий мемлинг на витрине — для декора «статуя мемлинга»
local function statueMemeling(data: PlayerData.Data): string
	local best, bestRank = DEFAULT_STATUE, 0
	for _, entry in ipairs(data.showcase) do
		local memeling = MemelingConfig.Memelings[entry.memelingId]
		local rank = if memeling then table.find(MemelingConfig.RarityOrder, memeling.Rarity) or 0 else 0
		if rank > bestRank then
			best, bestRank = entry.memelingId, rank
		end
	end
	return best
end

local function applyPlot(player: Player, data: PlayerData.Data)
	local plot = Studio.GetPlot(player)
	if plot == nil then
		return
	end
	plotOf[player] = plot
	CosmeticsBuilder.ApplyPlot(plot, data.cosmetics.equipped, player.DisplayName, statueMemeling(data))
end

local function applyCharacter(player: Player, data: PlayerData.Data)
	local character = player.Character
	if character then
		CosmeticsBuilder.ApplyCharacter(character, data.cosmetics.equipped)
	end
end

local function apply(player: Player, data: PlayerData.Data, category: string?)
	if category == nil or PLOT_CATEGORIES[category] then
		applyPlot(player, data)
	end
	if category == nil or not PLOT_CATEGORIES[category] then
		applyCharacter(player, data)
	end
end

-- Надеть/снять вещь (только купленную). Вернёт, что произошло (ShopRule.EquipResult)
local function toggle(player: Player, data: PlayerData.Data, itemId: string): string
	local item = ShopConfig.Items[itemId]
	local category = ShopConfig.Categories[item.Category]
	local list, result = ShopRule.ToggleEquip(
		data.cosmetics.equipped[item.Category] or {},
		itemId,
		category.MaxEquipped,
		data.cosmetics.owned[itemId] == true
	)
	if result ~= "full" and result ~= "notOwned" then
		data.cosmetics.equipped[item.Category] = list
		apply(player, data, item.Category)
	end
	return result
end

local function tryBuy(player: Player, itemId: string)
	if not limiter.Allow(player) then
		return
	end
	local data = PlayerData.GetData(player)
	if data == nil then
		return
	end
	local item = ShopConfig.Items[itemId]
	local verdict = ShopRule.CanBuy(item, data.cosmetics.owned[itemId] == true, Economy.GetBankedAura(player))
	if verdict ~= "ok" or item == nil then
		print(string.format("[Shop] %s: покупка %s отклонена — %s", player.Name, itemId, verdict))
		return
	end
	if not Economy.TrySpend(player, item.Price, "магазин: " .. itemId) then
		return
	end
	data.cosmetics.owned[itemId] = true
	-- Сразу надеваем, если в категории есть место (одиночный слот не перезаписываем без спроса)
	local category = ShopConfig.Categories[item.Category]
	if #(data.cosmetics.equipped[item.Category] or {}) < category.MaxEquipped then
		toggle(player, data, itemId)
	end
	publish(player, data)
	Analytics.UpgradePurchased(player, "shop_" .. itemId, 1, item.Price)
	print(string.format("[Shop] %s купил %s за %d Aura", player.Name, itemId, item.Price))
end

local function tryEquip(player: Player, itemId: string)
	if not limiter.Allow(player) then
		return
	end
	local data = PlayerData.GetData(player)
	if data == nil or ShopConfig.Items[itemId] == nil then
		return
	end
	local result = toggle(player, data, itemId)
	publish(player, data)
	print(string.format("[Shop] %s: %s — %s", player.Name, itemId, result))
end

local function onCharacterAdded(player: Player, character: Model)
	-- Титул вешается на голову: ждём, пока она появится
	character:WaitForChild("Head", 10)
	local data = PlayerData.GetData(player)
	if data and character.Parent then
		CosmeticsBuilder.ApplyCharacter(character, data.cosmetics.equipped)
	end
end

function Shop.Start()
	RemoteGuard.ConnectRemoteId(RemoteGuard.CreateRemote(Remotes.ShopBuy), "магазин: покупка", tryBuy)
	RemoteGuard.ConnectRemoteId(RemoteGuard.CreateRemote(Remotes.ShopEquip), "магазин: надеть", tryEquip)

	PlayerData.OnLoaded(function(player: Player, data: PlayerData.Data)
		publish(player, data)
		apply(player, data, nil)
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		local plot = plotOf[player]
		plotOf[player] = nil
		if plot then
			CosmeticsBuilder.ClearPlot(plot) -- участок освобождается: косметика уходит вместе с игроком
		end
	end)
end

return Shop
