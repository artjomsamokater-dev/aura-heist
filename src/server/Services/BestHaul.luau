--!strict
-- BestHaul: витрина «BEST HAUL» на площади хаба (задача 6.1).
-- На подиуме стоит копия самого редкого мемлинга, вынесенного на этом сервере за сессию, и ник игрока.
-- Заменяется только более редким (того же уровня — остаётся первый). Только картинка: подобрать нельзя,
-- в профиль ничего не пишется. Вызывает Extraction после успешной эвакуации.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MemelingConfig = require(ReplicatedStorage.Shared.Config.MemelingConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local MapBuilder = require(script.Parent.MapBuilder)

local BestHaul = {}

local bestRank = 0 -- номер редкости в MemelingConfig.RarityOrder (0 — витрина пуста)
local shown: Part? = nil

local function rankOf(memelingId: string): number
	local memeling = MemelingConfig.Memelings[memelingId]
	return if memeling then table.find(MemelingConfig.RarityOrder, memeling.Rarity) or 0 else 0
end

-- Игрок вынес мемлингов: если среди них есть кто-то редче того, что на витрине, — он встаёт на подиум
function BestHaul.Offer(player: Player, memelingIds: { string })
	local bestId: string? = nil
	local rank = bestRank
	for _, id in ipairs(memelingIds) do
		local r = rankOf(id)
		if r > rank then
			bestId, rank = id, r
		end
	end
	if bestId == nil then
		return
	end
	bestRank = rank

	local podium, stand = MapBuilder.GetBestHaul()
	if shown then
		shown:Destroy()
	end
	local size = StyleConfig.Memeling.Size
	local core = MapBuilder.MakeMemeling("BestHaulMemeling", bestId, stand * CFrame.new(0, size.Y / 2, 0), podium.Parent or podium)
	local name = TextConfig.MemelingNames[bestId] or bestId
	MapBuilder.AddLabel(core, string.format(TextConfig.BestHaulOwner, name, player.DisplayName), {
		Height = MapBuilder.GetMemelingLabelHeight(bestId),
		Scale = StyleConfig.Label.BestHaulScale,
	})
	shown = core
	MapBuilder.SetLabelText(podium, TextConfig.BestHaulTitle)
	print(string.format("[BestHaul] Новый рекорд сервера: %s (%s) от %s", bestId, MemelingConfig.Memelings[bestId].Rarity, player.Name))
end

return BestHaul
