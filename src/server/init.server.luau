-- Точка входа сервера.
-- Пока только печатает ключевые числа из Config, чтобы убедиться, что модули загружаются.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local EconomyConfig = require(Config.EconomyConfig)
local MemelingConfig = require(Config.MemelingConfig)
local ZoneConfig = require(Config.ZoneConfig)
local UpgradeConfig = require(Config.UpgradeConfig)

print("[Config] ===== AURA HEIST: Config загружен =====")

print("[Config] Редкости:")
for _, rarity in MemelingConfig.RarityOrder do
	local r = MemelingConfig.Rarities[rarity]
	print(
		string.format(
			"[Config]   %s: %d Aura/с, продажа %d, скорость %d, шанс safe %d%%, danger %d%%",
			rarity,
			r.AuraPerSecond,
			r.SellPrice,
			r.CarrySpeed,
			ZoneConfig.SpawnChances.Safe[rarity],
			ZoneConfig.SpawnChances.Danger[rarity]
		)
	)
end

local memelingCount = 0
for id, m in MemelingConfig.Memelings do
	memelingCount += 1
	print(string.format("[Config]   Мемлинг %s (%s) — %s", m.DisplayName, id, m.Rarity))
end
print(string.format("[Config] Всего мемлингов: %d", memelingCount))

-- Сумма шансов в каждой части зоны должна быть ровно 100
for part, chances in ZoneConfig.SpawnChances do
	local sum = 0
	for _, chance in chances do
		sum += chance
	end
	print(string.format("[Config] Сумма шансов в части %s: %d%%", part, sum))
end

print(
	string.format(
		"[Config] Зона: ресток %d с, эвакуация %d с, подбор ≤ %d студов, эвакуация ≤ %d студов",
		ZoneConfig.RestockSeconds,
		ZoneConfig.EvacuationSeconds,
		ZoneConfig.PickupDistance,
		ZoneConfig.EvacuationDistance
	)
)

print(
	string.format(
		"[Config] Старт: постаментов %d, слотов переноски %d, хранилище %d с дохода",
		UpgradeConfig.Pedestals.StartCount,
		UpgradeConfig.CarrySlots.StartCount,
		UpgradeConfig.Storage.StartSeconds
	)
)

print(
	string.format(
		"[Config] Экономика: бонус отряда +%d%% в радиусе %d студов, автосохранение %d с",
		EconomyConfig.SquadBonus.SellBonusPercent,
		EconomyConfig.SquadBonus.Radius,
		EconomyConfig.AutosaveSeconds
	)
)

print(string.format("[Config] Config заморожен: %s", tostring(table.isfrozen(MemelingConfig.Rarities.Common))))
