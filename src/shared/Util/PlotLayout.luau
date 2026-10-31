--!strict
-- PlotLayout: где стоит участок номер N. Нужен и серверу (MapBuilder строит участки),
-- и клиенту (стрелка туториала к своему постаменту, даже если участок ещё не загрузился).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)

local PlotLayout = {}

-- Участки равномерно по кругу вокруг хаба; каждый повёрнут лицом к хабу (−Z участка смотрит на хаб)
function PlotLayout.PlotCFrame(index: number): CFrame
	local cfg = MapConfig.Plots
	local hubCenter = MapConfig.Hub.Center
	local angle = (index - 1) * (2 * math.pi / cfg.Count)
	local center = hubCenter + Vector3.new(math.cos(angle), 0, math.sin(angle)) * cfg.RingRadius
	return CFrame.lookAt(center, hubCenter)
end

return PlotLayout
