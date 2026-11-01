--!strict
-- Raid: состояние игрока (InHub / InRaid), портал в зону и мемлинги «в руках» (Carried).
-- Carried живут только в памяти сервера: при смерти, новом персонаже или выходе — теряются
-- (потерянный мемлинг через ZoneConfig.LostRespawnSeconds возвращается на свою точку спавна).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local MemelingConfig = require(ReplicatedStorage.Shared.Config.MemelingConfig)
local UpgradeValues = require(ReplicatedStorage.Shared.Util.UpgradeValues)
local CarrySpeed = require(ReplicatedStorage.Shared.Util.CarrySpeed)
local MemelingSize = require(ReplicatedStorage.Shared.Util.MemelingSize)
local ExtractionRule = require(ReplicatedStorage.Shared.Util.ExtractionRule)
local PortalRule = require(ReplicatedStorage.Shared.Util.PortalRule)
local ZoneRule = require(ReplicatedStorage.Shared.Util.ZoneRule)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SecurityConfig = require(ReplicatedStorage.Shared.Config.SecurityConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local MapBuilder = require(script.Parent.MapBuilder)
local PlayerData = require(script.Parent.PlayerData)
local Tutorial = require(script.Parent.Tutorial)
local Analytics = require(script.Parent.Analytics)
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
	StartedAt: number, -- когда вошёл в зону (os.clock) — для экрана результата
}
local runs: { [Player]: Run } = {}

-- Кто хочет знать о подборе (Enemy: охрана). Подписываются через Raid.OnPickup — Raid не знает, кто это
local pickupListeners: { (player: Player, position: Vector3) -> () } = {}

function Raid.OnPickup(listener: (player: Player, position: Vector3) -> ())
	table.insert(pickupListeners, listener)
end

local pickupLimiter =
	RateLimiter.new(SecurityConfig.RateLimits.Pickup.MaxRequests, SecurityConfig.RateLimits.Pickup.WindowSeconds)
local dropLimiter = RateLimiter.new(SecurityConfig.RateLimits.Drop.MaxRequests, SecurityConfig.RateLimits.Drop.WindowSeconds)

local zones: { [Player]: string } = {} -- в какой зоне вылазка (Id из ZoneConfig.ZoneOrder)

-- Сервер хранит состояние у себя; атрибуты на игроке — копия для клиента (HUD, маркер EXTRACT) и Studio.
-- zoneId — зона вылазки (только для InRaid)
local function setState(player: Player, state: string, zoneId: string?)
	states[player] = state
	if state == Raid.State.InRaid and zoneId then
		zones[player] = zoneId
	else
		zones[player] = nil
	end
	player:SetAttribute("RaidState", state)
	player:SetAttribute("RaidZone", zones[player])
end

function Raid.GetState(player: Player): string?
	return states[player]
end

-- Зона текущей вылазки (nil — игрок в хабе)
function Raid.GetZone(player: Player): string?
	return zones[player]
end

-- Шаги туториала засчитываются только в зонах с Tutorial = true (стартовая)
local function inTutorialZone(player: Player): boolean
	local zoneId = zones[player]
	return zoneId ~= nil and ZoneConfig.Zones[zoneId].Tutorial
end

-- Есть ли у игрока доступ в зону: бесплатная или купленная (профиль, zoneAccess)
function Raid.HasZoneAccess(player: Player, zoneId: string): boolean
	local data = PlayerData.GetData(player)
	return ZoneRule.HasAccess(ZoneConfig.Zones[zoneId].AccessCost, if data then data.zoneAccess else nil, zoneId)
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

-- Редкости того, что сейчас в руках
local function getCarriedRarities(player: Player): { string }
	local rarities: { string } = {}
	for _, instanceId in ipairs(carried[player] or {}) do
		local record = Spawn.Get(instanceId)
		local memeling = record and MemelingConfig.Memelings[record.MemelingId]
		if memeling then
			table.insert(rarities, memeling.Rarity)
		end
	end
	return rarities
end

-- Можно ли эвакуироваться через вторую точку у входа (без Epic/Legendary в руках — ExtractionRule)
function Raid.CanUseSideExtraction(player: Player): boolean
	return ExtractionRule.SideAllowed(ZoneConfig.SideEvacuation.BlockedRarities, getCarriedRarities(player))
end

-- Скорость шага по тому, что в руках (CarrySpeed): самая медленная редкость, пустые руки — обычная.
-- Обычная скорость запоминается на Humanoid при появлении персонажа (атрибут BaseWalkSpeed).
-- Здесь же — атрибут SideExtractionBlocked для HUD (вызывается при любом изменении рук)
local function updateCarrySpeed(player: Player)
	player:SetAttribute("SideExtractionBlocked", not Raid.CanUseSideExtraction(player))
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

-- Высота мемлинга в руках: габарит × уменьшение в руках × размер его редкости
local function getCarriedHeight(instanceId: string): number
	local record = Spawn.Get(instanceId)
	local scale = if record then MapBuilder.GetMemelingScale(record.MemelingId) else 1
	return StyleConfig.Memeling.Size.Y * StyleConfig.Memeling.CarryScale * scale
end

-- Где висит мемлинг номер slotIndex из списка в руках: первый — перед грудью (крупный — дальше вперёд,
-- чтобы не влезал в персонажа), остальные — стопкой на голове, каждый на верхушке предыдущего
local function getCarryOffset(list: { string }, slotIndex: number): Vector3
	local cfg = StyleConfig.Memeling
	if slotIndex == 1 then
		local extra = getCarriedHeight(list[1]) - cfg.Size.Z * cfg.CarryScale
		return cfg.CarryFront - Vector3.new(0, 0, math.max(0, extra) / 2)
	end
	local heights: { number } = {}
	for i = 2, slotIndex do
		table.insert(heights, getCarriedHeight(list[i]))
	end
	return Vector3.new(0, MemelingSize.StackCenterY(heights, #heights, cfg.CarryHeadTop, cfg.CarryStackGap), 0)
end

-- Мемлинг едет вместе с персонажем: приварен к HumanoidRootPart и лежит внутри модели персонажа.
-- Развёрнут на 180°, чтобы глазами смотрел на игрока (камера обычно сзади).
local function attachToCharacter(part: Part, character: Model, root: BasePart, list: { string }, slotIndex: number)
	local offset = getCarryOffset(list, slotIndex)
	-- В руках мемлинг меньше и без подписи — не закрывает обзор (пока он ещё закреплён — уменьшаем)
	MapBuilder.ScaleMemeling(part, StyleConfig.Memeling.CarryScale)
	local label = part:FindFirstChild("Label")
	if label and label:IsA("BillboardGui") then
		label.Enabled = false
	end
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
	if record == nil or not Spawn.CanPickUp(record, player) then
		return -- уже подобран или чужой лут
	end
	local reach = MemelingSize.Reach(
		ZoneConfig.PickupDistance,
		StyleConfig.Memeling.Size.X,
		MapBuilder.GetMemelingScale(record.MemelingId)
	)
	if not RemoteGuard.IsNear(root, record.Part.Position, reach) then
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
	attachToCharacter(record.Part, character, root, list, #list)
	player:SetAttribute("CarriedCount", #list)
	updateCarrySpeed(player)
	print(string.format("[Raid] %s подобрал %s (%s)", player.Name, record.MemelingId, instanceId))
	for _, listener in ipairs(pickupListeners) do
		task.spawn(listener, player, root.Position)
	end
	if inTutorialZone(player) then
		Tutorial.Notify(player, "PickUp")
	end
	local memeling = MemelingConfig.Memelings[record.MemelingId]
	Analytics.MemelingPicked(player, if memeling then memeling.Rarity else "")
end

-- Игрок нажал «Drop»: последний мемлинг из рук отпускается и, как потерянный,
-- возвращается на свою точку спавна через ZoneConfig.LostRespawnSeconds. Только в зоне и только живым
local function tryDrop(player: Player)
	if not dropLimiter.Allow(player) then
		return
	end
	local character = RemoteGuard.GetAliveCharacter(player)
	local list = carried[player]
	if character == nil or states[player] ~= Raid.State.InRaid or list == nil or #list == 0 then
		return
	end
	local instanceId = table.remove(list) :: string
	Spawn.Lose(instanceId)
	player:SetAttribute("CarriedCount", #list)
	updateCarrySpeed(player)
	print(string.format("[Raid] %s отпустил мемлинга %s", player.Name, instanceId))
end

-- Почему портал не пустил — для Output (ключи — shared/Util/PortalRule)
local PORTAL_REASONS: { [string]: string } = {
	busy = "пауза после прошлого входа (MapConfig.Portal.CooldownSeconds)",
	notInHub = "игрок не в хабе (уже в вылазке)",
	noProfile = "профиль ещё не загружен (PlayerData) — вынесенное было бы некуда сохранить",
	dead = "персонаж мёртв",
	noAccess = "доступ в эту зону не куплен (золотые ворота)",
}
local PORTAL_LOG_SECONDS = 2 -- одну и ту же причину для игрока пишем не чаще: касаний много в секунду
local portalLog: { [Player]: { [string]: number } } = {}

local function logPortal(player: Player, zoneId: string, decision: string, source: string)
	local now = os.clock()
	local byReason = portalLog[player] or {}
	portalLog[player] = byReason
	local key = zoneId .. ":" .. decision
	if byReason[key] and now - byReason[key] < PORTAL_LOG_SECONDS then
		return
	end
	byReason[key] = now
	if decision == "ok" then
		print(string.format("[Portal] %s (%s, портал %s): пустили в зону", player.Name, source, zoneId))
	else
		print(string.format("[Portal] %s (%s, портал %s): не пустили — %s", player.Name, source, zoneId, PORTAL_REASONS[decision] or decision))
	end
end

-- Вход в портал зоны zoneId: и по касанию, и по проверке позиции (если Touched не сработал). Решение — PortalRule
local function tryEnterPortal(player: Player, character: Model, zoneId: string, source: string)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	-- Пока профиль не загружен, в зону не пускаем: вынесенное было бы некуда сохранить
	local data = PlayerData.GetData(player)
	local decision = PortalRule.Decide(
		portalBusy[player] == true,
		states[player] == Raid.State.InHub,
		data ~= nil,
		humanoid ~= nil and humanoid.Health > 0,
		Raid.HasZoneAccess(player, zoneId)
	)
	if decision == "busy" and states[player] ~= Raid.State.InHub then
		return -- только что вошли: в зоне касаний портала уже нет, писать нечего
	end
	logPortal(player, zoneId, decision, source)
	if decision ~= "ok" or data == nil then
		return
	end

	portalBusy[player] = true
	character:PivotTo(MapBuilder.GetZoneEntryCFrame(zoneId))
	runs[player] = { Rewarded = false, StartedAt = os.clock() }
	data.stats.raids += 1
	setState(player, Raid.State.InRaid, zoneId)
	if inTutorialZone(player) then
		Tutorial.Notify(player, "EnterZone")
	end
	Analytics.RaidStarted(player)
	print(string.format("[Raid] %s вошёл в зону %s", player.Name, zoneId))

	task.delay(MapConfig.Portal.CooldownSeconds, function()
		portalBusy[player] = nil
	end)
end

local function onPortalTouched(zoneId: string, hit: BasePart)
	-- hit может быть частью аксессуара, поэтому ищем персонажа выше по дереву (первая Model может быть
	-- моделью-деталью, например Figure мемлинга, — поэтому проверяем все модели вверх)
	local model = hit:FindFirstAncestorOfClass("Model")
	while model do
		local player = Players:GetPlayerFromCharacter(model)
		if player then
			tryEnterPortal(player, model, zoneId, "касание")
			return
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
end

-- Запасной путь: раз в PortalCheckSeconds — кто из игроков в хабе стоит внутри какого-нибудь портала.
-- Работает, даже если Touched не пришёл (тонкий триггер, быстрый бег, лаг)
local function checkPortalOverlap()
	for _, zoneId in ipairs(ZoneConfig.ZoneOrder) do
		local portal = MapBuilder.GetPortal(zoneId)
		local half = portal.Size / 2
		for player, state in states do
			if state == Raid.State.InHub and not portalBusy[player] then
				local character, root = RemoteGuard.GetAliveCharacter(player)
				if character and root then
					local offset = portal.CFrame:PointToObjectSpace(root.Position)
					if PortalRule.IsInside(offset.X, offset.Y, offset.Z, half.X, half.Y, half.Z, MapConfig.Portal.OverlapMargin) then
						tryEnterPortal(player, character, zoneId, "позиция")
					end
				end
			end
		end
	end
end

-- Проверка при старте: триггер портала зоны существует, в мире, касаем и стоит на полу хаба
local function validatePortal(zoneId: string)
	local portal = MapBuilder.GetPortal(zoneId)
	local problems: { string } = {}
	if not portal:IsDescendantOf(Workspace) then
		table.insert(problems, "деталь не в Workspace")
	end
	if not portal.CanTouch then
		table.insert(problems, "CanTouch = false — касания не придут")
	end
	local hub = MapConfig.Hub
	local floorTop = hub.Center.Y + hub.Size.Y / 2
	local bottom = portal.Position.Y - portal.Size.Y / 2
	if bottom > floorTop + 1 or portal.Position.Y + portal.Size.Y / 2 < floorTop + 3 then
		table.insert(problems, string.format("стоит не на уровне игрока (низ %.1f, пол хаба %.1f)", bottom, floorTop))
	end
	if #problems > 0 then
		warn(string.format("[Portal] Триггер портала %s неисправен: %s", zoneId, table.concat(problems, "; ")))
	else
		print(string.format("[Portal] Триггер портала в порядке (%s): %s, размер %s, CanTouch", zoneId, tostring(portal.Position), tostring(portal.Size)))
	end
end

-- Забирает добычу успешной эвакуации. Вернёт MemelingId всего, что было в руках, и сколько секунд
-- длилась вылазка — или nil, если игрок не в вылазке или награда за эту вылазку уже выдана.
function Raid.ClaimExtraction(player: Player): ({ string }?, number)
	local run = runs[player]
	if states[player] ~= Raid.State.InRaid or run == nil or run.Rewarded then
		return nil, 0
	end
	local raidSeconds = os.clock() - run.StartedAt
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
	return memelingIds, raidSeconds
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

-- Смерть в зоне: всё из рук выпадает на пол у места смерти — лут погибшего (Spawn.DropAsLoot).
-- Точка — внутри пола зоны, несколько мемлингов раскладываются кругом
local function dropCarriedAsLoot(player: Player, position: Vector3)
	local list = carried[player]
	carried[player] = nil
	player:SetAttribute("CarriedCount", 0)
	updateCarrySpeed(player)
	if list == nil or #list == 0 then
		return
	end
	local zone = MapConfig.Zones[zones[player] or ZoneConfig.FirstZone]
	local half = zone.Size / 2
	local margin = ZoneConfig.LootSpreadStuds + StyleConfig.Memeling.Size.X
	local x = math.clamp(position.X, zone.Center.X - half.X + margin, zone.Center.X + half.X - margin)
	local z = math.clamp(position.Z, zone.Center.Z - half.Z + margin, zone.Center.Z + half.Z - margin)
	local floorY = zone.Center.Y + half.Y
	local radius = if #list > 1 then ZoneConfig.LootSpreadStuds else 0
	for i, instanceId in ipairs(list) do
		local angle = (i - 1) * 2 * math.pi / #list
		Spawn.DropAsLoot(instanceId, player, Vector3.new(x + math.cos(angle) * radius, floorY, z + math.sin(angle) * radius))
	end
	print(string.format("[Raid] %s: выпало мемлингов: %d, поднять можно %d с", player.Name, #list, ZoneConfig.LootSeconds))
end

-- Смерть (ловушка, враг, Reset или падение из зоны): вылазка закрыта — награду за неё уже не выдать.
-- В зоне всё из рук выпадает лутом на месте смерти (deathPosition); падение из зоны (позиции нет) —
-- всё теряется, как раньше. Витрину и Aura смерть не трогает. Считаем в stats.deaths.
local function onDeath(player: Player, cause: string, deathPosition: Vector3?)
	Analytics.PlayerDied(player, #(carried[player] or {}), cause) -- до потери: сколько было в руках
	if deathPosition and states[player] == Raid.State.InRaid then
		dropCarriedAsLoot(player, deathPosition)
	else
		loseCarried(player, "смерть: " .. cause)
	end
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
	for player, state in states do
		local zoneId = zones[player]
		if state == Raid.State.InRaid and zoneId then
			local zone = MapConfig.Zones[zoneId]
			local limitY = zone.Center.Y + zone.Size.Y / 2 - zone.FallLimitStuds
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
			local root = character:FindFirstChild("HumanoidRootPart")
			local position = if root and root:IsA("BasePart") then root.Position else nil
			onDeath(player, if type(source) == "string" then source else "Reset", position)
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
	Spawn.LoseLootOf(player)
	states[player] = nil
	zones[player] = nil
	portalBusy[player] = nil
	portalLog[player] = nil
	runs[player] = nil
end

function Raid.Start()
	for _, zoneId in ipairs(ZoneConfig.ZoneOrder) do
		validatePortal(zoneId)
		MapBuilder.GetPortal(zoneId).Touched:Connect(function(hit: BasePart)
			onPortalTouched(zoneId, hit)
		end)
	end
	task.spawn(function()
		while true do
			task.wait(MapConfig.Portal.CheckSeconds)
			checkPortalOverlap()
		end
	end)
	Spawn.SetPickupHandler(tryPickup)
	RemoteGuard.ConnectRemote(RemoteGuard.CreateRemote(Remotes.DropCarried), "бросок", tryDrop)

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
			task.wait(MapConfig.Zones[ZoneConfig.FirstZone].FallCheckSeconds)
			checkFallenPlayers()
		end
	end)
end

return Raid
