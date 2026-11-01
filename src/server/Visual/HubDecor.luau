--!strict
-- HubDecor: декор площади хаба (задача 6.2) — фонтан, деревья, кусты, клумбы, фонари, скамейки,
-- указатели и гигантские мемные предметы. Только картинка: механики нет.
-- Места — MapConfig.Hub (Decor, Props), цвета — StyleConfig.Hub. Всё закреплено (Anchored), мелочь
-- без теней; столкновения только у того, что не мешает пройти (стволы, фонтан, гиганты в секторах).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)

local HubDecor = {}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- цилиндр Roblox лежит вдоль X; так он стоит вертикально

-- Kind: "Block" | "Ball" | "Cylinder" | "Oval" (шар-«сетка», растягивается по размеру) | "Wedge"
local function part(name: string, kind: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance, collide: boolean?): BasePart
	local p: BasePart
	if kind == "Wedge" then
		p = Instance.new("WedgePart")
	else
		local block = Instance.new("Part")
		if kind == "Ball" then
			block.Shape = Enum.PartType.Ball
		elseif kind == "Cylinder" then
			block.Shape = Enum.PartType.Cylinder
		elseif kind == "Oval" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = block
		end
		p = block
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

local function floorTop(): number
	local hub = MapConfig.Hub
	return hub.Center.Y + hub.Size.Y / 2
end

-- Точка на полу площади по углу (0° — +X, 90° — +Z) и расстоянию от центра, на высоте height над полом
local function polar(angleDegrees: number, radius: number, height: number): Vector3
	local hub = MapConfig.Hub
	local a = math.rad(angleDegrees)
	return Vector3.new(hub.Center.X + math.cos(a) * radius, floorTop() + height, hub.Center.Z + math.sin(a) * radius)
end

-- Повёрнут лицом (−Z) к центру площади
local function facingCenter(position: Vector3): CFrame
	local hub = MapConfig.Hub
	return CFrame.lookAt(position, Vector3.new(hub.Center.X, position.Y, hub.Center.Z))
end

local function model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Надпись на грани детали (SurfaceGui), крупно, с обводкой
local function signText(board: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Text"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = StyleConfig.Label.SignPixelsPerStud
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Font = StyleConfig.Fonts.Label
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
end

-- ── Мелкий декор ──────────────────────────────────────────────────────────

local function buildFountain(parent: Instance)
	local style = StyleConfig.Hub.Decor
	local r = MapConfig.Hub.Decor.FountainRadius
	local m = model("Fountain", parent)
	column("Rim", polar(0, 0, 0.7), 1.4, r * 2, style.FountainRim, m, true)
	local water = column("Water", polar(0, 0, 1.42), 0.1, r * 2 - 1.2, style.Water, m)
	water.Material = StyleConfig.GlowMaterial
	water.Transparency = style.WaterTransparency
	column("Column", polar(0, 0, 3.2), 4, 1.8, style.FountainStone, m, true)
	column("Bowl", polar(0, 0, 4.6), 0.6, 5, style.FountainRim, m)
	local bowlWater = column("BowlWater", polar(0, 0, 4.92), 0.1, 4.2, style.Water, m)
	bowlWater.Material = StyleConfig.GlowMaterial
	bowlWater.Transparency = style.WaterTransparency
	local top = part("Top", "Ball", Vector3.one * 1.3, CFrame.new(polar(0, 0, 5.6)), style.Water, m)
	top.Material = StyleConfig.GlowMaterial

	local spec = style.Splash
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = StyleConfig.ParticleTexture
	emitter.Color = ColorSequence.new(spec.Color)
	emitter.Rate = spec.Rate
	emitter.Lifetime = spec.Lifetime
	emitter.Speed = spec.Speed
	emitter.Size = NumberSequence.new(spec.Size, spec.Size * 0.4)
	emitter.SpreadAngle = Vector2.new(spec.SpreadAngle, spec.SpreadAngle)
	emitter.LightEmission = spec.LightEmission
	emitter.Acceleration = Vector3.new(0, -style.SplashGravity, 0)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = top
end

local function buildTree(index: number, angle: number, radius: number, parent: Instance)
	local style = StyleConfig.Hub.Decor
	local m = model("Tree" .. index, parent)
	column("Trunk", polar(angle, radius, 2.5), 5, 1.4, style.TreeTrunk, m, true)
	part("Crown", "Ball", Vector3.one * 7, CFrame.new(polar(angle, radius, 7.5)), style.TreeCrown, m)
	part("CrownTop", "Ball", Vector3.one * 4.5, CFrame.new(polar(angle, radius, 10.2) + Vector3.new(0.8, 0, -0.6)), style.TreeCrownLight, m)
end

-- Куст-облачко: три шара разного размера, без столкновений
local function buildBush(index: number, angle: number, radius: number, parent: Instance)
	local style = StyleConfig.Hub.Decor
	local m = model("Bush" .. index, parent)
	local base = facingCenter(polar(angle, radius, 0))
	part("Puff1", "Ball", Vector3.one * 3.6, base * CFrame.new(-1.6, 1.5, 0), style.Bush, m)
	part("Puff2", "Ball", Vector3.one * 4.4, base * CFrame.new(0.6, 1.9, 0.3), style.BushLight, m)
	part("Puff3", "Ball", Vector3.one * 3, base * CFrame.new(2.4, 1.3, -0.4), style.Bush, m)
end

-- Клумба: круглая грядка с ободком и пять крупных цветов (стебель, лепестки-диск, серединка)
local function buildFlowerBed(index: number, angle: number, radius: number, parent: Instance)
	local style = StyleConfig.Hub.Decor
	local m = model("FlowerBed" .. index, parent)
	column("Rim", polar(angle, radius, 0.3), 0.6, 5.6, style.BedRim, m)
	column("Soil", polar(angle, radius, 0.62), 0.1, 4.8, style.BedSoil, m)
	local center = polar(angle, radius, 0)
	for f = 1, 5 do
		local a = f * 2 * math.pi / 5
		local spot = center + (if f == 5 then Vector3.zero else Vector3.new(math.cos(a), 0, math.sin(a)) * 1.4)
		local height = if f == 5 then 2.6 else 1.8 + (f % 2) * 0.4
		column("Stem" .. f, spot + Vector3.new(0, height / 2, 0), height, 0.25, style.Stem, m)
		column("Petals" .. f, spot + Vector3.new(0, height, 0), 0.3, 1.5, style.Petals[(f - 1) % #style.Petals + 1], m)
		part("Center" .. f, "Ball", Vector3.one * 0.6, CFrame.new(spot + Vector3.new(0, height + 0.2, 0)), style.FlowerCenter, m)
	end
end

local function buildLamp(index: number, position: Vector3, parent: Instance)
	local style = StyleConfig.Hub.Decor
	local m = model("Lamp" .. index, parent)
	column("Post", position + Vector3.new(0, 3, 0), 6, 0.4, style.LampPost, m)
	local glow = part("Glow", "Ball", Vector3.one * 1.4, CFrame.new(position + Vector3.new(0, 6.5, 0)), style.LampGlow, m)
	glow.Material = StyleConfig.GlowMaterial
	column("Cap", position + Vector3.new(0, 7.3, 0), 0.3, 1.6, style.LampPost, m)
end

-- Скамейка лицом к центру: сиденье, спинка, две ножки
local function buildBench(index: number, angle: number, radius: number, parent: Instance)
	local style = StyleConfig.Hub.Decor
	local m = model("Bench" .. index, parent)
	local base = facingCenter(polar(angle, radius, 0))
	part("Seat", "Block", Vector3.new(5, 0.4, 1.6), base * CFrame.new(0, 1.3, 0), style.Bench, m)
	part("Back", "Block", Vector3.new(5, 1.4, 0.3), base * CFrame.new(0, 2.2, 0.75), style.Bench, m)
	for _, x in ipairs({ -2, 2 }) do
		part("Leg" .. x, "Block", Vector3.new(0.4, 1.1, 1.4), base * CFrame.new(x, 0.55, 0), style.BenchLegs, m)
	end
end

-- Стрелка-табличка от столба в сторону цели: доска + острый кончик, надпись с обеих сторон
local function buildArrow(name: string, from: Vector3, target: Vector3, height: number, text: string, parent: Instance)
	local style = StyleConfig.Hub.Decor
	local flatTarget = Vector3.new(target.X, from.Y, target.Z)
	local direction = (flatTarget - from).Unit
	-- Доска вдоль направления: ось X доски смотрит на цель
	local frame = CFrame.fromMatrix(from + Vector3.new(0, height, 0), direction, Vector3.yAxis)
	local board = part(name, "Block", Vector3.new(5.5, 1.3, 0.3), frame * CFrame.new(3, 0, 0), style.SignBoard, parent)
	-- Кончик: квадрат, повёрнутый на 45°, наполовину торчит из конца доски — получается остриё
	part(name .. "Tip", "Block", Vector3.new(0.92, 0.92, 0.3), frame * CFrame.new(5.75, 0, 0) * CFrame.Angles(0, 0, math.rad(45)), style.SignBoard, parent)
	signText(board, Enum.NormalId.Front, text, style.SignText)
	signText(board, Enum.NormalId.Back, text, style.SignText)
end

local function buildSignpost(index: number, angle: number, radius: number, parent: Instance)
	local style = StyleConfig.Hub.Decor
	local m = model("Signpost" .. index, parent)
	local base = polar(angle, radius, 0)
	column("Post", base + Vector3.new(0, 3.5, 0), 7, 0.5, style.SignPost, m, true)
	local hub = MapConfig.Hub
	local bestHaul = Vector3.new(hub.Center.X + hub.BestHaul.Offset.X, base.Y, hub.Center.Z + hub.BestHaul.Offset.Y)
	buildArrow("ToPortal", base, MapConfig.Portal.Position, 6, TextConfig.Portal, m)
	buildArrow("ToBestHaul", base, bestHaul, 4.6, TextConfig.BestHaulTitle, m)
end

-- ── Гиганты ───────────────────────────────────────────────────────────────

-- Гигантский мемный предмет kind на полу в точке base, лицом к центру площади. Вернёт false, если такого нет
function HubDecor.BuildGiant(kind: string, base: Vector3, parent: Instance): boolean
	local style = StyleConfig.Hub
	local face = facingCenter(base)
	if kind == "Phone" then
		local c = style.Phone
		-- Телефон стоит, чуть откинувшись назад; экран смотрит на центр
		local body = face * CFrame.new(0, 5.6, 0) * CFrame.Angles(math.rad(-10), 0, 0)
		part("Body", "Block", Vector3.new(6, 11, 1.2), body, c.Body, parent, true)
		part("Screen", "Block", Vector3.new(5, 8.6, 0.2), body * CFrame.new(0, 0.4, -0.65), c.Screen, parent)
		for i = 0, 3 do
			local x, y = (i % 2) * 2.2 - 1.1, 2.6 - math.floor(i / 2) * 2.2
			part("App" .. i, "Block", Vector3.new(1.5, 1.5, 0.15), body * CFrame.new(x, y, -0.8), c.Apps[i + 1], parent)
		end
		part("Button", "Cylinder", Vector3.new(0.2, 0.9, 0.9), body * CFrame.new(0, -4.7, -0.65) * CFrame.Angles(0, math.rad(90), 0), c.Button, parent)
		return true
	elseif kind == "Banana" then
		-- Банан лежит дугой: пять толстых отрезков по кругу, на концах — коричневые кончики
		local c = style.Banana
		local count = 5
		for i = 1, count do
			local a = math.rad(-50 + (i - 1) * 25)
			-- Ось цилиндра (X) — по касательной к дуге
			local segment = face * CFrame.new(math.sin(a) * 6, 1.6, math.cos(a) * 6 - 6) * CFrame.Angles(0, a, 0)
			part("Peel" .. i, "Cylinder", Vector3.new(3.4, 3.2 - math.abs(i - 3) * 0.4, 3.2 - math.abs(i - 3) * 0.4), segment, c.Peel, parent, true)
		end
		for _, a in ipairs({ math.rad(-62), math.rad(62) }) do
			part("Tip", "Ball", Vector3.one * 1.2, face * CFrame.new(math.sin(a) * 6, 1.6, math.cos(a) * 6 - 6), c.Tips, parent)
		end
		return true
	elseif kind == "Duck" then
		local c = style.Duck
		part("Body", "Oval", Vector3.new(8, 6, 10), face * CFrame.new(0, 3, 0.5), c.Body, parent, true)
		part("Tail", "Oval", Vector3.new(3, 3, 3), face * CFrame.new(0, 4.8, 5) * CFrame.Angles(math.rad(-30), 0, 0), c.Body, parent)
		part("Head", "Ball", Vector3.one * 5.2, face * CFrame.new(0, 7.4, -3), c.Body, parent)
		part("Beak", "Oval", Vector3.new(2.6, 1.2, 2.4), face * CFrame.new(0, 7, -5.6), c.Beak, parent)
		for _, x in ipairs({ -1.2, 1.2 }) do
			part("Eye", "Ball", Vector3.one * 0.8, face * CFrame.new(x, 8.2, -5.1), c.Eye, parent)
			part("Wing", "Oval", Vector3.new(1.2, 3, 5), face * CFrame.new(x * 3.2, 3.6, 0.8), c.Body, parent)
		end
		return true
	elseif kind == "Headphones" then
		-- Наушники стоят на чашках: дуга-оголовье из отрезков, по бокам чашки с мягкими подушками
		local c = style.Headphones
		local radius = 5
		for i = 0, 6 do
			local a = math.rad(i * 30)
			local spot = face * CFrame.new(math.cos(a) * radius, 3 + math.sin(a) * radius, 0) * CFrame.Angles(0, 0, a + math.rad(90))
			part("Band" .. i, "Block", Vector3.new(2.9, 1, 1.4), spot, c.Band, parent)
		end
		for _, x in ipairs({ -radius, radius }) do
			local cup = face * CFrame.new(x, 2.4, 0)
			part("Cup", "Cylinder", Vector3.new(2.2, 4.4, 4.4), cup, c.Cups, parent, true)
			part("Cushion", "Cylinder", Vector3.new(0.8, 3.6, 3.6), cup * CFrame.new(-math.sign(x) * 1.4, 0, 0), c.Cushions, parent)
		end
		return true
	end
	return false
end

-- ── Вся площадь ──────────────────────────────────────────────────────────

function HubDecor.Build(parent: Instance)
	local decor = MapConfig.Hub.Decor
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = parent

	buildFountain(folder)
	for i, spot in ipairs(decor.Trees) do
		buildTree(i, spot.Angle, spot.Radius, folder)
	end
	for i, spot in ipairs(decor.Bushes) do
		buildBush(i, spot.Angle, spot.Radius, folder)
	end
	for i, spot in ipairs(decor.FlowerBeds) do
		buildFlowerBed(i, spot.Angle, spot.Radius, folder)
	end
	for i, spot in ipairs(decor.Benches) do
		buildBench(i, spot.Angle, spot.Radius, folder)
	end
	for i, spot in ipairs(decor.Signposts) do
		buildSignpost(i, spot.Angle, spot.Radius, folder)
	end

	-- Фонари: по одному у каждой дорожки к мостику — с той стороны, что дальше от портала
	-- (у портала свой подиум), и пара у дорожки к порталу
	local plots = MapConfig.Plots
	local portalFlat = Vector3.new(MapConfig.Portal.Position.X, 0, MapConfig.Portal.Position.Z)
	local lamp = 0
	for i = 1, plots.Count do
		local angle = plots.AngleOffsetDegrees + (i - 1) * 360 / plots.Count
		local a = math.rad(angle)
		local side = Vector3.new(-math.sin(a), 0, math.cos(a)) * decor.LampSide
		local onPath = polar(angle, decor.LampRadius, 0)
		local left, right = onPath + side, onPath - side
		local function fromPortal(p: Vector3): number
			return (Vector3.new(p.X, 0, p.Z) - portalFlat).Magnitude
		end
		lamp += 1
		buildLamp(lamp, if fromPortal(left) >= fromPortal(right) then left else right, folder)
	end
	for _, sign in ipairs({ -1, 1 }) do
		lamp += 1
		local portalLamps = decor.PortalLamps
		buildLamp(lamp, polar(90, portalLamps.Radius, 0) + Vector3.new(sign * portalLamps.Side, 0, 0), folder)
	end
end

return HubDecor
