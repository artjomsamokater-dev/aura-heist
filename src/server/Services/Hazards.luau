--!strict
-- Hazards: ловушки в опасной части зоны — лазерная планка и плиты-«хлопушки» (числа — HazardConfig).
--
-- Где ловушка и когда она бьёт, считается по времени сервера (shared/Util/HazardMath).
-- Урон считает только сервер: раз в TickSeconds проверяет, пересекла ли «коробка» персонажа ловушку.
-- Никаких Touched: попадание — это геометрия в момент проверки.
-- Двигает планку и подсвечивает плиты клиент (HazardController) по тем же формулам — плавно и без трафика.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local HazardConfig = require(ReplicatedStorage.Shared.Config.HazardConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local HazardMath = require(ReplicatedStorage.Shared.Util.HazardMath)
local MapBuilder = require(script.Parent.MapBuilder)
local Raid = require(script.Parent.Raid)
local Damage = require(script.Parent.Damage)
local RemoteGuard = require(ServerScriptService.Server.Security.RemoteGuard)

local Hazards = {}

local MAX_HEALTH = 100 -- здоровье персонажа Roblox по умолчанию

type Plate = {
	Part: Part,
	OffsetSeconds: number,
	LastIndex: number, -- номер последнего цикла, в котором плита уже ударила
}

type Target = {
	Player: Player,
	Root: BasePart,
}

local laserStart = Vector3.zero
local laserEnd = Vector3.zero
local laserPrevPosition: Vector3? = nil
local laserLastHit: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
local plates: { Plate } = {}

local function zoneTop(): Vector3
	local zone = MapConfig.Zone
	return zone.Center + Vector3.new(0, zone.Size.Y / 2, 0)
end

local function makeHazardPart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = MapBuilder.MakePart(name, size, cframe, color, parent)
	part.CastShadow = false
	return part
end

-- Правила конфига, которые нельзя проверить консольными тестами (в HazardConfig есть Vector3)
local function validateConfig()
	if HazardConfig.Laser.Damage >= MAX_HEALTH or HazardConfig.Slam.Damage >= MAX_HEALTH then
		warn("[Hazards] Урон ловушки убивает с одного попадания — уменьши Damage в HazardConfig")
	end
	if HazardConfig.Slam.WarnSeconds < 1 or HazardConfig.Slam.WarnSeconds >= HazardConfig.Slam.CycleSeconds then
		warn("[Hazards] Подсветка плиты должна быть не короче 1 с и короче цикла (HazardConfig.Slam)")
	end
end

local function build()
	local folder = Instance.new("Folder")
	folder.Name = "Hazards"
	folder.Parent = MapBuilder.GetZoneFolder()
	local top = zoneTop()
	local style = StyleConfig.Hazards

	-- Лазерная планка: на сервере стоит в начале дорожки, двигает её клиент
	local laser = HazardConfig.Laser
	laserStart = top + laser.TrackStart
	laserEnd = top + laser.TrackEnd
	local bar = makeHazardPart("LaserBar", laser.Size, CFrame.new(laserStart), style.Laser, folder)
	bar.Material = StyleConfig.GlowMaterial
	bar.CanCollide = false
	bar.CanTouch = false
	bar.CanQuery = false
	bar:SetAttribute("TrackStart", laserStart)
	bar:SetAttribute("TrackEnd", laserEnd)
	CollectionService:AddTag(bar, HazardConfig.Tags.Laser)

	-- Рельсы на полу по краям дорожки: видно, где будет ездить планка
	local trackMiddle = (laserStart + laserEnd) / 2
	local trackLength = (laserEnd - laserStart).Magnitude + laser.Size.Z
	local trackDirection = (laserEnd - laserStart).Unit
	for i, side in ipairs({ -1, 1 }) do
		local railCenter = Vector3.new(trackMiddle.X + side * laser.Size.X / 2, top.Y + 0.1, trackMiddle.Z)
		local rail = makeHazardPart(
			"LaserRail" .. i,
			Vector3.new(style.RailWidth, 0.2, trackLength),
			CFrame.lookAt(railCenter, railCenter + Vector3.new(trackDirection.X, 0, trackDirection.Z)),
			style.Rail,
			folder
		)
		rail.CanCollide = false
		rail.CanQuery = false
	end

	-- Плиты-«хлопушки»
	local slam = HazardConfig.Slam
	for i, offset in ipairs(slam.Plates) do
		local part = makeHazardPart(
			"SlamPlate" .. i,
			slam.Size,
			CFrame.new(top + offset + Vector3.new(0, slam.Size.Y / 2, 0)),
			style.SlamIdle,
			folder
		)
		local offsetSeconds = (i - 1) * slam.StaggerSeconds
		part:SetAttribute("OffsetSeconds", offsetSeconds)
		CollectionService:AddTag(part, HazardConfig.Tags.Slam)
		local index = HazardMath.Slam(Workspace:GetServerTimeNow(), slam.CycleSeconds, slam.WarnSeconds, offsetSeconds)
		table.insert(plates, { Part = part, OffsetSeconds = offsetSeconds, LastIndex = index })
	end
end

-- Кого ловушки могут задеть: игроки в вылазке с живым персонажем
local function getTargets(): { Target }
	local targets: { Target } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if Raid.GetState(player) == Raid.State.InRaid then
			local _, root = RemoteGuard.GetAliveCharacter(player)
			if root then
				table.insert(targets, { Player = player, Root = root })
			end
		end
	end
	return targets
end

-- Пересекает ли «коробка» персонажа коробку ловушки (center, halfSize; без поворота)
local function overlaps(root: BasePart, center: Vector3, halfSize: Vector3): boolean
	local character = HazardConfig.CharacterHalfSize
	local p = root.Position - center
	return HazardMath.InBox(p.X, p.Y, p.Z, halfSize.X + character.X, halfSize.Y + character.Y, halfSize.Z + character.Z)
end

local function updateLaser(now: number, targets: { Target })
	local laser = HazardConfig.Laser
	local u = HazardMath.Laser(now, laser.SweepSeconds, laser.DwellSeconds)
	local position = laserStart:Lerp(laserEnd, u)
	-- Проверяем всю полосу, которую планка прошла с прошлой проверки: иначе быстрая планка «перепрыгнет» игрока
	local previous = laserPrevPosition or position
	laserPrevPosition = position
	local center = (previous + position) / 2
	local halfSize = laser.Size / 2 + Vector3.new(
		math.abs(position.X - previous.X) / 2,
		math.abs(position.Y - previous.Y) / 2,
		math.abs(position.Z - previous.Z) / 2
	)

	for _, target in ipairs(targets) do
		local last = laserLastHit[target.Player]
		if (last == nil or now - last >= laser.HitCooldownSeconds) and overlaps(target.Root, center, halfSize) then
			laserLastHit[target.Player] = now
			Damage.Apply(target.Player, laser.Damage, "лазер")
		end
	end
end

local function updatePlates(now: number, targets: { Target })
	local slam = HazardConfig.Slam
	for _, plate in ipairs(plates) do
		local index = HazardMath.Slam(now, slam.CycleSeconds, slam.WarnSeconds, plate.OffsetSeconds)
		if index > plate.LastIndex then
			plate.LastIndex = index -- удар один раз за цикл
			local center = plate.Part.Position + Vector3.new(0, slam.Size.Y / 2 + slam.HitHeight / 2, 0)
			local halfSize = Vector3.new(slam.Size.X / 2, slam.HitHeight / 2, slam.Size.Z / 2)
			for _, target in ipairs(targets) do
				if overlaps(target.Root, center, halfSize) then
					Damage.Apply(target.Player, slam.Damage, "плита")
				end
			end
		end
	end
end

function Hazards.Start()
	validateConfig()
	build()

	task.spawn(function()
		while true do
			task.wait(HazardConfig.TickSeconds)
			local now = Workspace:GetServerTimeNow()
			local targets = getTargets()
			updateLaser(now, targets)
			updatePlates(now, targets)
		end
	end)
	print(string.format("[Hazards] Ловушки готовы: лазер и %d плит", #plates))
end

return Hazards
