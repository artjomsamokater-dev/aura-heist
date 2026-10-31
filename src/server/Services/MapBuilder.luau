--!strict
-- MapBuilder: при старте сервера строит карту по MapConfig (формы, места) и StyleConfig (цвета, облик).
-- Хаб → Workspace.Hub, участки → Workspace.PlayerStudios, зона → Workspace.RaidZone.
-- Здесь же ставится мемлинг (MakeMemeling — им пользуются Spawn и Studio): модель из
-- ServerStorage.MemelingModels или из кода (server/Visual/MemelingBuilders) и кольцо редкости.
--
-- Скруглённые постаменты и кнопки: «логическая» деталь (коробка, к ней привязаны кнопки, подписи
-- и расстояния) невидима, а видно круглую деталь Look поверх неё. Механика от этого не меняется.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local MemelingConfig = require(ReplicatedStorage.Shared.Config.MemelingConfig)
local PlotLayout = require(ReplicatedStorage.Shared.Util.PlotLayout)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local MemelingKit = require(ServerScriptService.Server.Visual.MemelingKit)
local MemelingBuilders = require(ServerScriptService.Server.Visual.MemelingBuilders)

local MapBuilder = {}

local LOOK = "Look" -- имя видимых деталей поверх невидимой логической
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- цилиндр Roblox лежит вдоль X; так он встаёт вертикально

local built = false
local plots: { Model } = {} -- [номер участка] = Model участка
local portalPart: Part? = nil
local zoneFolder: Folder? = nil
local zoneEntryPart: Part? = nil
local extractionPad: Part? = nil

-- ── Детали ─────────────────────────────────────────────────────────────────

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

-- Деталь любой формы: "Ball" | "Block" | "Cylinder" | "Wedge"
local function makeShape(name: string, kind: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): BasePart
	if kind == "Wedge" then
		local wedge = Instance.new("WedgePart")
		wedge.Name = name
		wedge.Size = size
		wedge.CFrame = cframe
		wedge.Color = color
		wedge.Material = StyleConfig.Material
		wedge.Anchored = true
		wedge.Parent = parent
		return wedge
	end
	local part = makePart(name, size, cframe, color, parent)
	if kind == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif kind == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
	return part
end

-- Декор: не мешает игре (не ловит лучи и касания) и не даёт тени, если мелкий
local function decorate(part: BasePart, castShadow: boolean)
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = castShadow
end

-- Вертикальный цилиндр: center — центр, height — высота
local function makeColumn(name: string, center: CFrame, height: number, diameter: number, color: Color3, parent: Instance): Part
	local part = makePart(name, Vector3.new(height, diameter, diameter), center * UPRIGHT, color, parent)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Неоновая светящаяся деталь (портал, EXTRACT, столбы света)
local function makeGlow(part: BasePart, transparency: number)
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

local function addLight(part: BasePart, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = part
end

-- Логическую коробку прячем, сверху — круглый Look: цилиндр по размеру коробки и светлый ободок
local function makeRoundLook(logical: Part, color: Color3, rimColor: Color3)
	logical.Transparency = 1
	local size = logical.Size
	local diameter = math.min(size.X, size.Z)
	local body = makeColumn(LOOK, logical.CFrame, size.Y, diameter, color, logical)
	decorate(body, true)
	body.CanCollide = false
	local rimHeight = math.min(0.3, size.Y / 3)
	local rim = makeColumn(
		LOOK,
		logical.CFrame * CFrame.new(0, size.Y / 2 - rimHeight / 2 + 0.05, 0),
		rimHeight,
		diameter + 0.3,
		rimColor,
		logical
	)
	decorate(rim, false)
	rim.CanCollide = false
end

-- ── Подписи ────────────────────────────────────────────────────────────────

export type LabelOptions = {
	Height: number?, -- на сколько студов над центром детали (по умолчанию — сразу над её верхом)
	MaxDistance: number?, -- с какого расстояния видно (по умолчанию StyleConfig.Label.MaxDistance)
	Scale: number?, -- во сколько раз подпись больше или меньше обычной (по умолчанию 1)
}

local function makeLabelText(gui: Instance, text: string)
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextWrapped = true -- длинное имя переносится на вторую строку, а не мельчает
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
	local scale = (options and options.Scale) or 1
	local width = style.WidthStuds * scale
	local labelHeight = style.HeightStuds * scale
	local height = (options and options.Height) or (part.Size.Y / 2 + labelHeight / 2)

	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(width, labelHeight)
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

-- ── Мемлинги ───────────────────────────────────────────────────────────────

-- Своя модель из ServerStorage.MemelingModels[memelingId] (если автор сделал её в Studio).
-- Требования к модели: PrimaryPart — Part (станет ядром), точка опоры (Pivot) — центр габарита 6 × 6 × 6,
-- лицо смотрит в −Z. Все детали переносятся в ядро и привариваются к нему — как у моделей из кода.
local function fromCustomModel(name: string, memelingId: string, cframe: CFrame, parent: Instance): Part?
	local folder = ServerStorage:FindFirstChild("MemelingModels")
	local template = folder and folder:FindFirstChild(memelingId)
	if template == nil or not template:IsA("Model") then
		return nil
	end
	local primary = template.PrimaryPart
	if primary == nil or not primary:IsA("Part") then
		warn(string.format("[MapBuilder] Модель MemelingModels.%s без PrimaryPart (Part) — строю кодом", memelingId))
		return nil
	end

	local model = template:Clone()
	model:PivotTo(cframe)
	local core = model.PrimaryPart :: Part
	-- Старые сварки модели убираем: дальше каждая деталь приварена прямо к ядру (так работает уменьшение в руках)
	for _, joint in ipairs(model:GetDescendants()) do
		if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") then
			joint:Destroy()
		end
	end
	core.Name = name
	core.Anchored = true
	for _, part in ipairs(model:GetDescendants()) do -- список берём до переноса: детали могут лежать внутри ядра
		if part:IsA("BasePart") and part ~= core then
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = core
			weld.Part1 = part
			weld.Parent = part
			part.Parent = core
		end
	end
	core.Parent = parent
	model:Destroy()
	return core
end

-- Мемлинг-персонаж: своя модель из ServerStorage.MemelingModels или модель из кода (MemelingBuilders),
-- под ним кольцо цвета редкости. Возвращает ядро (Part) — с ним работают подбор, подписи и переноска;
-- детали к нему приварены. Мемлинг смотрит лицом в сторону −Z переданного cframe.
local function makeMemeling(name: string, memelingId: string, cframe: CFrame, parent: Instance): Part
	local memeling = MemelingConfig.Memelings[memelingId]
	local core = fromCustomModel(name, memelingId, cframe, parent)
	if core == nil then
		-- Ядро невидимое и без поворота: переноска и постаменты ставят мемлинга именно по нему
		local plain = makePart(name, StyleConfig.Memeling.CoreSize, cframe, StyleConfig.Outline.Color, parent)
		plain.Transparency = 1
		plain.CastShadow = false
		if not MemelingBuilders.Build(memelingId, MemelingKit.new(plain, cframe)) then
			warn(string.format("[MapBuilder] Нет строителя для мемлинга %s", memelingId))
		end
		core = plain
	end
	local ready = core :: Part
	MemelingKit.RarityRing(MemelingKit.new(ready, cframe), if memeling then memeling.Rarity else "Common")
	MemelingKit.TagOutline(ready)
	return ready
end

-- ── Хаб ────────────────────────────────────────────────────────────────────

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
	local portalCfg = MapConfig.Portal
	local style = StyleConfig.Portal

	makePart("Floor", hub.Size, CFrame.new(hub.Center), StyleConfig.Hub.Floor, folder)
	local path = makePart("Path", hub.PathSize, CFrame.new(hub.PathCenter), StyleConfig.Hub.Path, folder)
	decorate(path, false)

	-- Игрок появляется лицом к порталу: персонаж смотрит туда же, куда точка появления
	local spawnPosition = MapConfig.Spawn.Position
	local portalFlat = Vector3.new(portalCfg.Position.X, spawnPosition.Y, portalCfg.Position.Z)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = MapConfig.Spawn.Size
	spawn.CFrame = CFrame.lookAt(spawnPosition, portalFlat)
	spawn.Color = StyleConfig.Hub.Spawn
	spawn.Material = StyleConfig.Material
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = StyleConfig.Hub.SpawnForceFieldSeconds -- 0 = без силового поля
	spawn.Parent = folder

	-- Портал — самое яркое в хабе: неон, свет, искры, рамка и столб света
	local portal = makePart("Portal", portalCfg.Size, CFrame.new(portalCfg.Position), style.Color, folder)
	makeGlow(portal, style.Transparency)
	portal.CanCollide = false -- сквозь портал проходят
	addParticles(portal, style.Particles)
	addLight(portal, style.Color, style.Light.Brightness, style.Light.Range)
	addLabel(portal, TextConfig.Portal)
	portalPart = portal

	local floorTop = hub.Center.Y + hub.Size.Y / 2
	local frameCenterY = floorTop + portalCfg.FrameHeight / 2
	for i, side in ipairs({ -1, 1 }) do
		local pillar = makeColumn(
			"PortalPillar" .. i,
			CFrame.new(portalCfg.Position.X + side * portalCfg.FramePillarX, frameCenterY, portalCfg.Position.Z),
			portalCfg.FrameHeight,
			portalCfg.FramePillarDiameter,
			style.Frame,
			folder
		)
		decorate(pillar, true)
		local cap = makeShape(
			"PortalCap" .. i,
			"Ball",
			Vector3.one * portalCfg.FrameCapDiameter,
			CFrame.new(portalCfg.Position.X + side * portalCfg.FramePillarX, floorTop + portalCfg.FrameHeight, portalCfg.Position.Z),
			style.FrameCaps,
			folder
		)
		decorate(cap, false)
	end
	local beam = makeColumn(
		"PortalBeam",
		CFrame.new(portalCfg.Position.X, floorTop + portalCfg.FrameHeight, portalCfg.Position.Z) * CFrame.Angles(0, 0, math.rad(-90)),
		portalCfg.FramePillarX * 2,
		portalCfg.FramePillarDiameter * 0.8,
		style.Frame,
		folder
	)
	decorate(beam, true)

	local beacon = makeColumn(
		"PortalBeacon",
		CFrame.new(portalCfg.Position.X, floorTop + portalCfg.FrameHeight + portalCfg.BeaconHeight / 2, portalCfg.Position.Z),
		portalCfg.BeaconHeight,
		portalCfg.BeaconDiameter,
		style.Color,
		folder
	)
	makeGlow(beacon, style.BeaconTransparency)
	decorate(beacon, false)
	beacon.CanCollide = false
end

-- ── Участки ────────────────────────────────────────────────────────────────

-- Ограда: столбики через PostStep и перекладина по каждому отрезку
local function buildFence(plotCFrame: CFrame, accent: Color3, parent: Instance)
	local fence = MapConfig.Plots.Fence
	local floorTop = MapConfig.Plots.Size.Y / 2
	local postCenterY = floorTop + fence.PostHeight / 2
	local railY = floorTop + fence.PostHeight - fence.RailSize.Y
	for s, segment in ipairs(fence.Segments) do
		local from = Vector3.new(segment.From.X, 0, segment.From.Y)
		local to = Vector3.new(segment.To.X, 0, segment.To.Y)
		local length = (to - from).Magnitude
		local posts = math.max(1, math.floor(length / fence.PostStep))
		for i = 0, posts do
			local p = from:Lerp(to, i / posts)
			local post = makeColumn(
				"FencePost" .. s .. "_" .. i,
				plotCFrame * CFrame.new(p.X, postCenterY, p.Z),
				fence.PostHeight,
				fence.PostDiameter,
				accent,
				parent
			)
			decorate(post, false)
		end
		local middle = (from + to) / 2
		local rail = makePart(
			"FenceRail" .. s,
			Vector3.new(fence.RailSize.X, fence.RailSize.Y, length),
			plotCFrame * CFrame.lookAt(Vector3.new(middle.X, railY, middle.Z), Vector3.new(to.X, railY, to.Z)),
			StyleConfig.Plot.Rail,
			parent
		)
		decorate(rail, false)
	end
end

-- Арка входа: два круглых столба, перекладина, шары сверху. Табличка висит под перекладиной
local function buildArch(plotCFrame: CFrame, accent: Color3, parent: Instance)
	local arch = MapConfig.Plots.Arch
	local floorTop = MapConfig.Plots.Size.Y / 2
	for i, side in ipairs({ -1, 1 }) do
		local pillar = makeColumn(
			"ArchPillar" .. i,
			plotCFrame * CFrame.new(side * arch.PillarX, floorTop + arch.Height / 2, arch.Z),
			arch.Height,
			arch.PillarDiameter,
			accent,
			parent
		)
		decorate(pillar, true)
		local cap = makeShape(
			"ArchCap" .. i,
			"Ball",
			Vector3.one * arch.CapDiameter,
			plotCFrame * CFrame.new(side * arch.PillarX, floorTop + arch.Height + arch.BeamSize.Y / 2, arch.Z),
			StyleConfig.Plot.ArchCaps,
			parent
		)
		decorate(cap, false)
	end
	local beam = makePart(
		"ArchBeam",
		arch.BeamSize,
		plotCFrame * CFrame.new(0, floorTop + arch.Height + arch.BeamSize.Y / 2, arch.Z),
		accent,
		parent
	)
	decorate(beam, true)
end

local function buildRug(plotCFrame: CFrame, accent: Color3, parent: Instance)
	local cfg = MapConfig.Plots
	local border = makePart(
		"RugBorder",
		cfg.RugSize + Vector3.new(cfg.RugBorder * 2, 0, cfg.RugBorder * 2),
		plotCFrame * CFrame.new(cfg.RugCenter - Vector3.new(0, 0.01, 0)),
		accent,
		parent
	)
	decorate(border, false)
	local rug = makePart("Rug", cfg.RugSize, plotCFrame * CFrame.new(cfg.RugCenter + Vector3.new(0, 0.01, 0)), StyleConfig.Plot.Rug, parent)
	decorate(rug, false)
end

local function buildPlots()
	local folder = makeFolder("PlayerStudios")
	local cfg = MapConfig.Plots
	local accents = StyleConfig.Plot.Accents

	for i = 1, cfg.Count do
		local accent = accents[(i - 1) % #accents + 1]

		-- Участки равномерно по кругу; каждый повёрнут лицом к хабу (shared/Util/PlotLayout)
		local plotCFrame = PlotLayout.PlotCFrame(i)

		local model = Instance.new("Model")
		model.Name = "Studio" .. i
		model:SetAttribute("PlotIndex", i)
		model:SetAttribute("OwnerUserId", 0) -- 0 = участок свободен

		local floor = makePart("Floor", cfg.Size, plotCFrame, StyleConfig.Plot.Floor, model)
		model.PrimaryPart = floor

		local decor = Instance.new("Folder")
		decor.Name = "Decor"
		decor.Parent = model
		buildArch(plotCFrame, accent, decor)
		buildFence(plotCFrame, accent, decor)
		buildRug(plotCFrame, accent, decor)

		local sign = makePart("Sign", cfg.SignSize, plotCFrame * CFrame.new(cfg.SignOffset), accent, model)
		decorate(sign, true)
		addSignText(sign, TextConfig.FreePlot)

		local pedestals = Instance.new("Folder")
		pedestals.Name = "Pedestals"
		pedestals.Parent = model
		for p, offset in ipairs(cfg.PedestalOffsets) do
			local pedestal = makePart("Pedestal" .. p, cfg.PedestalSize, plotCFrame * CFrame.new(offset), accent, pedestals)
			pedestal:SetAttribute("PedestalIndex", p)
			makeRoundLook(pedestal, accent, StyleConfig.PlotParts.PedestalRim)
		end

		-- Кнопки-диски улучшений; подписи и кнопку «Buy» на них вешает Studio
		local buttons = Instance.new("Folder")
		buttons.Name = "Buttons"
		buttons.Parent = model
		for upgradeId, offset in cfg.UpgradeButtonOffsets do
			local button = makePart(
				"Upgrade_" .. upgradeId,
				cfg.ButtonSize,
				plotCFrame * CFrame.new(offset),
				StyleConfig.PlotParts.UpgradeButton,
				buttons
			)
			button.CastShadow = false
			button:SetAttribute("UpgradeId", upgradeId)
			makeRoundLook(button, StyleConfig.PlotParts.UpgradeButton, StyleConfig.PlotParts.ButtonRim)
			addLabel(button, "")
		end

		-- Диск запаса; подпись и кнопку «Sell» на него вешает Studio
		local reserve = makePart(
			"Reserve",
			cfg.ButtonSize,
			plotCFrame * CFrame.new(cfg.ReserveOffset),
			StyleConfig.PlotParts.ReservePad,
			buttons
		)
		reserve.CastShadow = false
		makeRoundLook(reserve, StyleConfig.PlotParts.ReservePad, StyleConfig.PlotParts.ReserveRim)
		addLabel(reserve, "")

		-- Диск Rebirth; подпись и кнопку (удержание 2 с) на него вешает Studio
		local rebirth = makePart(
			"Rebirth",
			cfg.ButtonSize,
			plotCFrame * CFrame.new(cfg.RebirthOffset),
			StyleConfig.PlotParts.RebirthPad,
			buttons
		)
		rebirth.CastShadow = false
		makeRoundLook(rebirth, StyleConfig.PlotParts.RebirthPad, StyleConfig.PlotParts.RebirthRim)
		addLabel(rebirth, "")

		model.Parent = folder
		plots[i] = model
	end
end

-- ── Зона ───────────────────────────────────────────────────────────────────

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

-- Ворота поперёк дорожки на линии x (смещение от центра зоны)
local function buildGate(name: string, x: number, color: Color3, parent: Instance)
	local zone = MapConfig.Zone
	local decor = zone.Decor
	local top = zone.Center.Y + zone.Size.Y / 2
	local base = zone.Center + Vector3.new(x, 0, 0)
	for i, side in ipairs({ -1, 1 }) do
		local pillar = makeColumn(
			name .. "Pillar" .. i,
			CFrame.new(base.X, top + decor.GateHeight / 2, base.Z + side * decor.GatePillarZ),
			decor.GateHeight,
			decor.GatePillarDiameter,
			color,
			parent
		)
		decorate(pillar, true)
		local cap = makeShape(
			name .. "Cap" .. i,
			"Ball",
			Vector3.one * decor.GateCapDiameter,
			CFrame.new(base.X, top + decor.GateHeight, base.Z + side * decor.GatePillarZ),
			StyleConfig.Zone.GateCaps,
			parent
		)
		decorate(cap, false)
	end
	local beam = makePart(
		name .. "Beam",
		Vector3.new(decor.GateBeamThickness, decor.GateBeamThickness, decor.GatePillarZ * 2),
		CFrame.new(base.X, top + decor.GateHeight, base.Z),
		color,
		parent
	)
	decorate(beam, true)
end

local function buildLandmarks(parent: Instance)
	local zone = MapConfig.Zone
	local decor = zone.Decor
	local style = StyleConfig.Zone
	local top = zone.Center.Y + zone.Size.Y / 2

	-- Грибы-великаны в безопасной части
	for m, mushroom in ipairs(decor.Mushrooms) do
		local base = Vector3.new(zone.Center.X + mushroom.Position.X, top, zone.Center.Z + mushroom.Position.Y)
		local stem = makeColumn("MushroomStem" .. m, CFrame.new(base + Vector3.new(0, mushroom.StemHeight / 2, 0)), mushroom.StemHeight, mushroom.StemDiameter, style.MushroomStem, parent)
		decorate(stem, true)
		local capCenter = base + Vector3.new(0, mushroom.StemHeight, 0)
		local brim = makeColumn("MushroomBrim" .. m, CFrame.new(capCenter), 1.6, mushroom.CapDiameter, style.MushroomCap, parent)
		decorate(brim, true)
		local domeSize = mushroom.CapDiameter * 0.8
		local dome = makeShape("MushroomDome" .. m, "Ball", Vector3.one * domeSize, CFrame.new(capCenter + Vector3.new(0, 0.8, 0)), style.MushroomCap, parent)
		decorate(dome, true)
		for d, offset in ipairs({ Vector3.new(0.25, 0.4, 0), Vector3.new(-0.2, 0.42, 0.2), Vector3.new(0, 0.38, -0.3) }) do
			local dot = makeShape(
				"MushroomDot" .. m .. "_" .. d,
				"Ball",
				Vector3.one * (domeSize * 0.18),
				CFrame.new(capCenter + Vector3.new(0, 0.8, 0) + offset * domeSize),
				style.MushroomDots,
				parent
			)
			decorate(dot, false)
		end
	end

	-- Кристаллы в опасной части: несколько наклонённых столбиков разной высоты
	local tilts = { Vector3.new(8, 0, 6), Vector3.new(-12, 30, 10), Vector3.new(14, 70, -10) }
	local spread = { Vector3.new(0, 0, 0), Vector3.new(3, 0, 2), Vector3.new(-2.5, 0, 3) }
	for c, crystal in ipairs(decor.Crystals) do
		local base = Vector3.new(zone.Center.X + crystal.Position.X, top, zone.Center.Z + crystal.Position.Y)
		for i, height in ipairs(crystal.Heights) do
			local tilt = tilts[(i - 1) % #tilts + 1]
			local width = 1.6 + height * 0.12
			local part = makePart(
				"Crystal" .. c .. "_" .. i,
				Vector3.new(width, height, width),
				CFrame.new(base + spread[(i - 1) % #spread + 1] + Vector3.new(0, height / 2 - 0.5, 0))
					* CFrame.Angles(math.rad(tilt.X), math.rad(tilt.Y), math.rad(tilt.Z)),
				style.Crystal,
				parent
			)
			decorate(part, true)
		end
	end
end

local function buildZone()
	local folder = makeFolder("RaidZone")
	zoneFolder = folder
	local zone = MapConfig.Zone
	local decor = zone.Decor
	local style = StyleConfig.Zone
	local top = zone.Center.Y + zone.Size.Y / 2

	-- Пол из двух частей: безопасная (у входа) и опасная (дальше, тёмная слива)
	local halfX = zone.Size.X / 2
	local safeWidth = halfX + zone.DangerFromX
	local dangerWidth = halfX - zone.DangerFromX
	local safeFloor = makePart(
		"SafeFloor",
		Vector3.new(safeWidth, zone.Size.Y, zone.Size.Z),
		CFrame.new(zone.Center + Vector3.new(-halfX + safeWidth / 2, 0, 0)),
		style.SafeFloor,
		folder
	)
	addLabel(safeFloor, TextConfig.Zone)
	local dangerFloor = makePart(
		"DangerFloor",
		Vector3.new(dangerWidth, zone.Size.Y, zone.Size.Z),
		CFrame.new(zone.Center + Vector3.new(zone.DangerFromX + dangerWidth / 2, 0, 0)),
		style.DangerFloor,
		folder
	)
	addLabel(dangerFloor, TextConfig.ZoneDanger)
	addFloorTexture(safeFloor)
	addFloorTexture(dangerFloor)

	local decorFolder = Instance.new("Folder")
	decorFolder.Name = "Decor"
	decorFolder.Parent = folder

	-- Полоса по границе опасной части
	local border = makePart(
		"DangerBorder",
		Vector3.new(decor.DangerBorderWidth, 0.1, zone.Size.Z),
		CFrame.new(zone.Center.X + zone.DangerFromX, top + 0.05, zone.Center.Z),
		style.DangerBorder,
		decorFolder
	)
	decorate(border, false)

	-- Дорожка от входа к EXTRACT
	local pathLength = decor.PathToX - decor.PathFromX
	local path = makePart(
		"Path",
		Vector3.new(pathLength, 0.1, decor.PathWidth),
		CFrame.new(zone.Center.X + (decor.PathFromX + decor.PathToX) / 2, top + 0.06, zone.Center.Z),
		style.Path,
		decorFolder
	)
	path.Transparency = style.PathTransparency
	decorate(path, false)

	-- Ворота: у входа (мята) и в опасную часть (коралл)
	buildGate("EntryGate", decor.EntryGateX, style.EntryGate, decorFolder)
	buildGate("DangerGate", zone.DangerFromX, style.DangerGate, decorFolder)
	buildLandmarks(decorFolder)

	-- Плоская плитка на полу: сюда портал переносит игрока
	local entry = makePart(
		"EntryPoint",
		zone.EntryMarkerSize,
		CFrame.new(zone.EntryPosition + Vector3.new(0, zone.EntryMarkerSize.Y / 2, 0)),
		style.Entry,
		folder
	)
	entry.CanCollide = false
	entry.CastShadow = false
	addLabel(entry, TextConfig.Entry, { Scale = StyleConfig.Label.EntryScale })
	zoneEntryPart = entry

	-- Круглая площадка эвакуации: её радиус совпадает с дистанцией из ZoneConfig.
	-- Цилиндр в Roblox лежит вдоль оси X, поэтому поворачиваем его на 90°, чтобы он стал «блином».
	local diameter = ZoneConfig.EvacuationDistance * 2
	local pad = makePart(
		"ExtractionPoint",
		Vector3.new(zone.ExtractionPadThickness, diameter, diameter),
		CFrame.new(zone.ExtractionPosition + Vector3.new(0, zone.ExtractionPadThickness / 2, 0)) * UPRIGHT,
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

	-- Столб света над EXTRACT: видно из любого места зоны, куда идти
	local beacon = makeColumn(
		"ExtractBeacon",
		CFrame.new(zone.ExtractionPosition + Vector3.new(0, decor.ExtractBeaconHeight / 2, 0)),
		decor.ExtractBeaconHeight,
		decor.ExtractBeaconDiameter,
		StyleConfig.Extraction.Color,
		decorFolder
	)
	makeGlow(beacon, StyleConfig.Extraction.BeaconTransparency)
	decorate(beacon, false)
	beacon.CanCollide = false

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
		local wall = makePart(spec.Name, spec.Size, CFrame.new(wallBase + spec.Offset), style.SafeFloor, walls)
		wall.Transparency = 1
		wall.CastShadow = false
	end
end

-- Хватает ли на участке места под все постаменты: столько мест, сколько даёт последний уровень,
-- не ближе PedestalMinSpacing друг к другу и к кнопкам, не ближе PedestalEdgeMargin к краю участка
local function validatePlotLayout()
	local cfg = MapConfig.Plots
	local offsets = cfg.PedestalOffsets
	local levels = UpgradeConfig.Pedestals.Levels
	local maxCount = if #levels > 0 then levels[#levels].Count else UpgradeConfig.Pedestals.StartCount
	if #offsets < maxCount then
		warn(string.format("[MapBuilder] Мест под постаменты %d, а улучшение даёт до %d — добавь места в MapConfig.Plots.PedestalOffsets", #offsets, maxCount))
	end
	local half = cfg.Size / 2
	local others: { Vector3 } = { cfg.ReserveOffset, cfg.RebirthOffset }
	for _, offset in cfg.UpgradeButtonOffsets do
		table.insert(others, offset)
	end
	local buttonClearance = cfg.ButtonSize.X / 2 + cfg.PedestalSize.X / 2
	for i, a in ipairs(offsets) do
		if math.abs(a.X) > half.X - cfg.PedestalEdgeMargin or math.abs(a.Z) > half.Z - cfg.PedestalEdgeMargin then
			warn(string.format("[MapBuilder] Постамент %d слишком близко к краю участка", i))
		end
		for j = i + 1, #offsets do
			local b = offsets[j]
			if Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude < cfg.PedestalMinSpacing then
				warn(string.format("[MapBuilder] Постаменты %d и %d стоят слишком близко", i, j))
			end
		end
		for _, other in ipairs(others) do
			if Vector3.new(a.X - other.X, 0, a.Z - other.Z).Magnitude < buttonClearance then
				warn(string.format("[MapBuilder] Постамент %d налезает на кнопку участка", i))
			end
		end
	end
end

function MapBuilder.Build()
	if built then
		return
	end
	built = true

	validatePlotLayout()
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

-- Куда ставить персонажа при входе в зону: лицом на восток — к воротам, дорожке и EXTRACT
function MapBuilder.GetZoneEntryCFrame(): CFrame
	local entry = assert(zoneEntryPart, "MapBuilder.Build() ещё не вызван")
	local position = entry.Position + Vector3.new(0, MapConfig.Zone.EntrySpawnHeight, 0)
	return CFrame.lookAt(position, position + Vector3.xAxis)
end

-- Куда ставить персонажа при возвращении в хаб (после эвакуации): лицом к порталу
function MapBuilder.GetHubArrivalCFrame(): CFrame
	local position = MapConfig.Spawn.Position + Vector3.new(0, MapConfig.Spawn.ArrivalHeight, 0)
	local portal = MapConfig.Portal.Position
	return CFrame.lookAt(position, Vector3.new(portal.X, position.Y, portal.Z))
end

-- Площадка эвакуации в зоне (на ней же подпись с прогрессом)
function MapBuilder.GetExtractionPad(): Part
	return (assert(extractionPad, "MapBuilder.Build() ещё не вызван"))
end

-- Прозрачность видимой части скруглённой детали (постамент-«призрак», пока не куплен)
function MapBuilder.SetLookTransparency(part: Instance, transparency: number)
	for _, child in ipairs(part:GetChildren()) do
		if child.Name == LOOK and child:IsA("BasePart") then
			child.Transparency = transparency
		end
	end
end

-- Уменьшает (или увеличивает) мемлинга целиком: ядро и все детали, с сохранением формы.
-- Детали приварены к ядру — сварки пересоздаём после изменения размеров
function MapBuilder.ScaleMemeling(core: BasePart, factor: number)
	local coreCFrame = core.CFrame
	for _, child in ipairs(core:GetChildren()) do
		if child:IsA("BasePart") then
			local relative = coreCFrame:ToObjectSpace(child.CFrame)
			local weld = child:FindFirstChildOfClass("WeldConstraint")
			if weld then
				weld:Destroy()
			end
			child.Size *= factor
			child.CFrame = coreCFrame * CFrame.new(relative.Position * factor) * relative.Rotation
			local newWeld = Instance.new("WeldConstraint")
			newWeld.Part0 = core
			newWeld.Part1 = child
			newWeld.Parent = child
		elseif child:IsA("PointLight") then
			child.Range *= factor
		end
	end
	core.Size *= factor
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
