--!strict
-- ZoneAccess: доступ в платные зоны (задача 7.2). Перед порталом такой зоны в хабе — золотые ворота
-- (MapBuilder), на их замке кнопка «Unlock» с удержанием ZoneConfig.UnlockHoldSeconds.
-- Все проверки — на сервере: рядом, профиль загружен, доступа ещё нет, Aura хватает. Списывает только
-- Economy.TrySpend, потом флаг zoneAccess[Id] в профиле — доступ навсегда (повторно не продаётся).
-- Атрибут игрока ZoneAccess_<Id> = true — копия для клиента: он прячет у себя ворота и кнопку.
-- Не купившего в зону не пускает Raid (PortalRule: noAccess).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local SecurityConfig = require(ReplicatedStorage.Shared.Config.SecurityConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local formatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local MapBuilder = require(script.Parent.MapBuilder)
local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local Analytics = require(script.Parent.Analytics)
local RemoteGuard = require(ServerScriptService.Server.Security.RemoteGuard)
local RateLimiter = require(ServerScriptService.Server.Security.RateLimiter)

local ZoneAccess = {}

local limiter = RateLimiter.new(SecurityConfig.RateLimits.Buy.MaxRequests, SecurityConfig.RateLimits.Buy.WindowSeconds)
local lastPurchaseAt: { [Player]: number } = {}

local function attributeName(zoneId: string): string
	return "ZoneAccess_" .. zoneId
end

-- Копия купленных доступов на игроке (для клиента)
local function publish(player: Player, data: PlayerData.Data)
	for _, zoneId in ipairs(ZoneConfig.ZoneOrder) do
		if ZoneConfig.Zones[zoneId].AccessCost ~= nil then
			player:SetAttribute(attributeName(zoneId), data.zoneAccess[zoneId] == true)
		end
	end
end

-- Игрок удержал «Unlock» у золотых ворот зоны zoneId
local function tryUnlock(player: Player, zoneId: string, lock: BasePart)
	local cost = ZoneConfig.Zones[zoneId].AccessCost
	if cost == nil or not limiter.Allow(player) then
		return
	end
	local last = lastPurchaseAt[player]
	if last and os.clock() - last < SecurityConfig.PurchaseCooldownSeconds then
		return
	end
	local _, root = RemoteGuard.GetAliveCharacter(player)
	local data = PlayerData.GetData(player)
	if root == nil or data == nil or not RemoteGuard.IsNear(root, lock.Position, EconomyConfig.ButtonDistance) then
		return
	end
	if data.zoneAccess[zoneId] then
		return -- уже куплено: доступ навсегда, второй раз не продаём
	end
	if not Economy.TrySpend(player, cost, "доступ в зону " .. zoneId) then
		print(string.format("[ZoneAccess] %s: не хватает Aura на доступ в %s (%d)", player.Name, zoneId, cost))
		return
	end
	data.zoneAccess[zoneId] = true
	lastPurchaseAt[player] = os.clock()
	publish(player, data)
	Analytics.UpgradePurchased(player, "zone_" .. zoneId, 1, cost)
	print(string.format("[ZoneAccess] %s купил доступ в %s за %d Aura", player.Name, zoneId, cost))
end

function ZoneAccess.Start()
	for _, zoneId in ipairs(ZoneConfig.ZoneOrder) do
		local cost = ZoneConfig.Zones[zoneId].AccessCost
		local lock = MapBuilder.GetZoneGateLock(zoneId)
		if cost ~= nil and lock then
			MapBuilder.SetLabelText(lock, formatNumber(cost))
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "UnlockPrompt"
			prompt.ActionText = TextConfig.UnlockAction
			prompt.ObjectText = string.format(TextConfig.PriceTag, formatNumber(cost))
			prompt.HoldDuration = ZoneConfig.UnlockHoldSeconds
			prompt.MaxActivationDistance = EconomyConfig.ButtonDistance
			prompt.RequiresLineOfSight = false
			prompt.Parent = lock
			RemoteGuard.ConnectPrompt(prompt, "доступ в зону", function(player: Player)
				tryUnlock(player, zoneId, lock)
			end)
		elseif cost ~= nil then
			warn(string.format("[ZoneAccess] У платной зоны %s нет золотых ворот — доступ не купить", zoneId))
		end
	end
	PlayerData.OnLoaded(publish)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastPurchaseAt[player] = nil
	end)
end

return ZoneAccess
