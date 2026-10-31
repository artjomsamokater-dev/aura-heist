--!strict
-- MemelingBuilders: модели 8 мемлингов и врага Grumblob в стиле «D · Микс» (задача 5.4).
-- У каждого персонажа своя функция-строитель: она добавляет детали к невидимому ядру через MemelingKit.
-- Цвета — StyleConfig.Characters, общие размеры и цвета лица — StyleConfig.Memeling.
--
-- Места — от центра мемлинга (габарит 6 × 6 × 6): низ −3, кольцо редкости до −2,6, на нём стоят ноги.
-- −Z — лицо, +X — слева для зрителя (блик), −X — справа (тень). Деталей — не больше ~25 на мемлинга.

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
local TRIANGLE_UP = MemelingKit.TRIANGLE_UP
local TRIANGLE_DOWN = MemelingKit.TRIANGLE_DOWN

local Colors = StyleConfig.Characters

local Builders: { [string]: (kit: Kit) -> () } = {}

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

	-- Сердитое лицо: брови к переносице, рот чёрточкой
	eye(kit, v3(1, 0.05, front(center, size, 1, 0.05)), 1.05, v2(0, -0.2))
	eye(kit, v3(-1, 0, front(center, size, -1, 0)), 0.8, v2(0, -0.2))
	local brow = StyleConfig.Memeling.Face.Mouth
	add(kit, "Block", v3(1.15, 0.3, 0.3), v3(1, 0.72, front(center, size, 1, 0.72) - 0.05), brow, v3(0, 0, 20))
	add(kit, "Block", v3(1.15, 0.3, 0.3), v3(-1, 0.62, front(center, size, -1, 0.62) - 0.05), brow, v3(0, 0, -20))
	mouth(kit, v3(1.2, 0.28, 0.25), v3(0, -0.85, front(center, size, 0, -0.85)))
	blush(kit, v3(0.8, 0.4, 0.2), v3(1.75, -0.55, front(center, size, 1.75, -0.55)))
	blush(kit, v3(0.8, 0.4, 0.2), v3(-1.75, -0.55, front(center, size, -1.75, -0.55) - 0.15))

	for _, x in ipairs({ 1.3, -1.3 }) do
		add(kit, "Oval", v3(0.8, 1, 0.8), v3(x, -2.1, -0.2), c.Legs)
	end
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

	-- Очки-звёзды (два квадрата под 45° — восьмиконечная звезда), глаза поверх стёкол
	for _, lens in ipairs({
		{ X = 0.65, Y = 1.2, Size = 1.15, Eye = 0.85, Turn = -25 },
		{ X = -0.6, Y = 1.15, Size = 0.9, Eye = 0.65, Turn = 25 },
	}) do
		local z = front(center, size, lens.X, lens.Y)
		local star = v3(lens.Size, lens.Size, 0.2)
		add(kit, "Block", star, v3(lens.X, lens.Y, z - 0.05), c.Glasses, v3(0, lens.Turn, 0))
		add(kit, "Block", star, v3(lens.X, lens.Y, z - 0.05), c.Glasses, v3(0, lens.Turn, 45))
		eye(kit, v3(lens.X, lens.Y, z - 0.1), lens.Eye, v2(0, 0.3))
	end
	mouth(kit, v3(1.5, 0.55, 0.3), v3(0, -0.15, front(center, size, 0, -0.15)))
	blush(kit, v3(0.7, 0.35, 0.2), v3(1, 0.35, front(center, size, 1, 0.35)))
	blush(kit, v3(0.7, 0.35, 0.2), v3(-1, 0.35, front(center, size, -1, 0.35) - 0.15))

	-- Руки вверх, в левой — нитка с диско-шаром
	add(kit, "Oval", v3(0.6, 1.9, 0.6), v3(1.75, 1.6, 0), c.Body, v3(0, 0, -25))
	add(kit, "Oval", v3(0.6, 1.9, 0.6), v3(-1.75, 1.6, 0), c.Body, v3(0, 0, 25))
	add(kit, "Cylinder", v3(1.3, 0.08, 0.08), v3(2.4, 1.85, 0), c.String, UP)
	local ball = add(kit, "Block", v3(1, 1, 1), v3(2.45, 0.75, -0.2), c.DiscoBall, v3(35, 45, 0))
	ball.Reflectance = 0.3 -- гранёный и блестящий
end

-- 7. Professor Bonk (Epic): молоток-профессор — рукоять и боёк, круглые очки, усы,
-- шапочка выпускника с кисточкой, шишка на голове
function Builders.ProfessorBonk(kit: Kit)
	local c = Colors.ProfessorBonk
	add(kit, "Cylinder", v3(3, 1, 1), v3(0, -1.1, 0), c.Handle, UP)
	local head = v3(0, 1.2, 0)
	local radius = 1.3
	add(kit, "Cylinder", v3(4.4, radius * 2, radius * 2), head, c.Head) -- боёк лежит вдоль X
	shade(kit, "Cylinder", v3(0.3, 2.62, 2.62), v3(-2.1, 1.2, 0), c.Head) -- тёмный торец справа
	gloss(kit, v3(1.4, 0.3, 0.25), v3(1.3, 2.32, -0.72), v3(58, 0, 0))

	-- Лицо на бойке: глубина поверхности зависит только от высоты (цилиндр вдоль X)
	local function faceZ(y: number): number
		local dy = y - head.Y
		return head.Z - math.sqrt(math.max(0, radius * radius - dy * dy))
	end
	-- Круглые очки: тёмный диск за белком — видна оправа
	for _, glass in ipairs({ { X = 0.75, Y = 1.35, Eye = 1.15 }, { X = -0.75, Y = 1.4, Eye = 0.9 } }) do
		local z = faceZ(glass.Y)
		add(kit, "Cylinder", v3(0.12, glass.Eye * 1.26, glass.Eye * 1.26), v3(glass.X, glass.Y, z - 0.03), c.Glasses, ALONG_Z)
		eye(kit, v3(glass.X, glass.Y, z), glass.Eye, v2(-0.2, 0.2))
	end
	add(kit, "Oval", v3(1.1, 0.4, 0.35), v3(0.45, 0.6, faceZ(0.6)), c.Mustache, v3(0, 0, 15))
	add(kit, "Oval", v3(1.1, 0.4, 0.35), v3(-0.45, 0.6, faceZ(0.6)), c.Mustache, v3(0, 0, -15))
	blush(kit, v3(0.6, 0.32, 0.2), v3(1.45, 0.85, faceZ(0.85) - 0.05))
	blush(kit, v3(0.6, 0.32, 0.2), v3(-1.45, 0.85, faceZ(0.85) - 0.05))

	-- Шапочка выпускника: тулья, доска ромбом, кисточка сбоку
	add(kit, "Cylinder", v3(0.6, 1.9, 1.9), v3(0, 2.6, 0), c.Cap, UP)
	add(kit, "Block", v3(2.8, 0.18, 2.8), v3(0, 2.95, 0), c.Cap, v3(0, 45, 0))
	add(kit, "Block", v3(0.1, 0.9, 0.1), v3(1.9, 2.45, 0), c.Tassel)
	add(kit, "Ball", v3(0.35, 0.35, 0.35), v3(1.9, 1.95, 0), c.Tassel)
	add(kit, "Oval", v3(0.9, 0.7, 0.9), v3(-1.3, 2.45, -0.3), c.Bump) -- шишка
end

-- 8. Mega Snoozeasaurus (Legendary): золотой свернувшийся динозавр — светлое брюхо, оранжевые шипы
-- на спине, корона, глаза закрыты дугами, пузырь из носа, над ним «Z z z»
function Builders.MegaSnoozeasaurus(kit: Kit)
	local c = Colors.MegaSnoozeasaurus
	local body, bodySize = v3(0, -0.9, 0.4), v3(4.8, 3.4, 4)
	add(kit, "Oval", bodySize, body, c.Body)
	shade(kit, "Oval", v3(4.7, 3.3, 3.9), v3(-0.25, -0.93, 0.42), c.Body)
	add(kit, "Oval", v3(3, 2.2, 1.4), v3(-0.5, -1.3, -1.05), c.Belly)

	-- Хвост обвивает тело спереди справа
	add(kit, "Oval", v3(2.2, 1.3, 1.6), v3(-1.9, -1.8, -1.1), c.Body, v3(0, 30, 0))
	add(kit, "Oval", v3(1.3, 0.9, 1), v3(-0.9, -2.1, -1.9), c.Body, v3(0, 60, 0))

	-- Шипы по спине
	for _, x in ipairs({ 1.8, -0.5, -1.3, -2 }) do
		local dx = x / (bodySize.X / 2)
		local top = body.Y + bodySize.Y / 2 * math.sqrt(math.max(0, 1 - dx * dx))
		add(kit, "Wedge", v3(0.3, 1, 1), v3(x, top + 0.3, 0.6), c.Spikes, TRIANGLE_UP)
	end

	-- Голова лежит спереди слева
	local head, headSize = v3(0.6, 0.4, -1.3), v3(2.6, 2.2, 2.4)
	add(kit, "Oval", headSize, head, c.Body)
	gloss(kit, v3(0.9, 0.35, 0.22), v3(1.25, 1.2, front(head, headSize, 1.25, 1.2) - 0.02), v3(40, 0, -30))

	-- Корона: обруч и три зубца, в середине — камень
	add(kit, "Cylinder", v3(0.6, 1.3, 1.3), v3(0.7, 1.7, -1.2), c.Crown, UP)
	add(kit, "Ball", v3(0.35, 0.35, 0.35), v3(0.25, 2.1, -1.25), c.Crown)
	add(kit, "Ball", v3(0.4, 0.4, 0.4), v3(0.7, 2.15, -1.25), c.Jewel)
	add(kit, "Ball", v3(0.35, 0.35, 0.35), v3(1.15, 2.1, -1.25), c.Crown)

	-- Закрытые глаза — дуги «◡» из двух чёрточек; одна дуга шире другой
	for _, closed in ipairs({ { X = 1.15, Half = 0.32 }, { X = 0.1, Half = 0.24 } }) do
		local y = 0.55
		local z = front(head, headSize, closed.X, y) - 0.05
		local length = closed.Half / math.cos(math.rad(25))
		local stroke = v3(length, 0.13, 0.15)
		mouth(kit, stroke, v3(closed.X + closed.Half / 2, y + 0.07, z), v3(0, 0, 25))
		mouth(kit, stroke, v3(closed.X - closed.Half / 2, y + 0.07, z), v3(0, 0, -25))
	end
	local bubble = add(kit, "Ball", v3(0.8, 0.8, 0.8), v3(0.95, 0, -2.75), c.Bubble)
	bubble.Transparency = 0.35
	blush(kit, v3(0.55, 0.3, 0.2), v3(1.45, 0.2, front(head, headSize, 1.45, 0.2)))
	blush(kit, v3(0.55, 0.3, 0.2), v3(-0.25, 0.2, front(head, headSize, -0.25, 0.2)))

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
