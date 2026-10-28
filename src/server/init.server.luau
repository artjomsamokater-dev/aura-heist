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
local MapBuilder = require(Services.MapBuilder)
local Studio = require(Services.Studio)
local Raid = require(Services.Raid)
local Spawn = require(Services.Spawn)

-- Порядок важен: сначала карта, потом сервисы, которые её используют
MapBuilder.Build()
Studio.Start()
Raid.Start()
Spawn.Start()

print("[Server] Сервисы запущены: MapBuilder, Studio, Raid, Spawn")
