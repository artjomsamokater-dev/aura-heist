--!strict
-- FallRescue: мягкий возврат упавшего в море (задача 7.5). Раз в MapConfig.FallRescue.CheckSeconds по позиции,
-- всё на сервере: игрок в хабе (InHub), корень ниже SeaCatchY (уступ под краем хаба или море) →
--   • был на паркуре — на последний чекпоинт (SecretObby.RescueOnRoute);
--   • иначе — на ближайшую точку суши (FallRule): дорожку у мостика или вход участка.
-- Это не смерть: ничего не теряется, смертей не прибавляется. Падение из зоны — в Raid (там теряется то, что в руках).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local FallRule = require(ReplicatedStorage.Shared.Util.FallRule)
local PlotLayout = require(ReplicatedStorage.Shared.Util.PlotLayout)
local Raid = require(script.Parent.Raid)
local SecretObby = require(script.Parent.SecretObby)
local RemoteGuard = require(ServerScriptService.Server.Security.RemoteGuard)

local FallRescue = {}

local targets: { CFrame } = {} -- куда ставить (лицом по ходу)
local points: { FallRule.Point } = {} -- те же точки по полу — для FallRule

local function addTarget(position: Vector3, lookAt: Vector3)
	table.insert(targets, CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z)))
	table.insert(points, { X = position.X, Z = position.Z })
end

-- Точки возврата: на дорожке к каждому мостику (лицом к центру площади) и у входа каждого участка (лицом внутрь)
local function buildTargets()
	local cfg = MapConfig.FallRescue
	local hub = MapConfig.Hub
	local plots = MapConfig.Plots
	local lift = hub.Center.Y + hub.Size.Y / 2 + cfg.Lift
	for i = 1, plots.Count do
		local a = math.rad(plots.AngleOffsetDegrees + (i - 1) * 360 / plots.Count)
		addTarget(hub.Center + Vector3.new(math.cos(a) * cfg.HubPointRadius, lift - hub.Center.Y, math.sin(a) * cfg.HubPointRadius), hub.Center)
		local plotCFrame = PlotLayout.PlotCFrame(i)
		local entrance = plotCFrame:PointToWorldSpace(Vector3.new(0, plots.Size.Y / 2 + cfg.Lift, cfg.PlotEntranceZ))
		addTarget(entrance, plotCFrame.Position)
	end
end

local function check()
	local catchY = MapConfig.FallRescue.SeaCatchY
	for _, player in ipairs(Players:GetPlayers()) do
		local character, root = RemoteGuard.GetAliveCharacter(player)
		if character == nil or root == nil or Raid.GetState(player) ~= Raid.State.InHub then
			continue
		end
		if not FallRule.Fallen(root.Position.Y, catchY) then
			continue
		end
		root.AssemblyLinearVelocity = Vector3.zero
		if SecretObby.RescueOnRoute(player, character) then
			continue
		end
		local index = FallRule.NearestIndex(root.Position.X, root.Position.Z, points)
		if index then
			character:PivotTo(targets[index])
			print(string.format("[FallRescue] %s упал в море — вернули на ближайшую точку (%d), ничего не потеряно", player.Name, index))
		end
	end
end

function FallRescue.Start()
	buildTargets()
	task.spawn(function()
		while true do
			task.wait(MapConfig.FallRescue.CheckSeconds)
			check()
		end
	end)
end

return FallRescue
