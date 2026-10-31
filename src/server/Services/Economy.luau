--!strict
-- Economy: ЕДИНСТВЕННОЕ место, где меняется BankedAura (Aura на базе).
-- Значение живёт в профиле игрока (PlayerData) и сохраняется вместе с ним.
-- Атрибут BankedAura на игроке — копия для HUD; клиент его только читает.
-- Все операции синхронные (без ожиданий), поэтому две одновременные покупки не спишут дважды.

local Players = game:GetService("Players")

local PlayerData = require(script.Parent.PlayerData)

local Economy = {}

local function publish(player: Player, data: PlayerData.Data)
	player:SetAttribute("BankedAura", data.bankedAura)
end

local function isValidAmount(amount: number): boolean
	return amount > 0 and amount == math.floor(amount) and amount < math.huge
end

function Economy.GetBankedAura(player: Player): number
	local data = PlayerData.GetData(player)
	return if data then data.bankedAura else 0
end

-- Начисляет Aura. amount — целое больше нуля, иначе ничего не меняется.
-- reason — для Output, чтобы было видно, откуда пришли деньги.
function Economy.AddBankedAura(player: Player, amount: number, reason: string): boolean
	if not isValidAmount(amount) then
		warn(string.format("[Economy] Отклонено начисление %s для %s (%s)", tostring(amount), player.Name, reason))
		return false
	end
	local data = PlayerData.GetData(player)
	if data == nil then
		return false
	end
	data.bankedAura += amount
	data.stats.auraEarned += amount
	publish(player, data)
	print(string.format("[Economy] %s +%d Aura (%s), всего %d", player.Name, amount, reason, data.bankedAura))
	return true
end

-- Списывает Aura, только если её хватает. Вернёт false и ничего не изменит, если не хватает.
function Economy.TrySpend(player: Player, amount: number, reason: string): boolean
	if not isValidAmount(amount) then
		warn(string.format("[Economy] Отклонено списание %s для %s (%s)", tostring(amount), player.Name, reason))
		return false
	end
	local data = PlayerData.GetData(player)
	if data == nil or data.bankedAura < amount then
		return false
	end
	data.bankedAura -= amount
	publish(player, data)
	print(string.format("[Economy] %s −%d Aura (%s), осталось %d", player.Name, amount, reason, data.bankedAura))
	return true
end

-- Rebirth: если Aura не меньше minimum — вся Aura сгорает (баланс становится 0). Иначе ничего не меняет.
function Economy.TrySpendAll(player: Player, minimum: number, reason: string): boolean
	local data = PlayerData.GetData(player)
	if data == nil or not isValidAmount(minimum) or data.bankedAura < minimum then
		return false
	end
	local spent = data.bankedAura
	data.bankedAura = 0
	publish(player, data)
	print(string.format("[Economy] %s −%d Aura (%s), осталось 0", player.Name, spent, reason))
	return true
end

function Economy.Start()
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("BankedAura", 0) -- пока профиль грузится
	end)
	PlayerData.OnLoaded(publish)
end

return Economy
