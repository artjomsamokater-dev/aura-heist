--!strict
-- Bounty: «Охота» (задача 7.5). Раз в EconomyConfig.Bounty.IntervalSeconds сервер выбирает одного мемлинга
-- из зон (не Secret, не тот же подряд — shared/Util/BountyRule). Вынесенный через эвакуацию, пока он BOUNTY,
-- получает флаг bounty в профиле навсегда — доход на постаменте × IncomeMultiplier (решает Extraction
-- через Bounty.IsBounty, флаг ставит Studio). Клиентам — атрибуты на ReplicatedStorage: BountyMemelingId и
-- BountyEndsAt (время сервера, GetServerTimeNow): табличка у портала, плашка в HUD и метки рисует клиент сам.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local MemelingConfig = require(ReplicatedStorage.Shared.Config.MemelingConfig)
local BountyRule = require(ReplicatedStorage.Shared.Util.BountyRule)

local Bounty = {}

Bounty.MemelingAttribute = "BountyMemelingId"
Bounty.EndsAttribute = "BountyEndsAt"

local SECRET = "Secret" -- редкость, на которую охоты нет (её не найти в зонах)

local current: string? = nil
local random = Random.new()

-- Этот мемлинг сейчас BOUNTY?
function Bounty.IsBounty(memelingId: string): boolean
	return current ~= nil and current == memelingId
end

local function pickNext()
	local candidates = BountyRule.Candidates(MemelingConfig.Memelings :: any, SECRET)
	current = BountyRule.Pick(candidates, current, random:NextNumber())
	local endsAt = Workspace:GetServerTimeNow() + EconomyConfig.Bounty.IntervalSeconds
	ReplicatedStorage:SetAttribute(Bounty.MemelingAttribute, current)
	ReplicatedStorage:SetAttribute(Bounty.EndsAttribute, endsAt)
	print(string.format("[Bounty] Охота: %s (доход x%d), %d с", tostring(current), EconomyConfig.Bounty.IncomeMultiplier, EconomyConfig.Bounty.IntervalSeconds))
end

function Bounty.Start()
	pickNext()
	task.spawn(function()
		while true do
			task.wait(EconomyConfig.Bounty.IntervalSeconds)
			pickNext()
		end
	end)
end

return Bounty
