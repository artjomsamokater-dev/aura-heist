--!strict
-- TextConfig: ВСЕ тексты, которые видит игрок. Игра на английском.
-- В коде сервисов строк для игрока нет — только ссылки сюда (так потом проще добавить перевод).
-- Сообщения в Output (print / warn) — для разработчика, они остаются в коде.

-- table.freeze замораживает только верхний уровень, поэтому замораживаем всё дерево
local function deepFreeze<T>(t: T): T
	for _, value in t :: any do
		if type(value) == "table" and not table.isfrozen(value) then
			deepFreeze(value)
		end
	end
	return table.freeze(t :: any) :: any
end

local TextConfig = {}

-- Подписи над объектами карты
TextConfig.FreePlot = "Empty plot"
TextConfig.ClaimPlot = "Join to claim!" -- табличка посреди свободного участка
-- Табличка у портала каждой зоны
TextConfig.PortalInfos = {
	Meme = "Danger zone inside!\nBring loot back to EXTRACT",
	Golden = "Golden memelings: x5 income!\nUnlock once, keep forever",
	Candy = "Candy memelings: x20 income!\nWatch out for Gummy Brutes",
} :: { [string]: string }
TextConfig.UnlockAction = "Unlock" -- кнопка у золотых ворот (цена — PriceTag)
TextConfig.SecretHint = "?" -- маленький знак у входа в секретный паркур (других подсказок нет)
TextConfig.Error404Text = "404" -- надпись на спине Error404Kitten

-- Меню слева (задача 7.8): пункты, закрытые «скоро», панели Base / Upgrades / Rebirth
TextConfig.MenuTitle = "MENU"
TextConfig.MenuItems = {
	Base = "Base",
	Collection = "Collection",
	Upgrades = "Upgrades",
	Rebirth = "Rebirth",
	Shop = "Shop",
	Quests = "Quests",
	Daily = "Daily rewards",
} :: { [string]: string }
TextConfig.MenuSoon = "Soon"
TextConfig.BaseTitle = "YOUR BASE"
TextConfig.BasePlot = "Plot #%d"
TextConfig.BaseNoPlot = "No plot yet"
TextConfig.BasePedestals = "Pedestals: %d / %d"
TextConfig.BaseReserve = "In reserve: %d"
TextConfig.BaseIncome = "Income: +%s Aura/s"
TextConfig.BaseStorage = "Stored: %s / %s Aura"
TextConfig.BaseHint = "Collect Aura at your pedestals"
TextConfig.UpgradesTitle = "UPGRADES"
TextConfig.UpgradeNames = { pedestals = "Pedestals", carrySlots = "Backpack", storage = "Storage" } :: { [string]: string }
-- Текущее значение улучшения (%d — число постаментов, слотов или множитель хранилища)
TextConfig.UpgradeValues = { pedestals = "%d pedestals", carrySlots = "%d slots", storage = "x%d storage" } :: { [string]: string }
TextConfig.UpgradeLevel = "Level %d / %d"
TextConfig.UpgradeNext = "Next: %s Aura"
TextConfig.UpgradesHint = "Buy at the gold buttons on your base"
TextConfig.RebirthTitle = "REBIRTH"
TextConfig.RebirthCount = "Rebirths: %d"
TextConfig.RebirthBonus = "Income bonus: +%d%%"
TextConfig.RebirthCost = "Next rebirth: %s Aura"
TextConfig.RebirthNeedMax = "Max all upgrades first"
TextConfig.RebirthNeedAura = "Collect more Aura"
TextConfig.RebirthReady = "Ready! Hold the plum pad on your base"
TextConfig.RebirthHint = "Your memelings stay with you"

-- Коллекция (задача 7.8)
TextConfig.CollectionTitle = "COLLECTION"
TextConfig.CollectionCounter = "%d/%d"
TextConfig.CollectionSecretSection = "SECRET"
TextConfig.CollectionUnknown = "???"
TextConfig.CollectionIncome = "Income: +%s Aura/s"
TextConfig.CollectionSell = "Sell price: %s Aura"
TextConfig.CollectionSpeed = "Speed with it: %d"
TextConfig.CollectionWhere = "Found in: %s"
TextConfig.CollectionWhereSecret = "Found in: a secret place"
TextConfig.CollectionOwned = "You have: %d"
TextConfig.CollectionLocked = "Extract it once to unlock!"
TextConfig.CollectionBack = "Back"

-- Магазин косметики (киоск на площади и кнопка в HUD)
TextConfig.ShopTitle = "SHOP"
TextConfig.ShopOpenAction = "Open shop"
TextConfig.ShopBuy = "BUY"
TextConfig.ShopEquip = "EQUIP"
TextConfig.ShopUnequip = "TAKE OFF"
TextConfig.ShopOwnedTag = "OWNED"
TextConfig.ShopEquippedTag = "ON"
TextConfig.ShopSlots = "%d / %d on" -- сколько надето в категории / сколько можно
TextConfig.ShopNote = "Cosmetics only · yours forever, even after Rebirth"
TextConfig.ShopCategoryNames = {
	Banner = "Banners",
	Decor = "Studio",
	PedestalSkin = "Pedestals",
	Trail = "Trails",
	Aura = "Auras",
	Title = "Titles",
} :: { [string]: string }
TextConfig.ShopItemNames = {
	BannerMintStripes = "Mint Stripes",
	BannerPlumStripes = "Plum Stripes",
	BannerChecker = "Checkers",
	BannerDots = "Polka Dots",
	BannerStar = "Big Star",
	BannerToast = "Toast Paw",
	BannerHeart = "Big Heart",
	BannerSnooze = "Sleepy Dino",
	BannerFire = "Fire",
	BannerGalaxy = "Galaxy",
	BannerRainbow = "Rainbow",
	BannerGolden = "Golden",
	DecorCarpet = "Carpet Path",
	DecorFountain = "Mini Fountain",
	DecorNeonSign = "Neon Name Sign",
	DecorStatue = "Memeling Statue",
	DecorFireworks = "Fireworks",
	SkinMarble = "Marble",
	SkinCloud = "Cloud",
	SkinNeon = "Neon",
	SkinGold = "Gold",
	TrailMint = "Mint Trail",
	TrailSparkle = "Sparkle Trail",
	TrailFire = "Fire Trail",
	TrailRainbow = "Rainbow Trail",
	AuraBubbles = "Bubbles",
	AuraStars = "Stars",
	AuraGlitch = "Glitch",
	AuraGolden = "Golden Glow",
	TitleLooter = "Speedy Looter",
	TitleCollector = "Meme Collector",
	TitleWaffleKing = "Waffle King",
	TitleLegendHunter = "Legend Hunter",
	TitleNotFound = "404 Not Found",
	TitleMemeLord = "Meme Lord",
} :: { [string]: string }
TextConfig.OwnedPlot = "%s's Studio" -- %s заменяется на имя игрока
TextConfig.Portal = "MEME ZONE"
-- Витрина в хабе: самый редкий мемлинг, вынесенный на этом сервере за сессию
TextConfig.BestHaulTitle = "BEST HAUL"
TextConfig.BestHaulEmpty = "BEST HAUL\nBring back something rare!"
TextConfig.BestHaulOwner = "%s\nby %s" -- имя мемлинга, ник игрока
TextConfig.ZoneNames = { Meme = "MEME ZONE", Golden = "GOLDEN ZONE", Candy = "CANDY CHAOS" } :: { [string]: string } -- название зоны по Id
TextConfig.ZoneDanger = "DANGER"
TextConfig.Entry = "Entry"
TextConfig.Extraction = "EXTRACT"
TextConfig.ExtractionProgress = "EXTRACTING... %d" -- %d — сколько секунд осталось
TextConfig.SideExtraction = "SLOW EXIT\nno Epic / Legendary" -- вторая точка эвакуации у входа
TextConfig.PedestalMemeling = "%s\n+%d/s" -- имя мемлинга и доход в секунду
TextConfig.PedestalStored = "%s Aura" -- сколько накоплено на постаменте
TextConfig.PedestalFull = "%s Aura (FULL)" -- накоплено до предела хранилища

-- Кнопки
TextConfig.PickupAction = "Pick up"
TextConfig.CollectAction = "Collect"
TextConfig.BuyAction = "Buy"
TextConfig.PriceTag = "%s Aura" -- цена на кнопке покупки
TextConfig.SellAction = "Sell"
TextConfig.SellPriceTag = "+%s Aura" -- сколько получишь за продажу
TextConfig.ReserveLabel = "x%d" -- рядом с иконкой ящика: сколько мемлингов в запасе

-- Rebirth: площадка на участке и счётчик над именем игрока
TextConfig.RebirthAction = "Rebirth"
TextConfig.RebirthLabel = "%s" -- рядом с иконкой звезды: цена
TextConfig.RebirthLocked = "Max all" -- сначала купить все улучшения
TextConfig.RebirthTag = "REBIRTH %d" -- %d — сколько rebirth сделано

-- Кнопки улучшений: над кнопкой — иконка и цена (коротко, крупно); подробно — в самой кнопке «Buy»
TextConfig.UpgradePrice = "%s" -- %s — цена
TextConfig.UpgradeMaxed = "MAX"
-- Подпись кнопки «Buy»: что даст следующий уровень и цена (%d — новое значение, %s — цена)
TextConfig.UpgradeLabels = {
	pedestals = "Pedestal #%d · %s Aura",
	carrySlots = "Backpack %d slots · %s Aura",
	storage = "Storage x%d · %s Aura",
} :: { [string]: string }

-- HUD (клиент)
-- HUD: иконки рисуются (shared/Ui/Icons), крупное число — главное, мелкая подпись — пояснение.
-- Без эмодзи: на разных устройствах они выглядят по-разному
TextConfig.HudBaseValue = "%s" -- %s — число Aura на базе
TextConfig.HudBaseCaption = "SAFE AT BASE"
TextConfig.HudIncome = "+%s Aura/s" -- общий доход базы под числом банка (задача 7.8)
TextConfig.HudAuraBadge = "AURA" -- подпись под иконкой Aura
TextConfig.HudHandsValue = "%d / %d" -- сколько несёшь / сколько можно
TextConfig.HudHandsCaption = "LOST IF YOU DIE"
TextConfig.RestockTimer = "New memelings in %s" -- %s — сколько осталось, например 1:23

-- Бонус отряда: плашка обоим игрокам и отметка на мемлинге (%d — проценты к доходу на постаменте)
TextConfig.SquadBonusBanner = "SQUAD BONUS! +%d%% income forever"
TextConfig.SquadTag = "\nSQUAD +%d%% income"

-- «Охота»: мемлинг-BOUNTY (%s — имя, %d — множитель дохода, второе %s — сколько осталось, например 7:32)
TextConfig.BountyPortal = "BOUNTY: %s\nx%d income · %s"
TextConfig.BountyHud = "BOUNTY %s x%d · %s"
TextConfig.BountyMarker = "BOUNTY x%d" -- метка над таким мемлингом в зоне
TextConfig.BountyTag = "\nBOUNTY x%d income" -- на постаменте
TextConfig.ResultBounty = " · BOUNTY x%d" -- в строке экрана результата

-- Объявление о редком спавне всем игрокам: «A LEGENDARY appeared in the DANGER zone!»
TextConfig.AnnounceSpawn = "A %s appeared in the %s · %s!" -- редкость, название зоны, часть зоны
TextConfig.RarityNames = { Common = "COMMON", Rare = "RARE", Epic = "EPIC", Legendary = "LEGENDARY", Secret = "SECRET" } :: { [string]: string }
TextConfig.ZonePartNames = { Safe = "SAFE", Danger = "DANGER" } :: { [string]: string }
TextConfig.ExtractMarker = "▼ EXTRACT ▼"
TextConfig.Extracting = "EXTRACTING... %.1fs" -- полоска вверху, пока стоишь на точке (сколько осталось)
TextConfig.ExtractingDone = "EXTRACTED!"
TextConfig.SideExtractMarker = "▼ SLOW EXIT ▼" -- маркер, когда ближе доступна вторая точка
TextConfig.ExtractMarkerDistance = "%s studs" -- %s — расстояние до точки эвакуации
TextConfig.ExtractEdgeArrow = "▲" -- стрелка у края экрана, когда точка эвакуации не видна

TextConfig.EnemyAlert = "!" -- над Grumblob, когда он заметил игрока с добычей

-- Свой выпавший лут после смерти (видит только погибший)
TextConfig.LootLabel = "YOUR LOOT\n%s" -- %s — сколько осталось, например 0:15

-- Кнопки действий (крупные, справа над кнопкой прыжка)
TextConfig.ActionDrop = "Drop"
TextConfig.ActionExtract = "Extract"
TextConfig.ActionExtracting = "Hold..."
TextConfig.KeyHint = "[%s]" -- клавиша на компьютере, например [G]

-- Экран результата эвакуации
TextConfig.ResultTitle = "EXTRACTED!"
TextConfig.ResultRow = "%s · %s · +%d/s%s" -- имя · редкость · доход в секунду · отметка BOUNTY (или пусто)
TextConfig.ResultEmpty = "Empty hands this time"
TextConfig.ResultTime = "Raid time %s" -- %s — например 1:23
TextConfig.ResultSquad = "SQUAD BONUS +%d%% income"
TextConfig.ResultBack = "Back to base"

-- Туториал: одна короткая подсказка на шаг (номер = шаг из shared/Util/TutorialSteps)
TextConfig.TutorialHints = {
	"Walk into the portal",
	"Pick up a memeling",
	"Stand on EXTRACT",
	"Go to your pedestal",
	"Collect your Aura",
	"Buy an upgrade",
}
TextConfig.TutorialStepTag = "%d/%d" -- номер шага / всего шагов
TextConfig.TutorialSkip = "Skip"

-- Событие Giant Object
TextConfig.GiantObjectName = "MEGA CHEESE WHEEL"

-- Буквы сна над Mega Snoozeasaurus
TextConfig.SnoozeLetters = "Z z z"

-- Сообщения при кике (сохранение)
TextConfig.KickProfileLoadFailed = "We couldn't load your save. Your progress is safe — please rejoin in a minute."
TextConfig.KickProfileNewer = "This server is outdated. Please rejoin to get the latest version."
TextConfig.KickSessionEnded = "Your save was opened on another server. Please rejoin."

-- Имена мемлингов: ключ — Id из MemelingConfig
TextConfig.MemelingNames = {
	ToastPaw = "Toast Paw",
	SirWobbleton = "Sir Wobbleton",
	Grumbloaf = "Grumbloaf",
	NoodleNinja = "Noodle Ninja",
	CaptainSockbeard = "Captain Sockbeard",
	DiscoPickle = "Disco Pickle",
	ProfessorBonk = "Professor Bonk",
	MegaSnoozeasaurus = "Mega Snoozeasaurus",
	BubbleTeaBandit = "Bubble Tea Bandit",
	CactusCrooner = "Cactus Crooner",
	PizzaPigeon = "Pizza Pigeon",
	RoboDuck = "Robo Duck",
	KingWaffleton = "King Waffleton",
	Error404Kitten = "Error 404 Kitten",
	-- Задача 7.6
	SoggyCereal = "Soggy Cereal",
	ChonkyDumpling = "Chonky Dumpling",
	SpicyNugget = "Spicy Nugget",
	ToiletPaperPrince = "Toilet Paper Prince",
	CosmicBurrito = "Cosmic Burrito",
	DiamondDonut = "Diamond Donut",
	TrophyTurtle = "Trophy Turtle",
	SirMoneybags = "Sir Moneybags",
	-- Задача 7.7: Candy Chaos
	CottonCandyCloud = "Cotton Candy Cloud",
	LollipopLlama = "Lollipop Llama",
	GummyWormGang = "Gummy Worm Gang",
	MarshmallowMage = "Marshmallow Mage",
	ChocoKing = "Choco King",
} :: { [string]: string }

return deepFreeze(TextConfig)
