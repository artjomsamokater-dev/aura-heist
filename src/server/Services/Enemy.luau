--!strict
-- Enemy: враги Grumblob в опасной части зоны (числа — EnemyConfig.Chaser,
-- вид — server/Visual/MemelingBuilders.BuildEnemy, цвета — StyleConfig.Characters.Grumblob).
--
-- • Ходят только внутри опасной части: цель за её краем — враг останавливается у границы (EnemyMath).
--   В круг ExtractionKeepOut вокруг EXTRACT тоже не заходят: эвакуацию караулить нельзя.
-- • Humanoid + PathfindingService: сквозь стены не проходят, путь пересчитывается раз в ThinkSeconds.
-- • Спят, если ни одного игрока в вылазке нет ближе WakeRadius: тогда ничего не считают.
-- • Урон при касании: сервер раз в DamageTickSeconds меряет расстояние (без Touched), с перезарядкой.
-- • Раз в PerfReportSeconds пишут в Output, сколько времени сервера на них уходит.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local EnemyMath = require(ReplicatedStorage.Shared.Util.EnemyMath)
local MapBuilder = require(script.Parent.MapBuilder)
local Raid = require(script.Parent.Raid)
local Damage = require(script.Parent.Damage)
local RemoteGuard = require(ServerScriptService.Server.Security.RemoteGuard)
local MemelingKit = require(ServerScriptService.Server.Visual.MemelingKit)
local MemelingBuilders = require(ServerScriptService.Server.Visual.MemelingBuilders)

local Enemy = {}

local MAX_HEALTH = 100 -- здоровье персонажа Roblox по умолчанию
local ROOT_SIZE = Vector3.new(2, 2, 1)

type Chaser = {
	Model: Model,
	Root: Part,
	Body: Part,
	Humanoid: Humanoid,
	Path: Path,
	Home: Vector3,
	Sleeping: boolean,
	Waypoints: { PathWaypoint }?,
	WaypointIndex: number,
	LastHit: { [Player]: number },
}

type Target = {
	Player: Player,
	Root: BasePart,
}

local chasers: { Chaser } = {}
local perf = { DamageSeconds = 0, ThinkSeconds = 0, PathComputes = 0 }

local function zoneTop(): Vector3
	local zone = MapConfig.Zone
	return zone.Center + Vector3.new(0, zone.Size.Y / 2, 0)
end

-- Прямоугольник опасной части по полу; margin — отступ от краёв
local function dangerArea(margin: number): (number, number, number, number)
	local zone = MapConfig.Zone
	local center = zone.Center
	local half = zone.Size / 2
	return center.X + zone.DangerFromX + margin, center.X + half.X - margin, center.Z - half.Z + margin, center.Z + half.Z - margin
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

local function weld(part: BasePart, root: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = root
	constraint.Part1 = part
	constraint.Parent = part
end

local function buildChaser(index: number, floorPosition: Vector3, parent: Instance): Chaser
	local cfg = EnemyConfig.Chaser
	local bodyColor = StyleConfig.Characters.Grumblob.Body
	local center = floorPosition + Vector3.new(0, cfg.BodySize / 2, 0)
	local cframe = CFrame.lookAt(center, center - Vector3.xAxis) -- смотрит на запад, к входу в зону

	local model = Instance.new("Model")
	model.Name = "Grumblob" .. index

	-- Невидимый корень, которым двигает Humanoid
	local root = MapBuilder.MakePart("HumanoidRootPart", ROOT_SIZE, cframe, bodyColor, model)
	root.Transparency = 1
	root.Anchored = false

	local body = MapBuilder.MakePart("Body", Vector3.one * cfg.BodySize, cframe, bodyColor, model)
	body.Shape = Enum.PartType.Ball
	body.Anchored = false
	body.CanCollide = false
	body.Massless = true
	body.CastShadow = false
	weld(body, root)

	-- Лицо, блик, тень и румянец — в стиле мемлингов; контур ставит клиент (тег Outlined)
	MemelingBuilders.BuildEnemy(body, cframe, cfg.BodySize)
	MemelingKit.TagOutline(model)
	-- Подписи у врага нет: его и так видно по цвету и сердитым бровям

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15 -- у R15 высоту над полом задаёт HipHeight
	humanoid.HipHeight = cfg.BodySize / 2 - ROOT_SIZE.Y / 2 -- тело касается пола
	humanoid.WalkSpeed = cfg.WalkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false) -- врага не убить
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid.Parent = model

	model.PrimaryPart = root
	model.Parent = parent
	root:SetNetworkOwner(nil) -- двигает только сервер: клиент не может утащить врага

	local chaser: Chaser = {
		Model = model,
		Root = root,
		Body = body,
		Humanoid = humanoid,
		Path = PathfindingService:CreatePath({
			AgentRadius = cfg.BodySize / 2,
			AgentHeight = cfg.BodySize,
			AgentCanJump = false,
		}),
		Home = center,
		Sleeping = true,
		Waypoints = nil,
		WaypointIndex = 0,
		LastHit = setmetatable({}, { __mode = "k" }) :: any,
	}

	-- Дошёл до точки пути — идём к следующей
	humanoid.MoveToFinished:Connect(function(reached: boolean)
		local waypoints = chaser.Waypoints
		if not reached or waypoints == nil then
			return
		end
		chaser.WaypointIndex += 1
		local nextPoint = waypoints[chaser.WaypointIndex]
		if nextPoint then
			humanoid:MoveTo(nextPoint.Position)
		else
			chaser.Waypoints = nil
		end
	end)
	return chaser
end

local function setSleeping(chaser: Chaser, sleeping: boolean)
	if chaser.Sleeping == sleeping then
		return
	end
	chaser.Sleeping = sleeping
	if sleeping then
		chaser.Waypoints = nil
		chaser.Humanoid:MoveTo(chaser.Root.Position) -- стоит на месте
	end
end

-- Куда идти: к ближайшему игроку в опасной части в радиусе погони, иначе домой
local function chooseGoal(chaser: Chaser, targets: { Target }): (Vector3?, boolean)
	local cfg = EnemyConfig.Chaser
	local position = chaser.Root.Position
	local minX, maxX, minZ, maxZ = dangerArea(0)
	local walkMinX, walkMaxX, walkMinZ, walkMaxZ = dangerArea(cfg.AreaMargin)

	local nearestAny = math.huge
	local goal: Vector3? = nil
	local goalDistance = cfg.ChaseRadius
	for _, target in ipairs(targets) do
		local p = target.Root.Position
		local distance = EnemyMath.FlatDistance(position.X, position.Z, p.X, p.Z)
		nearestAny = math.min(nearestAny, distance)
		if distance <= goalDistance and EnemyMath.IsInArea(p.X, p.Z, minX, maxX, minZ, maxZ) then
			goalDistance = distance
			local x, z = EnemyMath.ClampToArea(p.X, p.Z, walkMinX, walkMaxX, walkMinZ, walkMaxZ)
			goal = Vector3.new(x, chaser.Home.Y, z)
		end
	end

	-- Вокруг EXTRACT враги не заходят: цель внутри круга — только до его края.
	-- Если враг сам оказался внутри (его толкнули) — выходит на край
	local extract = MapConfig.Zone.ExtractionPosition
	local keepOut = cfg.ExtractionKeepOut
	local target = goal or chaser.Home
	local gx, gz = EnemyMath.PushOutOfCircle(target.X, target.Z, extract.X, extract.Z, keepOut, position.X, position.Z)
	if EnemyMath.FlatDistance(position.X, position.Z, extract.X, extract.Z) < keepOut then
		gx, gz = EnemyMath.PushOutOfCircle(position.X, position.Z, extract.X, extract.Z, keepOut, position.X - 1, position.Z)
	end
	goal = Vector3.new(gx, chaser.Home.Y, gz)

	local awake = nearestAny <= cfg.WakeRadius
	return goal, awake
end

local function think(chaser: Chaser)
	local startedAt = os.clock()
	local goal, awake = chooseGoal(chaser, getTargets())
	setSleeping(chaser, not awake)
	if not awake or goal == nil then
		perf.ThinkSeconds += os.clock() - startedAt
		return
	end

	local position = chaser.Root.Position
	if EnemyMath.FlatDistance(position.X, position.Z, goal.X, goal.Z) < 2 then
		perf.ThinkSeconds += os.clock() - startedAt
		return -- уже на месте
	end
	perf.ThinkSeconds += os.clock() - startedAt

	-- Расчёт пути ждёт ответа движка (это не время сервера, поэтому не входит в ThinkSeconds)
	local ok = pcall(function()
		chaser.Path:ComputeAsync(position, goal)
	end)
	perf.PathComputes += 1
	if chaser.Sleeping then
		return -- пока считали путь, все ушли
	end
	if ok and chaser.Path.Status == Enum.PathStatus.Success then
		local waypoints = chaser.Path:GetWaypoints()
		chaser.Waypoints = waypoints
		chaser.WaypointIndex = 2 -- первая точка — там, где враг уже стоит
		local first = waypoints[2] or waypoints[1]
		if first then
			chaser.Humanoid:MoveTo(first.Position)
		end
	else
		chaser.Waypoints = nil
		chaser.Humanoid:MoveTo(goal) -- путь не нашёлся — просто идём (стены всё равно не пустят)
	end
end

local function checkHits()
	local startedAt = os.clock()
	local cfg = EnemyConfig.Chaser
	local now = os.clock()
	local targets = getTargets()
	for _, chaser in ipairs(chasers) do
		if not chaser.Sleeping then
			local position = chaser.Root.Position
			for _, target in ipairs(targets) do
				local last = chaser.LastHit[target.Player]
				if
					(last == nil or now - last >= cfg.HitCooldownSeconds)
					and (target.Root.Position - position).Magnitude <= cfg.HitRadius
				then
					chaser.LastHit[target.Player] = now
					Damage.Apply(target.Player, cfg.Damage, "Grumblob")
				end
			end
		end
	end
	perf.DamageSeconds += os.clock() - startedAt
end

-- Страховка: враг упал с зоны — возвращаем домой
local function rescueFallen()
	local limitY = zoneTop().Y - MapConfig.Zone.FallLimitStuds
	for _, chaser in ipairs(chasers) do
		if chaser.Root.Position.Y < limitY then
			chaser.Waypoints = nil
			chaser.Model:PivotTo(CFrame.new(chaser.Home))
		end
	end
end

local function reportPerf()
	local cfg = EnemyConfig.Chaser
	local awake = 0
	for _, chaser in ipairs(chasers) do
		if not chaser.Sleeping then
			awake += 1
		end
	end
	local seconds = cfg.PerfReportSeconds
	print(
		string.format(
			"[Enemy] врагов %d (не спят %d): проверки касания %.2f мс/с, решения %.2f мс/с, путей %.1f в секунду",
			#chasers,
			awake,
			perf.DamageSeconds * 1000 / seconds,
			perf.ThinkSeconds * 1000 / seconds,
			perf.PathComputes / seconds
		)
	)
	perf.DamageSeconds, perf.ThinkSeconds, perf.PathComputes = 0, 0, 0
end

function Enemy.Start()
	local cfg = EnemyConfig.Chaser
	if cfg.Damage >= MAX_HEALTH then
		warn("[Enemy] Урон врага убивает с одного касания — уменьши EnemyConfig.Chaser.Damage")
	end

	local folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = MapBuilder.GetZoneFolder()
	local top = zoneTop()
	local count = math.min(cfg.Count, #cfg.SpawnPoints)
	for i = 1, count do
		table.insert(chasers, buildChaser(i, top + cfg.SpawnPoints[i], folder))
	end

	-- У каждого врага свой цикл решений, со случайным сдвигом: пересчёты путей не совпадают по времени
	for _, chaser in ipairs(chasers) do
		task.spawn(function()
			task.wait(math.random() * cfg.ThinkSeconds)
			while true do
				think(chaser)
				task.wait(cfg.ThinkSeconds)
			end
		end)
	end

	task.spawn(function()
		while true do
			task.wait(cfg.DamageTickSeconds)
			checkHits()
		end
	end)

	task.spawn(function()
		local sinceReport = 0
		while true do
			task.wait(1)
			rescueFallen()
			sinceReport += 1
			if sinceReport >= cfg.PerfReportSeconds then
				sinceReport = 0
				reportPerf()
			end
		end
	end)

	print(string.format("[Enemy] В опасной части врагов: %d", count))
end

return Enemy
