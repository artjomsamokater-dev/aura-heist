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
TextConfig.FreePlot = "Free Studio"
TextConfig.OwnedPlot = "%s's Studio" -- %s заменяется на имя игрока
TextConfig.Portal = "MEME ZONE"
TextConfig.Zone = "MEME ZONE"
TextConfig.ZoneDanger = "DANGER"
TextConfig.Entry = "Entry"
TextConfig.Extraction = "EXTRACT"
TextConfig.ExtractionProgress = "EXTRACTING... %d" -- %d — сколько секунд осталось
TextConfig.PedestalMemeling = "%s\n+%d/s" -- имя мемлинга и доход в секунду
TextConfig.PedestalStored = "%s Aura" -- сколько накоплено на постаменте
TextConfig.PedestalFull = "%s Aura (FULL)" -- накоплено до предела хранилища

-- Кнопки
TextConfig.PickupAction = "Pick up"
TextConfig.CollectAction = "Collect"

-- HUD (клиент)
TextConfig.HudBaseCaption = "SAFE AT BASE"
TextConfig.HudBaseValue = "%s Aura" -- %s — число Aura на базе
TextConfig.HudHandsCaption = "IN HANDS · LOST IF YOU DIE"
TextConfig.HudHandsValue = "In hands: %d/%d" -- сколько несёшь / сколько можно
TextConfig.ExtractMarker = "▼ EXTRACT ▼"
TextConfig.ExtractMarkerDistance = "%s studs" -- %s — расстояние до точки эвакуации
TextConfig.ExtractEdgeArrow = "▲" -- стрелка у края экрана, когда точка эвакуации не видна

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
} :: { [string]: string }

return deepFreeze(TextConfig)
