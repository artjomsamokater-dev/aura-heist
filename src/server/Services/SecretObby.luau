--!strict
-- SecretObby: секретный паркур над морем (задача 7.3). Детали строит MapBuilder (server/Visual/ObbyBuilder),
-- здесь — логика, всё на сервере, раз в MapConfig.Obby.CheckSeconds по позиции персонажа:
--   • упал с паркура — встаёт на последний чекпоинт (или на первую платформу). Падение замечает сервис
--     FallRescue и спрашивает SecretObby.RescueOnRoute; это не смерть: ничего не теряется;
--   • встал на платформу-чекпоинт — она становится последним (назад не откатывает, только на эту сессию);
--   • дошёл до тайного острова — награда (SecretRule): первый раз Secret-мемлинг сразу на витрину
--     (флаг secret.found в профиле до выдачи — ровно один раз), потом Aura не чаще раза в сутки;
--   • площадка возврата на острове переносит в хаб.
-- Никаких подсказок в HUD — только знак «?» у входа.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local SecretRule = require(ReplicatedStorage.Shared.Util.SecretRule)
local FallRule = require(ReplicatedStorage.Shared.Util.FallRule)
local MapBuilder = require(script.Parent.MapBuilder)
local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local Studio = require(script.Parent.Studio)
local Raid = require(script.Parent.Raid)
local RemoteGuard = require(ServerScriptService.Server.Security.RemoteGuard)

local SecretObby = {}

local checkpoints: { [Player]: number } = {} -- номер последнего чекпоинта (0 — ещё ни одного)
local onIsland: { [Player]: boolean } = {} -- уже на острове: награда — одна за приход
local onRoute: { [Player]: boolean } = {} -- стоял на платформе паркура и ещё не вернулся на площадь

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Стоит на площадке radius вокруг top: по полу ближе radius, по высоте — над ней, не выше прыжка
local function standsOn(root: BasePart, top: Vector3, radius: number): boolean
	local height = root.Position.Y - top.Y
	return flat(root.Position, top) <= radius and height > 0 and height < 8
end

-- Куда ставить после падения: платформа последнего чекпоинта или первая платформа
local function respawnPoint(player: Player): Vector3
	local cfg = MapConfig.Obby
	local index = checkpoints[player] or 0
	local platform = if index > 0 then cfg.Platforms[cfg.Checkpoints[index]] else cfg.Platforms[1]
	return platform.Position
end

local function returnToCheckpoint(player: Player, character: Model)
	local point = respawnPoint(player) + Vector3.new(0, 3.5, 0)
	local next = MapConfig.Obby.Island.Position
	character:PivotTo(CFrame.lookAt(point, Vector3.new(next.X, point.Y, next.Z)))
	print(string.format("[Obby] %s упал в море — на чекпоинт %d", player.Name, checkpoints[player] or 0))
end

-- Награда за приход на остров: Secret один раз, потом Aura раз в сутки (SecretRule)
local function reward(player: Player)
	local data = PlayerData.GetData(player)
	if data == nil then
		return
	end
	local cfg = EconomyConfig.SecretObby
	local now = os.time()
	local decision = SecretRule.Decide(data.secret.found, data.secret.lastDailyAt, now, cfg.CooldownSeconds)
	if decision == "secret" then
		-- Флаги до выдачи: второй раз Secret не выдаётся никогда
		data.secret.found = true
		data.secret.lastDailyAt = now
		Studio.AddToShowcase(player, { cfg.MemelingId })
		print(string.format("[Obby] %s нашёл тайный остров — %s на витрину", player.Name, cfg.MemelingId))
	elseif decision == "daily" then
		data.secret.lastDailyAt = now
		Economy.AddBankedAura(player, cfg.DailyAura, "секретный паркур")
		print(string.format("[Obby] %s снова на острове — +%d Aura (раз в сутки)", player.Name, cfg.DailyAura))
	else
		print(string.format("[Obby] %s снова на острове — награда за сегодня уже получена", player.Name))
	end
end

-- Упал, будучи на паркуре: на последний чекпоинт (true). Не на паркуре — false: вернёт FallRescue
function SecretObby.RescueOnRoute(player: Player, character: Model): boolean
	if not onRoute[player] then
		return false
	end
	returnToCheckpoint(player, character)
	return true
end

local function check()
	local cfg = MapConfig.Obby
	local hub = MapConfig.Hub
	local built = MapBuilder.GetObby()
	for _, player in ipairs(Players:GetPlayers()) do
		local character, root = RemoteGuard.GetAliveCharacter(player)
		if character == nil or root == nil or Raid.GetState(player) ~= Raid.State.InHub then
			continue
		end
		-- На паркуре: стоит на любой платформе; вернулся на площадь — уже нет
		for _, platform in ipairs(cfg.Platforms) do
			if standsOn(root, platform.Position, platform.Diameter / 2 + cfg.PlatformCatchRadius) then
				onRoute[player] = true
			end
		end
		if flat(root.Position, hub.Center) < hub.Radius and not FallRule.Fallen(root.Position.Y, MapConfig.FallRescue.SeaCatchY) then
			onRoute[player] = nil
		end
		for index, platformIndex in ipairs(cfg.Checkpoints) do
			if standsOn(root, cfg.Platforms[platformIndex].Position, cfg.CheckpointRadius) then
				local current = checkpoints[player] or 0
				local nextIndex = SecretRule.NextCheckpoint(current, index)
				if nextIndex ~= current then
					checkpoints[player] = nextIndex
					print(string.format("[Obby] %s: чекпоинт %d", player.Name, nextIndex))
				end
			end
		end
		local island = cfg.Island
		if standsOn(root, island.Position, island.Radius) then
			if not onIsland[player] then
				onIsland[player] = true
				reward(player)
			end
			if standsOn(root, built.ReturnPad.Position, cfg.ReturnPadRadius) then
				checkpoints[player] = nil
				onRoute[player] = nil
				character:PivotTo(MapBuilder.GetHubArrivalCFrame())
				print(string.format("[Obby] %s вернулся с острова в хаб", player.Name))
			end
		else
			onIsland[player] = nil
		end
	end
end

function SecretObby.Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		checkpoints[player] = nil
		onIsland[player] = nil
		onRoute[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(MapConfig.Obby.CheckSeconds)
			check()
		end
	end)
end

return SecretObby
