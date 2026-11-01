--!strict
-- ObbyBuilder: секретный паркур над морем (задача 7.3) — только детали, без логики.
-- Места — MapConfig.Obby, цвета — StyleConfig.Obby. Логику (чекпоинты, море, награда) ведёт сервис SecretObby.
--   • платформы-диски (на чекпоинтах — мятный неоновый круг, атрибут CheckpointIndex);
--   • тайный остров с площадкой возврата в хаб (ReturnPad);
--   • маленький знак «?» у прохода в стене хаба.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)

local ObbyBuilder = {}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- цилиндр Roblox лежит вдоль X; так он стоит вертикально

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance, collide: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = StyleConfig.Material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = collide
	p.CanTouch = false
	p.CanQuery = collide -- по платформам ходит персонаж: пол должен «ловиться»
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- Вертикальный диск/столб: center — центр, height — высота
local function disc(name: string, center: Vector3, height: number, diameter: number, color: Color3, parent: Instance, collide: boolean): Part
	local p = part(name, Vector3.new(height, diameter, diameter), CFrame.new(center) * UPRIGHT, color, parent, collide)
	p.Shape = Enum.PartType.Cylinder
	return p
end

export type Built = {
	IslandTop: Vector3, -- центр верха острова (там стоит Secret-мемлинг для красоты)
	ReturnPad: Part,
}

function ObbyBuilder.Build(parent: Instance): Built
	local cfg = MapConfig.Obby
	local style = StyleConfig.Obby
	local folder = Instance.new("Folder")
	folder.Name = "SecretObby"
	folder.Parent = parent

	local thickness = cfg.PlatformThickness
	for i, spec in ipairs(cfg.Platforms) do
		local top = spec.Position
		local platform = disc("Platform" .. i, top - Vector3.new(0, thickness / 2, 0), thickness, spec.Diameter, style.Platform, folder, true)
		disc("Rim" .. i, top - Vector3.new(0, thickness / 2, 0), thickness * 0.6, spec.Diameter + 0.4, style.PlatformRim, folder, false)
		local checkpoint = table.find(cfg.Checkpoints, i)
		if checkpoint then
			platform:SetAttribute("CheckpointIndex", checkpoint)
			local pad = disc("Checkpoint" .. checkpoint, top + Vector3.new(0, 0.05, 0), 0.1, spec.Diameter - 1.2, style.Checkpoint, folder, false)
			pad.Material = StyleConfig.GlowMaterial
			pad.Transparency = 0.2
		end
	end

	-- Тайный остров: трава, «земля» ступенями вниз
	local island = cfg.Island
	local top = island.Position
	disc("IslandGrass", top - Vector3.new(0, 1, 0), 2, island.Radius * 2, style.IslandGrass, folder, true)
	local y = top.Y - 2
	for step, share in ipairs({ { Height = 0.45, Width = 0.9 }, { Height = 0.35, Width = 0.6 }, { Height = 0.2, Width = 0.3 } }) do
		local height = island.Depth * share.Height
		local color = if step == 3 then style.IslandEarthDark else style.IslandEarth
		disc("IslandEarth" .. step, Vector3.new(top.X, y - height / 2, top.Z), height, island.Radius * 2 * share.Width, color, folder, false)
		y -= height
	end

	-- Площадка возврата в хаб (на неё встают — жёлтая)
	local returnPad = disc("ReturnPad", top + cfg.ReturnPadOffset + Vector3.new(0, 0.05, 0), 0.1, cfg.ReturnPadRadius * 2, style.ReturnPad, folder, false)
	returnPad.Material = StyleConfig.GlowMaterial

	-- Маленький знак «?» у прохода — единственная подсказка
	local hint = part("Hint", Vector3.new(1.2, 1.2, 0.2), CFrame.new(cfg.HintOffset + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, math.rad(90), 0), style.HintBoard, folder, false)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = StyleConfig.Label.SignPixelsPerStud
		gui.Parent = hint
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
		label.Font = StyleConfig.Fonts.Label
		label.TextColor3 = style.HintText
		label.Text = TextConfig.SecretHint
		label.Parent = gui
	end
	part("HintPost", Vector3.new(0.2, 0.8, 0.2), CFrame.new(cfg.HintOffset + Vector3.new(0, 0.4, 0)), style.HintBoard, folder, false)

	return { IslandTop = top, ReturnPad = returnPad }
end

return ObbyBuilder
