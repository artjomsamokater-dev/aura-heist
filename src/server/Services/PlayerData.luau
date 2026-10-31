--!strict
-- PlayerData: профиль игрока на ProfileStore — то, что переживает перезаход.
--
-- Правила:
-- • Блокировка сессии: один профиль открыт только на одном сервере (это делает ProfileStore).
-- • Автосохранение каждые EconomyConfig.AutosaveSeconds, при выходе и при остановке сервера (BindToClose).
-- • Не загрузился профиль — игрока кикает с понятным текстом. Сохранять нечего, и мы ничего не пишем:
--   ProfileStore сохраняет только профили, которые успешно загрузились, поэтому пустой профиль
--   поверх старого не попадёт никогда. Profile.Data целиком мы тоже никогда не заменяем.
-- • Остальные сервисы ждут PlayerData.OnLoaded и работают с данными через PlayerData.GetData.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local TutorialSteps = require(ReplicatedStorage.Shared.Util.TutorialSteps)
local ProfileStore = require(ServerScriptService.Server.Packages.ProfileStore)

local PlayerData = {}

local STORE_NAME = "PlayerProfiles" -- имя DataStore; сменишь — все начнут с нуля
-- 1 — первая схема; 2 — запас стал списком записей (с флагом бонуса отряда), а не просто Id
local SCHEMA_VERSION = 2

-- Мемлинг на постаменте
export type ShowcaseEntry = {
	pedestal: number, -- номер постамента на участке (1, 2, ...)
	memelingId: string, -- Id из MemelingConfig
	lastCollect: number, -- время сервера (секунды Unix), с которого копится Aura
	squadBonus: boolean?, -- принесён в отряде: цена продажи выше (EconomyConfig.SquadBonus)
}

-- Мемлинг «в запасе» (не хватило постаментов)
export type ReserveEntry = {
	memelingId: string,
	squadBonus: boolean?,
}

export type Data = {
	schemaVersion: number,
	bankedAura: number, -- меняет только Economy
	showcase: { ShowcaseEntry }, -- мемлинги на постаментах
	reserve: { ReserveEntry }, -- мемлинги «в запасе»
	upgrades: { -- сколько уровней куплено (0 = стартовое значение)
		pedestals: number,
		carrySlots: number,
		storage: number,
	},
	tutorial: { -- туториал (shared/Util/TutorialSteps): текущий шаг и пройден ли
		step: number,
		completed: boolean,
	},
	stats: {
		raids: number,
		extractions: number,
		memelingsExtracted: number,
		memelingsSold: number,
		auraEarned: number,
		deaths: number, -- смерти (ловушки, враги, Reset, падение из зоны)
		squadBonuses: number, -- сколько раз получал бонус отряда
	},
}

local TEMPLATE: Data = {
	schemaVersion = SCHEMA_VERSION,
	bankedAura = 0,
	showcase = {},
	reserve = {},
	upgrades = { pedestals = 0, carrySlots = 0, storage = 0 },
	tutorial = { step = 1, completed = false },
	stats = {
		raids = 0,
		extractions = 0,
		memelingsExtracted = 0,
		memelingsSold = 0,
		auraEarned = 0,
		deaths = 0,
		squadBonuses = 0,
	},
}

type Profile = ProfileStore.Profile<Data>
type LoadedCallback = (player: Player, data: Data) -> ()

ProfileStore.SetConstant("AUTO_SAVE_PERIOD", EconomyConfig.AutosaveSeconds)
local store = ProfileStore.New(STORE_NAME, TEMPLATE :: any)

local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { LoadedCallback } = {}

local function getProfileData(profile: Profile): Data
	return profile.Data :: any
end

-- Перевод старых профилей на текущую схему. Профиль, сохранённый новой версией игры,
-- старый сервер открывать не должен — он бы его испортил (вернёт false).
local function migrate(data: Data): boolean
	if type(data.schemaVersion) ~= "number" then
		data.schemaVersion = 1
	end
	if data.schemaVersion > SCHEMA_VERSION then
		return false
	end

	-- 1 → 2: в запасе лежали просто Id мемлингов — делаем из них записи.
	-- Делаем всегда, а не только по номеру версии: повторный перевод ничего не меняет
	local reserve = data.reserve :: { any }
	for i, item in ipairs(reserve) do
		if type(item) == "string" then
			reserve[i] = { memelingId = item }
		end
	end

	-- Туториал появился позже: кто уже эвакуировался, его не проходит (поле tutorial дописал Reconcile)
	TutorialSteps.CompleteForVeteran(data.tutorial, data.stats.extractions)

	data.schemaVersion = SCHEMA_VERSION
	return true
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync("Player_" .. player.UserId, {
		-- Перестаём ждать профиль, если игрок уже ушёл
		Cancel = function()
			return player.Parent ~= Players
		end,
	} :: any)

	if profile == nil then
		if player.Parent == Players then
			warn(string.format("[PlayerData] Профиль %s не загрузился — кик", player.Name))
			player:Kick(TextConfig.KickProfileLoadFailed)
		end
		return
	end

	profile:AddUserId(player.UserId) -- для GDPR-запросов
	profile:Reconcile() -- дописывает новые поля из TEMPLATE, существующие не трогает

	local data = getProfileData(profile)
	if not migrate(data) then
		warn(string.format("[PlayerData] Профиль %s новее этого сервера — кик", player.Name))
		profile:EndSession()
		player:Kick(TextConfig.KickProfileNewer)
		return
	end

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			-- Профиль открыли на другом сервере: здесь играть дальше нельзя
			player:Kick(TextConfig.KickSessionEnded)
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession() -- игрок ушёл, пока профиль грузился
		return
	end

	profiles[player] = profile
	player:SetAttribute("DataLoaded", true)
	print(
		string.format(
			"[PlayerData] Профиль %s загружен: %d Aura, витрина %d, запас %d",
			player.Name,
			data.bankedAura,
			#data.showcase,
			#data.reserve
		)
	)
	for _, callback in ipairs(loadedCallbacks) do
		task.spawn(callback, player, data)
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		profile:EndSession() -- последнее сохранение и снятие блокировки
	end
end

-- Данные игрока или nil, если профиль ещё не загружен (или уже закрыт)
function PlayerData.GetData(player: Player): Data?
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return nil
	end
	return getProfileData(profile)
end

function PlayerData.IsLoaded(player: Player): boolean
	return PlayerData.GetData(player) ~= nil
end

-- Вызвать callback, когда профиль игрока загрузится (и сразу — для уже загруженных)
function PlayerData.OnLoaded(callback: LoadedCallback)
	table.insert(loadedCallbacks, callback)
	for player in profiles do
		local data = PlayerData.GetData(player)
		if data then
			task.spawn(callback, player, data)
		end
	end
end

function PlayerData.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	-- Остановка сервера: закрываем все сессии (ProfileStore сохранит их и дождётся записи)
	game:BindToClose(function()
		for _, profile in profiles do
			profile:EndSession()
		end
	end)
end

return PlayerData
