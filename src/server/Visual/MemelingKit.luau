--!strict
-- MemelingKit: общие приёмы стиля «D · Микс» для мемлингов и врага (задача 5.4).
-- Строители персонажей (MemelingBuilders) собирают модель из этих деталей.
--
-- Все места — от центра мемлинга: −Z — вперёд (лицо), +Y — вверх,
-- +X — слева для того, кто смотрит мемлингу в лицо. Свет падает сверху-слева:
-- блик — слева сверху (+X), гранёная тень — справа (−X).
-- Каждая деталь приварена к ядру и не мешает игре: не сталкивается, не ловит лучи и касания, без тени.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)

local MemelingKit = {}

-- Повороты деталей, градусы по X, Y, Z
MemelingKit.UP = Vector3.new(0, 0, 90) -- цилиндр Roblox лежит вдоль X — так он стоит вертикально
MemelingKit.ALONG_Z = Vector3.new(0, 90, 0) -- цилиндр вдоль Z (вперёд-назад)
MemelingKit.TRIANGLE_UP = Vector3.new(0, 90, 0) -- клин треугольником к зрителю, острием вверх (шипы)
MemelingKit.TRIANGLE_DOWN = Vector3.new(0, 90, 180) -- острием вниз (зубцы бороды)

export type Kit = {
	Core: BasePart, -- ядро: к нему привариваются детали
	Origin: CFrame, -- центр мемлинга, лицо смотрит в −Z
	Count: number, -- сколько деталей уже добавлено
}

function MemelingKit.new(core: BasePart, origin: CFrame): Kit
	return { Core = core, Origin = origin, Count = 0 }
end

-- Kind: "Ball" (шар, размер одинаковый по осям) | "Oval" (овал любого размера) |
-- "Block" | "Cylinder" (лежит вдоль X) | "Wedge" (клин)
local function makeRaw(kind: string): BasePart
	if kind == "Wedge" then
		return Instance.new("WedgePart")
	end
	local part = Instance.new("Part")
	if kind == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif kind == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	elseif kind == "Oval" then
		-- Шар Roblox всегда круглый; овал — блок с круглой «сеткой», она растягивается по размеру детали
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	return part
end

-- Деталь, приваренная к ядру. rotation — градусы по X, Y, Z (сначала Z, потом Y, потом X)
function MemelingKit.Add(kit: Kit, kind: string, size: Vector3, offset: Vector3, color: Color3, rotation: Vector3?): BasePart
	kit.Count += 1
	local r = rotation or Vector3.zero
	local part = makeRaw(kind)
	part.Name = "Part" .. kit.Count
	part.Size = size
	part.CFrame = kit.Origin * CFrame.new(offset) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
	part.Color = color
	part.Material = StyleConfig.Material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = kit.Core
	weld.Part1 = part
	weld.Parent = part
	part.Parent = kit.Core
	return part
end

-- Глубина передней поверхности овала (z < 0) в точке (x, y): туда сажаем глаза, рот и румянец
function MemelingKit.Front(center: Vector3, size: Vector3, x: number, y: number): number
	local dx = (x - center.X) / (size.X / 2)
	local dy = (y - center.Y) / (size.Y / 2)
	return center.Z - size.Z / 2 * math.sqrt(math.max(0, 1 - dx * dx - dy * dy))
end

-- То же для вертикального цилиндра (стаканчик, носок): радиус и центр по X и Z
function MemelingKit.FrontRound(center: Vector3, radius: number, x: number): number
	local dx = x - center.X
	return center.Z - math.sqrt(math.max(0, radius * radius - dx * dx))
end

-- Цвет тени: цвет тела, смешанный с тёмным цветом контура
function MemelingKit.Darker(color: Color3): Color3
	return color:Lerp(StyleConfig.Outline.Color, StyleConfig.Memeling.Face.ShadeDarken)
end

-- Глаз: белок, зрачок и белая точка-блик. look — куда смотрит зрачок (−1..1 по X и Y)
function MemelingKit.Eye(kit: Kit, position: Vector3, size: number, look: Vector2?)
	local face = StyleConfig.Memeling.Face
	local shift = look or Vector2.zero
	MemelingKit.Add(kit, "Ball", Vector3.one * size, position, face.EyeWhite)
	local pupilSize = size * face.PupilScale
	local pupil = position + Vector3.new(shift.X * size * 0.18, shift.Y * size * 0.18, -size * 0.3)
	MemelingKit.Add(kit, "Ball", Vector3.one * pupilSize, pupil, face.Pupil)
	-- Блик — сверху-слева на зрачке, чуть впереди него
	local glint = pupil + Vector3.new(pupilSize * 0.25, pupilSize * 0.25, -pupilSize * 0.35)
	MemelingKit.Add(kit, "Ball", Vector3.one * size * face.GlintScale, glint, face.Glint)
end

-- Румянец: розовый полупрозрачный овал
function MemelingKit.Blush(kit: Kit, size: Vector3, position: Vector3, rotation: Vector3?)
	local face = StyleConfig.Memeling.Face
	local part = MemelingKit.Add(kit, "Oval", size, position, face.Blush, rotation)
	part.Transparency = face.BlushTransparency
end

-- Глянцевый блик: белый полупрозрачный овал сверху-слева
function MemelingKit.Gloss(kit: Kit, size: Vector3, position: Vector3, rotation: Vector3?)
	local face = StyleConfig.Memeling.Face
	local part = MemelingKit.Add(kit, "Oval", size, position, face.Gloss, rotation)
	part.Transparency = face.GlossTransparency
end

-- Гранёная тень: та же форма тёмнее, чуть сдвинута вправо (−X) и чуть тоньше — справа видна тёмная грань
function MemelingKit.Shade(kit: Kit, kind: string, size: Vector3, offset: Vector3, bodyColor: Color3, rotation: Vector3?): BasePart
	local part = MemelingKit.Add(kit, kind, size, offset, MemelingKit.Darker(bodyColor), rotation)
	part.Name = "Shade"
	return part
end

-- Рот и прочие тёмные чёрточки лица
function MemelingKit.Mouth(kit: Kit, size: Vector3, position: Vector3, rotation: Vector3?): BasePart
	return MemelingKit.Add(kit, "Oval", size, position, StyleConfig.Memeling.Face.Mouth, rotation)
end

local function addParticles(part: BasePart, spec: StyleConfig.Particles)
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
end

-- Кольцо-подставка цвета редкости под мемлингом. У Epic и Legendary — неон, свет и искры
-- (PointLight только у них: Common и Rare без света, так дешевле для телефонов)
function MemelingKit.RarityRing(kit: Kit, rarityId: string)
	local cfg = StyleConfig.Memeling
	local style = cfg.Rarities[rarityId] or cfg.Rarities.Common
	local ring = MemelingKit.Add(
		kit,
		"Cylinder",
		Vector3.new(cfg.RingHeight, cfg.RingDiameter, cfg.RingDiameter),
		Vector3.new(0, -cfg.Size.Y / 2 + cfg.RingHeight / 2, 0),
		style.Color,
		MemelingKit.UP
	)
	ring.Name = "RarityRing"
	if style.Glow then
		ring.Material = StyleConfig.GlowMaterial
	end
	if style.Light then
		local light = Instance.new("PointLight")
		light.Color = style.Color
		light.Brightness = style.Light.Brightness
		light.Range = style.Light.Range
		light.Shadows = false
		light.Parent = kit.Core
	end
	if style.Particles then
		addParticles(kit.Core, style.Particles)
	end
end

-- Отметка «нужен контур»: Highlight ставит клиент (OutlineController), только ближним и своим
function MemelingKit.TagOutline(instance: Instance)
	CollectionService:AddTag(instance, StyleConfig.Outline.Tag)
end

return MemelingKit
