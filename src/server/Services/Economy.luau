--!strict
-- Economy: ЕДИНСТВЕННОЕ место, где меняется BankedAura (Aura на базе).
-- Пока только в памяти сервера, сохранение — задача 2.1.
-- Атрибут BankedAura на игроке — копия для HUD; клиент его только читает.

local Players = game:GetService("Players")

local Economy = {}

local banked: { [Player]: number } = {}

local function publish(player: Player)
	player:SetAttribute("BankedAura", banked[player] or 0)
end

function Economy.GetBankedAura(player: Player): number
	return banked[player] or 0
end

-- Начисляет Aura. amount — целое больше нуля, иначе ничего не меняется.
-- reason — для Output, чтобы было видно, откуда пришли деньги.
function Economy.AddBankedAura(player: Player, amount: number, reason: string): boolean
	if amount <= 0 or amount ~= math.floor(amount) then
		warn(string.format("[Economy] Отклонено начисление %s для %s (%s)", tostring(amount), player.Name, reason))
		return false
	end
	if player.Parent == nil then
		return false
	end
	banked[player] = (banked[player] or 0) + amount
	publish(player)
	print(string.format("[Economy] %s +%d Aura (%s), всего %d", player.Name, amount, reason, banked[player]))
	return true
end

local function onPlayerAdded(player: Player)
	banked[player] = banked[player] or 0
	publish(player)
end

function Economy.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		banked[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
end

return Economy
