-- Raid (минимальный): состояние игрока InHub / InRaid и портал в зону.
-- Касание портала переносит персонажа в точку входа зоны.
-- После смерти или Reset персонаж появляется в хабе и снова InHub.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local MapBuilder = require(script.Parent.MapBuilder)

local Raid = {}

Raid.State = table.freeze({
	InHub = "InHub",
	InRaid = "InRaid",
})

local states = {} -- [Player] = Raid.State.*
local portalBusy = {} -- [Player] = true, пока действует защита от повторного срабатывания

-- Сервер хранит состояние у себя; атрибут на игроке — только копия, чтобы видеть его в Studio
local function setState(player, state)
	states[player] = state
	player:SetAttribute("RaidState", state)
end

function Raid.GetState(player)
	return states[player]
end

local function onPortalTouched(hit)
	-- hit может быть частью аксессуара, поэтому ищем модель персонажа выше по дереву
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end
	if portalBusy[player] or states[player] ~= Raid.State.InHub then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
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

local function onCharacterAdded(player)
	-- Персонаж всегда появляется на SpawnLocation в хабе
	setState(player, Raid.State.InHub)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		onCharacterAdded(player)
	end)
	if player.Character then
		onCharacterAdded(player)
	end
end

local function onPlayerRemoving(player)
	states[player] = nil
	portalBusy[player] = nil
end

function Raid.Start()
	MapBuilder.GetPortal().Touched:Connect(onPortalTouched)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
end

return Raid
