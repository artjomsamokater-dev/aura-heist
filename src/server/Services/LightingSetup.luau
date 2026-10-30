--!strict
-- LightingSetup: при старте сервера настраивает свет по StyleConfig.Lighting —
-- солнце под углом, атмосфера, Bloom, мягкая цветокоррекция, небо. Сервер меняет Lighting, клиенты видят то же.
-- Тени (Lighting.Technology = ShadowMap) задаются в default.project.json: из скрипта их не включить.
-- Эффекты этих типов, которые уже лежат в Lighting (например, из шаблона места), заменяются нашими,
-- иначе их было бы по два и Roblox брал бы любой из них.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)

local LightingSetup = {}

local REPLACED_CLASSES = { "Sky", "Atmosphere", "BloomEffect", "ColorCorrectionEffect" }

local function removeExisting()
	for _, child in ipairs(Lighting:GetChildren()) do
		if table.find(REPLACED_CLASSES, child.ClassName) then
			child:Destroy()
		end
	end
end

function LightingSetup.Apply()
	local cfg = StyleConfig.Lighting
	removeExisting()

	Lighting.ClockTime = cfg.ClockTime
	Lighting.GeographicLatitude = cfg.GeographicLatitude -- вместе с ClockTime задаёт угол солнца
	Lighting.Brightness = cfg.Brightness
	Lighting.Ambient = cfg.Ambient
	Lighting.OutdoorAmbient = cfg.OutdoorAmbient
	Lighting.ExposureCompensation = cfg.ExposureCompensation
	Lighting.EnvironmentDiffuseScale = cfg.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = cfg.EnvironmentSpecularScale
	Lighting.ShadowSoftness = cfg.ShadowSoftness
	Lighting.GlobalShadows = true

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = cfg.Atmosphere.Density
	atmosphere.Offset = cfg.Atmosphere.Offset
	atmosphere.Color = cfg.Atmosphere.Color
	atmosphere.Decay = cfg.Atmosphere.Decay
	atmosphere.Glare = cfg.Atmosphere.Glare
	atmosphere.Haze = cfg.Atmosphere.Haze
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = cfg.Bloom.Intensity
	bloom.Size = cfg.Bloom.Size
	bloom.Threshold = cfg.Bloom.Threshold
	bloom.Parent = Lighting

	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Saturation = cfg.ColorCorrection.Saturation
	colorCorrection.Contrast = cfg.ColorCorrection.Contrast
	colorCorrection.Brightness = cfg.ColorCorrection.Brightness
	colorCorrection.TintColor = cfg.ColorCorrection.TintColor
	colorCorrection.Parent = Lighting

	-- Новый Sky уже со стандартным голубым небом Roblox
	local sky = Instance.new("Sky")
	sky.SunAngularSize = cfg.Sky.SunAngularSize
	sky.StarCount = cfg.Sky.StarCount
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting

	print("[LightingSetup] Свет настроен: яркий день")
end

return LightingSetup
