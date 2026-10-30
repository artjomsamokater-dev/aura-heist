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

-- Порядок важен: сначала карта, потом сервисы, которые её используют
LightingSetup.Apply()
MapBuilder.Build()
Announcer.Start() -- раньше Spawn: первый спавн уже может объявлять
Economy.Start()
Studio.Start()
Raid.Start()
Spawn.Start()
Extraction.Start()
Hazards.Start()
Enemy.Start()
-- Последним: все сервисы уже подписались на PlayerData.OnLoaded
PlayerData.Start()

print("[Server] Сервисы запущены: MapBuilder, Economy, Studio, Raid, Spawn, Extraction, Hazards, Enemy, Announcer, PlayerData")
