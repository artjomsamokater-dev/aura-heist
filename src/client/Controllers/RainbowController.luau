--!strict
-- RainbowController: детали с тегом StyleConfig.Rainbow.Tag переливаются всеми цветами (задача 7.3) —
-- кольцо редкости Secret и «глитч»-полосы Error404Kitten. Только картинка на этом клиенте.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)

local RainbowController = {}

function RainbowController.Start()
	local style = StyleConfig.Rainbow
	RunService.RenderStepped:Connect(function()
		local base = (os.clock() / style.CycleSeconds) % 1
		for i, part in ipairs(CollectionService:GetTagged(style.Tag)) do
			if part:IsA("BasePart") then
				part.Color = Color3.fromHSV((base + i * style.Spread) % 1, style.Saturation, style.Value)
			end
		end
	end)
end

return RainbowController
