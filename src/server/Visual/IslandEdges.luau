--!strict
-- IslandEdges: края островов (задача 7.5) — мир не выглядит площадкой. Только картинка: механики нет,
-- настоящая граница — невидимые стены (MapBuilder), их просто не видно за «естественным» краем.
--   • хаб: уступ с травой, скала до моря, крупные камни по кругу, плотная стена деревьев и кустов;
--   • участок: скала под полом с камнями по бокам и пена у воды;
--   • зона: каменное «дно» уступами, уступ вокруг пола, забор по краю, камни, кристаллы и мемные
--     великаны на уступе, облака ниже края — видно, что это парящий остров.
-- Места — MapConfig.HubEdge и MapConfig.Zones[Id].Edge, цвета — StyleConfig.Background и тема зоны.
-- Крупные формы вместо множества мелких, теней нет ни у чего.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)

local IslandEdges = {}

type ZoneMap = typeof(MapConfig.Zones.Meme)
type ZoneTheme = typeof(StyleConfig.Zone)

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- цилиндр Roblox лежит вдоль X; так он стоит вертикально

-- Kind: "Block" | "Ball" | "Cylinder" | "Oval" (шар-«сетка», растягивается по размеру)
local function part(name: string, kind: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance, collide: boolean?): BasePart
	local p = Instance.new("Part")
	if kind == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif kind == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	elseif kind == "Oval" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = StyleConfig.Material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- Вертикальный цилиндр: center — центр, height — высота
local function column(name: string, center: Vector3, height: number, diameter: number, color: Color3, parent: Instance, collide: boolean?): BasePart
	return part(name, "Cylinder", Vector3.new(height, diameter, diameter), CFrame.new(center) * UPRIGHT, color, parent, collide)
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Насколько далеко углы a и b друг от друга (в градусах, 0..180)
local function angleGap(a: number, b: number): number
	return math.abs((a - b + 180) % 360 - 180)
end

-- Пена на уровне моря вокруг подножия скалы (тонкая плита)
local function seaFoam(name: string, cframe: CFrame, size: Vector2, round: boolean, parent: Instance)
	local y = MapConfig.Background.SeaLevel + 0.1
	local position = Vector3.new(cframe.Position.X, y, cframe.Position.Z)
	if round then
		column(name, position, 0.2, size.X, StyleConfig.Background.Foam, parent)
	else
		part(name, "Block", Vector3.new(size.X, 0.24, size.Y), CFrame.new(position) * cframe.Rotation, StyleConfig.Background.Foam, parent)
	end
end

-- ── Хаб ────────────────────────────────────────────────────────────────────

function IslandEdges.BuildHub(parent: Instance)
	local cfg = MapConfig.HubEdge
	local hub = MapConfig.Hub
	local style = StyleConfig.Background
	local root = folder("HubEdge", parent)
	local floorBottom = hub.Center.Y - hub.Size.Y / 2
	local floorTop = hub.Center.Y + hub.Size.Y / 2
	local center = Vector3.new(hub.Center.X, 0, hub.Center.Z)
	local random = Random.new(75)

	local plots = MapConfig.Plots
	local bridgeAngles: { number } = {}
	for i = 1, plots.Count do
		table.insert(bridgeAngles, plots.AngleOffsetDegrees + (i - 1) * 360 / plots.Count)
	end
	local function nearBridge(angle: number, degrees: number): boolean
		for _, b in ipairs(bridgeAngles) do
			if angleGap(angle, b) < degrees then
				return true
			end
		end
		return false
	end
	local function nearObby(angle: number): boolean
		return angleGap(angle, MapConfig.Obby.EntryAngle) < cfg.ObbyClearDegrees
	end
	local function polar(angle: number, radius: number, y: number): Vector3
		local a = math.rad(angle)
		return center + Vector3.new(math.cos(a) * radius, y, math.sin(a) * radius)
	end

	-- Уступ с травой вокруг площади и скала под ним до самого моря
	column("Ledge", Vector3.new(center.X, floorBottom - 0.5, center.Z), 1, cfg.LedgeRadius * 2, style.Ledge, root, true)
	local cliffHeight = floorBottom - 1 - cfg.CliffBottomY
	column("Cliff", Vector3.new(center.X, cfg.CliffBottomY + cliffHeight / 2, center.Z), cliffHeight, cfg.LedgeRadius * 2 - 1, style.Cliff, root)

	-- Крупные камни по кругу: обрывистый край. У мостиков и паркура — ниже мостика
	local rocks = folder("Rocks", root)
	for k = 0, cfg.Rocks - 1 do
		local angle = k * 360 / cfg.Rocks + 360 / cfg.Rocks / 2
		local low = nearBridge(angle, cfg.RockClearDegrees) or nearObby(angle)
		local peak = if low then cfg.RockLowPeakY else random:NextNumber(cfg.RockPeakY[1], cfg.RockPeakY[2])
		local top = floorTop + peak
		local height = top - cfg.CliffBottomY
		local width = cfg.RockSize.X * random:NextNumber(0.85, 1.15)
		local position = polar(angle, cfg.RockRadius, cfg.CliffBottomY + height / 2)
		local cframe = CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z))
			* CFrame.Angles(math.rad(random:NextNumber(-4, 4)), math.rad(random:NextNumber(-8, 8)), math.rad(random:NextNumber(-4, 4)))
		part("Rock" .. k, "Block", Vector3.new(width, height, cfg.RockSize.Z), cframe, if k % 2 == 0 then style.Cliff else style.CliffDark, rocks)
	end

	-- Стена деревьев и кустов в каждом промежутке между мостиками (у мостиков и паркура — проходы)
	local trees = folder("Trees", root)
	local count = 0
	for _, bridge in ipairs(bridgeAngles) do
		local from = bridge + cfg.BridgeClearDegrees
		local span = 360 / plots.Count - cfg.BridgeClearDegrees * 2
		local step = span / cfg.TreesPerSector
		for t = 0, cfg.TreesPerSector do
			-- Кусты — на границах шагов, деревья — посередине шага
			local bushAngle = from + t * step
			if not nearObby(bushAngle) then
				count += 1
				local diameter = cfg.BushDiameter * random:NextNumber(0.85, 1.2)
				part("Bush" .. count, "Ball", Vector3.one * diameter, CFrame.new(polar(bushAngle, cfg.BushRadius, floorBottom + diameter * 0.3)), style.EdgeBush, trees)
			end
			local treeAngle = from + (t + 0.5) * step
			if t < cfg.TreesPerSector and not nearObby(treeAngle) then
				count += 1
				local trunk = cfg.TreeHeight[count % 2 + 1]
				local crown = cfg.CrownDiameter[count % 2 + 1]
				local base = polar(treeAngle, cfg.TreeRadius, floorBottom)
				column("Trunk" .. count, base + Vector3.new(0, trunk / 2, 0), trunk, 2, style.EdgeTrunk, trees)
				local color = style.EdgeCrowns[count % #style.EdgeCrowns + 1]
				part("Crown" .. count, "Ball", Vector3.one * crown, CFrame.new(base + Vector3.new(0, trunk + crown * 0.3, 0)), color, trees)
				local side = polar(treeAngle + 3, cfg.TreeRadius + 1, floorBottom + trunk + crown * 0.05)
				part("CrownSide" .. count, "Ball", Vector3.one * crown * 0.7, CFrame.new(side), color, trees)
			end
		end
	end

	local outer = cfg.RockRadius + cfg.RockSize.Z / 2 + StyleConfig.Background.FoamWidth
	seaFoam("Foam", CFrame.new(center), Vector2.new(outer * 2, outer * 2), true, root)
end

-- Скала под участком: блок до моря, крупные камни по бокам (вершины ниже пола участка) и пена у воды
function IslandEdges.BuildPlot(plotCFrame: CFrame, floorSize: Vector3, parent: Instance)
	local cfg = MapConfig.HubEdge
	local style = StyleConfig.Background
	local root = folder("Cliff", parent)
	local floorBottomY = plotCFrame.Position.Y - floorSize.Y / 2
	local height = floorBottomY - cfg.CliffBottomY
	local width = floorSize.X + cfg.PlotCliffInset * 2
	local depth = floorSize.Z + cfg.PlotCliffInset * 2
	local below = plotCFrame * CFrame.new(0, -floorSize.Y / 2 - height / 2, 0)
	part("Rock", "Block", Vector3.new(width, height, depth), below, style.Cliff, root)

	local rockHeight = height + floorSize.Y / 2 -- вершина — в середине толщины пола: снаружи пола не торчит
	for i, rock in ipairs(cfg.PlotRocks) do
		local alongZ = math.abs(rock.X) > math.abs(rock.Z) -- камень на боковой стороне — вытянут вдоль Z
		local size = if alongZ then Vector3.new(6, rockHeight, rock.Width) else Vector3.new(rock.Width, rockHeight, 6)
		local cframe = plotCFrame
			* CFrame.new(rock.X, -floorSize.Y / 2 - height / 2 + floorSize.Y / 4, rock.Z)
			* CFrame.Angles(0, math.rad(i * 7 - 14), 0)
		part("SideRock" .. i, "Block", size, cframe, style.CliffDark, root)
	end

	local foam = StyleConfig.Background.FoamWidth * 2
	seaFoam("Foam", plotCFrame, Vector2.new(width + foam + 6, depth + foam + 6), false, root)
end

-- ── Зоны ───────────────────────────────────────────────────────────────────

-- Мемные великаны и камни на уступе зоны. base — точка на уступе, look — повёрнут лицом к центру зоны
local function buildRocks(base: CFrame, style: ZoneTheme, random: Random, parent: Instance)
	for i, spec in ipairs({
		{ Size = Vector3.new(10, 16, 9), Offset = Vector3.new(0, 0, 0) },
		{ Size = Vector3.new(7, 10, 7), Offset = Vector3.new(6.5, 0, 2) },
		{ Size = Vector3.new(5, 6, 5), Offset = Vector3.new(-6, 0, -1) },
	}) do
		local cframe = base
			* CFrame.new(spec.Offset + Vector3.new(0, spec.Size.Y / 2 - 1, 0))
			* CFrame.Angles(math.rad(random:NextNumber(-6, 6)), math.rad(random:NextNumber(0, 90)), math.rad(random:NextNumber(-6, 6)))
		part("Rock" .. i, "Block", spec.Size, cframe, if i == 2 then style.EdgeRockDark else style.EdgeRock, parent)
	end
end

local function buildCrystal(base: CFrame, style: ZoneTheme, random: Random, parent: Instance)
	part("Base", "Block", Vector3.new(7, 3, 7), base * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, math.rad(25), 0), style.EdgeRockDark, parent)
	for i, spec in ipairs({
		{ Size = Vector3.new(3.6, 20, 3.6), Offset = Vector3.new(0, 0, 0), Tilt = 0 },
		{ Size = Vector3.new(2.8, 13, 2.8), Offset = Vector3.new(3, 0, 1), Tilt = 16 },
		{ Size = Vector3.new(2.2, 9, 2.2), Offset = Vector3.new(-3, 0, -1), Tilt = -18 },
	}) do
		local crystal = part(
			"Crystal" .. i,
			"Block",
			spec.Size,
			base * CFrame.new(spec.Offset + Vector3.new(0, spec.Size.Y / 2, 0)) * CFrame.Angles(0, math.rad(45 + random:NextNumber(-10, 10)), math.rad(spec.Tilt)),
			style.EdgeCrystal,
			parent
		)
		crystal.Material = StyleConfig.GlowMaterial
	end
end

local function buildCan(base: CFrame, style: ZoneTheme, parent: Instance)
	local colors = style.GiantCan
	local tilt = base * CFrame.Angles(math.rad(-8), 0, math.rad(6))
	part("Can", "Cylinder", Vector3.new(15, 9, 9), tilt * CFrame.new(0, 7.5, 0) * UPRIGHT, colors.Body, parent)
	part("Band", "Cylinder", Vector3.new(4, 9.2, 9.2), tilt * CFrame.new(0, 8, 0) * UPRIGHT, colors.Band, parent)
	part("Top", "Cylinder", Vector3.new(0.6, 7.6, 7.6), tilt * CFrame.new(0, 15.1, 0) * UPRIGHT, colors.Top, parent)
end

local function buildPopsicle(base: CFrame, style: ZoneTheme, parent: Instance)
	local colors = style.GiantPopsicle
	local tilt = base * CFrame.Angles(0, 0, math.rad(10))
	part("Stick", "Block", Vector3.new(1.8, 7, 1.2), tilt * CFrame.new(0, 3.5, 0), colors.Stick, parent)
	part("Ice", "Block", Vector3.new(8, 12, 3.6), tilt * CFrame.new(0, 12, 0), colors.Ice, parent)
	part("IceTop", "Cylinder", Vector3.new(3.6, 8, 8), tilt * CFrame.new(0, 18, 0) * CFrame.Angles(0, math.rad(90), 0), colors.Ice, parent)
	part("Bite", "Ball", Vector3.one * 3.4, tilt * CFrame.new(4, 19, 0), colors.Bite, parent)
end

local function buildDonut(base: CFrame, style: ZoneTheme, parent: Instance)
	local colors = style.GiantDonut
	-- Пончик стоит на ребре лицом к центру зоны: ось цилиндра (X) смотрит на центр
	local wheel = base * CFrame.new(0, 7, 0) * CFrame.Angles(0, math.rad(90), 0)
	part("Dough", "Cylinder", Vector3.new(4, 14, 14), wheel, colors.Dough, parent)
	part("Frosting", "Cylinder", Vector3.new(4.4, 12, 12), wheel, colors.Frosting, parent)
	part("Hole", "Cylinder", Vector3.new(4.6, 4.4, 4.4), wheel, colors.Hole, parent)
end

function IslandEdges.BuildZone(zone: ZoneMap, style: ZoneTheme, parent: Instance)
	local edge = zone.Edge
	local root = folder("Edge", parent)
	local random = Random.new(math.floor(zone.Center.X))
	local half = zone.Size.X / 2
	local floorBottom = zone.Center.Y - zone.Size.Y / 2
	local cx, cz = zone.Center.X, zone.Center.Z
	local full = zone.Size.X + edge.RimWidth * 2

	-- Уступ вокруг пола и каменное «дно» острова ступенями вниз
	part("Rim", "Block", Vector3.new(full, 1, full), CFrame.new(cx, floorBottom - 0.5, cz), style.EdgeRim, root, true)
	local y = floorBottom - 1
	for i, step in ipairs(edge.Bottom) do
		local width = full * step.Width
		part("Bottom" .. i, "Block", Vector3.new(width, step.Height, width), CFrame.new(cx, y - step.Height / 2, cz), if i % 2 == 0 then style.EdgeRockDark else style.EdgeRock, root)
		y -= step.Height
	end

	-- Забор по краю пола: крупные столбы и две длинные перекладины на сторону
	local fence = folder("Fence", root)
	local inner = half - edge.FenceInset
	local floorTop = floorBottom + zone.Size.Y
	local sides = {
		{ Normal = Vector3.new(0, 0, -1), Tangent = Vector3.new(1, 0, 0) },
		{ Normal = Vector3.new(1, 0, 0), Tangent = Vector3.new(0, 0, 1) },
		{ Normal = Vector3.new(0, 0, 1), Tangent = Vector3.new(-1, 0, 0) },
		{ Normal = Vector3.new(-1, 0, 0), Tangent = Vector3.new(0, 0, -1) },
	}
	local length = inner * 2
	local posts = math.max(1, math.floor(length / edge.FencePostStep))
	for s, side in ipairs(sides) do
		local middle = Vector3.new(cx, floorTop, cz) + side.Normal * inner
		local along = CFrame.lookAt(middle, middle + side.Tangent) -- −Z вдоль стороны
		for r, height in ipairs({ edge.FenceHeight * 0.38, edge.FenceHeight * 0.82 }) do
			part("Rail" .. s .. "_" .. r, "Block", Vector3.new(0.5, 0.5, length), along * CFrame.new(0, height, 0), style.EdgeFence, fence, true)
		end
		for k = 0, posts - 1 do
			local offset = -inner + k * length / posts
			part(
				"Post" .. s .. "_" .. k,
				"Block",
				Vector3.new(edge.FencePostSize, edge.FenceHeight + 0.6, edge.FencePostSize),
				CFrame.new(middle + side.Tangent * offset + Vector3.new(0, (edge.FenceHeight + 0.6) / 2, 0)),
				style.EdgeFencePost,
				fence,
				true
			)
		end
	end

	-- На уступе за забором: камни, кристаллы и мемные великаны (виды по очереди, на каждой стороне — со сдвигом)
	local props = folder("Props", root)
	local center = Vector3.new(cx, floorBottom, cz)
	local function placeAt(name: string, kind: string, position: Vector3)
		local model = Instance.new("Model")
		model.Name = name
		local base = CFrame.lookAt(position, Vector3.new(cx, position.Y, cz))
		if kind == "Rocks" then
			buildRocks(base, style, random, model)
		elseif kind == "Crystal" then
			buildCrystal(base, style, random, model)
		elseif kind == "Can" then
			buildCan(base, style, model)
		elseif kind == "Popsicle" then
			buildPopsicle(base, style, model)
		elseif kind == "Donut" then
			buildDonut(base, style, model)
		end
		model.Parent = props
	end
	local out = half + edge.PropFromEdge
	for s, side in ipairs(sides) do
		for i, offset in ipairs(edge.PropOffsets) do
			local kind = edge.Kinds[(i + (s - 1) * 2 - 1) % #edge.Kinds + 1]
			placeAt("Prop" .. s .. "_" .. i, kind, center + side.Normal * out + side.Tangent * offset)
		end
		-- Угол: крупная груда камней
		local nextSide = sides[s % #sides + 1]
		placeAt("Corner" .. s, "Rocks", center + (side.Normal + nextSide.Normal) * out)
	end

	-- Облака ниже края: кольцо крупных полупрозрачных «подушек»
	local clouds = folder("Clouds", root)
	for k = 0, edge.Clouds - 1 do
		local angle = math.rad(k * 360 / edge.Clouds + random:NextNumber(-6, 6))
		local radius = edge.CloudRadius[k % 2 + 1]
		local depth = edge.CloudDepth[k % 2 + 1]
		local size = edge.CloudSize[(k // 2) % 2 + 1]
		local position = center + Vector3.new(math.cos(angle) * radius, -depth, math.sin(angle) * radius)
		local cloud = part("Cloud" .. k, "Oval", Vector3.new(size, size * 0.4, size * 0.75), CFrame.new(position) * CFrame.Angles(0, -angle, 0), style.Cloud, clouds)
		cloud.Transparency = style.CloudTransparency
	end
end

return IslandEdges
