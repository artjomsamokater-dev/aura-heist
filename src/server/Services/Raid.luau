--!strict
-- Raid: состояние игрока (InHub / InRaid), портал в зону и мемлинги «в руках» (Carried).
-- Carried живут только в памяти сервера: при смерти, новом персонаже или выходе — теряются
-- (потерянный мемлинг через ZoneConfig.LostRespawnSeconds возвращается на свою точку спавна).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local MemelingConfig = require(ReplicatedStorage.Shared.Config.MemelingConfig)
local UpgradeValues = require(ReplicatedStorage.Shared.Util.UpgradeValues)
local CarrySpeed = require(ReplicatedStorage.Shared.Util.CarrySpeed)
local SecurityConfig = require(ReplicatedStorage.Shared.Config.SecurityConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local MapBuilder = require(script.Parent.MapBuilder)
local PlayerData = require(script.Parent.PlayerData)
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

-- Текущая вылазка игрока: создаётся при входе через портал.
-- Rewarded — флаг «награда за эту вылазку выдана», ставится ДО выдачи.
type Run = {
	Rewarded: boolean,
}
local runs: { [Player]: Run } = {}

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

-- Сколько мемлингов игрок может нести: стартовое число или купленный уровень рюкзака
local function getCarrySlots(player: Player): number
	local data = PlayerData.GetData(player)
	return UpgradeValues.CarrySlots(if data then data.upgrades.carrySlots else 0)
end

-- Обновить атрибут CarrySlots для HUD (после загрузки профиля и после покупки слота)
function Raid.RefreshCarrySlots(player: Player)
	player:SetAttribute("CarrySlots", getCarrySlots(player))
end

local function getCarried(player: Player): { string }
	local list = carried[player]
	if list == nil then
		list = {}
		carried[player] = list
	end
	return list
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

-- Скорость шага по тому, что в руках (CarrySpeed): самая медленная редкость, пустые руки — обычная.
-- Обычная скорость запоминается на Humanoid при появлении персонажа (атрибут BaseWalkSpeed).
local function updateCarrySpeed(player: Player)
	local humanoid = getHumanoid(player)
	if humanoid == nil then
		return
	end
	local base = humanoid:GetAttribute("BaseWalkSpeed")
	if type(base) ~= "number" then
		return
	end
	local speeds: { number } = {}
	for _, instanceId in ipairs(carried[player] or {}) do
		local record = Spawn.Get(instanceId)
		local memeling = record and MemelingConfig.Memelings[record.MemelingId]
		local rarity = memeling and MemelingConfig.Rarities[memeling.Rarity]
		if rarity then
			table.insert(speeds, rarity.CarrySpeed)
		end
	end
	humanoid.WalkSpeed = CarrySpeed.Compute(base, speeds)
end

-- Всё, что было в руках, пропадает из мира
local function loseCarried(player: Player, reason: string)
	local list = carried[player]
	carried[player] = nil
	player:SetAttribute("CarriedCount", 0)
	updateCarrySpeed(player)
	if list == nil or #list == 0 then
		return
	end
	for _, instanceId in ipairs(list) do
		Spawn.Lose(instanceId)
	end
	print(string.format("[Raid] %s потерял мемлингов: %d (%s)", player.Name, #list, reason))
end

-- Где висит мемлинг номер slotIndex: места из StyleConfig, дальше — выше по стопке
local function getCarryOffset(slotIndex: number): Vector3
	local offsets = StyleConfig.Memeling.CarrySlotOffsets
	local offset = offsets[slotIndex]
	if offset then
		return offset
	end
	return offsets[#offsets] + StyleConfig.Memeling.CarryStackStep * (slotIndex - #offsets)
end

-- Мемлинг едет вместе с персонажем: приварен к HumanoidRootPart и лежит внутри модели персонажа.
-- Развёрнут на 180°, чтобы глазами смотрел на игрока (камера обычно сзади).
local function attachToCharacter(part: Part, character: Model, root: BasePart, slotIndex: number)
	local offset = getCarryOffset(slotIndex)
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	part.CFrame = root.CFrame * CFrame.new(offset) * CFrame.Angles(0, math.pi, 0)

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
	updateCarrySpeed(player)
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
	-- Пока профиль не загружен, в зону не пускаем: вынесенное было бы некуда сохранить
	local data = PlayerData.GetData(player)
	if data == nil then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end

	portalBusy[player] = true
	character:PivotTo(MapBuilder.GetZoneEntryCFrame())
	runs[player] = { Rewarded = false }
	data.stats.raids += 1
	setState(player, Raid.State.InRaid)
	print(string.format("[Raid] %s вошёл в зону", player.Name))

	task.delay(MapConfig.Portal.CooldownSeconds, function()
		portalBusy[player] = nil
	end)
end

-- Забирает добычу успешной эвакуации. Вернёт MemelingId всего, что было в руках,
-- или nil, если игрок не в вылазке или награда за эту вылазку уже выдана.
function Raid.ClaimExtraction(player: Player): { string }?
	local run = runs[player]
	if states[player] ~= Raid.State.InRaid or run == nil or run.Rewarded then
		return nil
	end
	run.Rewarded = true -- флаг до выдачи: второй вызов получит nil

	local list = carried[player] or {}
	carried[player] = nil
	player:SetAttribute("CarriedCount", 0)

	local memelingIds = {}
	for _, instanceId in ipairs(list) do
		local record = Spawn.Get(instanceId)
		if record then
			table.insert(memelingIds, record.MemelingId)
		end
		Spawn.Despawn(instanceId)
	end
	updateCarrySpeed(player) -- руки пустые — обычная скорость
	return memelingIds
end

-- Переносит живого персонажа в хаб и ставит InHub (после эвакуации)
function Raid.ReturnToHub(player: Player)
	runs[player] = nil
	setState(player, Raid.State.InHub)
	local character = RemoteGuard.GetAliveCharacter(player)
	if character then
		character:PivotTo(MapBuilder.GetHubArrivalCFrame())
	end
end

-- Смерть (ловушка, враг, Reset или падение из зоны): всё из рук теряется, вылазка закрыта —
-- награду за неё уже не выдать. Витрину и Aura смерть не трогает. Считаем в stats.deaths.
local function onDeath(player: Player, cause: string)
	loseCarried(player, "смерть: " .. cause)
	runs[player] = nil
	local data = PlayerData.GetData(player)
	if data then
		data.stats.deaths += 1
	end
	print(string.format("[Raid] %s погиб (%s), смертей всего %d", player.Name, cause, if data then data.stats.deaths else 0))
end

-- Страховка: игрок InRaid провалился ниже пола зоны — как после смерти:
-- всё из рук теряется, новый персонаж появляется в хабе
local function checkFallenPlayers()
	local zone = MapConfig.Zone
	local limitY = zone.Center.Y + zone.Size.Y / 2 - zone.FallLimitStuds
	for player, state in states do
		if state == Raid.State.InRaid then
			local _, root = RemoteGuard.GetAliveCharacter(player)
			if root and root.Position.Y < limitY then
				print(string.format("[Raid] %s выпал из зоны, возвращаем в хаб", player.Name))
				onDeath(player, "выпал из зоны")
				setState(player, Raid.State.InHub)
				task.spawn(function()
					player:LoadCharacterAsync()
				end)
			end
		end
	end
end

local function onCharacterAdded(player: Player, character: Model)
	-- Новый персонаж всегда появляется на SpawnLocation в хабе и ничего не несёт
	loseCarried(player, "новый персонаж")
	runs[player] = nil
	setState(player, Raid.State.InHub)

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		-- Новый персонаж ещё ничего не несёт: его скорость и есть обычная
		if humanoid:GetAttribute("BaseWalkSpeed") == nil then
			humanoid:SetAttribute("BaseWalkSpeed", humanoid.WalkSpeed)
		end
		humanoid.Died:Connect(function()
			-- Источник последнего урона записывает сервис Damage; нет его — значит, Reset
			local source = humanoid:GetAttribute("LastDamageSource")
			onDeath(player, if type(source) == "string" then source else "Reset")
		end)
	end
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("CarriedCount", 0)
	player:SetAttribute("CarrySlots", getCarrySlots(player))
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
	runs[player] = nil
end

function Raid.Start()
	MapBuilder.GetPortal().Touched:Connect(onPortalTouched)
	Spawn.SetPickupHandler(tryPickup)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	PlayerData.OnLoaded(function(player)
		Raid.RefreshCarrySlots(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MapConfig.Zone.FallCheckSeconds)
			checkFallenPlayers()
		end
	end)
end

return Raid
