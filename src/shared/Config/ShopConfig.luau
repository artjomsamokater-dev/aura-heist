--!strict
-- ShopConfig: магазин косметики за Aura (задача 7.4). Только внешний вид — силы и дохода не даёт.
-- Здесь — категории, список вещей и цены. Названия для игрока — TextConfig.ShopItemNames,
-- как вещь выглядит — StyleConfig.Cosmetics. Купленное — навсегда (профиль, cosmetics.owned),
-- что надето/стоит — отдельно (cosmetics.equipped); Rebirth косметику не трогает.

-- table.freeze замораживает только верхний уровень, поэтому замораживаем всё дерево
local function deepFreeze<T>(t: T): T
	for _, value in t :: any do
		if type(value) == "table" and not table.isfrozen(value) then
			deepFreeze(value)
		end
	end
	return table.freeze(t :: any) :: any
end

export type Item = {
	Category: string,
	Price: number,
}

local ShopConfig = {}

-- Категории по порядку (вкладки магазина). MaxEquipped — сколько вещей категории надето/стоит сразу:
-- 1 — новая заменяет прежнюю; больше 1 — включаются по отдельности, пока есть место
ShopConfig.CategoryOrder = { "Banner", "Decor", "PedestalSkin", "Trail", "Aura", "Title" }
ShopConfig.Categories = {
	Banner = { MaxEquipped = 3 }, -- флаги над студией, 3 флагштока
	Decor = { MaxEquipped = 5 }, -- декор студии: каждая вещь на своём месте
	PedestalSkin = { MaxEquipped = 1 },
	Trail = { MaxEquipped = 1 },
	Aura = { MaxEquipped = 1 },
	Title = { MaxEquipped = 1 },
} :: { [string]: { MaxEquipped: number } }

-- Все вещи. Id никогда не меняем (он попадёт в сохранения). Самые дорогие — миллионы: цель на поздней игре
ShopConfig.Items = {
	-- Баннеры (12)
	BannerMintStripes = { Category = "Banner", Price = 5_000 },
	BannerPlumStripes = { Category = "Banner", Price = 7_500 },
	BannerChecker = { Category = "Banner", Price = 15_000 },
	BannerDots = { Category = "Banner", Price = 25_000 },
	BannerStar = { Category = "Banner", Price = 50_000 },
	BannerToast = { Category = "Banner", Price = 75_000 },
	BannerHeart = { Category = "Banner", Price = 100_000 },
	BannerSnooze = { Category = "Banner", Price = 150_000 },
	BannerFire = { Category = "Banner", Price = 300_000 },
	BannerGalaxy = { Category = "Banner", Price = 500_000 },
	BannerRainbow = { Category = "Banner", Price = 1_000_000 },
	BannerGolden = { Category = "Banner", Price = 2_000_000 },
	-- Декор студии (5)
	DecorCarpet = { Category = "Decor", Price = 20_000 },
	DecorFountain = { Category = "Decor", Price = 60_000 },
	DecorNeonSign = { Category = "Decor", Price = 120_000 },
	DecorStatue = { Category = "Decor", Price = 400_000 },
	DecorFireworks = { Category = "Decor", Price = 1_500_000 },
	-- Скины постаментов (4)
	SkinMarble = { Category = "PedestalSkin", Price = 30_000 },
	SkinCloud = { Category = "PedestalSkin", Price = 90_000 },
	SkinNeon = { Category = "PedestalSkin", Price = 250_000 },
	SkinGold = { Category = "PedestalSkin", Price = 1_200_000 },
	-- Следы (4)
	TrailMint = { Category = "Trail", Price = 10_000 },
	TrailSparkle = { Category = "Trail", Price = 40_000 },
	TrailFire = { Category = "Trail", Price = 200_000 },
	TrailRainbow = { Category = "Trail", Price = 800_000 },
	-- Аура-частицы вокруг персонажа (4)
	AuraBubbles = { Category = "Aura", Price = 35_000 },
	AuraStars = { Category = "Aura", Price = 150_000 },
	AuraGlitch = { Category = "Aura", Price = 600_000 },
	AuraGolden = { Category = "Aura", Price = 1_800_000 },
	-- Титулы над ником (6)
	TitleLooter = { Category = "Title", Price = 5_000 },
	TitleCollector = { Category = "Title", Price = 25_000 },
	TitleWaffleKing = { Category = "Title", Price = 100_000 },
	TitleLegendHunter = { Category = "Title", Price = 400_000 },
	TitleNotFound = { Category = "Title", Price = 900_000 },
	TitleMemeLord = { Category = "Title", Price = 2_000_000 },
} :: { [string]: Item }

ShopConfig.KioskDistance = 10 -- кнопка «Open shop» у киоска на площади

return deepFreeze(ShopConfig)
