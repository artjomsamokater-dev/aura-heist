--!strict
-- MemelingBuilders: модели 8 мемлингов и врага Grumblob в стиле «D · Микс» (задача 5.4).
-- У каждого персонажа своя функция-строитель: она добавляет детали к невидимому ядру через MemelingKit.
-- Цвета — StyleConfig.Characters, общие размеры и цвета лица — StyleConfig.Memeling.
--
-- Места — от центра мемлинга (габарит 6 × 6 × 6): низ −3, кольцо редкости до −2,6, на нём стоят ноги.
-- −Z — лицо, +X — слева для зрителя (блик), −X — справа (тень). Деталей — не больше ~32 на мемлинга.
-- Сзади и сбоку у каждого есть своя деталь (хвост, плащ, наклейка, пупырышки, обмотка, шипы), чтобы не был гладким.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local MemelingKit = require(script.Parent.MemelingKit)

type Kit = MemelingKit.Kit

local v3 = Vector3.new
local v2 = Vector2.new
local add = MemelingKit.Add
local eye = MemelingKit.Eye
local blush = MemelingKit.Blush
local gloss = MemelingKit.Gloss
local shade = MemelingKit.Shade
local mouth = MemelingKit.Mouth
local front = MemelingKit.Front
local frontRound = MemelingKit.FrontRound
local UP = MemelingKit.UP
local ALONG_Z = MemelingKit.ALONG_Z
local TRIANGLE_DOWN = MemelingKit.TRIANGLE_DOWN

local Colors = StyleConfig.Characters

local Builders: { [string]: (kit: Kit) -> () } = {}

-- Глубина задней поверхности овала (z > 0) в точке (x, y): туда сажаем детали спины
local function back(center: Vector3, size: Vector3, x: number, y: number): number
	return 2 * center.Z - front(center, size, x, y)
end

-- Шип-ромб: кубик, повёрнутый на 45° вокруг X, наполовину утоплен в тело — сбоку виден треугольник
local function spike(kit: Kit, size: number, position: Vector3, color: Color3, turnY: number?)
	add(kit, "Block", v3(size * 0.4, size, size), position, color, v3(45, turnY or 0, 0))
end

-- 1. Toast Paw (Common): ломоть тоста — корочка вокруг мякиша, кривые глаза, открытый рот с языком,
-- две кошачьи лапки с розовыми подушечками
function Builders.ToastPaw(kit: Kit)
	local c = Colors.ToastPaw
	-- Корочка сзади (тоньше), мякиш спереди (толще — выступает из корочки, корочка видна каймой)
	add(kit, "Block", v3(4.6, 3, 1.4), v3(0, -0.9, 0), c.Crust)
	add(kit, "Cylinder", v3(1.4, 5, 5), v3(0, 0.6, 0), c.Crust, ALONG_Z)
	shade(kit, "Block", v3(0.5, 3, 1.36), v3(-2.45, -0.9, 0), c.Crust)
	shade(kit, "Cylinder", v3(1.36, 5, 5), v3(-0.3, 0.5, 0), c.Crust, ALONG_Z)
	add(kit, "Block", v3(3.8, 2.6, 1.6), v3(0, -0.8, 0), c.Crumb)
	add(kit, "Cylinder", v3(1.6, 4.2, 4.2), v3(0, 0.6, 0), c.Crumb, ALONG_Z)
	gloss(kit, v3(1.3, 0.45, 0.15), v3(1.2, 2.1, -0.82), v3(0, 0, -35))

	-- Кривые глаза: большой выше, маленький ниже, смотрят в разные стороны
	eye(kit, v3(0.9, 0.9, -0.8), 1.15, v2(0.3, 0.2))
	eye(kit, v3(-0.85, 0.7, -0.8), 0.8, v2(-0.4, -0.3))
	mouth(kit, v3(1, 0.75, 0.3), v3(0, -0.4, -0.8))
	add(kit, "Oval", v3(0.6, 0.35, 0.2), v3(0, -0.6, -0.92), c.Tongue)
	blush(kit, v3(0.8, 0.42, 0.15), v3(1.45, 0, -0.83))
	blush(kit, v3(0.8, 0.42, 0.15), v3(-1.45, 0, -0.83))

	-- Лапки снизу, на кольце
	for _, x in ipairs({ 1, -1 }) do
		add(kit, "Oval", v3(1.3, 0.9, 1.4), v3(x, -2.15, -0.75), c.Crumb)
		add(kit, "Ball", v3(0.42, 0.42, 0.42), v3(x, -2.15, -1.47), c.Pads)
	end

	-- Сзади — кошачий хвост загибается вверх справа (виден сбоку и чуть-чуть спереди)
	add(kit, "Oval", v3(0.55, 2.2, 0.55), v3(-1.7, -1.1, 1.05), c.Crust, v3(0, 0, 35))
	add(kit, "Ball", v3(0.7, 0.7, 0.7), v3(-2.3, 0, 1.05), c.Crumb)
end

-- 2. Sir Wobbleton (Common): желейное яйцо-пудинг в маленьком серебряном шлеме с плюмажем,
-- с маленьким мечом и растерянным видом
function Builders.SirWobbleton(kit: Kit)
	local c = Colors.SirWobbleton
	local center, size = v3(0, -0.2, 0), v3(4, 4.8, 4)
	add(kit, "Oval", size, center, c.Body)
	shade(kit, "Oval", v3(3.96, 4.7, 3.88), v3(-0.2, -0.22, 0.02), c.Body)
	gloss(kit, v3(1.1, 0.5, 0.25), v3(1.15, 1, front(center, size, 1.15, 1) - 0.02), v3(0, 0, -40))

	-- Шлем: купол и ободок, плюмаж из двух овалов
	add(kit, "Oval", v3(3, 1.9, 3), v3(0, 2, 0.1), c.Helmet)
	add(kit, "Cylinder", v3(0.3, 3.3, 3.3), v3(0, 1.25, 0), c.Helmet, UP)
	add(kit, "Oval", v3(0.55, 1.5, 1), v3(0, 3.3, 0.3), c.Plume, v3(-15, 0, 0))
	add(kit, "Oval", v3(0.5, 1.2, 0.9), v3(0, 3, 1.1), c.Plume, v3(-55, 0, 0))

	-- Растерянный: глаза разного размера смотрят в разные стороны, рот «о»
	eye(kit, v3(0.8, 0.35, front(center, size, 0.8, 0.35)), 1.25, v2(0.4, 0.3))
	eye(kit, v3(-0.85, 0.45, front(center, size, -0.85, 0.45)), 0.85, v2(-0.3, 0.4))
	mouth(kit, v3(0.45, 0.55, 0.25), v3(0, -0.75, front(center, size, 0, -0.75)))
	blush(kit, v3(0.75, 0.4, 0.2), v3(1.35, -0.25, front(center, size, 1.35, -0.25)))
	blush(kit, v3(0.75, 0.4, 0.2), v3(-1.35, -0.25, front(center, size, -1.35, -0.25) - 0.15))

	-- Маленький меч в правой руке
	add(kit, "Block", v3(0.22, 2.6, 0.55), v3(-2.5, 0.2, -0.7), c.Blade, v3(0, 0, -12))
	add(kit, "Block", v3(1, 0.22, 0.5), v3(-2.75, -1.05, -0.7), c.Guard, v3(0, 0, -12))
	add(kit, "Oval", v3(0.9, 0.9, 0.9), v3(-2.65, -1.35, -0.7), c.Body)

	for _, x in ipairs({ 0.85, -0.85 }) do
		add(kit, "Oval", v3(1.1, 0.6, 1.4), v3(x, -2.3, -0.3), c.Feet)
	end

	-- Сзади — маленький красный плащ рыцаря
	add(kit, "Oval", v3(3, 3, 1.6), v3(0, -0.5, back(center, size, 0, -0.5) - 0.55), c.Plume) -- выпуклый, облегает спину
end

-- 3. Grumbloaf (Common): широкий батон с насечками сверху, сердитые брови, маленькие ножки
function Builders.Grumbloaf(kit: Kit)
	local c = Colors.Grumbloaf
	local center, size = v3(0, -0.3, 0), v3(5.6, 3.6, 3.4)
	add(kit, "Oval", size, center, c.Body)
	shade(kit, "Oval", v3(5.5, 3.5, 3.3), v3(-0.25, -0.35, 0.02), c.Body)
	gloss(kit, v3(1.4, 0.5, 0.25), v3(1.6, 0.85, front(center, size, 1.6, 0.85) - 0.02), v3(0, 0, -25))

	-- Насечки сверху
	add(kit, "Oval", v3(0.55, 0.35, 2.2), v3(1.5, 1.17, 0), c.Cuts, v3(0, 30, 0))
	add(kit, "Oval", v3(0.55, 0.35, 2.2), v3(0, 1.45, 0), c.Cuts, v3(0, 30, 0))
	add(kit, "Oval", v3(0.55, 0.35, 2.2), v3(-1.5, 1.17, 0), c.Cuts, v3(0, 30, 0))

	-- Сердитое лицо по центру морды: глаза близко к середине и наполовину утоплены в тело,
	-- брови к переносице, рот чёрточкой
	for _, e in ipairs({ { X = 0.75, Y = 0.05, Size = 0.95 }, { X = -0.75, Y = 0, Size = 0.82 } }) do
		eye(kit, v3(e.X, e.Y, front(center, size, e.X, e.Y) + e.Size * 0.2), e.Size, v2(0, -0.2))
	end
	local brow = StyleConfig.Memeling.Face.Mouth
	add(kit, "Block", v3(1, 0.3, 0.3), v3(0.75, 0.65, front(center, size, 0.75, 0.65) - 0.05), brow, v3(0, 0, 20))
	add(kit, "Block", v3(1, 0.3, 0.3), v3(-0.75, 0.58, front(center, size, -0.75, 0.58) - 0.05), brow, v3(0, 0, -20))
	mouth(kit, v3(1.1, 0.28, 0.25), v3(0, -0.8, front(center, size, 0, -0.8)))
	blush(kit, v3(0.8, 0.4, 0.2), v3(1.6, -0.5, front(center, size, 1.6, -0.5)))
	blush(kit, v3(0.8, 0.4, 0.2), v3(-1.6, -0.5, front(center, size, -1.6, -0.5) - 0.15))

	for _, x in ipairs({ 1.3, -1.3 }) do
		add(kit, "Oval", v3(0.8, 1, 0.8), v3(x, -2.1, -0.2), c.Legs)
	end

	-- Сзади — розовая наклейка-ценник
	add(kit, "Oval", v3(1.1, 0.7, 0.2), v3(0.8, -0.2, back(center, size, 0.8, -0.2) - 0.03), c.Sticker, v3(0, 0, 15))
end

-- 4. Noodle Ninja (Rare): стаканчик лапши — лапша торчит сверху, тёмная повязка ниндзя
-- с хвостами, две палочки
function Builders.NoodleNinja(kit: Kit)
	local c = Colors.NoodleNinja
	local cup = v3(0, -0.7, 0)
	local radius = 1.8
	add(kit, "Cylinder", v3(3.8, radius * 2, radius * 2), cup, c.Cup, UP)
	shade(kit, "Cylinder", v3(3.7, 3.5, 3.5), v3(-0.2, -0.72, 0.02), c.Cup, UP)
	add(kit, "Cylinder", v3(0.35, 3.85, 3.85), v3(0, 1.05, 0), c.Rim, UP)
	gloss(kit, v3(0.45, 1.6, 0.25), v3(1.1, -0.6, frontRound(cup, radius, 1.1) - 0.05), v3(0, -38, 0))

	-- Лапша: шапка сверху и две торчащие пряди
	add(kit, "Oval", v3(3.4, 1.4, 3.4), v3(0, 1.35, 0), c.Noodles)
	add(kit, "Oval", v3(0.35, 1.6, 0.35), v3(-0.6, 2.1, -0.3), c.Noodles, v3(0, 0, 20))
	add(kit, "Oval", v3(0.35, 1.4, 0.35), v3(0.5, 2.15, 0.3), c.Noodles, v3(0, 0, -25))

	-- Палочки торчат из лапши
	add(kit, "Cylinder", v3(3.4, 0.22, 0.22), v3(1.1, 2.4, 0.5), c.Sticks, v3(0, 0, 70))
	add(kit, "Cylinder", v3(3.4, 0.22, 0.22), v3(1.45, 2.25, 0.1), c.Sticks, v3(0, 0, 62))

	-- Повязка ниндзя на уровне глаз и два хвоста сзади
	local bandRadius = 1.85
	add(kit, "Cylinder", v3(1.1, bandRadius * 2, bandRadius * 2), v3(0, 0.15, 0), c.Band, UP)
	add(kit, "Block", v3(0.2, 0.4, 1.5), v3(-0.35, 0.1, 2.4), c.Band, v3(15, -20, 0))
	add(kit, "Block", v3(0.2, 0.4, 1.5), v3(0.35, 0, 2.35), c.Band, v3(-10, 20, 0))

	eye(kit, v3(0.7, 0.2, frontRound(cup, bandRadius, 0.7)), 1.15, v2(0.3, 0))
	eye(kit, v3(-0.72, 0.15, frontRound(cup, bandRadius, -0.72)), 0.85, v2(0.3, 0))
	mouth(kit, v3(0.7, 0.3, 0.25), v3(0, -0.9, frontRound(cup, radius, 0)), v3(0, 0, 10))
	blush(kit, v3(0.7, 0.38, 0.2), v3(1, -0.55, frontRound(cup, radius, 1) - 0.05))
	blush(kit, v3(0.7, 0.38, 0.2), v3(-1, -0.55, frontRound(cup, radius, -1) - 0.2))
end

-- 5. Captain Sockbeard (Rare): голубой носок с белыми полосками, чёрная треуголка с жёлтой точкой,
-- повязка на глаз, белая борода зубцами, жёлтая серьга
function Builders.CaptainSockbeard(kit: Kit)
	local c = Colors.CaptainSockbeard
	local leg = v3(0, 0.2, 0.2)
	local radius = 1.5
	add(kit, "Cylinder", v3(3.4, radius * 2, radius * 2), leg, c.Sock, UP)
	shade(kit, "Cylinder", v3(3.3, 2.92, 2.92), v3(-0.18, 0.2, 0.22), c.Sock, UP)
	add(kit, "Oval", v3(2.9, 1.6, 3.2), v3(0, -1.8, -0.3), c.Sock) -- стопа носком вперёд
	add(kit, "Cylinder", v3(0.35, 3.1, 3.1), v3(0, 1.45, 0.2), c.Stripes, UP)
	add(kit, "Cylinder", v3(0.35, 3.1, 3.1), v3(0, 0.85, 0.2), c.Stripes, UP)
	gloss(kit, v3(0.3, 1, 0.2), v3(1.3, -0.6, frontRound(leg, radius, 1.3) - 0.03), v3(0, -60, 0))

	-- Треуголка: поля ромбом (угол вперёд), верх и жёлтая точка
	add(kit, "Block", v3(3, 0.3, 3), v3(0, 2.05, 0.2), c.Hat, v3(0, 45, 0))
	add(kit, "Oval", v3(2.6, 1.5, 2.4), v3(0, 2.5, 0.2), c.Hat)
	add(kit, "Ball", v3(0.5, 0.5, 0.5), v3(0, 2.55, -1.05), c.HatDot)

	-- Один глаз открыт (большой), второй под повязкой; ремешок повязки наискосок вокруг носка
	eye(kit, v3(0.6, 0, frontRound(leg, radius, 0.6)), 1.15, v2(-0.2, 0.1))
	add(kit, "Oval", v3(0.95, 0.85, 0.3), v3(-0.6, 0.05, frontRound(leg, radius, -0.6) - 0.05), c.Patch)
	add(kit, "Cylinder", v3(0.15, 3.1, 3.1), v3(0, 0.35, 0.2), c.Patch, v3(0, 0, 116.6))

	-- Борода: основа и три зубца, лежит на стопе
	add(kit, "Oval", v3(2.2, 0.9, 0.8), v3(0, -0.85, -1.35), c.Beard)
	for _, x in ipairs({ 0.65, 0, -0.65 }) do
		add(kit, "Wedge", v3(0.3, 0.8, 0.7), v3(x, -1.35, -1.75), c.Beard, TRIANGLE_DOWN)
	end
	add(kit, "Ball", v3(0.45, 0.45, 0.45), v3(1.6, -0.3, 0.2), c.Earring)
	blush(kit, v3(0.65, 0.35, 0.2), v3(1.1, -0.4, frontRound(leg, radius, 1.1) - 0.05))
	blush(kit, v3(0.65, 0.35, 0.2), v3(-1.1, -0.4, frontRound(leg, radius, -1.1) - 0.2))
end

-- 6. Disco Pickle (Epic): огурец с пупырышками, розовые очки-звёзды, широкая улыбка,
-- руки вверх, рядом гранёный диско-шар на нитке
function Builders.DiscoPickle(kit: Kit)
	local c = Colors.DiscoPickle
	local center, size = v3(0, 0, 0), v3(3.4, 5.2, 3.2)
	add(kit, "Oval", size, center, c.Body)
	shade(kit, "Oval", v3(3.35, 5.1, 3.1), v3(-0.2, -0.02, 0.02), c.Body)
	gloss(kit, v3(0.35, 1.3, 0.22), v3(1.2, -1, front(center, size, 1.2, -1) - 0.02), v3(0, -45, 0))
	add(kit, "Ball", v3(0.4, 0.4, 0.4), v3(1.1, -1.9, front(center, size, 1.1, -1.9)), c.Bumps)
	add(kit, "Ball", v3(0.4, 0.4, 0.4), v3(-0.9, -1.4, front(center, size, -0.9, -1.4) - 0.1), c.Bumps)

	-- Очки-звёзды: пять розовых лучей-ромбов вокруг каждого глаза (середину звезды закрывает глаз)
	for _, lens in ipairs({
		{ X = 0.65, Y = 1.2, Size = 1.25, Eye = 0.85 },
		{ X = -0.62, Y = 1.15, Size = 1.05, Eye = 0.68 },
	}) do
		local ray = lens.Size * 0.4
		for k = 0, 4 do
			local angle = 90 + k * 72 -- первый луч смотрит вверх
			local rx = lens.X + math.cos(math.rad(angle)) * lens.Size * 0.38
			local ry = lens.Y + math.sin(math.rad(angle)) * lens.Size * 0.38
			-- Квадрат, повёрнутый на angle + 45°, смотрит углом наружу — это кончик луча
			add(kit, "Block", v3(ray, ray, 0.3), v3(rx, ry, front(center, size, rx, ry) - 0.02), c.Glasses, v3(0, 0, angle + 45))
		end
		eye(kit, v3(lens.X, lens.Y, front(center, size, lens.X, lens.Y) - 0.12), lens.Eye, v2(0, 0.3))
	end
	mouth(kit, v3(1.5, 0.55, 0.3), v3(0, -0.15, front(center, size, 0, -0.15)))
	blush(kit, v3(0.7, 0.35, 0.2), v3(1, 0.3, front(center, size, 1, 0.3)))
	blush(kit, v3(0.7, 0.35, 0.2), v3(-1, 0.3, front(center, size, -1, 0.3) - 0.15))

	-- Обе руки подняты вверх, на концах — ладошки
	for _, side in ipairs({ 1, -1 }) do
		add(kit, "Oval", v3(0.7, 2, 0.7), v3(side * 1.85, 1.5, 0), c.Body, v3(0, 0, side * -30))
		add(kit, "Ball", v3(0.75, 0.75, 0.75), v3(side * 2.4, 2.45, 0), c.Body)
	end
	-- Над левой ладошкой — крупный гранёный диско-шар на нитке
	add(kit, "Cylinder", v3(1, 0.08, 0.08), v3(2.4, 3.3, 0), c.String, UP)
	local ball = add(kit, "Block", v3(1.5, 1.5, 1.5), v3(2.4, 4.4, 0), c.DiscoBall, v3(35, 45, 0))
	ball.Reflectance = 0.3 -- гранёный и блестящий

	-- Сзади — пупырышки, как у настоящего огурца
	add(kit, "Ball", v3(0.45, 0.45, 0.45), v3(0.7, 0.6, back(center, size, 0.7, 0.6)), c.Bumps)
	add(kit, "Ball", v3(0.45, 0.45, 0.45), v3(-0.5, -0.9, back(center, size, -0.5, -0.9)), c.Bumps)
	add(kit, "Ball", v3(0.4, 0.4, 0.4), v3(0.2, 1.8, back(center, size, 0.2, 1.8)), c.Bumps)
end

-- 7. Professor Bonk (Epic): молоток-профессор — рукоять и боёк, круглые очки, усы,
-- шапочка выпускника с кисточкой, шишка на голове
function Builders.ProfessorBonk(kit: Kit)
	local c = Colors.ProfessorBonk
	-- Коричневая рукоять с тёмной обмоткой (обмотку видно со всех сторон)
	add(kit, "Cylinder", v3(3, 1, 1), v3(0, -1.3, 0), c.Handle, UP)
	add(kit, "Cylinder", v3(0.3, 1.1, 1.1), v3(0, -1.75, 0), c.Cap, UP)
	-- Боёк короче и толще: на нём крупное лицо. Лежит вдоль X, серо-стальной
	local head = v3(0, 1, 0)
	local radius = 1.5
	local length = 3.4
	add(kit, "Cylinder", v3(length, radius * 2, radius * 2), head, c.Head)
	shade(kit, "Cylinder", v3(0.3, radius * 2 + 0.02, radius * 2 + 0.02), v3(-length / 2 + 0.14, head.Y, 0), c.Head) -- тёмный торец справа
	gloss(kit, v3(1.2, 0.3, 0.25), v3(0.9, 2.2, -0.92), v3(53, 0, 0))

	-- Лицо на бойке: глубина поверхности зависит только от высоты (цилиндр вдоль X)
	local function faceZ(y: number): number
		local dy = y - head.Y
		return head.Z - math.sqrt(math.max(0, radius * radius - dy * dy))
	end
	-- Крупные круглые очки: тёмный диск за белком — видна оправа
	for _, glass in ipairs({ { X = 0.8, Y = 1.2, Eye = 1.4 }, { X = -0.8, Y = 1.25, Eye = 1.1 } }) do
		local z = faceZ(glass.Y)
		add(kit, "Cylinder", v3(0.12, glass.Eye * 1.26, glass.Eye * 1.26), v3(glass.X, glass.Y, z - 0.03), c.Glasses, ALONG_Z)
		eye(kit, v3(glass.X, glass.Y, z), glass.Eye, v2(-0.2, 0.2))
	end
	-- Пышные тёмные усы с закрученными кончиками
	add(kit, "Oval", v3(1.5, 0.55, 0.45), v3(0.6, 0.3, faceZ(0.3)), c.Mustache, v3(0, 0, 15))
	add(kit, "Oval", v3(1.5, 0.55, 0.45), v3(-0.6, 0.3, faceZ(0.3)), c.Mustache, v3(0, 0, -15))
	add(kit, "Ball", v3(0.4, 0.4, 0.4), v3(1.32, 0.42, faceZ(0.42) + 0.05), c.Mustache)
	add(kit, "Ball", v3(0.4, 0.4, 0.4), v3(-1.32, 0.42, faceZ(0.42) + 0.05), c.Mustache)
	blush(kit, v3(0.55, 0.3, 0.2), v3(1.15, -0.1, faceZ(-0.1) - 0.05))
	blush(kit, v3(0.55, 0.3, 0.2), v3(-1.15, -0.1, faceZ(-0.1) - 0.05))

	-- Шапочка выпускника: тулья, доска ромбом, кисточка сбоку
	add(kit, "Cylinder", v3(0.6, 1.9, 1.9), v3(0, 2.65, 0), c.Cap, UP)
	add(kit, "Block", v3(2.8, 0.18, 2.8), v3(0, 3, 0), c.Cap, v3(0, 45, 0))
	add(kit, "Block", v3(0.1, 0.9, 0.1), v3(1.9, 2.5, 0), c.Tassel)
	add(kit, "Ball", v3(0.35, 0.35, 0.35), v3(1.9, 2, 0), c.Tassel)
	add(kit, "Oval", v3(0.9, 0.7, 0.9), v3(-1.2, 2.45, -0.4), c.Bump) -- шишка
end

-- 8. Mega Snoozeasaurus (Legendary): золотой сидящий динозавр — тело со светлым брюхом, отдельная голова
-- с мордой, глаза закрыты дугами, корона на голове, ряд оранжевых шипов по спине до хвоста,
-- пузырь из носа, над ним «Z z z». Крупнее остальных — за счёт размера редкости (RarityScale)
function Builders.MegaSnoozeasaurus(kit: Kit)
	local c = Colors.MegaSnoozeasaurus
	local body, bodySize = v3(0, -1.05, 0.5), v3(4, 3.2, 4.4)
	add(kit, "Oval", bodySize, body, c.Body)
	shade(kit, "Oval", v3(3.9, 3.1, 4.3), v3(-0.22, -1.08, 0.52), c.Body)
	add(kit, "Oval", v3(2.6, 2.2, 1), v3(0, -1.25, front(body, bodySize, 0, -1.25) + 0.2), c.Belly)
	for _, x in ipairs({ 1.3, -1.3 }) do
		add(kit, "Oval", v3(1.2, 0.8, 1.5), v3(x, -2.25, -1.2), c.Body) -- лапы
	end

	-- Шея и голова спереди сверху, морда вытянута к зрителю
	add(kit, "Oval", v3(1.6, 1.4, 1.6), v3(0, 0.1, -0.7), c.Body)
	local head, headSize = v3(0, 1.05, -1), v3(2.8, 2.2, 2.6)
	add(kit, "Oval", headSize, head, c.Body)
	local snout, snoutSize = v3(0, 0.65, -2.1), v3(2, 1.3, 1.8)
	add(kit, "Oval", snoutSize, snout, c.Body)
	gloss(kit, v3(0.8, 0.3, 0.22), v3(0.75, 1.85, front(head, headSize, 0.75, 1.85) - 0.02), v3(40, 0, -30))
	mouth(kit, v3(0.9, 0.15, 0.15), v3(0, 0.3, front(snout, snoutSize, 0, 0.3))) -- сонная улыбка

	-- Закрытые глаза — крупные дуги из двух чёрточек над мордой
	for _, x in ipairs({ 0.6, -0.6 }) do
		local y = 1.35
		local half = 0.34
		local z = front(head, headSize, x, y) - 0.03
		local stroke = v3(half / math.cos(math.rad(25)), 0.18, 0.18)
		mouth(kit, stroke, v3(x + half / 2, y + 0.07, z), v3(0, 0, 25))
		mouth(kit, stroke, v3(x - half / 2, y + 0.07, z), v3(0, 0, -25))
	end
	local bubble = add(kit, "Ball", v3(0.8, 0.8, 0.8), v3(0.6, 0.75, -3.25), c.Bubble)
	bubble.Transparency = 0.35
	blush(kit, v3(0.55, 0.3, 0.2), v3(1.05, 0.95, front(head, headSize, 1.05, 0.95)))
	blush(kit, v3(0.55, 0.3, 0.2), v3(-1.05, 0.95, front(head, headSize, -1.05, 0.95) - 0.1))

	-- Корона на макушке: обруч, четыре зубца по краю, камень спереди
	add(kit, "Cylinder", v3(0.5, 1.4, 1.4), v3(0, 2.3, -0.9), c.Crown, UP)
	for _, p in ipairs({ v3(0.45, 2.65, -1.35), v3(-0.45, 2.65, -1.35), v3(0.45, 2.65, -0.45), v3(-0.45, 2.65, -0.45) }) do
		add(kit, "Ball", v3(0.38, 0.38, 0.38), p, c.Crown)
	end
	add(kit, "Ball", v3(0.4, 0.4, 0.4), v3(0, 2.35, -1.6), c.Jewel)

	-- Ряд оранжевых шипов по спине: от затылка к хвосту, всё мельче
	for _, s in ipairs({ { Z = 0.6, Size = 0.95 }, { Z = 1.3, Size = 0.9 }, { Z = 1.95, Size = 0.8 }, { Z = 2.45, Size = 0.65 } }) do
		local dz = (s.Z - body.Z) / (bodySize.Z / 2)
		local top = body.Y + bodySize.Y / 2 * math.sqrt(math.max(0, 1 - dz * dz))
		spike(kit, s.Size, v3(0, top, s.Z), c.Spikes)
	end

	-- Хвост сзади, загибается вправо; на нём последний шип
	add(kit, "Oval", v3(1.4, 1.1, 2.4), v3(-0.6, -2, 2.9), c.Body, v3(0, -25, 0))
	add(kit, "Oval", v3(0.8, 0.7, 1.4), v3(-1.4, -2.25, 3.9), c.Body, v3(0, -50, 0))
	spike(kit, 0.5, v3(-0.65, -1.45, 3), c.Spikes, -25)

	-- «Z z z» над головой: подпись в мире, не Label (Label меняют постаменты и прячет переноска)
	local snooze = StyleConfig.Memeling.Snooze
	local gui = Instance.new("BillboardGui")
	gui.Name = "Snooze"
	gui.Size = UDim2.fromScale(snooze.WidthStuds, snooze.HeightStuds)
	gui.StudsOffsetWorldSpace = snooze.Offset
	gui.MaxDistance = snooze.MaxDistance
	gui.Parent = kit.Core
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = StyleConfig.Fonts.Label
	text.TextColor3 = snooze.Text
	text.TextStrokeColor3 = snooze.Stroke
	text.TextStrokeTransparency = 0
	text.Text = TextConfig.SnoozeLetters
	text.Parent = gui
end

-- ── Golden Zone ────────────────────────────────────────────────────────────

-- 9. Bubble Tea Bandit (Rare): стакан бабл-ти в маске грабителя, на дне шарики тапиоки, толстая трубочка,
-- сзади хвосты маски
function Builders.BubbleTeaBandit(kit: Kit)
	local c = Colors.BubbleTeaBandit
	local cup = v3(0, -0.5, 0)
	local radius = 1.8
	add(kit, "Cylinder", v3(4.2, radius * 2, radius * 2), cup, c.Tea, UP)
	shade(kit, "Cylinder", v3(4.1, 3.5, 3.5), v3(-0.2, -0.52, 0.02), c.Tea, UP)
	gloss(kit, v3(0.45, 1.8, 0.25), v3(1.1, -0.6, frontRound(cup, radius, 1.1) - 0.05), v3(0, -38, 0))
	add(kit, "Cylinder", v3(0.3, 3.9, 3.9), v3(0, 1.6, 0), c.Lid, UP)
	add(kit, "Oval", v3(3.7, 1.3, 3.7), v3(0, 1.75, 0), c.Lid)
	add(kit, "Cylinder", v3(3.2, 0.55, 0.55), v3(0.55, 3.1, 0.3), c.Straw, v3(0, 0, 78))

	-- Шарики тапиоки на дне (видны спереди)
	for _, p in ipairs({ v2(-0.8, -2.15), v2(0.1, -2.25), v2(0.95, -2.1), v2(-0.35, -1.65), v2(0.55, -1.6) }) do
		add(kit, "Ball", v3(0.62, 0.62, 0.62), v3(p.X, p.Y, frontRound(cup, radius, p.X) + 0.1), c.Pearls)
	end

	-- Маска грабителя: тёмная повязка на уровне глаз, глаза — поверх неё
	local maskRadius = 1.86
	add(kit, "Cylinder", v3(1, maskRadius * 2, maskRadius * 2), v3(0, 0.45, 0), c.Mask, UP)
	add(kit, "Block", v3(0.2, 0.45, 1.5), v3(-0.35, 0.4, 2.4), c.Mask, v3(15, -20, 0))
	add(kit, "Block", v3(0.2, 0.45, 1.5), v3(0.35, 0.3, 2.35), c.Mask, v3(-10, 20, 0))
	eye(kit, v3(0.65, 0.5, frontRound(cup, maskRadius, 0.65)), 1.05, v2(-0.3, 0))
	eye(kit, v3(-0.7, 0.45, frontRound(cup, maskRadius, -0.7)), 0.85, v2(-0.3, 0))
	-- Ухмылка: рот наискосок
	mouth(kit, v3(0.9, 0.25, 0.25), v3(0.1, -0.55, frontRound(cup, radius, 0.1)), v3(0, 0, -12))
	blush(kit, v3(0.7, 0.38, 0.2), v3(1.05, -0.35, frontRound(cup, radius, 1.05) - 0.05))
	blush(kit, v3(0.7, 0.38, 0.2), v3(-1.05, -0.35, frontRound(cup, radius, -1.05) - 0.2))
end

-- 10. Cactus Crooner (Rare): кактус в горшке и шляпе, одна рука поднята, второй держит микрофон у рта,
-- рот открыт — поёт; сзади цветок
function Builders.CactusCrooner(kit: Kit)
	local c = Colors.CactusCrooner
	add(kit, "Cylinder", v3(1.4, 3.2, 3.2), v3(0, -2, 0), c.Pot, UP)
	add(kit, "Cylinder", v3(0.35, 3.5, 3.5), v3(0, -1.35, 0), c.Pot, UP)
	local center, size = v3(0, -0.2, 0), v3(2.8, 4.4, 2.8)
	add(kit, "Oval", size, center, c.Body)
	shade(kit, "Oval", v3(2.74, 4.3, 2.7), v3(-0.18, -0.22, 0.02), c.Body)
	gloss(kit, v3(0.3, 1.2, 0.2), v3(0.85, 0.6, front(center, size, 0.85, 0.6) - 0.02), v3(0, -40, 0))
	for _, p in ipairs({ v2(1.05, -0.9), v2(-1.0, -1.2), v2(1.15, 0.2), v2(-1.15, 0.5) }) do
		add(kit, "Ball", v3(0.25, 0.25, 0.25), v3(p.X, p.Y, front(center, size, p.X, p.Y)), c.Spines)
	end

	-- Шляпа: поля, тулья и лента
	add(kit, "Cylinder", v3(0.25, 3.6, 3.6), v3(0, 2.0, 0), c.Hat, UP)
	add(kit, "Cylinder", v3(1.1, 2.2, 2.2), v3(0, 2.6, 0), c.Hat, UP)
	add(kit, "Cylinder", v3(0.3, 2.25, 2.25), v3(0, 2.25, 0), c.HatBand, UP)

	-- Поёт: глаза прищурены от удовольствия (один меньше), рот открыт «О»
	eye(kit, v3(0.55, 0.85, front(center, size, 0.55, 0.85)), 0.9, v2(0.2, 0.4))
	eye(kit, v3(-0.5, 0.9, front(center, size, -0.5, 0.9)), 0.7, v2(0.2, 0.4))
	mouth(kit, v3(0.7, 0.8, 0.3), v3(0, -0.2, front(center, size, 0, -0.2)))
	blush(kit, v3(0.55, 0.3, 0.2), v3(0.95, 0.3, front(center, size, 0.95, 0.3)))
	blush(kit, v3(0.55, 0.3, 0.2), v3(-0.95, 0.3, front(center, size, -0.95, 0.3) - 0.1))

	-- Правая рука вверх (как на сцене), левая — с микрофоном у рта
	add(kit, "Oval", v3(0.8, 1.9, 0.8), v3(-1.75, 0.9, 0), c.Body, v3(0, 0, 30))
	add(kit, "Oval", v3(0.8, 1.6, 0.8), v3(1.3, -0.8, -0.9), c.Body, v3(-50, 0, -20))
	add(kit, "Cylinder", v3(1.1, 0.35, 0.35), v3(0.75, -0.55, -1.75), c.Mic, UP)
	add(kit, "Ball", v3(0.75, 0.75, 0.75), v3(0.75, 0.05, -1.8), c.MicHead)

	-- Сзади — розовый цветок на макушке-боку
	add(kit, "Ball", v3(0.8, 0.8, 0.8), v3(0.5, 1.3, back(center, size, 0.5, 1.3)), c.Flower)
	add(kit, "Ball", v3(0.35, 0.35, 0.35), v3(0.5, 1.3, back(center, size, 0.5, 1.3) + 0.35), c.Spines)
end

-- 11. Pizza Pigeon (Epic): голубь, у которого тело — кусок пиццы (тесто, сыр, пепперони, корочка-хвост),
-- серая голова с бирюзовой шеей, крылья по бокам, розовые лапки
function Builders.PizzaPigeon(kit: Kit)
	local c = Colors.PizzaPigeon
	local body, bodySize = v3(0, -1.2, 0.4), v3(3.2, 2.4, 4.4)
	add(kit, "Oval", bodySize, body, c.Dough)
	shade(kit, "Oval", v3(3.1, 2.3, 4.3), v3(-0.2, -1.22, 0.42), c.Dough)
	add(kit, "Oval", v3(2.9, 0.7, 4), v3(0, -0.15, 0.4), c.Cheese)
	for _, p in ipairs({ v3(0.7, 0.18, 0), v3(-0.6, 0.15, 0.9), v3(0.2, 0.12, 1.7) }) do
		add(kit, "Cylinder", v3(0.15, 0.85, 0.85), p, c.Pepperoni, UP)
	end
	-- Корочка — толстый валик сзади, за ней хвостовые перья
	add(kit, "Cylinder", v3(3, 1.1, 1.1), v3(0, -0.8, 2.5), c.Crust)
	add(kit, "Oval", v3(2, 0.3, 1.4), v3(0, -0.5, 3.4), c.Feathers, v3(-15, 0, 0))

	-- Голова и шея
	add(kit, "Cylinder", v3(0.8, 1.6, 1.6), v3(0, 0.25, -1.6), c.Neck, UP)
	local head, headSize = v3(0, 1.3, -1.9), v3(2.2, 2.1, 2.2)
	add(kit, "Oval", headSize, head, c.Feathers)
	gloss(kit, v3(0.6, 0.25, 0.2), v3(0.6, 2.0, front(head, headSize, 0.6, 2.0) - 0.02), v3(40, 0, -30))
	add(kit, "Oval", v3(0.6, 0.4, 1), v3(0, 1.0, front(head, headSize, 0, 1.0) - 0.3), c.Beak)
	eye(kit, v3(0.5, 1.5, front(head, headSize, 0.5, 1.5)), 0.75, v2(0.3, 0))
	eye(kit, v3(-0.5, 1.55, front(head, headSize, -0.5, 1.55)), 0.6, v2(-0.3, 0.2))
	blush(kit, v3(0.45, 0.25, 0.15), v3(0.85, 1.1, front(head, headSize, 0.85, 1.1)))
	blush(kit, v3(0.45, 0.25, 0.15), v3(-0.85, 1.1, front(head, headSize, -0.85, 1.1) - 0.05))

	-- Крылья и лапки
	for _, x in ipairs({ 1.7, -1.7 }) do
		add(kit, "Oval", v3(0.6, 1.6, 2.6), v3(x, -0.9, 0.4), c.Feathers, v3(0, 0, if x > 0 then -15 else 15))
		add(kit, "Oval", v3(0.6, 0.4, 1), v3(x * 0.4, -2.45, -0.5), c.Feet)
	end
end

-- 12. Robo Duck (Epic): резиновая уточка-робот — визор с горящими глазами, антенна с огоньком,
-- заклёпки на щеках, сзади панель с болтами
function Builders.RoboDuck(kit: Kit)
	local c = Colors.RoboDuck
	local body, bodySize = v3(0, -1.2, 0.4), v3(4.2, 3.2, 4.8)
	add(kit, "Oval", bodySize, body, c.Body)
	shade(kit, "Oval", v3(4.1, 3.1, 4.7), v3(-0.22, -1.22, 0.42), c.Body)
	add(kit, "Oval", v3(1.6, 1.6, 1.6), v3(0, 0.2, 2.6), c.Body, v3(-30, 0, 0)) -- хвостик
	for _, x in ipairs({ 1.9, -1.9 }) do
		add(kit, "Oval", v3(0.6, 1.6, 2.6), v3(x, -1.0, 0.5), c.Body, v3(0, 0, if x > 0 then -15 else 15))
	end

	local head, headSize = v3(0, 1, -0.9), v3(3, 2.8, 2.8)
	add(kit, "Oval", headSize, head, c.Body)
	gloss(kit, v3(0.8, 0.3, 0.22), v3(0.8, 2.0, front(head, headSize, 0.8, 2.0) - 0.02), v3(40, 0, -30))
	add(kit, "Oval", v3(1.7, 0.7, 1.5), v3(0, 0.45, front(head, headSize, 0, 0.45) - 0.4), c.Beak)

	-- Визор: тёмная полоса, на ней два светящихся глаза разного размера с бликом
	local visorY = 1.35
	local visorZ = front(head, headSize, 0, visorY) - 0.05
	add(kit, "Oval", v3(2.6, 0.95, 0.5), v3(0, visorY, visorZ), c.Visor)
	for _, e in ipairs({ { X = 0.55, Size = 0.55 }, { X = -0.55, Size = 0.45 } }) do
		local glow = add(kit, "Ball", Vector3.one * e.Size, v3(e.X, visorY, visorZ - 0.2), c.VisorGlow)
		glow.Material = StyleConfig.GlowMaterial
		add(kit, "Ball", Vector3.one * e.Size * 0.3, v3(e.X + e.Size * 0.15, visorY + e.Size * 0.15, visorZ - 0.2 - e.Size * 0.4), StyleConfig.Memeling.Face.Glint)
	end
	for _, x in ipairs({ 1.2, -1.2 }) do
		add(kit, "Ball", v3(0.3, 0.3, 0.3), v3(x, 0.7, front(head, headSize, x, 0.7)), c.Metal) -- заклёпки
	end

	-- Антенна с огоньком
	add(kit, "Cylinder", v3(1.4, 0.16, 0.16), v3(0.4, 3.0, -0.8), c.Metal, UP)
	local tip = add(kit, "Ball", v3(0.5, 0.5, 0.5), v3(0.4, 3.8, -0.8), c.AntennaTip)
	tip.Material = StyleConfig.GlowMaterial

	-- Сзади — панель с болтами
	local panelY = -0.9
	add(kit, "Block", v3(1.6, 1.2, 0.2), v3(0, panelY, back(body, bodySize, 0, panelY) - 0.05), c.Metal)
	for _, p in ipairs({ v2(0.6, 0.4), v2(-0.6, 0.4), v2(0.6, -0.4), v2(-0.6, -0.4) }) do
		add(kit, "Ball", v3(0.2, 0.2, 0.2), v3(p.X, panelY + p.Y, back(body, bodySize, 0, panelY) + 0.08), c.Visor)
	end
end

-- 13. King Waffleton (Legendary): вафля-король — квадратная вафля с решёткой, корона с камнем,
-- кусочек масла, скипетр, за спиной плащ из сиропа с каплями
function Builders.KingWaffleton(kit: Kit)
	local c = Colors.KingWaffleton
	add(kit, "Block", v3(4.2, 4.4, 1.4), v3(0, -0.3, 0), c.Waffle)
	shade(kit, "Block", v3(0.4, 4.4, 1.36), v3(-1.95, -0.3, 0), c.Waffle)
	gloss(kit, v3(1.2, 0.3, 0.15), v3(1.1, 1.6, -0.75), v3(0, 0, -25))
	-- Решётка вафли спереди: два ряда и две колонны выпуклых брусков
	for _, x in ipairs({ -0.75, 0.75 }) do
		add(kit, "Block", v3(0.3, 4.2, 0.2), v3(x, -0.3, -0.75), c.Grid)
	end
	for _, y in ipairs({ -1.5, 0.1 }) do
		add(kit, "Block", v3(4, 0.3, 0.2), v3(0, y, -0.75), c.Grid)
	end

	-- Лицо поверх решётки
	eye(kit, v3(0.75, 0.9, -0.95), 1.1, v2(0.2, 0.3))
	eye(kit, v3(-0.75, 0.95, -0.95), 0.9, v2(0.2, 0.3))
	mouth(kit, v3(1.2, 0.35, 0.25), v3(0, -0.7, -0.95))
	blush(kit, v3(0.7, 0.38, 0.15), v3(1.4, -0.2, -0.88))
	blush(kit, v3(0.7, 0.38, 0.15), v3(-1.4, -0.2, -0.88))

	-- Корона: обруч, четыре зубца, камень спереди; рядом кусочек масла
	add(kit, "Cylinder", v3(0.6, 2.2, 2.2), v3(0, 2.2, 0), c.Crown, UP)
	for _, p in ipairs({ v3(0.75, 2.65, -0.75), v3(-0.75, 2.65, -0.75), v3(0.75, 2.65, 0.75), v3(-0.75, 2.65, 0.75) }) do
		add(kit, "Ball", v3(0.45, 0.45, 0.45), p, c.Crown)
	end
	add(kit, "Ball", v3(0.5, 0.5, 0.5), v3(0, 2.2, -1.12), c.Jewel)
	add(kit, "Block", v3(1, 0.45, 0.9), v3(-1.5, 2.1, 0), c.Butter)

	-- Ручки и скипетр в левой
	add(kit, "Oval", v3(0.7, 1.5, 0.7), v3(2.3, -0.6, -0.2), c.Waffle, v3(0, 0, -20))
	add(kit, "Oval", v3(0.7, 1.5, 0.7), v3(-2.3, -0.6, -0.2), c.Waffle, v3(0, 0, 20))
	add(kit, "Cylinder", v3(3.2, 0.25, 0.25), v3(2.6, 0.4, -0.5), c.Crown, UP)
	add(kit, "Ball", v3(0.6, 0.6, 0.6), v3(2.6, 2.05, -0.5), c.Jewel)
	for _, x in ipairs({ 0.9, -0.9 }) do
		add(kit, "Oval", v3(1.1, 0.6, 1.3), v3(x, -2.3, -0.2), c.Waffle)
	end

	-- Плащ из сиропа за спиной, с каплями внизу
	local cape = add(kit, "Oval", v3(4.4, 4.6, 0.8), v3(0, -0.5, 0.95), c.Syrup)
	cape.Transparency = 0.1
	for _, x in ipairs({ -1.3, 0, 1.2 }) do
		add(kit, "Oval", v3(0.5, 0.9, 0.5), v3(x, -2.7, 1.05), c.Syrup)
	end
	add(kit, "Oval", v3(1.2, 0.4, 0.6), v3(0.8, 1.95, -0.55), c.Syrup) -- капля сиропа на макушке спереди
end

-- ── Секретный паркур ───────────────────────────────────────────────────────

-- 14. Error 404 Kitten (Secret): котик-кубик — глаза-пиксели разного размера с бликом, уши-квадратики,
-- «глитч»-полосы, торчащие вбок (переливаются), ротик из пикселей, хвост-лесенка, сзади надпись «404»
function Builders.Error404Kitten(kit: Kit)
	local c = Colors.Error404Kitten
	local bodySize = v3(4, 3.6, 3.6)
	local body = add(kit, "Block", bodySize, v3(0, -0.8, 0), c.Body)
	shade(kit, "Block", v3(0.4, 3.6, 3.56), v3(-1.82, -0.8, 0), c.Body)
	gloss(kit, v3(1.2, 0.3, 0.15), v3(1, 0.7, -1.82), v3(0, 0, -20))
	local face = -bodySize.Z / 2 - 0.05

	-- Уши-квадратики, повёрнутые на 45°
	for _, x in ipairs({ 1.2, -1.2 }) do
		add(kit, "Block", v3(1.1, 1.1, 0.8), v3(x, 1.05, -0.3), c.Ears, v3(0, 0, 45))
	end

	-- Глаза-пиксели: белый квадрат, тёмный квадрат-зрачок, белый пиксель-блик
	for _, e in ipairs({ { X = 0.85, Size = 1.05 }, { X = -0.85, Size = 0.8 } }) do
		add(kit, "Block", v3(e.Size, e.Size, 0.15), v3(e.X, -0.1, face), StyleConfig.Memeling.Face.EyeWhite)
		local pupil = e.Size * 0.5
		add(kit, "Block", v3(pupil, pupil, 0.15), v3(e.X - e.Size * 0.12, -0.15, face - 0.06), c.Pixel)
		add(kit, "Block", v3(pupil * 0.35, pupil * 0.35, 0.1), v3(e.X - e.Size * 0.02, -0.02, face - 0.12), StyleConfig.Memeling.Face.Glint)
	end
	-- Ротик «:3» из трёх пикселей
	for _, p in ipairs({ v2(0.22, -1.05), v2(-0.22, -1.05), v2(0, -1.3) }) do
		add(kit, "Block", v3(0.25, 0.25, 0.12), v3(p.X, p.Y, face), c.Pixel)
	end
	for _, x in ipairs({ 1.45, -1.45 }) do
		add(kit, "Block", v3(0.6, 0.35, 0.1), v3(x, -0.85, face), c.Blush)
	end

	-- «Глитч»-полосы: сдвинутые вбок тонкие светящиеся полоски, переливаются
	for _, g in ipairs({ { Y = 0.5, X = 0.5, Z = face - 0.02 }, { Y = -1.75, X = -0.6, Z = face - 0.02 }, { Y = -0.4, X = 0.3, Z = 1.85 } }) do
		local stripe = add(kit, "Block", v3(4.6, 0.18, 0.1), v3(g.X, g.Y, g.Z), c.Glitch)
		stripe.Material = StyleConfig.GlowMaterial
		MemelingKit.TagRainbow(stripe)
	end

	-- Лапки и хвост-лесенка из кубиков
	for _, x in ipairs({ 1.2, -1.2 }) do
		add(kit, "Block", v3(0.9, 0.5, 0.9), v3(x, -2.45, -0.9), c.Ears)
	end
	add(kit, "Block", v3(0.7, 0.7, 1.2), v3(0.8, -1.9, 2.3), c.Body)
	add(kit, "Block", v3(0.7, 1.4, 0.7), v3(0.8, -1.2, 2.75), c.Body)
	add(kit, "Block", v3(0.7, 0.7, 0.7), v3(0.8, -0.2, 3.1), c.Ears)

	-- Сзади — «404» на спине
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Error404"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = StyleConfig.Label.SignPixelsPerStud
	gui.Parent = body
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0.5)
	label.Position = UDim2.fromScale(0, 0.25)
	label.TextScaled = true
	label.Font = StyleConfig.Fonts.Label
	label.TextColor3 = c.Text
	label.Text = TextConfig.Error404Text
	label.Parent = gui
end

local MemelingBuilders = {}

-- Строит мемлинга по Id. Вернёт false, если строителя для такого Id нет
function MemelingBuilders.Build(memelingId: string, kit: Kit): boolean
	local build = Builders[memelingId]
	if build == nil then
		return false
	end
	build(kit)
	return true
end

-- Враг Grumblob: зелёный желейный шар с сердитыми бровями. body — шар-тело (уже создан), diameter — его размер
function MemelingBuilders.BuildEnemy(body: BasePart, cframe: CFrame, diameter: number)
	local c = Colors.Grumblob
	body.Color = c.Body
	local kit = MemelingKit.new(body, cframe)
	local size = Vector3.one * diameter
	local r = diameter / 2
	shade(kit, "Oval", size * v3(0.98, 0.98, 0.97), v3(-r * 0.08, 0, 0.02), c.Body)
	gloss(kit, v3(1.3, 0.55, 0.25), v3(1.1, 1.4, front(Vector3.zero, size, 1.1, 1.4) - 0.02), v3(0, 0, -40))

	eye(kit, v3(0.85, 0.55, front(Vector3.zero, size, 0.85, 0.55)), 1.5, v2(-0.3, -0.2))
	eye(kit, v3(-0.85, 0.5, front(Vector3.zero, size, -0.85, 0.5)), 1.1, v2(0.3, -0.2))
	-- Сердитые брови: внутренние концы ниже
	add(kit, "Block", v3(1.5, 0.35, 0.4), v3(0.85, 1.45, front(Vector3.zero, size, 0.85, 1.45) - 0.05), c.Brow, v3(0, 0, 20))
	add(kit, "Block", v3(1.3, 0.35, 0.4), v3(-0.85, 1.3, front(Vector3.zero, size, -0.85, 1.3) - 0.05), c.Brow, v3(0, 0, -20))
	mouth(kit, v3(1.3, 0.3, 0.3), v3(0, -0.6, front(Vector3.zero, size, 0, -0.6)))
	blush(kit, v3(0.8, 0.4, 0.2), v3(1.45, -0.15, front(Vector3.zero, size, 1.45, -0.15)))
	blush(kit, v3(0.8, 0.4, 0.2), v3(-1.45, -0.15, front(Vector3.zero, size, -1.45, -0.15) - 0.15))
end

return MemelingBuilders
