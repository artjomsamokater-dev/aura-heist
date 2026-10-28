--!strict
-- Raid: состояние игрока (InHub / InRaid), портал в зону и мемлинги «в руках» (Carried).
-- Carried живут только в памяти сервера: при смерти, новом персонаже или выходе — теряются.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local SecurityConfig = require(ReplicatedStorage.Shared.Config.SecurityConfig)
local MapBuilder = require(script.Parent.MapBuilder)
local Spawn = require(script.Parent.Spawn)
local RemoteGuard = require(ServerScriptService.Server.Security.RemoteGuard)
local RateLimiter = require(ServerScriptService.Server.Security.RateLimiter)

local Raid = {}

Raid.State = table.freeze({
	InHub = "InHub",
	InRaid = "InRaid",
})

local states: { [Player]: string } = {}
local portalBusy: { [Player]: boolean } = {} -- защита портала от повторного срабатывания
local carried: { [Player]: { string } } = {} -- InstanceId мемлингов в руках, по порядку подбора

local pickupLimiter =
	RateLimiter.new(SecurityConfig.RateLimits.Pickup.MaxRequests, SecurityConfig.RateLimits.Pickup.WindowSeconds)

-- Сервер хранит состояние у себя; атрибут на игроке — только копия, чтобы видеть его в Studio
local function setState(player: Player, state: string)
	states[player] = state
	player:SetAttribute("RaidState", state)
end

function Raid.GetState(player: Player): string?
	return states[player]
end

-- Сколько мемлингов игрок может нести. Улучшение слотов появится позже (задачи 2.2 и 3.3).
local function getCarrySlots(_player: Player): number
	return UpgradeConfig.CarrySlots.StartCount
end

local function getCarried(player: Player): { string }
	local list = carried[player]
	if list == nil then
		list = {}
		carried[player] = list
	end
	return list
end

-- Всё, что было в руках, пропадает из мира
local function loseCarried(player: Player, reason: string)
	local list = carried[player]
	carried[player] = nil
	player:SetAttribute("CarriedCount", 0)
	if list == nil or #list == 0 then
		return
	end
	for _, instanceId in ipairs(list) do
		Spawn.Despawn(instanceId)
	end
	print(string.format("[Raid] %s потерял мемлингов: %d (%s)", player.Name, #list, reason))
end

-- Куб едет вместе с персонажем: приварен к HumanoidRootPart и лежит внутри модели персонажа
local function attachToCharacter(part: Part, character: Model, root: BasePart, slotIndex: number)
	local offset = MapConfig.Memeling.CarryOffset + MapConfig.Memeling.CarryStackStep * (slotIndex - 1)
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	part.CFrame = root.CFrame * CFrame.new(offset)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part

	part.Parent = character
end

-- Игрок нажал «Pick up». Каждая проверка — на сервере, клиент прислал только сам факт нажатия.
local function tryPickup(player: Player, instanceId: string)
	if not pickupLimiter.Allow(player) then
		return
	end
	if not RemoteGuard.IsId(instanceId) then
		return
	end

	local character, root = RemoteGuard.GetAliveCharacter(player)
	if character == nil or root == nil then
		return
	end
	if states[player] ~= Raid.State.InRaid then
		return
	end

	local record = Spawn.Get(instanceId)
	if record == nil or record.State ~= Spawn.State.InZone then
		return
	end
	if not RemoteGuard.IsNear(root, record.Part.Position, ZoneConfig.PickupDistance) then
		return
	end

	local list = getCarried(player)
	if #list >= getCarrySlots(player) then
		print(string.format("[Raid] %s: руки заняты (%d/%d)", player.Name, #list, getCarrySlots(player)))
		return
	end

	-- Сначала флаг «подобран», потом всё остальное
	if not Spawn.MarkCarried(instanceId, player) then
		return
	end
	table.insert(list, instanceId)
	attachToCharacter(record.Part, character, root, #list)
	player:SetAttribute("CarriedCount", #list)
	print(string.format("[Raid] %s подобрал %s (%s)", player.Name, record.MemelingId, instanceId))
end

local function onPortalTouched(hit: BasePart)
	-- hit может быть частью аксессуара, поэтому ищем модель персонажа выше по дереву
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if character == nil or player == nil then
		return
	end
	if portalBusy[player] or states[player] ~= Raid.State.InHub then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end

	portalBusy[player] = true
	character:PivotTo(MapBuilder.GetZoneEntryCFrame())
	setState(player, Raid.State.InRaid)
	print(string.format("[Raid] %s вошёл в зону", player.Name))

	task.delay(MapConfig.Portal.CooldownSeconds, function()
		portalBusy[player] = nil
	end)
end

local function onCharacterAdded(player: Player, character: Model)
	-- Новый персонаж всегда появляется на SpawnLocation в хабе и ничего не несёт
	loseCarried(player, "новый персонаж")
	setState(player, Raid.State.InHub)

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			loseCarried(player, "смерть")
		end)
	end
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("CarriedCount", 0)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	loseCarried(player, "выход из игры")
	states[player] = nil
	portalBusy[player] = nil
end

function Raid.Start()
	MapBuilder.GetPortal().Touched:Connect(onPortalTouched)
	Spawn.SetPickupHandler(tryPickup)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
end

return Raid
