--!strict
-- Точка входа сервера: проверяет Config и запускает сервисы по порядку.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local EconomyConfig = require(Config.EconomyConfig)
local MemelingConfig = require(Config.MemelingConfig)
local ZoneConfig = require(Config.ZoneConfig)
local UpgradeConfig = require(Config.UpgradeConfig)
local MapConfig = require(Config.MapConfig)

local memelingCount = 0
for _ in MemelingConfig.Memelings do
	memelingCount += 1
end
print(
	string.format(
		"[Config] OK: %d редкости, %d мемлингов, ресток %d с, старт %d постамента, автосейв %d с, участков %d",
		#MemelingConfig.RarityOrder,
		memelingCount,
		ZoneConfig.RestockSeconds,
		UpgradeConfig.Pedestals.StartCount,
		EconomyConfig.AutosaveSeconds,
		MapConfig.Plots.Count
	)
)

local Services = script.Services
local LightingSetup = require(Services.LightingSetup)
local MapBuilder = require(Services.MapBuilder)
local PlayerData = require(Services.PlayerData)
local Economy = require(Services.Economy)
local Studio = require(Services.Studio)
local Raid = require(Services.Raid)
local Spawn = require(Services.Spawn)
local Extraction = require(Services.Extraction)
local Hazards = require(Services.Hazards)
local Enemy = require(Services.Enemy)
local Announcer = require(Services.Announcer)
local Event = require(Services.Event)
local Tutorial = require(Services.Tutorial)
local Analytics = require(Services.Analytics)
local ZoneAccess = require(Services.ZoneAccess)
local SecretObby = require(Services.SecretObby)
local DebugCommands = require(Services.DebugCommands)

-- Ошибка при запуске одного сервиса не должна молча выключать все следующие (например, портал в Raid):
-- она видна в Output с именем сервиса, остальные запускаются дальше
local failed: { string } = {}
local function start(name: string, fn: () -> ())
	local ok, err = xpcall(fn :: any, debug.traceback)
	if not ok then
		table.insert(failed, name)
		warn(string.format("[Server] Сервис %s упал при запуске: %s", name, tostring(err)))
	end
end

-- Порядок важен: сначала карта, потом сервисы, которые её используют
start("LightingSetup", LightingSetup.Apply)
start("MapBuilder", MapBuilder.Build)
start("Announcer", Announcer.Start) -- раньше Spawn: первый спавн уже может объявлять
start("Economy", Economy.Start)
start("Studio", Studio.Start)
start("ZoneAccess", ZoneAccess.Start)
start("SecretObby", SecretObby.Start)
start("Raid", Raid.Start)
start("Spawn", Spawn.Start)
start("Extraction", Extraction.Start)
start("Hazards", Hazards.Start)
start("Enemy", Enemy.Start)
start("Event", Event.Start)
start("Tutorial", Tutorial.Start)
start("Analytics", Analytics.Start)
start("DebugCommands", DebugCommands.Start) -- только в Studio
-- Последним: все сервисы уже подписались на PlayerData.OnLoaded
start("PlayerData", PlayerData.Start)
if #failed > 0 then
	warn("[Server] Не запустились: " .. table.concat(failed, ", ") .. " — смотри ошибки выше")
end

print("[Server] Сервисы запущены: MapBuilder, Economy, Studio, Raid, Spawn, Extraction, Hazards, Enemy, Event, Tutorial, Analytics, Announcer, PlayerData")
