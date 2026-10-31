--!strict
-- DebugCommands: команды для проверки в Studio. В опубликованной игре их НЕТ (RunService:IsStudio()).
--   /aura <число> — добавить себе столько Aura (через Economy, как любое начисление), чтобы быстро
--                   проверять дорогие улучшения и Rebirth. Пример: /aura 100000

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Economy = require(script.Parent.Economy)

local DebugCommands = {}

local MAX_AURA = 10_000_000 -- больше за раз не даём даже в Studio, чтобы не сломать подписи опечаткой

local function giveAura(player: Player, text: string)
	local amount = tonumber(string.match(text, "^/aura%s+(%d+)%s*$"))
	if amount == nil or amount < 1 then
		print("[Debug] Формат команды: /aura 100000")
		return
	end
	Economy.AddBankedAura(player, math.min(math.floor(amount), MAX_AURA), "отладка /aura")
end

function DebugCommands.Start()
	if not RunService:IsStudio() then
		return -- только в Studio
	end

	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		-- Новый чат Roblox: команда /aura
		local command = Instance.new("TextChatCommand")
		command.Name = "DebugAura"
		command.PrimaryAlias = "/aura"
		command.Parent = TextChatService
		command.Triggered:Connect(function(source: TextSource, text: string)
			local player = Players:GetPlayerByUserId(source.UserId)
			if player then
				giveAura(player, text)
			end
		end)
	else
		-- Старый чат: ловим сообщения игроков
		local function watch(player: Player)
			player.Chatted:Connect(function(message: string)
				if string.sub(message, 1, 5) == "/aura" then
					giveAura(player, message)
				end
			end)
		end
		Players.PlayerAdded:Connect(watch)
		for _, player in ipairs(Players:GetPlayers()) do
			watch(player)
		end
	end
	print("[Debug] В Studio доступна команда /aura <число>")
end

return DebugCommands
