--!strict
-- ExtractFxController: картинка и звук эвакуации на этом клиенте (задача 6.1).
-- Сервер выставляет атрибуты ExtractHoldStart (время сервера) и ExtractHoldSeconds, пока игрок стоит
-- на точке эвакуации (сервис Extraction). По ним:
--   • вокруг ног загорается круг из сегментов — сколько осталось держать;
--   • писк повторяется всё выше и громче;
--   • в конце — вспышка экрана и конфетти.
-- Засчитывает эвакуацию только сервер: это лишь подсказка, как долго ещё стоять.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local ExtractTarget = require(script.Parent.Parent.Util.ExtractTarget)

local ExtractFxController = {}

local player = Players.LocalPlayer
local style = StyleConfig.ExtractFx

local function getRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function makeSound(id: string): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Parent = SoundService
	return sound
end

-- Круг из сегментов: деталь только на этом клиенте, не сталкивается и не ловит лучи
local function buildRing(): (Model, { BasePart })
	local model = Instance.new("Model")
	model.Name = "ExtractRing"
	local segments: { BasePart } = {}
	for i = 1, style.RingSegments do
		local part = Instance.new("Part")
		part.Name = "Segment" .. i
		part.Size = style.SegmentSize
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = StyleConfig.GlowMaterial
		part.Parent = model
		segments[i] = part
	end
	return model, segments
end

local function flash(playerGui: Instance)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ExtractFlash"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = playerGui
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = style.FlashColor
	frame.BackgroundTransparency = style.FlashTransparency
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local tween = TweenService:Create(frame, TweenInfo.new(style.FlashSeconds), { BackgroundTransparency = 1 })
	tween.Completed:Connect(function()
		gui:Destroy()
	end)
	tween:Play()
end

local function confetti(root: BasePart)
	local cfg = style.Confetti
	local attachment = Instance.new("Attachment")
	attachment.Name = "Confetti"
	attachment.Parent = root
	local keypoints = {}
	for i, color in ipairs(cfg.Colors) do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / math.max(1, #cfg.Colors - 1), color))
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = StyleConfig.ParticleTexture
	emitter.Color = ColorSequence.new(keypoints)
	emitter.Rate = 0
	emitter.Speed = cfg.Speed
	emitter.Lifetime = cfg.Lifetime
	emitter.Size = NumberSequence.new(cfg.Size)
	emitter.SpreadAngle = Vector2.new(cfg.SpreadAngle, cfg.SpreadAngle)
	emitter.Acceleration = Vector3.new(0, -cfg.Gravity, 0)
	emitter.RotSpeed = NumberRange.new(-360, 360)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = attachment
	emitter:Emit(cfg.Count)
	task.delay(cfg.Lifetime.Max + 0.5, function()
		attachment:Destroy()
	end)
end

function ExtractFxController.Start()
	local playerGui = player:WaitForChild("PlayerGui")
	local ring, segments = buildRing()
	local charge = makeSound(style.ChargeSound.SoundId)
	charge.Looped = true
	local done = makeSound(style.DoneSound.SoundId)
	done.PlaybackSpeed = style.DoneSound.Speed
	done.Volume = style.DoneSound.Volume

	local finished = false -- вспышка и конфетти — один раз на одно удержание
	RunService.RenderStepped:Connect(function()
		local startedAt = tonumber(player:GetAttribute("ExtractHoldStart"))
		local seconds = tonumber(player:GetAttribute("ExtractHoldSeconds"))
		local root = getRoot()
		if startedAt == nil or seconds == nil or seconds <= 0 or root == nil then
			ring.Parent = nil
			if charge.IsPlaying then
				charge:Stop()
			end
			finished = false
			return
		end

		local progress = math.clamp((Workspace:GetServerTimeNow() - startedAt) / seconds, 0, 1)
		local color = ExtractTarget.Get(root.Position).Color
		local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
		local hip = if humanoid then humanoid.HipHeight else 2
		-- Чуть выше пола под персонажем, над площадкой эвакуации
		local feet = root.Position - Vector3.new(0, root.Size.Y / 2 + hip - style.SegmentSize.Y, 0)
		local lit = math.floor(progress * #segments + 0.001)
		for i, segment in ipairs(segments) do
			local angle = (i - 1) * 2 * math.pi / #segments
			segment.CFrame = CFrame.new(feet) * CFrame.Angles(0, -angle, 0) * CFrame.new(0, 0, -style.RingRadius)
			segment.Color = color
			segment.Transparency = if i <= lit then 0 else style.EmptyTransparency
		end
		ring.Parent = Workspace

		local sound = style.ChargeSound
		charge.PlaybackSpeed = sound.FromSpeed + (sound.ToSpeed - sound.FromSpeed) * progress
		charge.Volume = sound.FromVolume + (sound.ToVolume - sound.FromVolume) * progress
		if not charge.IsPlaying then
			charge:Play()
		end

		if progress >= 1 and not finished then
			finished = true
			charge:Stop()
			done:Play()
			flash(playerGui)
			confetti(root)
		end
	end)
end

return ExtractFxController
