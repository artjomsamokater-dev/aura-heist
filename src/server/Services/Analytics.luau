--!strict
-- Analytics: события воронки в Roblox Analytics (Creator Dashboard). Единственное место, где вызывается
-- AnalyticsService. События из документации (раздел 7):
--   FirstJoin · TutorialStep · RaidStarted · MemelingPicked (редкость) · ExtractionSuccess (число, редкость) ·
--   PlayerDied (что потерял) · UpgradePurchased · MemelingSold · SessionEnded (длительность).
-- Шаги туториала идут ещё и в стандартную воронку онбординга (LogOnboardingFunnelStepEvent).
-- Каждое событие дублируется строкой «[Analytics] …» в Output — так их видно при проверке в Studio
-- (из Studio Roblox события в дашборд не отправляет, они приходят только с живых серверов).

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")

local PlayerData = require(script.Parent.PlayerData)
local Tutorial = require(script.Parent.Tutorial)

local Analytics = {}

local sessionStartedAt: { [Player]: number } = {}

-- Подробности события: до трёх полей CustomField01..03 (в дашборде по ним можно разбить график)
local function fields(first: string?, second: string?, third: string?): { [string]: any }
	local result: { [string]: any } = {}
	local keys = { Enum.AnalyticsCustomFieldKeys.CustomField01, Enum.AnalyticsCustomFieldKeys.CustomField02, Enum.AnalyticsCustomFieldKeys.CustomField03 }
	for i, value in ipairs({ first or "", second or "", third or "" }) do
		if value ~= "" then
			result[keys[i].Name] = value
		end
	end
	return result
end

local function describe(customFields: { [string]: any }?): string
	if customFields == nil then
		return ""
	end
	local parts = {}
	for _, value in customFields do
		table.insert(parts, tostring(value))
	end
	table.sort(parts)
	return if #parts > 0 then " [" .. table.concat(parts, ", ") .. "]" else ""
end

local function log(player: Player, eventName: string, value: number?, customFields: { [string]: any }?)
	print(string.format("[Analytics] %s %s%s%s", eventName, player.Name, if value then " = " .. tostring(value) else "", describe(customFields)))
	local ok, err = pcall(function()
		AnalyticsService:LogCustomEvent(player, eventName, value, customFields)
	end)
	if not ok then
		warn("[Analytics] Не отправилось " .. eventName .. ": " .. tostring(err))
	end
end

function Analytics.RaidStarted(player: Player)
	log(player, "RaidStarted")
end

function Analytics.MemelingPicked(player: Player, rarity: string)
	log(player, "MemelingPicked", nil, fields(rarity))
end

-- count — сколько вынес, rarest — самая редкая редкость среди вынесенных ("" — ничего)
function Analytics.ExtractionSuccess(player: Player, count: number, rarest: string, squad: boolean)
	log(player, "ExtractionSuccess", count, fields(rarest, if squad then "Squad" else "Solo"))
end

-- lost — сколько мемлингов было в руках, cause — от чего смерть
function Analytics.PlayerDied(player: Player, lost: number, cause: string)
	log(player, "PlayerDied", lost, fields(cause))
end

function Analytics.UpgradePurchased(player: Player, upgradeId: string, level: number, cost: number)
	log(player, "UpgradePurchased", cost, fields(upgradeId, tostring(level)))
end

function Analytics.MemelingSold(player: Player, rarity: string, price: number)
	log(player, "MemelingSold", price, fields(rarity))
end

local function onTutorialStep(player: Player, stepNumber: number, stepName: string)
	if stepName == "Skipped" then
		log(player, "TutorialStep", 0, fields("Skipped"))
		return
	end
	log(player, "TutorialStep", stepNumber, fields(stepName))
	local ok, err = pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, stepNumber, stepName)
	end)
	if not ok then
		warn("[Analytics] Не отправился шаг онбординга: " .. tostring(err))
	end
end

function Analytics.Start()
	Players.PlayerAdded:Connect(function(player)
		sessionStartedAt[player] = os.clock()
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		sessionStartedAt[player] = os.clock()
	end
	Players.PlayerRemoving:Connect(function(player)
		local startedAt = sessionStartedAt[player]
		sessionStartedAt[player] = nil
		if startedAt then
			log(player, "SessionEnded", math.floor(os.clock() - startedAt))
		end
	end)

	PlayerData.OnLoaded(function(player)
		if PlayerData.IsFirstSession(player) then
			log(player, "FirstJoin")
		end
	end)
	Tutorial.OnStep(onTutorialStep)
end

return Analytics
