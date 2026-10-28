--!strict
-- UpgradeValues: что даёт купленный уровень улучшения. Уровень 0 = стартовое значение.
-- Все числа — из UpgradeConfig; здесь только чтение.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)

-- "pedestals" | "carrySlots" | "storage". Просто string: точный тип-перечисление теряется
-- при импорте между модулями в анализаторе Luau
export type UpgradeId = string

local UpgradeValues = {}

-- Все улучшения по порядку (так же называются поля в профиле: data.upgrades.<id>)
local IDS: { UpgradeId } = table.freeze({ "pedestals", "carrySlots", "storage" })

function UpgradeValues.GetIds(): { UpgradeId }
	return IDS
end

local function getLevels(id: UpgradeId): { { Cost: number } }
	if id == "pedestals" then
		return UpgradeConfig.Pedestals.Levels :: any
	elseif id == "carrySlots" then
		return UpgradeConfig.CarrySlots.Levels :: any
	elseif id == "storage" then
		return UpgradeConfig.Storage.Levels :: any
	end
	return {} -- неизвестное улучшение: уровней нет, купить нечего
end

function UpgradeValues.MaxLevel(id: UpgradeId): number
	return #getLevels(id)
end

-- Цена следующего уровня или nil, если улучшение уже максимальное
function UpgradeValues.NextCost(id: UpgradeId, level: number): number?
	local nextLevel = getLevels(id)[level + 1]
	return if nextLevel then nextLevel.Cost else nil
end

function UpgradeValues.PedestalCount(level: number): number
	local entry = UpgradeConfig.Pedestals.Levels[level]
	return if entry then entry.Count else UpgradeConfig.Pedestals.StartCount
end

function UpgradeValues.CarrySlots(level: number): number
	local entry = UpgradeConfig.CarrySlots.Levels[level]
	return if entry then entry.Count else UpgradeConfig.CarrySlots.StartCount
end

-- Лимит хранилища постамента в секундах дохода
function UpgradeValues.StorageSeconds(level: number): number
	local entry = UpgradeConfig.Storage.Levels[level]
	local multiplier = if entry then entry.Multiplier else 1
	return UpgradeConfig.Storage.StartSeconds * multiplier
end

-- Значение после покупки следующего уровня (для подписи на кнопке)
function UpgradeValues.NextValue(id: UpgradeId, level: number): number
	if id == "pedestals" then
		return UpgradeValues.PedestalCount(level + 1)
	elseif id == "carrySlots" then
		return UpgradeValues.CarrySlots(level + 1)
	end
	local entry = UpgradeConfig.Storage.Levels[level + 1]
	return if entry then entry.Multiplier else 1
end

return UpgradeValues
