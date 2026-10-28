--!strict
-- MapBuilder: при старте сервера строит карту по MapConfig (формы) и StyleConfig (цвета, материалы).
-- Хаб → Workspace.Hub, участки → Workspace.PlayerStudios, зона → Workspace.RaidZone.
-- Здесь же собирается вид мемлинга (тело + глаза) — им пользуются Spawn и Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local MemelingConfig = require(ReplicatedStorage.Shared.Config.MemelingConfig)

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
	part.Material = StyleConfig.Material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.Parent = parent
	return part
end

-- Неоновая светящаяся деталь (порталы, площадка EXTRACT)
local function makeGlow(part: Part, transparency: number)
	part.Material = StyleConfig.GlowMaterial
	part.Transparency = transparency
	part.CastShadow = false
end

local function addParticles(part: BasePart, spec: StyleConfig.Particles): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = StyleConfig.ParticleTexture
	emitter.Color = ColorSequence.new(spec.Color)
	emitter.Rate = spec.Rate
	emitter.Lifetime = spec.Lifetime
	emitter.Speed = spec.Speed
	emitter.Size = NumberSequence.new(spec.Size, 0)
	emitter.SpreadAngle = Vector2.new(spec.SpreadAngle, spec.SpreadAngle)
	emitter.LightEmission = spec.LightEmission
	emitter.Transparency = NumberSequence.new(0.1, 1)
	emitter.Parent = part
	return emitter
end

export type LabelOptions = {
	Height: number?, -- на сколько студов над центром детали (по умолчанию — сразу над её верхом)
	MaxDistance: number?, -- с какого расстояния видно (по умолчанию StyleConfig.Label.MaxDistance)
}

local function makeLabelText(gui: Instance, text: string)
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = StyleConfig.Fonts.Label
	label.TextColor3 = StyleConfig.Label.Text
	label.TextStrokeColor3 = StyleConfig.Label.Stroke
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
end

-- Вешает над деталью подпись, которая всегда повёрнута к камере.
-- Подписи не «всегда сверху»: их закрывают стены и предметы (поверх всего — только маркер EXTRACT в HUD).
local function addLabel(part: BasePart, text: string, options: LabelOptions?)
	local style = StyleConfig.Label
	local height = (options and options.Height) or (part.Size.Y / 2 + style.HeightStuds / 2)

	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(style.WidthStuds, style.HeightStuds)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = (options and options.MaxDistance) or style.MaxDistance
	gui.AlwaysOnTop = false
	gui.Parent = part
	makeLabelText(gui, text)
end

-- Надпись прямо на табличке, на обеих сторонах: крупно и не висит в воздухе
local function addSignText(sign: BasePart, text: string)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Label"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = StyleConfig.Label.SignPixelsPerStud
		gui.Parent = sign
		makeLabelText(gui, text)
	end
end

-- Мелкая деталь мемлинга: не мешает физике и не даёт тени
local function makeDetail(name: string, diameter: number, cframe: CFrame, color: Color3, body: Part): Part
	local detail = makePart(name, Vector3.new(diameter, diameter, diameter), cframe, color, body)
	detail.Shape = Enum.PartType.Ball
	detail.Anchored = false
	detail.CanCollide = false
	detail.CanTouch = false
	detail.CanQuery = false
	detail.Massless = true
	detail.CastShadow = false

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = detail
	weld.Parent = detail
	return detail
end

-- Мемлинг-персонаж: круглое тело цвета редкости и два глаза. Возвращает тело (Part);
-- глаза приварены к нему, поэтому двигаются вместе с телом.
-- Тело смотрит глазами в сторону -Z переданного cframe.
local function makeMemeling(name: string, memelingId: string, cframe: CFrame, parent: Instance): Part
	local cfg = StyleConfig.Memeling
	local memeling = MemelingConfig.Memelings[memelingId]
	local style = (memeling and cfg.Rarities[memeling.Rarity]) or cfg.Rarities.Common

	local body = makePart(name, cfg.Size, cframe, style.Body, parent)
	body.Shape = Enum.PartType.Ball
	body.CastShadow = false

	for i, offset in ipairs(cfg.EyeOffsets) do
		local eyeCFrame = cframe * CFrame.new(offset)
		makeDetail("Eye" .. i, cfg.EyeSize, eyeCFrame, cfg.EyeWhite, body)
		makeDetail("Pupil" .. i, cfg.PupilSize, eyeCFrame * CFrame.new(0, 0, -cfg.PupilForward), cfg.Pupil, body)
	end

	if style.Outline then
		-- Только контур, без заливки; сквозь стены не виден
		local outline = Instance.new("Highlight")
		outline.FillTransparency = 1
		outline.OutlineColor = style.Outline
		outline.OutlineTransparency = 0
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Adornee = body
		outline.Parent = body
	end

	if style.Glow then
		local light = Instance.new("PointLight")
		light.Color = style.Body
		light.Brightness = cfg.Light.Brightness
		light.Range = cfg.Light.Range
		light.Shadows = false
		light.Parent = body
	end
	if style.Particles then
		addParticles(body, style.Particles)
	end
	return body
end

-- Узор плиткой на верхней грани пола зоны
local function addFloorTexture(floor: BasePart)
	local style = StyleConfig.Zone
	local texture = Instance.new("Texture")
	texture.Texture = style.FloorTexture
	texture.Face = Enum.NormalId.Top
	texture.StudsPerTileU = style.FloorTextureStuds
	texture.StudsPerTileV = style.FloorTextureStuds
	texture.Transparency = style.FloorTextureTransparency
	texture.Color3 = style.FloorTextureColor
	texture.Parent = floor
end

local function paintGround()
	-- Baseplate из default.project.json: формы не трогаем, только цвет
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Color = StyleConfig.Ground
		baseplate.Material = StyleConfig.Material
	end
end

local function buildHub()
	local folder = makeFolder("Hub")
	local hub = MapConfig.Hub

	makePart("Floor", hub.Size, CFrame.new(hub.Center), StyleConfig.Hub.Floor, folder)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = MapConfig.Spawn.Size
	spawn.CFrame = CFrame.new(MapConfig.Spawn.Position)
	spawn.Color = StyleConfig.Hub.Spawn
	spawn.Material = StyleConfig.Material
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = StyleConfig.Hub.SpawnForceFieldSeconds -- 0 = без силового поля
	spawn.Parent = folder

	local portal = makePart(
		"Portal",
		MapConfig.Portal.Size,
		CFrame.new(MapConfig.Portal.Position),
		StyleConfig.Portal.Color,
		folder
	)
	makeGlow(portal, StyleConfig.Portal.Transparency)
	portal.CanCollide = false -- сквозь портал проходят
	addParticles(portal, StyleConfig.Portal.Particles)
	addLabel(portal, TextConfig.Portal)
	portalPart = portal
end

local function buildPlots()
	local folder = makeFolder("PlayerStudios")
	local cfg = MapConfig.Plots
	local hubCenter = MapConfig.Hub.Center

	for i = 1, cfg.Count do
		local colors = StyleConfig.Plots[(i - 1) % #StyleConfig.Plots + 1]

		-- Участки равномерно по кругу; каждый повёрнут лицом к хабу
		local angle = (i - 1) * (2 * math.pi / cfg.Count)
		local center = hubCenter + Vector3.new(math.cos(angle), 0, math.sin(angle)) * cfg.RingRadius
		local plotCFrame = CFrame.lookAt(center, hubCenter)

		local model = Instance.new("Model")
		model.Name = "Studio" .. i
		model:SetAttribute("PlotIndex", i)
		model:SetAttribute("OwnerUserId", 0) -- 0 = участок свободен

		local floor = makePart("Floor", cfg.Size, plotCFrame, colors.Floor, model)
		model.PrimaryPart = floor

		local sign = makePart("Sign", cfg.SignSize, plotCFrame * CFrame.new(cfg.SignOffset), colors.Accent, model)
		addSignText(sign, TextConfig.FreePlot)

		local pedestals = Instance.new("Folder")
		pedestals.Name = "Pedestals"
		pedestals.Parent = model
		for p, offset in ipairs(cfg.PedestalOffsets) do
			local pedestal = makePart(
				"Pedestal" .. p,
				cfg.PedestalSize,
				plotCFrame * CFrame.new(offset),
				colors.Accent,
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

	-- Пол из двух частей: безопасная (у входа) и опасная (дальше, тревожного цвета)
	local halfX = zone.Size.X / 2
	local safeWidth = halfX + zone.DangerFromX
	local dangerWidth = halfX - zone.DangerFromX
	local safeFloor = makePart(
		"SafeFloor",
		Vector3.new(safeWidth, zone.Size.Y, zone.Size.Z),
		CFrame.new(zone.Center + Vector3.new(-halfX + safeWidth / 2, 0, 0)),
		StyleConfig.Zone.SafeFloor,
		folder
	)
	addLabel(safeFloor, TextConfig.Zone)
	local dangerFloor = makePart(
		"DangerFloor",
		Vector3.new(dangerWidth, zone.Size.Y, zone.Size.Z),
		CFrame.new(zone.Center + Vector3.new(zone.DangerFromX + dangerWidth / 2, 0, 0)),
		StyleConfig.Zone.DangerFloor,
		folder
	)
	addLabel(dangerFloor, TextConfig.ZoneDanger)
	addFloorTexture(safeFloor)
	addFloorTexture(dangerFloor)

	-- Плоская плитка на полу: сюда портал переносит игрока
	local entry = makePart(
		"EntryPoint",
		zone.EntryMarkerSize,
		CFrame.new(zone.EntryPosition + Vector3.new(0, zone.EntryMarkerSize.Y / 2, 0)),
		StyleConfig.Zone.Entry,
		folder
	)
	entry.CanCollide = false
	entry.CastShadow = false
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
		StyleConfig.Extraction.Color,
		folder
	)
	pad.Shape = Enum.PartType.Cylinder
	pad.CanCollide = false
	makeGlow(pad, StyleConfig.Extraction.Transparency)
	local sparks = addParticles(pad, StyleConfig.Extraction.Particles)
	sparks.EmissionDirection = Enum.NormalId.Right -- после поворота «право» цилиндра смотрит вверх
	addLabel(pad, TextConfig.Extraction, { Height = StyleConfig.Label.HeightStuds })
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
		local wall = makePart(spec.Name, spec.Size, CFrame.new(wallBase + spec.Offset), StyleConfig.Zone.SafeFloor, walls)
		wall.Transparency = 1
		wall.CastShadow = false
	end
end

function MapBuilder.Build()
	if built then
		return
	end
	built = true

	paintGround()
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

-- Те же помощники для других сервисов
MapBuilder.MakePart = makePart
MapBuilder.AddLabel = addLabel
MapBuilder.MakeMemeling = makeMemeling

-- Меняет текст подписи, созданной addLabel или addSignText (у таблички их две — с обеих сторон)
function MapBuilder.SetLabelText(part: Instance?, text: string)
	if part == nil then
		return
	end
	for _, gui in ipairs(part:GetChildren()) do
		if gui.Name == "Label" then
			local label = gui:FindFirstChild("Text")
			if label and label:IsA("TextLabel") then
				label.Text = text
			end
		end
	end
end

return MapBuilder
