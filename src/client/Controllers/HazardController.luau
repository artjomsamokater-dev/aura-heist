--!strict
-- HazardController: картинка ловушек на клиенте — только вид, урон считает сервер.
-- Планка и плиты считаются по тем же формулам (HazardMath) и тому же времени сервера
-- (GetServerTimeNow), что и на сервере, поэтому то, что видит игрок, совпадает с тем, что бьёт.
--   • Лазер плавно ездит по дорожке и мигает у концов перед следующим проездом.
--   • Плита за WarnSeconds до удара горит оранжевым, в момент удара вспыхивает и подпрыгивает.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HazardConfig = require(ReplicatedStorage.Shared.Config.HazardConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local HazardMath = require(ReplicatedStorage.Shared.Util.HazardMath)

local HazardController = {}

type Laser = {
	Part: BasePart,
	Start: Vector3,
	End: Vector3,
	SweepSeconds: number,
}

type Plate = {
	Part: BasePart,
	BaseCFrame: CFrame,
	OffsetSeconds: number,
	LastIndex: number,
	PopUntil: number,
	Look: string, -- что показано сейчас: "idle" / "warn" / "strike"
}

local lasers: { [BasePart]: Laser } = {}
local plates: { [BasePart]: Plate } = {}

local function addLaser(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local startPosition = instance:GetAttribute("TrackStart")
	local endPosition = instance:GetAttribute("TrackEnd")
	local sweepSeconds = tonumber(instance:GetAttribute("SweepSeconds"))
	if typeof(startPosition) == "Vector3" and typeof(endPosition) == "Vector3" and sweepSeconds then
		lasers[instance] = { Part = instance, Start = startPosition, End = endPosition, SweepSeconds = sweepSeconds }
	end
end

local function addPlate(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local slam = HazardConfig.Slam
	local offset = tonumber(instance:GetAttribute("OffsetSeconds")) or 0
	local index = HazardMath.Slam(Workspace:GetServerTimeNow(), slam.CycleSeconds, slam.WarnSeconds, offset)
	plates[instance] = {
		Part = instance,
		BaseCFrame = instance.CFrame,
		OffsetSeconds = offset,
		LastIndex = index,
		PopUntil = 0,
		Look = "idle",
	}
end

local function watchTag(tag: string, onAdded: (Instance) -> (), onRemoved: (Instance) -> ())
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		onAdded(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(onAdded)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(onRemoved)
end

local function setPlateLook(plate: Plate, look: string)
	if plate.Look == look then
		return
	end
	plate.Look = look
	local style = StyleConfig.Hazards
	if look == "strike" then
		plate.Part.Color = style.SlamStrike
		plate.Part.Material = StyleConfig.GlowMaterial
		plate.Part.CFrame = plate.BaseCFrame + Vector3.new(0, style.SlamPopHeight, 0)
	elseif look == "warn" then
		plate.Part.Color = style.SlamWarn
		plate.Part.Material = StyleConfig.GlowMaterial
		plate.Part.CFrame = plate.BaseCFrame
	else
		plate.Part.Color = style.SlamIdle
		plate.Part.Material = StyleConfig.Material
		plate.Part.CFrame = plate.BaseCFrame
	end
end

local function render()
	local now = Workspace:GetServerTimeNow()
	local laserCfg = HazardConfig.Laser
	local style = StyleConfig.Hazards

	for _, laser in lasers do
		local u, blinking = HazardMath.Laser(now, laser.SweepSeconds, laserCfg.DwellSeconds)
		laser.Part.CFrame = CFrame.new(laser.Start:Lerp(laser.End, u))
		local blinkOff = blinking and math.floor(now * style.LaserBlinkHz * 2) % 2 == 0
		laser.Part.Transparency = if blinkOff then style.LaserBlinkTransparency else 0
	end

	local slam = HazardConfig.Slam
	for _, plate in plates do
		local index, warning = HazardMath.Slam(now, slam.CycleSeconds, slam.WarnSeconds, plate.OffsetSeconds)
		if index > plate.LastIndex then
			plate.LastIndex = index
			plate.PopUntil = now + style.SlamPopSeconds
		end
		if now < plate.PopUntil then
			setPlateLook(plate, "strike")
		elseif warning then
			setPlateLook(plate, "warn")
		else
			setPlateLook(plate, "idle")
		end
	end
end

function HazardController.Start()
	watchTag(HazardConfig.Tags.Laser, addLaser, function(instance)
		if instance:IsA("BasePart") then
			lasers[instance] = nil
		end
	end)
	watchTag(HazardConfig.Tags.Slam, addPlate, function(instance)
		if instance:IsA("BasePart") then
			plates[instance] = nil
		end
	end)
	RunService.RenderStepped:Connect(render)
end

return HazardController
