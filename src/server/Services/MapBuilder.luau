--!strict
-- MapBuilder: при старте сервера строит серый прототип карты по MapConfig.
-- Хаб → Workspace.Hub, участки → Workspace.PlayerStudios, зона → Workspace.RaidZone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)

local MapBuilder = {}

local built = false
local plots: { Model } = {} -- [номер участка] = Model участка
local portalPart: Part? = nil
local zoneFolder: Folder? = nil
local zoneEntryPart: Part? = nil
local extractionPad: Part? = nil

-- Создаёт папку в Workspace; старую с тем же именем удаляет, чтобы не было дублей
local function makeFolder(name: string): Folder
	local old = Workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = Workspace
	return folder
end

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.Parent = parent
	return part
end

-- Вешает над деталью подпись, которая всегда повёрнута к камере.
-- heightAbovePart — на сколько студов поднять подпись над центром детали (по умолчанию — над её верхом)
local function addLabel(part: BasePart, text: string, heightAbovePart: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(MapConfig.Label.WidthStuds, MapConfig.Label.HeightStuds)
	local height = heightAbovePart or (part.Size.Y / 2 + MapConfig.Label.HeightStuds / 2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = MapConfig.Label.MaxDistance
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
end

local function buildHub()
	local folder = makeFolder("Hub")
	local hub = MapConfig.Hub

	makePart("Floor", hub.Size, CFrame.new(hub.Center), MapConfig.Colors.Hub, folder)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = MapConfig.Spawn.Size
	spawn.CFrame = CFrame.new(MapConfig.Spawn.Position)
	spawn.Color = MapConfig.Colors.Spawn
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Parent = folder

	local portal = makePart(
		"Portal",
		MapConfig.Portal.Size,
		CFrame.new(MapConfig.Portal.Position),
		MapConfig.Colors.Portal,
		folder
	)
	portal.Material = Enum.Material.Neon
	portal.Transparency = 0.3
	portal.CanCollide = false -- сквозь портал проходят
	addLabel(portal, TextConfig.Portal)
	portalPart = portal
end

local function buildPlots()
	local folder = makeFolder("PlayerStudios")
	local cfg = MapConfig.Plots
	local hubCenter = MapConfig.Hub.Center

	for i = 1, cfg.Count do
		-- Участки равномерно по кругу; каждый повёрнут лицом к хабу
		local angle = (i - 1) * (2 * math.pi / cfg.Count)
		local center = hubCenter + Vector3.new(math.cos(angle), 0, math.sin(angle)) * cfg.RingRadius
		local plotCFrame = CFrame.lookAt(center, hubCenter)

		local model = Instance.new("Model")
		model.Name = "Studio" .. i
		model:SetAttribute("PlotIndex", i)
		model:SetAttribute("OwnerUserId", 0) -- 0 = участок свободен

		local floor = makePart("Floor", cfg.Size, plotCFrame, MapConfig.Colors.Plot, model)
		model.PrimaryPart = floor

		local sign = makePart("Sign", cfg.SignSize, plotCFrame * CFrame.new(cfg.SignOffset), MapConfig.Colors.Sign, model)
		addLabel(sign, TextConfig.FreePlot)

		local pedestals = Instance.new("Folder")
		pedestals.Name = "Pedestals"
		pedestals.Parent = model
		for p, offset in ipairs(cfg.PedestalOffsets) do
			local pedestal = makePart(
				"Pedestal" .. p,
				cfg.PedestalSize,
				plotCFrame * CFrame.new(offset),
				MapConfig.Colors.Pedestal,
				pedestals
			)
			pedestal:SetAttribute("PedestalIndex", p)
		end

		model.Parent = folder
		plots[i] = model
	end
end

local function buildZone()
	local folder = makeFolder("RaidZone")
	zoneFolder = folder
	local zone = MapConfig.Zone

	local floor = makePart("Floor", zone.Size, CFrame.new(zone.Center), MapConfig.Colors.Zone, folder)
	addLabel(floor, TextConfig.Zone)

	-- Плоская плитка на полу: сюда портал переносит игрока
	local entry = makePart(
		"EntryPoint",
		zone.EntryMarkerSize,
		CFrame.new(zone.EntryPosition + Vector3.new(0, zone.EntryMarkerSize.Y / 2, 0)),
		MapConfig.Colors.Entry,
		folder
	)
	entry.CanCollide = false
	addLabel(entry, TextConfig.Entry)
	zoneEntryPart = entry

	-- Круглая площадка эвакуации: её радиус совпадает с дистанцией из ZoneConfig.
	-- Цилиндр в Roblox лежит вдоль оси X, поэтому поворачиваем его на 90°, чтобы он стал «блином».
	local diameter = ZoneConfig.EvacuationDistance * 2
	local pad = makePart(
		"ExtractionPoint",
		Vector3.new(zone.ExtractionPadThickness, diameter, diameter),
		CFrame.new(zone.ExtractionPosition + Vector3.new(0, zone.ExtractionPadThickness / 2, 0))
			* CFrame.Angles(0, 0, math.rad(90)),
		MapConfig.Colors.Extraction,
		folder
	)
	pad.Shape = Enum.PartType.Cylinder
	pad.CanCollide = false
	addLabel(pad, TextConfig.Extraction, MapConfig.Label.HeightStuds)
	extractionPad = pad

	-- Невидимые стены по четырём краям пола, чтобы из зоны нельзя было выпасть
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = folder
	local half = zone.Size / 2
	local t = zone.WallThickness
	local h = zone.WallHeight
	local wallBase = zone.Center + Vector3.new(0, zone.Size.Y / 2 + h / 2, 0)
	local wallSpecs = {
		{ Name = "North", Size = Vector3.new(zone.Size.X + t * 2, h, t), Offset = Vector3.new(0, 0, -(half.Z + t / 2)) },
		{ Name = "South", Size = Vector3.new(zone.Size.X + t * 2, h, t), Offset = Vector3.new(0, 0, half.Z + t / 2) },
		{ Name = "West", Size = Vector3.new(t, h, zone.Size.Z), Offset = Vector3.new(-(half.X + t / 2), 0, 0) },
		{ Name = "East", Size = Vector3.new(t, h, zone.Size.Z), Offset = Vector3.new(half.X + t / 2, 0, 0) },
	}
	for _, spec in ipairs(wallSpecs) do
		local wall = makePart(spec.Name, spec.Size, CFrame.new(wallBase + spec.Offset), MapConfig.Colors.Zone, walls)
		wall.Transparency = 1
		wall.CastShadow = false
	end
end

function MapBuilder.Build()
	if built then
		return
	end
	built = true

	buildHub()
	buildPlots()
	buildZone()
	print(string.format("[MapBuilder] Карта построена: хаб, %d участков, зона", #plots))
end

-- Список участков по порядку (Model)
function MapBuilder.GetPlots(): { Model }
	return plots
end

function MapBuilder.GetPortal(): Part
	return assert(portalPart, "MapBuilder.Build() ещё не вызван")
end

-- Папка Workspace.RaidZone
function MapBuilder.GetZoneFolder(): Folder
	return assert(zoneFolder, "MapBuilder.Build() ещё не вызван")
end

-- Куда ставить персонажа при входе в зону
function MapBuilder.GetZoneEntryCFrame(): CFrame
	local entry = assert(zoneEntryPart, "MapBuilder.Build() ещё не вызван")
	return CFrame.new(entry.Position + Vector3.new(0, MapConfig.Zone.EntrySpawnHeight, 0))
end

-- Куда ставить персонажа при возвращении в хаб (после эвакуации)
function MapBuilder.GetHubArrivalCFrame(): CFrame
	return CFrame.new(MapConfig.Spawn.Position + Vector3.new(0, MapConfig.Spawn.ArrivalHeight, 0))
end

-- Площадка эвакуации в зоне (на ней же подпись с прогрессом)
function MapBuilder.GetExtractionPad(): Part
	return (assert(extractionPad, "MapBuilder.Build() ещё не вызван"))
end

-- Те же помощники для других сервисов (серые детали и подписи)
MapBuilder.MakePart = makePart
MapBuilder.AddLabel = addLabel

-- Меняет текст подписи, созданной addLabel
function MapBuilder.SetLabelText(part: Instance?, text: string)
	local gui = part and part:FindFirstChild("Label")
	local label = gui and gui:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

return MapBuilder
