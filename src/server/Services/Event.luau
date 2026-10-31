--!strict
-- Event: событие Giant Object — огромное колесо сыра катится по опасной части (числа — EventConfig.GiantObject).
--
-- • Раз в IntervalMin..IntervalMax секунд (случайно). Если в зоне нет игроков — не запускается.
-- • За WarnSeconds до старта маршрут подсвечивается мигающей полосой и звучит сигнал.
-- • Колесо закреплено (anchored) и едет по маршруту с помощью Tween; после маршрута исчезает.
-- • Урон считает сервер раз в TickSeconds по пересечению с «коробкой» персонажа (без Touched),
--   с перезарядкой на игрока. Урон наносит только сервис Damage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local HazardConfig = require(ReplicatedStorage.Shared.Config.HazardConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local GiantRoute = require(ReplicatedStorage.Shared.Util.GiantRoute)
local MapBuilder = require(script.Parent.MapBuilder)
local Raid = require(script.Parent.Raid)
local Damage = require(script.Parent.Damage)
local RemoteGuard = require(ServerScriptService.Server.Security.RemoteGuard)

local Event = {}

local MAX_HEALTH = 100 -- здоровье персонажа Roblox по умолчанию

local random = Random.new()
local eventFolder: Folder? = nil

type Target = {
	Player: Player,
	Root: BasePart,
}

local function zoneTop(): Vector3
	local zone = MapConfig.Zone
	return zone.Center + Vector3.new(0, zone.Size.Y / 2, 0)
end

-- Точки маршрута в мире (по полу зоны)
local function routePoints(): { Vector3 }
	local top = zoneTop()
	local points = {}
	for _, offset in ipairs(EventConfig.GiantObject.Route) do
		table.insert(points, top + offset)
	end
	return points
end

-- Игроки в вылазке с живым персонажем
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

local function decorate(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

-- Подсветка маршрута: светящаяся полоса на полу по каждому отрезку
local function buildHighlight(points: { Vector3 }, parent: Instance): { BasePart }
	local strips: { BasePart } = {}
	local width = EventConfig.GiantObject.RouteHighlightWidth
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = (b - a).Magnitude + width
		local middle = (a + b) / 2 + Vector3.new(0, 0.08, 0)
		local strip = MapBuilder.MakePart(
			"RouteHighlight" .. i,
			Vector3.new(width, 0.1, length),
			CFrame.lookAt(middle, middle + (b - a)),
			StyleConfig.Event.RouteHighlight,
			parent
		)
		strip.Material = StyleConfig.GlowMaterial
		decorate(strip)
		table.insert(strips, strip)
	end
	return strips
end

local function playWarnSound(parent: BasePart)
	local sound = Instance.new("Sound")
	sound.SoundId = StyleConfig.Event.WarnSound
	sound.Volume = StyleConfig.Event.WarnSoundVolume
	sound.RollOffMaxDistance = 400
	sound.Parent = parent
	sound:Play()
end

-- Предупреждение: полоса мигает WarnSeconds, звучит сигнал
local function warnRoute(strips: { BasePart })
	if strips[1] then
		playWarnSound(strips[1])
	end
	local style = StyleConfig.Event
	local half = 1 / (style.RouteBlinkHz * 2)
	local elapsed = 0
	local on = true
	while elapsed < EventConfig.GiantObject.WarnSeconds do
		for _, strip in ipairs(strips) do
			strip.Transparency = if on then 0 else style.RouteBlinkTransparency
		end
		on = not on
		task.wait(half)
		elapsed += half
	end
end

local function attach(part: BasePart, body: BasePart)
	part.Anchored = false
	part.Massless = true
	decorate(part)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = part
	weld.Parent = part
end

-- Колесо сыра: ось вдоль X (поперёк движения), дырки на обоих боках, рожица на одном боку
local function buildWheel(cframe: CFrame, parent: Instance): Part
	local cfg = EventConfig.GiantObject
	local style = StyleConfig.Event
	local radius = cfg.Diameter / 2

	local wheel = MapBuilder.MakePart("CheeseWheel", Vector3.new(cfg.Thickness, cfg.Diameter, cfg.Diameter), cframe, style.Cheese, parent)
	wheel.Shape = Enum.PartType.Cylinder
	decorate(wheel)

	-- Светлые «корки» на боках
	for i, side in ipairs({ -1, 1 }) do
		local rind = MapBuilder.MakePart(
			"Rind" .. i,
			Vector3.new(0.3, cfg.Diameter * 0.86, cfg.Diameter * 0.86),
			cframe * CFrame.new(side * cfg.Thickness / 2, 0, 0),
			style.Rind,
			wheel
		)
		rind.Shape = Enum.PartType.Cylinder
		attach(rind, wheel)
	end

	-- Дырки (тёмные шарики, наполовину в сыре) на обоих боках и на ободе
	local holes = {
		Vector3.new(-cfg.Thickness / 2, radius * 0.45, radius * 0.3),
		Vector3.new(-cfg.Thickness / 2, -radius * 0.4, -radius * 0.45),
		Vector3.new(cfg.Thickness / 2, -radius * 0.5, radius * 0.35),
		Vector3.new(0.6, radius * 0.97, 0),
		Vector3.new(-0.8, 0, radius * 0.97),
	}
	for i, offset in ipairs(holes) do
		local hole = MapBuilder.MakePart("Hole" .. i, Vector3.one * (radius * 0.35), cframe * CFrame.new(offset), style.Holes, wheel)
		hole.Shape = Enum.PartType.Ball
		attach(hole, wheel)
	end

	-- Глупая рожица на боку +X: глаза разного размера и широкая улыбка
	local faceX = cfg.Thickness / 2 + 0.15
	for i, eye in ipairs({ { Offset = Vector3.new(faceX, radius * 0.25, -radius * 0.3), Size = 1.4 }, { Offset = Vector3.new(faceX, radius * 0.35, radius * 0.25), Size = 1.0 } }) do
		local ball = MapBuilder.MakePart("Eye" .. i, Vector3.one * eye.Size, cframe * CFrame.new(eye.Offset), style.Face, wheel)
		ball.Shape = Enum.PartType.Ball
		attach(ball, wheel)
	end
	local mouth = MapBuilder.MakePart("Mouth", Vector3.new(0.3, 0.5, radius * 0.9), cframe * CFrame.new(faceX, -radius * 0.25, 0), style.Face, wheel)
	attach(mouth, wheel)

	MapBuilder.AddLabel(wheel, TextConfig.GiantObjectName, { Height = StyleConfig.Event.LabelHeight })
	return wheel
end

-- Пересекает ли колесо «коробку» персонажа: в системе колеса без вращения (ось X — поперёк движения)
local function hits(frame: CFrame, root: BasePart): boolean
	local cfg = EventConfig.GiantObject
	local character = HazardConfig.CharacterHalfSize
	local p = frame:PointToObjectSpace(root.Position)
	local alongAxis = math.abs(p.X) <= cfg.Thickness / 2 + character.X
	local inCircle = math.sqrt(p.Y * p.Y + p.Z * p.Z) <= cfg.Diameter / 2 + character.X
	return alongAxis and inCircle
end

-- Колесо катится по маршруту; урон проверяется параллельно, пока оно едет
local function roll(wheel: Part, points: { Vector3 })
	local cfg = EventConfig.GiantObject
	local radius = cfg.Diameter / 2
	local up = Vector3.new(0, radius, 0)
	local frame = CFrame.lookAt(points[1] + up, points[2] + up)
	local rolling = true
	local lastHit: { [Player]: number } = {}

	-- Урон: раз в TickSeconds — пересечение в этот момент
	task.spawn(function()
		while rolling do
			local now = os.clock()
			for _, target in ipairs(getTargets()) do
				local last = lastHit[target.Player]
				if (last == nil or now - last >= cfg.HitCooldownSeconds) and hits(frame, target.Root) then
					lastHit[target.Player] = now
					Damage.Apply(target.Player, cfg.Damage, "Giant Object")
				end
			end
			task.wait(cfg.TickSeconds)
		end
	end)

	local angle = 0
	local durations = GiantRoute.SegmentDurations(points :: any, cfg.Speed)
	for i = 1, #points - 1 do
		local a, b = points[i] + up, points[i + 1] + up
		local direction = (b - a).Unit
		local length = (b - a).Magnitude
		local startAngle = angle

		-- Tween двигает число 0 → 1, а по нему ставим позицию и поворот колеса (несколько оборотов
		-- одним Tween поворота не сделать — он выбирает кратчайший путь)
		local progress = Instance.new("NumberValue")
		progress.Value = 0
		progress.Changed:Connect(function(alpha: number)
			local position = a:Lerp(b, alpha)
			frame = CFrame.lookAt(position, position + direction)
			angle = startAngle + GiantRoute.RollAngle(length * alpha, radius)
			wheel.CFrame = frame * CFrame.Angles(-angle, 0, 0)
		end)
		local tween = TweenService:Create(progress, TweenInfo.new(durations[i], Enum.EasingStyle.Linear), { Value = 1 })
		tween:Play()
		tween.Completed:Wait()
		progress:Destroy()
	end
	rolling = false
end

local function runEvent()
	local folder = (assert(eventFolder, "Event.Start() ещё не вызван"))
	local points = routePoints()
	if #points < 2 then
		return
	end
	print("[Event] Giant Object: предупреждение")

	local strips = buildHighlight(points, folder)
	warnRoute(strips)
	for _, strip in ipairs(strips) do
		strip:Destroy()
	end

	local radius = EventConfig.GiantObject.Diameter / 2
	local start = CFrame.lookAt(points[1] + Vector3.new(0, radius, 0), points[2] + Vector3.new(0, radius, 0))
	local wheel = buildWheel(start, folder)
	print("[Event] Giant Object покатился")
	roll(wheel, points)
	wheel:Destroy()
	print("[Event] Giant Object доехал и исчез")
end

function Event.Start()
	local cfg = EventConfig.GiantObject
	if cfg.Damage >= MAX_HEALTH then
		warn("[Event] Урон Giant Object убивает с одного удара — уменьши EventConfig.GiantObject.Damage")
	end

	local folder = Instance.new("Folder")
	folder.Name = "Events"
	folder.Parent = MapBuilder.GetZoneFolder()
	eventFolder = folder

	task.spawn(function()
		while true do
			task.wait(random:NextNumber(cfg.IntervalMin, cfg.IntervalMax))
			-- Нет игроков в зоне — не запускаем: катиться не для кого
			if GiantRoute.ShouldStart(#getTargets()) then
				xpcall(runEvent, function(err)
					warn("[Event] Giant Object: ошибка — " .. tostring(err))
					folder:ClearAllChildren() -- не оставлять на карте колесо или подсветку
				end)
			end
		end
	end)
end

return Event
