--!strict
-- ExtractFxController: картинка и звук эвакуации на этом клиенте (задача 6.1).
-- Сервер выставляет атрибуты ExtractHoldStart (время сервера) и ExtractHoldSeconds, пока игрок стоит
-- на точке эвакуации (сервис Extraction). По ним:
--   • вокруг ног загорается круг из сегментов — сколько осталось держать;
--   • вверху по центру крупная полоска «EXTRACTING... 2.1s» (задача 7.8), поверх остального HUD;
--   • писк повторяется всё выше и громче;
--   • в конце — вспышка экрана и конфетти.
-- Засчитывает эвакуацию только сервер: это лишь подсказка, как долго ещё стоять.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
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

-- Крупная полоска прогресса вверху по центру: под таймером рестока и плашкой BOUNTY.
-- Вернёт (ScreenGui, заливка, надпись)
local function buildBar(playerGui: Instance): (ScreenGui, Frame, TextLabel)
	local hud = StyleConfig.Hud
	local gui = Instance.new("ScreenGui")
	gui.Name = "ExtractBar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5 -- поверх HUD
	gui.Enabled = false
	gui.Parent = playerGui
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, GuiService:GetGuiInset().Y + style.BarTop)
	holder.Size = UDim2.new(0.8, 0, 0, style.BarHeight)
	holder.BackgroundColor3 = style.BarBack
	holder.BorderSizePixel = 0
	holder.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(style.BarMaxWidth, style.BarHeight)
	limit.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = holder
	local stroke = Instance.new("UIStroke")
	stroke.Color = hud.Stroke
	stroke.Thickness = hud.StrokeThickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = holder
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = holder
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = StyleConfig.Fonts.Hud
	label.TextSize = style.BarTextSize
	label.TextColor3 = hud.TextDark
	label.ZIndex = 2
	label.Parent = holder
	return gui, fill, label
end

function ExtractFxController.Start()
	local playerGui = player:WaitForChild("PlayerGui")
	local ring, segments = buildRing()
	local barGui, barFill, barLabel = buildBar(playerGui)
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
			barGui.Enabled = false
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

		-- Полоска вверху: заполняется цветом точки эвакуации, внутри — сколько секунд осталось
		barGui.Enabled = true
		barFill.Size = UDim2.fromScale(progress, 1)
		barFill.BackgroundColor3 = color
		local left = math.max(0, seconds * (1 - progress))
		barLabel.Text = if progress >= 1 then TextConfig.ExtractingDone else string.format(TextConfig.Extracting, left)

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
