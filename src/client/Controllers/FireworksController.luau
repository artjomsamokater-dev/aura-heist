--!strict
-- FireworksController: салют над студиями, где стоит декор «Fireworks» из магазина (атрибут Fireworks
-- на участке ставит сервер). Раз в CosmeticsLayout.FireworksSeconds — несколько вспышек частиц над участком.
-- Только картинка на этом клиенте: сервер салют не считает.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)

local FireworksController = {}

local random = Random.new()

local function burst(position: Vector3, colors: { Color3 })
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = Workspace
	local color = colors[random:NextInteger(1, #colors)]
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = StyleConfig.ParticleTexture
	emitter.Color = ColorSequence.new(color)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(22, 32)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(1.2, 1.8)
	emitter.Acceleration = Vector3.new(0, -18, 0)
	emitter.Size = NumberSequence.new(0.9, 0)
	emitter.LightEmission = 1
	emitter.Parent = anchor
	emitter:Emit(StyleConfig.CosmeticsLayout.FireworksParticles)
	Debris:AddItem(anchor, 3)
end

function FireworksController.Start()
	local layout = StyleConfig.CosmeticsLayout
	local colors = StyleConfig.Cosmetics.DecorFireworks.Colors or { StyleConfig.Cosmetics.DecorFireworks.Preview }
	while true do
		task.wait(layout.FireworksSeconds)
		local studios = Workspace:FindFirstChild("PlayerStudios")
		for _, plot in ipairs(if studios then studios:GetChildren() else {}) do
			if plot:IsA("Model") and plot:GetAttribute("Fireworks") == true and plot.PrimaryPart then
				local center = plot.PrimaryPart.Position
				for i = 1, layout.FireworksBursts do
					task.delay((i - 1) * 0.4, function()
						burst(center + Vector3.new(random:NextNumber(-10, 10), layout.FireworksHeight + random:NextNumber(-3, 3), random:NextNumber(-10, 10)), colors)
					end)
				end
			end
		end
	end
end

return FireworksController
