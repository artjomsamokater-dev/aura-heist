--!strict
-- Studio: раздаёт игрокам участки баз (студии).
-- Вошёл — получил первый свободный участок, вышел — участок снова свободен.
-- Если свободных нет, игрок просто играет без участка.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local MapBuilder = require(script.Parent.MapBuilder)

local Studio = {}

local plotOwners = {} -- [номер участка] = Player
local playerPlots = {} -- [Player] = номер участка

local function assignPlot(player)
	if playerPlots[player] then
		return
	end

	for index, plot in ipairs(MapBuilder.GetPlots()) do
		if plotOwners[index] == nil then
			plotOwners[index] = player
			playerPlots[player] = index
			plot:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("StudioIndex", index)
			MapBuilder.SetLabelText(plot:FindFirstChild("Sign"), string.format(MapConfig.Text.OwnedPlot, player.DisplayName))
			print(string.format("[Studio] %s получил участок %d", player.Name, index))
			return
		end
	end

	warn(string.format("[Studio] Свободных участков нет, %s играет без участка", player.Name))
end

local function releasePlot(player)
	local index = playerPlots[player]
	if not index then
		return
	end

	playerPlots[player] = nil
	plotOwners[index] = nil

	local plot = MapBuilder.GetPlots()[index]
	if plot then
		plot:SetAttribute("OwnerUserId", 0)
		MapBuilder.SetLabelText(plot:FindFirstChild("Sign"), MapConfig.Text.FreePlot)
	end
	print(string.format("[Studio] Участок %d освобождён (%s вышел)", index, player.Name))
end

-- Model участка игрока или nil, если участка нет
function Studio.GetPlot(player)
	local index = playerPlots[player]
	return index and MapBuilder.GetPlots()[index] or nil
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
