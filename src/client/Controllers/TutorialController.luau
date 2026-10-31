--!strict
-- TutorialController: стрелка к цели и короткая подсказка для текущего шага туториала. Без окон с текстом.
-- Шаг приходит от сервера (атрибут TutorialStep: 1..6, 0 — пройден); засчитывает шаги только сервер.
-- Кнопка Skip отправляет серверу RemoteEvent TutorialSkip (без аргументов).
--
-- Куда показывает стрелка:
--   1 — на портал; 2 — на ближайшего мемлинга; 3 — на EXTRACT (на шагах 2–3 из хаба — снова на портал);
--   4–5 — на свой постамент с мемлингом; 6 — на золотую кнопку постамента.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local TutorialSteps = require(ReplicatedStorage.Shared.Util.TutorialSteps)
local PlotLayout = require(ReplicatedStorage.Shared.Util.PlotLayout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local TutorialController = {}

local HUD = StyleConfig.Hud
local player = Players.LocalPlayer

local function getRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Свой участок в мире (если загрузился) и его номер
local function getPlot(): (Instance?, number?)
	local index = tonumber(player:GetAttribute("StudioIndex"))
	if index == nil then
		return nil, nil
	end
	local studios = Workspace:FindFirstChild("PlayerStudios")
	return studios and studios:FindFirstChild("Studio" .. index), index
end

-- Ближайший мемлинг в зоне (у них есть атрибут InstanceId)
local function nearestMemeling(): Vector3?
	local zone = Workspace:FindFirstChild("RaidZone")
	local folder = zone and zone:FindFirstChild("Memelings")
	local root = getRoot()
	if folder == nil or root == nil then
		return nil
	end
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute("InstanceId") then
			local distance = (child.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = child.Position, distance
			end
		end
	end
	return best
end

-- Свой постамент, на котором стоит мемлинг (если участок не загрузился — место первого постамента)
local function ownPedestal(): Vector3?
	local plot, index = getPlot()
	if index == nil then
		return nil
	end
	local pedestals = plot and plot:FindFirstChild("Pedestals")
	if pedestals then
		for _, pedestal in ipairs(pedestals:GetChildren()) do
			if pedestal:IsA("BasePart") and pedestal:FindFirstChild("Memeling") then
				return pedestal.Position
			end
		end
	end
	return (PlotLayout.PlotCFrame(index) * CFrame.new(MapConfig.Plots.PedestalOffsets[1])).Position
end

local function upgradeButton(): Vector3?
	local plot, index = getPlot()
	if index == nil then
		return nil
	end
	local buttons = plot and plot:FindFirstChild("Buttons")
	local button = buttons and buttons:FindFirstChild("Upgrade_pedestals")
	if button and button:IsA("BasePart") then
		return button.Position
	end
	return (PlotLayout.PlotCFrame(index) * CFrame.new(MapConfig.Plots.UpgradeButtonOffsets.pedestals)).Position
end

local function getTarget(step: number): Vector3?
	local inRaid = player:GetAttribute("RaidState") == "InRaid"
	local name = TutorialSteps.Steps[step]
	if name == "EnterZone" or ((name == "PickUp" or name == "Extract") and not inRaid) then
		return MapConfig.Portal.Position
	elseif name == "PickUp" then
		return nearestMemeling() or MapConfig.Zone.Center
	elseif name == "Extract" then
		return MapConfig.Zone.ExtractionPosition
	elseif name == "VisitPedestal" or name == "Collect" then
		return ownPedestal()
	elseif name == "BuyUpgrade" then
		return upgradeButton()
	end
	return nil
end

local function makeText(parent: Instance, text: string, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = StyleConfig.Fonts.Hud
	label.TextSize = size
	label.TextColor3 = color
	label.Text = text
	label.Parent = parent
	return label
end

local function addCorner(frame: GuiObject, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = frame
end

-- Подсказка внизу по центру: номер шага, короткий текст, кнопка Skip
local function buildHint(gui: ScreenGui): (Frame, TextLabel, TextLabel, TextButton)
	local panel = Instance.new("Frame")
	panel.Name = "TutorialHint"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -HUD.TutorialBottom)
	panel.Size = UDim2.fromOffset(HUD.TutorialWidth, HUD.TutorialHeight)
	panel.BackgroundColor3 = HUD.TutorialPanel
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	addCorner(panel, UDim.new(1, 0))
	local stroke = Instance.new("UIStroke")
	stroke.Color = HUD.Stroke
	stroke.Thickness = HUD.StrokeThickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = panel

	local badgeSize = HUD.TutorialHeight - 12
	local badge = Instance.new("Frame")
	badge.BackgroundColor3 = HUD.TutorialAccent
	badge.BorderSizePixel = 0
	badge.Position = UDim2.fromOffset(6, 6)
	badge.Size = UDim2.fromOffset(badgeSize, badgeSize)
	badge.Parent = panel
	addCorner(badge, UDim.new(1, 0))
	local stepLabel = makeText(badge, "", 16, HUD.TextLight)
	stepLabel.Size = UDim2.fromScale(1, 1)

	local hint = makeText(panel, "", HUD.TutorialTextSize, HUD.TextDark)
	hint.Position = UDim2.fromOffset(badgeSize + 14, 0)
	hint.Size = UDim2.new(1, -(badgeSize + 14 + HUD.TutorialSkipWidth + 12), 1, 0)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = HUD.TutorialTextSize
	limit.Parent = hint

	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.AnchorPoint = Vector2.new(1, 0.5)
	skip.Position = UDim2.new(1, -8, 0.5, 0)
	skip.Size = UDim2.fromOffset(HUD.TutorialSkipWidth, HUD.TutorialHeight - 16)
	skip.BackgroundColor3 = HUD.Stroke
	skip.BorderSizePixel = 0
	skip.Font = StyleConfig.Fonts.Hud
	skip.TextSize = 16
	skip.TextColor3 = HUD.TextLight
	skip.Text = TextConfig.TutorialSkip
	skip.Parent = panel
	addCorner(skip, UDim.new(1, 0))

	return panel, stepLabel, hint, skip
end

function TutorialController.Start()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "Tutorial"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- координаты стрелки у края совпадают с камерой
	gui.Parent = playerGui

	local panel, stepLabel, hint, skip = buildHint(gui)

	-- Стрелка над целью: невидимая точка-якорь только на этом клиенте + подпись поверх всего
	local anchor = Instance.new("Part")
	anchor.Name = "TutorialArrowAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Parent = Workspace
	local marker = Instance.new("BillboardGui")
	marker.Adornee = anchor
	marker.AlwaysOnTop = true
	marker.MaxDistance = math.huge
	marker.Size = UDim2.fromOffset(HUD.TutorialArrowSize, HUD.TutorialArrowSize)
	marker.Enabled = false
	marker.ResetOnSpawn = false
	marker.Parent = playerGui
	local arrowDown = makeText(marker, TextConfig.ExtractEdgeArrow, HUD.TutorialArrowSize, HUD.TutorialAccent)
	arrowDown.Size = UDim2.fromScale(1, 1)
	arrowDown.Rotation = 180 -- «▲» вниз: показывает на цель
	arrowDown.TextStrokeTransparency = 0
	arrowDown.TextStrokeColor3 = HUD.Stroke

	-- Стрелка у края экрана, когда цель за кадром
	local edge = makeText(gui, TextConfig.ExtractEdgeArrow, HUD.EdgeArrowSize, HUD.TutorialAccent)
	edge.AnchorPoint = Vector2.new(0.5, 0.5)
	edge.Size = UDim2.fromOffset(HUD.EdgeArrowSize + 14, HUD.EdgeArrowSize + 14)
	edge.TextStrokeTransparency = 0
	edge.TextStrokeColor3 = HUD.Stroke
	edge.Visible = false

	local skipEvent = ReplicatedStorage:WaitForChild(Remotes.Folder):WaitForChild(Remotes.TutorialSkip)
	skip.Activated:Connect(function()
		if skipEvent:IsA("RemoteEvent") then
			skipEvent:FireServer()
		end
	end)

	local function refreshHint()
		local step = tonumber(player:GetAttribute("TutorialStep")) or 0
		local text = TextConfig.TutorialHints[step]
		panel.Visible = step > 0 and text ~= nil
		if text then
			hint.Text = text
			stepLabel.Text = string.format(TextConfig.TutorialStepTag, step, TutorialSteps.Count())
		end
	end
	player:GetAttributeChangedSignal("TutorialStep"):Connect(refreshHint)
	refreshHint()

	local target: Vector3? = nil
	local sinceTargetUpdate = math.huge
	RunService.RenderStepped:Connect(function(dt: number)
		local step = tonumber(player:GetAttribute("TutorialStep")) or 0
		local camera = Workspace.CurrentCamera
		if step <= 0 or camera == nil then
			marker.Enabled = false
			edge.Visible = false
			return
		end

		-- Цель ищем 4 раза в секунду, а не каждый кадр
		sinceTargetUpdate += dt
		if sinceTargetUpdate >= 0.25 then
			sinceTargetUpdate = 0
			target = getTarget(step)
		end
		local goal = target
		if goal == nil then
			marker.Enabled = false
			edge.Visible = false
			return
		end

		local bob = math.sin(os.clock() * HUD.TutorialArrowBobHz * 2 * math.pi) * HUD.TutorialArrowBob
		local point = goal + Vector3.new(0, HUD.TutorialArrowHeight + bob, 0)
		anchor.Position = point
		marker.Enabled = true

		local screenPoint, onScreen = camera:WorldToViewportPoint(point)
		if onScreen then
			edge.Visible = false
			return
		end
		local viewport = camera.ViewportSize
		local center = viewport / 2
		local direction = Vector2.new(screenPoint.X, screenPoint.Y) - center
		if screenPoint.Z < 0 then
			direction = -direction -- цель позади камеры: экранные координаты перевёрнуты
		end
		if direction.Magnitude < 1 then
			direction = Vector2.new(0, -1)
		end
		direction = direction.Unit
		local radius = math.min(viewport.X, viewport.Y) / 2 - HUD.EdgePadding - 40
		local position = center + direction * radius
		edge.Position = UDim2.fromOffset(position.X, position.Y)
		edge.Rotation = math.deg(math.atan2(direction.Y, direction.X)) + 90
		edge.Visible = true
	end)
end

return TutorialController
