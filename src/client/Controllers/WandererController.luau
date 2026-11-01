--!strict
-- WandererController: декоративные мемлинги бродят по площади хаба (задача 6.2). Только этот клиент:
-- сервер поставил их «дома» (Workspace.Hub.Wanderers, атрибуты HomeX / HomeZ / WanderRadius) и больше
-- их не трогает, поэтому движение не нагружает ни сервер, ни сеть.
-- Каждый шагает к случайной точке около дома, останавливается, иногда подпрыгивает или машет (качается).
-- Числа — StyleConfig.Hub.Wanderers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)

local WandererController = {}

local style = StyleConfig.Hub.Wanderers
local random = Random.new()

type Walker = {
	Core: BasePart,
	Home: Vector3,
	Radius: number,
	BaseY: number,
	Position: Vector3, -- по полу (Y = BaseY)
	Facing: Vector3,
	Target: Vector3?,
	Mode: string, -- "walk" | "pause" | "hop" | "wave"
	Timer: number,
}

local walkers: { Walker } = {}

local function pickTarget(walker: Walker): Vector3
	local angle = random:NextNumber(0, 2 * math.pi)
	local distance = random:NextNumber(0.3, 1) * walker.Radius
	return walker.Home + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

local function addWalker(core: Instance)
	if not core:IsA("BasePart") then
		return
	end
	local homeX, homeZ = tonumber(core:GetAttribute("HomeX")), tonumber(core:GetAttribute("HomeZ"))
	if homeX == nil or homeZ == nil then
		return
	end
	local baseY = core.Position.Y
	local position = Vector3.new(core.Position.X, baseY, core.Position.Z)
	table.insert(walkers, {
		Core = core,
		Home = Vector3.new(homeX, baseY, homeZ),
		Radius = tonumber(core:GetAttribute("WanderRadius")) or 4,
		BaseY = baseY,
		Position = position,
		Facing = -Vector3.zAxis,
		Target = nil,
		Mode = "pause",
		Timer = random:NextNumber(0, style.PauseSeconds.Max), -- начинают не одновременно
	})
end

-- После шага: постоять, подпрыгнуть или помахать
local function afterStep(walker: Walker)
	local roll = random:NextNumber()
	if roll < style.HopChance then
		walker.Mode, walker.Timer = "hop", style.HopSeconds * style.Hops
	elseif roll < style.HopChance + style.WaveChance then
		walker.Mode, walker.Timer = "wave", style.WaveSeconds
	else
		walker.Mode, walker.Timer = "pause", random:NextNumber(style.PauseSeconds.Min, style.PauseSeconds.Max)
	end
end

local function step(walker: Walker, dt: number)
	local lift, sway = 0, 0
	if walker.Mode == "walk" then
		local target = walker.Target or pickTarget(walker)
		walker.Target = target
		local offset = target - walker.Position
		local distance = offset.Magnitude
		if distance < 0.2 then
			walker.Target = nil
			afterStep(walker)
		else
			walker.Facing = offset.Unit
			walker.Position += offset.Unit * math.min(distance, style.Speed * dt)
			lift = math.abs(math.sin(os.clock() * 10)) * 0.25 -- лёгкое подпрыгивание на ходу
		end
	else
		walker.Timer -= dt
		if walker.Mode == "hop" then
			local t = (walker.Timer % style.HopSeconds) / style.HopSeconds
			lift = math.sin(t * math.pi) * style.HopHeight
		elseif walker.Mode == "wave" then
			sway = math.sin(walker.Timer * style.WaveHz * 2 * math.pi) * math.rad(style.WaveDegrees)
		end
		if walker.Timer <= 0 then
			walker.Mode = "walk"
		end
	end

	local position = walker.Position + Vector3.new(0, lift, 0)
	walker.Core:PivotTo(CFrame.lookAt(position, position + walker.Facing) * CFrame.Angles(0, 0, sway))
end

function WandererController.Start()
	local hub = Workspace:WaitForChild("Hub")
	local folder = hub:WaitForChild("Wanderers")
	for _, core in ipairs(folder:GetChildren()) do
		addWalker(core)
	end
	folder.ChildAdded:Connect(addWalker)

	RunService.RenderStepped:Connect(function(dt: number)
		for i = #walkers, 1, -1 do
			local walker = walkers[i]
			if walker.Core.Parent == nil then
				table.remove(walkers, i)
			else
				step(walker, math.min(dt, 0.1))
			end
		end
	end)
end

return WandererController
