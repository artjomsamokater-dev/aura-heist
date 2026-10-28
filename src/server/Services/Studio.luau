--!strict
-- Studio: раздаёт игрокам участки баз (студии).
-- Вошёл — получил первый свободный участок, вышел — участок снова свободен.
-- Если свободных нет, игрок просто играет без участка.
-- Ещё Studio хранит список мемлингов «на витрине» — пока только в памяти сервера
-- (постаменты — задача 1.5, сохранение — задача 2.1).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local MapBuilder = require(script.Parent.MapBuilder)

local Studio = {}

local plotOwners: { [number]: Player? } = {} -- [номер участка] = Player
local playerPlots: { [Player]: number } = {} -- [Player] = номер участка
local showcases: { [Player]: { string } } = {} -- [Player] = MemelingId мемлингов на витрине

local function assignPlot(player: Player)
	if playerPlots[player] then
		return
	end

	for index, plot in ipairs(MapBuilder.GetPlots()) do
		if plotOwners[index] == nil then
			plotOwners[index] = player
			playerPlots[player] = index
			plot:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("StudioIndex", index)
			MapBuilder.SetLabelText(plot:FindFirstChild("Sign"), string.format(TextConfig.OwnedPlot, player.DisplayName))
			print(string.format("[Studio] %s получил участок %d", player.Name, index))
			return
		end
	end

	warn(string.format("[Studio] Свободных участков нет, %s играет без участка", player.Name))
end

local function releasePlot(player: Player)
	showcases[player] = nil

	local index = playerPlots[player]
	if not index then
		return
	end

	playerPlots[player] = nil
	plotOwners[index] = nil

	local plot = MapBuilder.GetPlots()[index]
	if plot then
		plot:SetAttribute("OwnerUserId", 0)
		MapBuilder.SetLabelText(plot:FindFirstChild("Sign"), TextConfig.FreePlot)
	end
	print(string.format("[Studio] Участок %d освобождён (%s вышел)", index, player.Name))
end

-- Model участка игрока или nil, если участка нет
function Studio.GetPlot(player: Player): Model?
	local index = playerPlots[player]
	return index and MapBuilder.GetPlots()[index] or nil
end

-- Добавляет мемлингов на витрину игрока (вызывает Extraction после успешной эвакуации)
function Studio.AddToShowcase(player: Player, memelingIds: { string })
	local list = showcases[player]
	if list == nil then
		list = {}
		showcases[player] = list
	end
	for _, memelingId in ipairs(memelingIds) do
		table.insert(list, memelingId)
	end
	player:SetAttribute("ShowcaseCount", #list)
end

-- Копия списка витрины (MemelingId по порядку добавления)
function Studio.GetShowcase(player: Player): { string }
	return table.clone(showcases[player] or {})
end

function Studio.Start()
	Players.PlayerAdded:Connect(assignPlot)
	Players.PlayerRemoving:Connect(releasePlot)

	-- Игроки, которые успели зайти до запуска сервиса
	for _, player in ipairs(Players:GetPlayers()) do
		assignPlot(player)
	end
end

return Studio
