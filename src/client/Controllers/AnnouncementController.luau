--!strict
-- AnnouncementController: крупная плашка вверху экрана.
-- • «A LEGENDARY appeared in the DANGER zone!» — сервер присылает только Id редкости и части зоны
--   (Remotes.Announcement), цвет плашки — цвет редкости из StyleConfig.
-- • «SQUAD BONUS!» — сервер присылает только сам факт (Remotes.SquadBonus), процент — из EconomyConfig.
-- Тексты — из TextConfig. Новое объявление заменяет старое, а не встаёт в очередь.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local AnnouncementController = {}

local HUD = StyleConfig.Hud

local function build(playerGui: Instance): (Frame, TextLabel, UIStroke)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Announcement"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10 -- поверх остального HUD
	gui.Parent = playerGui

	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, GuiService:GetGuiInset().Y + HUD.TimerTop + HUD.TimerHeight + HUD.AnnounceGap)
	banner.Size = UDim2.new(0.9, 0, 0, HUD.AnnounceHeight)
	banner.BorderSizePixel = 0
	banner.Visible = false
	banner.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, HUD.CornerRadius)
	corner.Parent = banner
	local stroke = Instance.new("UIStroke")
	stroke.Color = HUD.Stroke
	stroke.Thickness = HUD.StrokeThickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = banner
	-- На узком экране телефона плашка не шире экрана
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(HUD.AnnounceWidth, HUD.AnnounceHeight)
	sizeLimit.Parent = banner

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -20, 1, -8)
	label.Position = UDim2.fromOffset(10, 4)
	label.Font = StyleConfig.Fonts.Hud
	label.TextSize = HUD.AnnounceTextSize
	label.TextScaled = true
	label.TextColor3 = HUD.TextDark
	label.Parent = banner
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = HUD.AnnounceTextSize
	textLimit.Parent = label

	return banner, label, stroke
end

function AnnouncementController.Start()
	local player = Players.LocalPlayer
	local banner, label, stroke = build(player:WaitForChild("PlayerGui"))
	local showToken = 0

	local function fade(visible: boolean)
		local info = TweenInfo.new(HUD.AnnounceFadeSeconds)
		local target = if visible then 0 else 1
		TweenService:Create(banner, info, { BackgroundTransparency = target }):Play()
		TweenService:Create(label, info, { TextTransparency = target }):Play()
		TweenService:Create(stroke, info, { Transparency = target }):Play()
	end

	local function show(text: string, color: Color3)
		banner.BackgroundColor3 = color
		label.Text = text

		showToken += 1
		local token = showToken
		banner.BackgroundTransparency = 1
		label.TextTransparency = 1
		stroke.Transparency = 1
		banner.Visible = true
		fade(true)
		task.delay(HUD.AnnounceSeconds, function()
			if token ~= showToken then
				return -- пришло новое объявление — его не гасим
			end
			fade(false)
			task.wait(HUD.AnnounceFadeSeconds)
			if token == showToken then
				banner.Visible = false
			end
		end)
	end

	local folder = ReplicatedStorage:WaitForChild(Remotes.Folder)

	-- Редкий спавн: всем игрокам на сервере
	local announcement = folder:WaitForChild(Remotes.Announcement)
	if announcement:IsA("RemoteEvent") then
		announcement.OnClientEvent:Connect(function(rarity: unknown, part: unknown)
			if type(rarity) ~= "string" or type(part) ~= "string" then
				return
			end
			local rarityStyle = StyleConfig.Memeling.Rarities[rarity]
			show(
				string.format(TextConfig.AnnounceSpawn, TextConfig.RarityNames[rarity] or rarity, TextConfig.ZonePartNames[part] or part),
				if rarityStyle then rarityStyle.Body else HUD.BaseCard
			)
		end)
	end

	-- Бонус отряда: только этому игроку
	local squadBonus = folder:WaitForChild(Remotes.SquadBonus)
	if squadBonus:IsA("RemoteEvent") then
		squadBonus.OnClientEvent:Connect(function()
			show(string.format(TextConfig.SquadBonusBanner, EconomyConfig.SquadBonus.SellBonusPercent), HUD.HandsCard)
		end)
	end
end

return AnnouncementController
