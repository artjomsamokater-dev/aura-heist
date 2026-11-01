--!strict
-- Enemy: враги Grumblob в опасной части зоны (числа — EnemyConfig.Chaser,
-- вид — server/Visual/MemelingBuilders.BuildEnemy, цвета — StyleConfig.Characters.Grumblob).
--
-- • Ходят только внутри опасной части: цель за её краем — враг останавливается у границы (EnemyMath).
--   В круг ExtractionKeepOut вокруг EXTRACT тоже не заходят: эвакуацию караулить нельзя.
-- • Humanoid + PathfindingService: сквозь стены не проходят, путь пересчитывается раз в ThinkSeconds.
-- • Спят, если ни одного игрока в вылазке нет ближе WakeRadius: тогда ничего не считают.
-- • Без цели — патруль вокруг дома (PatrolRadius, медленнее, с паузами), а не стоят на месте (задача 7.1).
-- • Цель — игрок ближе ChaseRadius или (охрана) подобравший мемлинга ближе AggroRadius: «!» и звук.
--   Гонятся, пока игрок не дальше LeashRadius, в опасной части и не у EXTRACT (EnemyMath.ChaseBlock).
-- • Раз в StatusLogSeconds — в Output состояние каждого (спит / патруль / гонится / путь не найден) и причина.
-- • Урон при касании: сервер раз в DamageTickSeconds меряет расстояние (без Touched), с перезарядкой.
--   Перед ударом — замах WindupSeconds (враг раздувается и краснеет, рисует клиент): успел отбежать — промах.
-- • Раз в PerfReportSeconds пишут в Output, сколько времени сервера на них уходит.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
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
	ZoneId: string, -- в какой зоне живёт (Id из ZoneConfig.ZoneOrder)
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
	Windup: { Player: Player, StrikeAt: number }?, -- замах: по кому и когда ударит (os.clock)
	Target: Player?, -- за кем гонится (держится, пока погоня возможна — EnemyMath.ChaseBlock)
	PatrolPoint: Vector3?, -- куда идёт в патруле
	PatrolUntil: number, -- не дошёл к этому моменту (os.clock) — новая точка
	PauseUntil: number, -- пауза между точками патруля
	Thinking: boolean,
	Status: string, -- для Output: спит / патруль / гонится / путь не найден
	Reason: string,
	AlertSound: Sound,
}

type Target = {
	Player: Player,
	Root: BasePart,
}

local chasers: { Chaser } = {}
local random = Random.new()
local perf = { DamageSeconds = 0, ThinkSeconds = 0, PathComputes = 0 }

local function zoneTop(zoneId: string): Vector3
	local zone = MapConfig.Zones[zoneId]
	return zone.Center + Vector3.new(0, zone.Size.Y / 2, 0)
end

-- Прямоугольник опасной части зоны по полу; margin — отступ от краёв
local function dangerArea(zoneId: string, margin: number): (number, number, number, number)
	local zone = MapConfig.Zones[zoneId]
	local center = zone.Center
	local half = zone.Size / 2
	return center.X + zone.DangerFromX + margin, center.X + half.X - margin, center.Z - half.Z + margin, center.Z + half.Z - margin
end

-- Игроки в вылазке в этой зоне с живым персонажем
local function getTargets(zoneId: string): { Target }
	local targets: { Target } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if Raid.GetState(player) == Raid.State.InRaid and Raid.GetZone(player) == zoneId then
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

local function buildChaser(zoneId: string, index: number, floorPosition: Vector3, parent: Instance): Chaser
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

	local alertStyle = StyleConfig.EnemyAlert
	local alertSound = Instance.new("Sound")
	alertSound.Name = "AlertSound"
	alertSound.SoundId = alertStyle.SoundId
	alertSound.Volume = alertStyle.Volume
	alertSound.PlaybackSpeed = alertStyle.PlaybackSpeed
	alertSound.RollOffMaxDistance = alertStyle.MaxDistance
	alertSound.Parent = body

	local chaser: Chaser = {
		ZoneId = zoneId,
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
		Windup = nil,
		Target = nil,
		PatrolPoint = nil,
		PatrolUntil = 0,
		PauseUntil = 0,
		Thinking = false,
		Status = "спит",
		Reason = "только появился",
		AlertSound = alertSound,
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

local function setStatus(chaser: Chaser, status: string, reason: string)
	chaser.Status = status
	chaser.Reason = reason
end

local function flat(a: Vector3, b: Vector3): number
	return EnemyMath.FlatDistance(a.X, a.Z, b.X, b.Z)
end

local function inDanger(zoneId: string, p: Vector3): boolean
	local minX, maxX, minZ, maxZ = dangerArea(zoneId, 0)
	return EnemyMath.IsInArea(p.X, p.Z, minX, maxX, minZ, maxZ)
end

-- У EXTRACT своей зоны (в круге ExtractionKeepOut) враги не гонятся и туда не заходят
local function atExtract(zoneId: string, p: Vector3): boolean
	return flat(p, MapConfig.Zones[zoneId].ExtractionPosition) < EnemyConfig.Chaser.ExtractionKeepOut
end

local DROP_TEXT: { [string]: string } = {
	leash = "игрок дальше LeashRadius",
	safe = "игрок в безопасной части",
	extract = "игрок у EXTRACT",
}

-- Можно ли гнаться за этим игроком (nil) или почему нельзя (ключ EnemyMath.DropReason)
local function chaseBlock(chaser: Chaser, target: Target): string?
	local p = target.Root.Position
	local zoneId = chaser.ZoneId
	return EnemyMath.ChaseBlock(flat(chaser.Root.Position, p), EnemyConfig.Chaser.LeashRadius, inDanger(zoneId, p), atExtract(zoneId, p))
end

-- Куда идти на самом деле: внутри опасной части (с отступом), не в круге у EXTRACT.
-- Если враг сам оказался в круге (его толкнули) — выходит на край
local function walkGoal(chaser: Chaser, x: number, z: number): Vector3
	local cfg = EnemyConfig.Chaser
	local position = chaser.Root.Position
	local minX, maxX, minZ, maxZ = dangerArea(chaser.ZoneId, cfg.AreaMargin)
	local cx, cz = EnemyMath.ClampToArea(x, z, minX, maxX, minZ, maxZ)
	local extract = MapConfig.Zones[chaser.ZoneId].ExtractionPosition
	local gx, gz = EnemyMath.PushOutOfCircle(cx, cz, extract.X, extract.Z, cfg.ExtractionKeepOut, position.X, position.Z)
	if atExtract(chaser.ZoneId, position) then
		gx, gz = EnemyMath.PushOutOfCircle(position.X, position.Z, extract.X, extract.Z, cfg.ExtractionKeepOut, position.X - 1, position.Z)
	end
	return Vector3.new(gx, chaser.Home.Y, gz)
end

-- Идти к goal: путь через PathfindingService (сквозь стены не ходят). Не нашёлся — идёт напрямую.
-- Вернёт true, если путь найден, иначе false и причину для Output
local function moveAlong(chaser: Chaser, goal: Vector3): (boolean, string)
	local position = chaser.Root.Position
	if flat(position, goal) < 2 then
		return true, "уже на месте"
	end
	-- Расчёт пути ждёт ответа движка (это не время сервера, поэтому не входит в ThinkSeconds)
	local ok, err = pcall(function()
		chaser.Path:ComputeAsync(position, goal)
	end)
	perf.PathComputes += 1
	if chaser.Sleeping then
		return true, "уснул, пока считал путь"
	end
	if ok and chaser.Path.Status == Enum.PathStatus.Success then
		local waypoints = chaser.Path:GetWaypoints()
		chaser.Waypoints = waypoints
		chaser.WaypointIndex = 2 -- первая точка — там, где враг уже стоит
		local first = waypoints[2] or waypoints[1]
		if first then
			chaser.Humanoid:MoveTo(first.Position)
		end
		return true, ""
	end
	chaser.Waypoints = nil
	chaser.Humanoid:MoveTo(goal) -- путь не нашёлся — просто идём (стены всё равно не пустят)
	return false, if ok then tostring(chaser.Path.Status) else tostring(err)
end

-- Решение врага: спит → (цель: текущая, пока погоня возможна, или новая ближе ChaseRadius) → погоня,
-- иначе патруль вокруг дома. Состояние и причина — в chaser.Status / Reason (Output раз в StatusLogSeconds)
local function decide(chaser: Chaser)
	local cfg = EnemyConfig.Chaser
	local startedAt = os.clock()
	local targets = getTargets(chaser.ZoneId)
	local position = chaser.Root.Position

	local nearest = math.huge
	for _, target in ipairs(targets) do
		nearest = math.min(nearest, flat(position, target.Root.Position))
	end
	if nearest > cfg.WakeRadius then
		setSleeping(chaser, true)
		chaser.Target = nil
		chaser.PatrolPoint = nil
		setStatus(
			chaser,
			"спит",
			if #targets == 0
				then "в зоне нет игроков"
				else string.format("ближайший игрок в %d студах (WakeRadius %d)", math.floor(nearest), cfg.WakeRadius)
		)
		perf.ThinkSeconds += os.clock() - startedAt
		return
	end
	setSleeping(chaser, false)

	-- Текущая цель: гонимся, пока можно; иначе бросаем и пишем почему
	local target: Target? = nil
	if chaser.Target then
		for _, t in ipairs(targets) do
			if t.Player == chaser.Target then
				target = t
			end
		end
		local dropped = if target == nil then "игрок погиб или вышел из зоны" else nil
		if target then
			local block = chaseBlock(chaser, target)
			if block then
				dropped = DROP_TEXT[block] or block
				target = nil
			end
		end
		if dropped then
			print(string.format("[Enemy] %s бросил погоню за %s: %s", chaser.Model.Name, chaser.Target.Name, dropped))
			chaser.Target = nil
		end
	end
	-- Новая цель: ближайший игрок ближе ChaseRadius, за которым можно гнаться
	if target == nil then
		local best = cfg.ChaseRadius
		for _, t in ipairs(targets) do
			local distance = flat(position, t.Root.Position)
			if distance <= best and chaseBlock(chaser, t) == nil then
				target, best = t, distance
			end
		end
		if target then
			chaser.Target = target.Player
		end
	end
	perf.ThinkSeconds += os.clock() - startedAt

	if target then
		chaser.Humanoid.WalkSpeed = cfg.WalkSpeed
		chaser.PatrolPoint = nil
		local p = target.Root.Position
		local found, why = moveAlong(chaser, walkGoal(chaser, p.X, p.Z))
		local reason = string.format("за %s, %d студов", target.Player.Name, math.floor(flat(position, p)))
		if found then
			setStatus(chaser, "гонится", reason)
		else
			setStatus(chaser, "путь не найден", reason .. " — иду напрямую (" .. why .. ")")
		end
		return
	end

	-- Патруль: к случайной точке около дома, медленно; дошёл или застрял — пауза и новая точка
	chaser.Humanoid.WalkSpeed = cfg.PatrolWalkSpeed
	local now = os.clock()
	local point = chaser.PatrolPoint
	if point and (flat(position, point) < 2 or now > chaser.PatrolUntil) then
		chaser.PatrolPoint = nil
		chaser.PauseUntil = now + random:NextNumber(cfg.PatrolPauseSeconds.Min, cfg.PatrolPauseSeconds.Max)
		point = nil
	end
	if point then
		setStatus(chaser, "патруль", string.format("иду к точке, осталось %d студов", math.floor(flat(position, point))))
		return
	end
	if now < chaser.PauseUntil then
		setStatus(chaser, "патруль", "пауза между точками")
		return
	end
	local x, z = EnemyMath.PatrolPoint(chaser.Home.X, chaser.Home.Z, cfg.PatrolRadius, random:NextNumber(0, 2 * math.pi), random:NextNumber(0.3, 1))
	local goal = walkGoal(chaser, x, z)
	chaser.PatrolPoint = goal
	chaser.PatrolUntil = now + cfg.PatrolGiveUpSeconds
	local found, why = moveAlong(chaser, goal)
	if found then
		setStatus(chaser, "патруль", "новая точка")
	else
		setStatus(chaser, "путь не найден", "патруль — иду напрямую (" .. why .. ")")
	end
end

-- Один расчёт за раз: решение может прийти и из цикла, и сразу при агро (Path нельзя считать дважды одновременно)
local function think(chaser: Chaser)
	if chaser.Thinking then
		return
	end
	chaser.Thinking = true
	local ok, err = pcall(decide :: any, chaser)
	chaser.Thinking = false
	if not ok then
		warn(string.format("[Enemy] %s: ошибка в решении — %s", chaser.Model.Name, tostring(err)))
	end
end

-- «!» над врагом на AlertSeconds и звук: враг заметил игрока с добычей
local function alert(chaser: Chaser)
	local cfg = EnemyConfig.Chaser
	local style = StyleConfig.EnemyAlert
	local gui = Instance.new("BillboardGui")
	gui.Name = "Alert"
	gui.Size = UDim2.fromScale(style.SizeStuds, style.SizeStuds)
	gui.StudsOffsetWorldSpace = Vector3.new(0, cfg.BodySize / 2 + style.SizeStuds / 2 + 0.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = style.MaxDistance
	gui.Parent = chaser.Body
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Font = StyleConfig.Fonts.Label
	label.Text = TextConfig.EnemyAlert
	label.TextColor3 = style.Color
	label.TextStrokeColor3 = style.Stroke
	label.TextStrokeTransparency = 0
	label.Parent = gui
	Debris:AddItem(gui, cfg.AlertSeconds)
	chaser.AlertSound:Play()
end

-- Охрана: игрок подобрал мемлинга — все враги ближе AggroRadius сразу просыпаются и гонятся за ним
local function onPickup(player: Player, position: Vector3)
	local cfg = EnemyConfig.Chaser
	local zoneId = Raid.GetZone(player)
	for _, chaser in ipairs(chasers) do
		local distance = flat(chaser.Root.Position, position)
		if
			chaser.ZoneId == zoneId
			and chaser.Target ~= player
			and EnemyMath.ShouldAggro(distance, cfg.AggroRadius, inDanger(chaser.ZoneId, position), atExtract(chaser.ZoneId, position))
		then
			chaser.Target = player
			chaser.PatrolPoint = nil
			setSleeping(chaser, false)
			alert(chaser)
			print(string.format("[Enemy] %s: %s подобрал мемлинга в %d студах — погоня", chaser.Model.Name, player.Name, math.floor(distance)))
			task.spawn(think, chaser)
		end
	end
end

local function logStatus()
	for _, chaser in ipairs(chasers) do
		print(string.format("[Enemy] %s: %s — %s", chaser.Model.Name, chaser.Status, chaser.Reason))
	end
end

-- Замах: атрибут WindupUntil (время сервера) на модели — клиент рисует раздувание и покраснение
local function setWindup(chaser: Chaser, windup: { Player: Player, StrikeAt: number }?)
	chaser.Windup = windup
	chaser.Model:SetAttribute("WindupUntil", if windup then Workspace:GetServerTimeNow() + EnemyConfig.Chaser.WindupSeconds else nil)
end

-- Удар в два шага: игрок подошёл ближе WindupRadius → замах WindupSeconds → удар, если он всё ещё в HitRadius
local function checkHits()
	local startedAt = os.clock()
	local cfg = EnemyConfig.Chaser
	local now = os.clock()
	local targetsByZone: { [string]: { Target } } = {}
	for _, zoneId in ipairs(ZoneConfig.ZoneOrder) do
		targetsByZone[zoneId] = getTargets(zoneId)
	end
	for _, chaser in ipairs(chasers) do
		local targets: { Target } = targetsByZone[chaser.ZoneId] or {}
		local position = chaser.Root.Position
		local windup = chaser.Windup
		if chaser.Sleeping then
			if windup then
				setWindup(chaser, nil)
			end
		elseif windup then
			if now >= windup.StrikeAt then
				setWindup(chaser, nil)
				chaser.LastHit[windup.Player] = now -- и при промахе: следующий замах не сразу
				for _, target in ipairs(targets) do
					if target.Player == windup.Player and (target.Root.Position - position).Magnitude <= cfg.HitRadius then
						Damage.Apply(target.Player, cfg.Damage, "Grumblob")
					end
				end
			end
		else
			for _, target in ipairs(targets) do
				local last = chaser.LastHit[target.Player]
				if
					(last == nil or now - last >= cfg.HitCooldownSeconds)
					and (target.Root.Position - position).Magnitude <= cfg.WindupRadius
				then
					setWindup(chaser, { Player = target.Player, StrikeAt = now + cfg.WindupSeconds })
					break
				end
			end
		end
	end
	perf.DamageSeconds += os.clock() - startedAt
end

-- Страховка: враг упал с зоны — возвращаем домой
local function rescueFallen()
	for _, chaser in ipairs(chasers) do
		local limitY = zoneTop(chaser.ZoneId).Y - MapConfig.Zones[chaser.ZoneId].FallLimitStuds
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

	-- Враги каждой зоны: сколько и где дома — EnemyConfig.Zones[Id]
	local total = 0
	for _, zoneId in ipairs(ZoneConfig.ZoneOrder) do
		local spec = EnemyConfig.Zones[zoneId]
		if spec then
			local folder = Instance.new("Folder")
			folder.Name = "Enemies"
			folder.Parent = MapBuilder.GetZoneFolder(zoneId)
			local top = zoneTop(zoneId)
			local count = math.min(spec.Count, #spec.SpawnPoints)
			for i = 1, count do
				total += 1
				table.insert(chasers, buildChaser(zoneId, total, top + spec.SpawnPoints[i], folder))
			end
		end
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
		local sinceReport, sinceStatus = 0, 0
		while true do
			task.wait(1)
			rescueFallen()
			sinceReport += 1
			sinceStatus += 1
			if sinceReport >= cfg.PerfReportSeconds then
				sinceReport = 0
				reportPerf()
			end
			if sinceStatus >= cfg.StatusLogSeconds then
				sinceStatus = 0
				logStatus()
			end
		end
	end)

	Raid.OnPickup(onPickup)

	print(string.format("[Enemy] Врагов в опасных частях всех зон: %d", total))
end

return Enemy
