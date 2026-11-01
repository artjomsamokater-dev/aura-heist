--!strict
-- HitFxController: предупреждения и отдача от ударов на этом клиенте (задача 6.1).
--   • Замах Grumblob: у модели врага атрибут WindupUntil (время сервера) — вокруг врага растёт красный
--     полупрозрачный шар («раздувается и краснеет»). Ударит ли — решает сервер.
--   • Колесо сыра сбило игрока: сервер присылает направление (Remotes.Knockback) — персонаж отлетает.
--     Персонажем управляет его клиент, поэтому толкаем его здесь; урон уже нанёс сервер.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local HitFxController = {}

local player = Players.LocalPlayer
local style = StyleConfig.EnemyWindup

local swells: { [Model]: Part } = {}

local function makeSwell(): Part
	local ball = Instance.new("Part")
	ball.Name = "WindupSwell"
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanTouch = false
	ball.CanQuery = false
	ball.CastShadow = false
	ball.Material = StyleConfig.GlowMaterial
	ball.Color = style.Color
	ball.Transparency = style.Transparency
	ball.Parent = Workspace
	return ball
end

local function updateWindups()
	local now = Workspace:GetServerTimeNow()
	local cfg = EnemyConfig.Chaser
	local active: { [Model]: boolean } = {}
	for _, target in ipairs(CollectionService:GetTagged(StyleConfig.Outline.Tag)) do
		local untilTime = tonumber(target:GetAttribute("WindupUntil"))
		if target:IsA("Model") and untilTime and untilTime > now then
			local root = target.PrimaryPart
			if root then
				active[target] = true
				local swell = swells[target] or makeSwell()
				swells[target] = swell
				local progress = math.clamp(1 - (untilTime - now) / cfg.WindupSeconds, 0, 1)
				swell.Size = Vector3.one * cfg.BodySize * (1 + style.Grow * progress)
				swell.CFrame = root.CFrame
			end
		end
	end
	for model, swell in pairs(swells) do
		if not active[model] then
			swell:Destroy()
			swells[model] = nil
		end
	end
end

local function onKnockback(direction: unknown)
	if typeof(direction) ~= "Vector3" then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") or humanoid.Health <= 0 then
		return
	end
	local cfg = EventConfig.GiantObject
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.01 then
		return
	end
	-- Пока летит, Humanoid не гасит скорость шагом: PlatformStand на KnockbackSeconds
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = flat.Unit * cfg.KnockbackSpeed + Vector3.new(0, cfg.KnockbackUp, 0)
	task.delay(cfg.KnockbackSeconds, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
		end
	end)
end

function HitFxController.Start()
	RunService.RenderStepped:Connect(updateWindups)
	local event = ReplicatedStorage:WaitForChild(Remotes.Folder):WaitForChild(Remotes.Knockback)
	if event:IsA("RemoteEvent") then
		event.OnClientEvent:Connect(onKnockback)
	end
end

return HitFxController
