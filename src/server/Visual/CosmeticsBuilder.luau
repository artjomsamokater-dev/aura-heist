--!strict
-- CosmeticsBuilder: как выглядит купленная косметика (задача 7.4) — только картинка, без логики.
-- Что надето, решает сервис Shop; здесь — построить это на участке и на персонаже.
-- Вид — StyleConfig.Cosmetics / CosmeticsLayout, места на участке — MapConfig.Plots.Cosmetics.
--   • участок: до 3 баннеров на флагштоках выше арки, декор (дорожка, фонтанчик, статуя, неон-вывеска
--     с ником, фейерверк — атрибут Fireworks, салют пускает клиент), скин постаментов;
--   • персонаж: след (Trail), аура-частицы, титул над ником.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local MapBuilder = require(script.Parent.Parent.Services.MapBuilder)

local CosmeticsBuilder = {}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local FOLDER = "Cosmetics"

local function part(name: string, kind: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = StyleConfig.Material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	if kind == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif kind == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Parent = parent
	return p
end

local function styleOf(id: string): StyleConfig.CosmeticStyle
	return StyleConfig.Cosmetics[id] or { Preview = StyleConfig.Palette.CreamLight }
end

local function colorAt(style: StyleConfig.CosmeticStyle, index: number): Color3
	local colors = style.Colors or { style.Preview }
	return colors[(index - 1) % #colors + 1]
end

local function sparkles(parent: BasePart, color: Color3)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = StyleConfig.ParticleTexture
	emitter.Color = ColorSequence.new(color)
	emitter.Rate = 4
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 1
	emitter.Parent = parent
end

-- Рисунок флага из рамок на SurfaceGui (с обеих сторон)
local function drawFlag(flag: BasePart, style: StyleConfig.CosmeticStyle)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = StyleConfig.CosmeticsLayout.FlagPixelsPerStud
		gui.Parent = flag
		local function box(color: Color3, position: UDim2, size: UDim2, round: boolean?, rotation: number?): Frame
			local f = Instance.new("Frame")
			f.BorderSizePixel = 0
			f.BackgroundColor3 = color
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = position
			f.Size = size
			f.Rotation = rotation or 0
			f.Parent = gui
			if round then
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0.5, 0)
				corner.Parent = f
			end
			return f
		end
		local pattern = style.Pattern or "Solid"
		local background = colorAt(style, 1)
		local accent = colorAt(style, 2)
		box(background, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1))
		if pattern == "Stripes" then
			local count = 6
			for i = 1, count do
				box(colorAt(style, i), UDim2.fromScale(0.5, (i - 0.5) / count), UDim2.fromScale(1, 1 / count))
			end
		elseif pattern == "Checker" then
			for x = 0, 5 do
				for y = 0, 3 do
					if (x + y) % 2 == 0 then
						box(accent, UDim2.fromScale((x + 0.5) / 6, (y + 0.5) / 4), UDim2.fromScale(1 / 6, 1 / 4))
					end
				end
			end
		elseif pattern == "Dots" then
			for x = 0, 4 do
				for y = 0, 2 do
					box(accent, UDim2.fromScale((x + 0.5 + (y % 2) * 0.3) / 5, (y + 0.5) / 3), UDim2.fromScale(0.09, 0.15), true)
				end
			end
		elseif pattern == "Star" then
			for _, rotation in ipairs({ 0, 45 }) do
				box(accent, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.34, 0.55), false, rotation)
			end
		elseif pattern == "Heart" then
			box(accent, UDim2.fromScale(0.42, 0.42), UDim2.fromScale(0.22, 0.36), true)
			box(accent, UDim2.fromScale(0.58, 0.42), UDim2.fromScale(0.22, 0.36), true)
			box(accent, UDim2.fromScale(0.5, 0.58), UDim2.fromScale(0.24, 0.38), false, 45)
		elseif pattern == "Face" then
			-- Рожица мемлинга: глаза разного размера с бликом и улыбка
			for _, eye in ipairs({ { X = 0.38, S = 0.3 }, { X = 0.62, S = 0.22 } }) do
				box(Color3.new(1, 1, 1), UDim2.fromScale(eye.X, 0.42), UDim2.fromScale(eye.S * 0.6, eye.S), true)
				box(accent, UDim2.fromScale(eye.X, 0.44), UDim2.fromScale(eye.S * 0.33, eye.S * 0.55), true)
			end
			box(accent, UDim2.fromScale(0.5, 0.72), UDim2.fromScale(0.22, 0.08), true)
		end
	end
end

local function buildBanner(plotCFrame: CFrame, slot: number, id: string, parent: Instance)
	local layout = StyleConfig.CosmeticsLayout
	local style = styleOf(id)
	local floorTop = MapConfig.Plots.Size.Y / 2
	local base = plotCFrame * CFrame.new(MapConfig.Plots.Cosmetics.BannerPoles[slot] + Vector3.new(0, floorTop, 0))
	part("Pole" .. slot, "Cylinder", Vector3.new(layout.PoleHeight, layout.PoleDiameter, layout.PoleDiameter), base * CFrame.new(0, layout.PoleHeight / 2, 0) * UPRIGHT, layout.Pole, parent)
	part("PoleCap" .. slot, "Ball", Vector3.one * 1, base * CFrame.new(0, layout.PoleHeight + 0.3, 0), layout.PoleCap, parent)
	local size = layout.FlagSize
	local flag = part("Flag" .. slot, "Block", size, base * CFrame.new(size.X / 2 + layout.PoleDiameter / 2, layout.PoleHeight - size.Y / 2 - 0.4, 0), colorAt(style, 1), parent)
	flag:SetAttribute("ShopItem", id)
	if style.Glow then
		flag.Material = StyleConfig.GlowMaterial
	end
	if style.Rainbow then
		CollectionService:AddTag(flag, StyleConfig.Rainbow.Tag)
	else
		drawFlag(flag, style)
	end
	if style.Particles then
		sparkles(flag, colorAt(style, 2))
	end
end

local function buildDecor(plotCFrame: CFrame, id: string, ownerName: string, statueId: string, parent: Instance)
	local cfg = MapConfig.Plots
	local spots = cfg.Cosmetics
	local style = styleOf(id)
	local floorTop = cfg.Size.Y / 2
	local function at(offset: Vector3, height: number): CFrame
		return plotCFrame * CFrame.new(offset + Vector3.new(0, floorTop + height, 0))
	end
	if id == "DecorCarpet" then
		-- Ковровая дорожка поверх коврика участка, с каймой
		local rug = cfg.RugCenter
		part("Carpet", "Block", Vector3.new(cfg.RugSize.X - 1.2, 0.05, cfg.RugSize.Z), plotCFrame * CFrame.new(rug + Vector3.new(0, 0.06, 0)), colorAt(style, 1), parent)
		for _, x in ipairs({ -1, 1 }) do
			part("CarpetTrim", "Block", Vector3.new(0.3, 0.06, cfg.RugSize.Z), plotCFrame * CFrame.new(rug + Vector3.new(x * (cfg.RugSize.X / 2 - 0.75), 0.07, 0)), colorAt(style, 2), parent)
		end
	elseif id == "DecorFountain" then
		part("FountainRim", "Cylinder", Vector3.new(0.9, 4, 4), at(spots.Fountain, 0.45) * UPRIGHT, colorAt(style, 1), parent)
		local water = part("FountainWater", "Cylinder", Vector3.new(0.1, 3.4, 3.4), at(spots.Fountain, 0.92) * UPRIGHT, colorAt(style, 2), parent)
		water.Material = StyleConfig.GlowMaterial
		water.Transparency = 0.25
		part("FountainColumn", "Cylinder", Vector3.new(2, 0.6, 0.6), at(spots.Fountain, 1.9) * UPRIGHT, colorAt(style, 3), parent)
		local top = part("FountainTop", "Ball", Vector3.one * 0.8, at(spots.Fountain, 3), colorAt(style, 2), parent)
		top.Material = StyleConfig.GlowMaterial
		sparkles(top, colorAt(style, 3))
	elseif id == "DecorStatue" then
		-- Каменный постамент и большая тусклая статуя самого ценного мемлинга игрока
		part("StatueBase", "Cylinder", Vector3.new(1.2, 4.6, 4.6), at(spots.Statue, 0.6) * UPRIGHT, colorAt(style, 2), parent)
		local size = StyleConfig.Memeling.Size
		local stand = at(spots.Statue, 1.2 + size.Y / 2)
		local core = MapBuilder.MakeMemeling("Statue", statueId, CFrame.lookAt(stand.Position, (stand * CFrame.new(0, 0, -1)).Position), parent)
		CollectionService:RemoveTag(core, StyleConfig.Outline.Tag)
		core.CanCollide = false
		for _, child in ipairs(core:GetDescendants()) do
			if child:IsA("BasePart") then
				child.Color = child.Color:Lerp(colorAt(style, 1), 0.8)
				child.Material = StyleConfig.Material
			elseif child:IsA("Light") or child:IsA("ParticleEmitter") then
				child:Destroy()
			end
		end
	elseif id == "DecorNeonSign" then
		local board = part("NeonSign", "Block", Vector3.new(12, 2.4, 0.3), at(spots.NeonSign, 0), colorAt(style, 1), parent)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = StyleConfig.Label.SignPixelsPerStud
		gui.LightInfluence = 0 -- текст светится, как неон
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(0.94, 0.86)
		label.Position = UDim2.fromScale(0.03, 0.07)
		label.TextScaled = true
		label.Font = StyleConfig.Fonts.Label
		label.TextColor3 = colorAt(style, 2)
		label.TextStrokeColor3 = colorAt(style, 2)
		label.TextStrokeTransparency = 0.6
		label.Text = ownerName
		label.Parent = gui
	elseif id == "DecorFireworks" then
		part("FireworksBase", "Cylinder", Vector3.new(1, 2.4, 2.4), at(spots.Fireworks, 0.5) * UPRIGHT, colorAt(style, 1), parent)
		part("FireworksTube", "Cylinder", Vector3.new(2, 0.8, 0.8), at(spots.Fireworks, 1.8) * CFrame.Angles(0, 0, math.rad(80)), colorAt(style, 2), parent)
	end
end

-- Скин постаментов участка: цвет/материал видимого «тела» каждого постамента (nil — обычный, цвет акцента).
-- Облако — ещё пушистые шары вокруг основания (в папку косметики)
local function applyPedestalSkin(plot: Model, skinId: string?, parent: Instance)
	local pedestals = plot:FindFirstChild("Pedestals")
	if pedestals == nil then
		return
	end
	local style = if skinId then styleOf(skinId) else nil
	for _, pedestal in ipairs(pedestals:GetChildren()) do
		if not pedestal:IsA("BasePart") then
			continue
		end
		-- Тело — самая высокая из видимых деталей Look (ободок тоньше)
		local body: BasePart? = nil
		for _, look in ipairs(pedestal:GetChildren()) do
			if look.Name == "Look" and look:IsA("BasePart") and (body == nil or look.Size.X > body.Size.X) then
				body = look
			end
		end
		if body == nil then
			continue
		end
		local accent = pedestal:GetAttribute("AccentColor")
		body.Color = if style then colorAt(style, 1) elseif typeof(accent) == "Color3" then accent else body.Color
		body.Material = if style and style.Glow then StyleConfig.GlowMaterial elseif style and style.Material then style.Material else StyleConfig.Material
		body.Reflectance = if style and style.Reflectance then style.Reflectance else 0
		if skinId == "SkinCloud" and style then
			for i = 1, 3 do
				local angle = i * 2 * math.pi / 3
				local offset = Vector3.new(math.cos(angle) * 2.1, -0.6, math.sin(angle) * 2.1)
				part("Cloud", "Ball", Vector3.one * 1.8, pedestal.CFrame * CFrame.new(offset), colorAt(style, (i % 2) + 1), parent)
			end
		end
	end
end

-- Косметика на участке: всё прежнее убирается и строится заново по списку надетого
function CosmeticsBuilder.ApplyPlot(plot: Model, equipped: { [string]: { string } }, ownerName: string, statueId: string)
	CosmeticsBuilder.ClearPlot(plot)
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder.Parent = plot
	local floor = plot.PrimaryPart
	if floor == nil then
		return
	end
	local plotCFrame = floor.CFrame
	for slot, id in ipairs(equipped.Banner or {}) do
		if slot <= #MapConfig.Plots.Cosmetics.BannerPoles then
			buildBanner(plotCFrame, slot, id, folder)
		end
	end
	local decor = equipped.Decor or {}
	for _, id in ipairs(decor) do
		buildDecor(plotCFrame, id, ownerName, statueId, folder)
	end
	plot:SetAttribute("Fireworks", table.find(decor, "DecorFireworks") ~= nil)
	applyPedestalSkin(plot, (equipped.PedestalSkin or {})[1], folder)
end

function CosmeticsBuilder.ClearPlot(plot: Model)
	local old = plot:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	plot:SetAttribute("Fireworks", nil)
	applyPedestalSkin(plot, nil, plot)
end

-- Косметика на персонаже: след, аура-частицы, титул над ником (прежние убираются)
function CosmeticsBuilder.ApplyCharacter(character: Model, equipped: { [string]: { string } })
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local layout = StyleConfig.CosmeticsLayout
	for _, name in ipairs({ "ShopTrail", "ShopTrailTop", "ShopTrailBottom", "ShopAura" }) do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local oldTitle = head and head:FindFirstChild("ShopTitle")
	if oldTitle then
		oldTitle:Destroy()
	end

	local trailId = (equipped.Trail or {})[1]
	if trailId then
		local style = styleOf(trailId)
		local top = Instance.new("Attachment")
		top.Name = "ShopTrailTop"
		top.Position = Vector3.new(0, layout.TrailWidth / 2, 0)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Name = "ShopTrailBottom"
		bottom.Position = Vector3.new(0, -layout.TrailWidth / 2, 0)
		bottom.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = "ShopTrail"
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Lifetime = layout.TrailLifetime
		local colors = style.Colors or { style.Preview }
		local keypoints = {}
		for i, color in ipairs(colors) do
			table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / math.max(1, #colors - 1), color))
		end
		if #keypoints == 1 then
			table.insert(keypoints, ColorSequenceKeypoint.new(1, colors[1]))
		end
		trail.Color = ColorSequence.new(keypoints)
		trail.Transparency = NumberSequence.new(0.1, 1)
		trail.LightEmission = 0.6
		if style.Particles then
			trail.Texture = StyleConfig.ParticleTexture
			trail.TextureMode = Enum.TextureMode.Wrap
		end
		trail.Parent = root
	end

	local auraId = (equipped.Aura or {})[1]
	if auraId then
		local style = styleOf(auraId)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "ShopAura"
		emitter.Texture = StyleConfig.ParticleTexture
		emitter.Color = ColorSequence.new(colorAt(style, 1), colorAt(style, 2))
		emitter.Rate = layout.AuraRate
		emitter.Lifetime = layout.AuraLifetime
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.Size = NumberSequence.new(layout.AuraSize, 0)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.LightEmission = if style.Glow then 1 else 0.4
		emitter.Parent = root
	end

	local titleId = (equipped.Title or {})[1]
	if titleId and head and head:IsA("BasePart") then
		local style = styleOf(titleId)
		local gui = Instance.new("BillboardGui")
		gui.Name = "ShopTitle"
		gui.Size = UDim2.fromScale(layout.TitleWidth, layout.TitleTextHeight)
		gui.StudsOffsetWorldSpace = Vector3.new(0, layout.TitleHeight, 0)
		gui.MaxDistance = StyleConfig.Label.MaxDistance
		gui.Parent = head
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
		label.Font = StyleConfig.Fonts.Label
		label.TextColor3 = colorAt(style, 1)
		label.TextStrokeColor3 = StyleConfig.Label.Stroke
		label.TextStrokeTransparency = 0
		label.Text = TextConfig.ShopItemNames[titleId] or titleId
		label.Parent = gui
		if style.Rainbow then
			label:SetAttribute("RainbowText", true) -- переливается: цвет меняет клиент (RainbowController)
			CollectionService:AddTag(label, StyleConfig.Rainbow.Tag)
		end
	end
end

return CosmeticsBuilder
