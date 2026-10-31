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

type Laser = {
	Start: Vector3,
	End: Vector3,
	Size: Vector3,
	SweepSeconds: number,
	PrevPosition: Vector3?,
	LastHit: { [Player]: number },
}

local lasers: { Laser } = {}
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

	-- Лазерные планки: на сервере стоят в начале дорожки, двигает их клиент (по тем же формулам)
	for n, spec in ipairs(HazardConfig.Lasers) do
		local startPosition = top + spec.TrackStart
		local endPosition = top + spec.TrackEnd
		local bar = makeHazardPart("LaserBar" .. n, spec.Size, CFrame.new(startPosition), style.Laser, folder)
		bar.Material = StyleConfig.GlowMaterial
		bar.CanCollide = false
		bar.CanTouch = false
		bar.CanQuery = false
		bar:SetAttribute("TrackStart", startPosition)
		bar:SetAttribute("TrackEnd", endPosition)
		bar:SetAttribute("SweepSeconds", spec.SweepSeconds)
		CollectionService:AddTag(bar, HazardConfig.Tags.Laser)
		table.insert(lasers, {
			Start = startPosition,
			End = endPosition,
			Size = spec.Size,
			SweepSeconds = spec.SweepSeconds,
			PrevPosition = nil,
			LastHit = setmetatable({}, { __mode = "k" }) :: any,
		})

		-- Рельсы на полу по краям дорожки: видно, где будет ездить планка.
		-- Края — по длинной стороне планки (поперёк направления движения)
		local direction = (endPosition - startPosition).Unit
		local alongX = math.abs(direction.X) > math.abs(direction.Z)
		local halfWidth = if alongX then spec.Size.Z / 2 else spec.Size.X / 2
		local side = if alongX then Vector3.zAxis else Vector3.xAxis
		local middle = (startPosition + endPosition) / 2
		local length = (endPosition - startPosition).Magnitude + (if alongX then spec.Size.X else spec.Size.Z)
		for i, sign in ipairs({ -1, 1 }) do
			local railCenter = Vector3.new(middle.X, top.Y + 0.1, middle.Z) + side * sign * halfWidth
			local rail = makeHazardPart(
				"LaserRail" .. n .. "_" .. i,
				Vector3.new(style.RailWidth, 0.2, length),
				CFrame.lookAt(railCenter, railCenter + Vector3.new(direction.X, 0, direction.Z)),
				style.Rail,
				folder
			)
			rail.CanCollide = false
			rail.CanQuery = false
		end
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

local function updateLaser(laser: Laser, now: number, targets: { Target })
	local shared = HazardConfig.Laser
	local u = HazardMath.Laser(now, laser.SweepSeconds, shared.DwellSeconds)
	local position = laser.Start:Lerp(laser.End, u)
	-- Проверяем всю полосу, которую планка прошла с прошлой проверки: иначе быстрая планка «перепрыгнет» игрока
	local previous = laser.PrevPosition or position
	laser.PrevPosition = position
	local center = (previous + position) / 2
	local halfSize = laser.Size / 2 + Vector3.new(
		math.abs(position.X - previous.X) / 2,
		math.abs(position.Y - previous.Y) / 2,
		math.abs(position.Z - previous.Z) / 2
	)

	for _, target in ipairs(targets) do
		local last = laser.LastHit[target.Player]
		if (last == nil or now - last >= shared.HitCooldownSeconds) and overlaps(target.Root, center, halfSize) then
			laser.LastHit[target.Player] = now
			Damage.Apply(target.Player, shared.Damage, "лазер")
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
			for _, laser in ipairs(lasers) do
				updateLaser(laser, now, targets)
			end
			updatePlates(now, targets)
		end
	end)
	print(string.format("[Hazards] Ловушки готовы: лазеров %d, плит %d", #lasers, #plates))
end

return Hazards
