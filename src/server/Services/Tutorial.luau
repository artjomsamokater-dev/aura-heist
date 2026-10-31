--!strict
-- Tutorial: туториал из 6 шагов (shared/Util/TutorialSteps). Прогресс — в профиле (data.tutorial).
-- Шаг засчитывает сервер по реальному действию: сервисы сообщают о нём через Tutorial.Notify
-- (Raid — портал и подбор, Extraction — эвакуация, Studio — сбор и покупка). Шаг «подойти к постаменту»
-- сервер проверяет сам раз в CheckSeconds. Клиент видит номер шага в атрибуте TutorialStep (0 — пройден)
-- и только рисует стрелку и подсказку. Пропуск — RemoteEvent TutorialSkip через RemoteGuard.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TutorialSteps = require(ReplicatedStorage.Shared.Util.TutorialSteps)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local RemoteGuard = require(ServerScriptService.Server.Security.RemoteGuard)

local Tutorial = {}

Tutorial.Attribute = "TutorialStep"
local CHECK_SECONDS = 0.5 -- как часто проверяем шаг «подойти к постаменту» (не баланс — частота проверки)

type StepCallback = (player: Player, stepNumber: number, stepName: string) -> ()

local pedestalCheck: ((player: Player) -> boolean)? = nil
local stepCallbacks: { StepCallback } = {}

local function publish(player: Player, data: PlayerData.Data)
	player:SetAttribute(Tutorial.Attribute, TutorialSteps.Visible(data.tutorial))
end

-- Игрок сделал действие (имя из TutorialSteps.Steps). Засчитает шаг, если он сейчас текущий
function Tutorial.Notify(player: Player, action: string)
	local data = PlayerData.GetData(player)
	if data == nil then
		return
	end
	local stepNumber = data.tutorial.step
	if TutorialSteps.Advance(data.tutorial, action) then
		publish(player, data)
		print(string.format("[Tutorial] %s: шаг %d (%s) пройден%s", player.Name, stepNumber, action, if data.tutorial.completed then " — туториал завершён" else ""))
		for _, callback in ipairs(stepCallbacks) do
			task.spawn(callback, player, stepNumber, action)
		end
	end
end

-- Кто проверяет «игрок стоит у своего постамента с мемлингом» (задаёт Studio)
function Tutorial.SetPedestalCheck(check: (player: Player) -> boolean)
	pedestalCheck = check
end

-- Подписка на пройденные шаги (для аналитики)
function Tutorial.OnStep(callback: StepCallback)
	table.insert(stepCallbacks, callback)
end

function Tutorial.Start()
	PlayerData.OnLoaded(publish)

	local skip = RemoteGuard.CreateRemote(Remotes.TutorialSkip)
	RemoteGuard.ConnectRemote(skip, "пропуск туториала", function(player: Player)
		local data = PlayerData.GetData(player)
		if data and not data.tutorial.completed then
			TutorialSteps.Skip(data.tutorial)
			publish(player, data)
			print(string.format("[Tutorial] %s пропустил туториал", player.Name))
		end
	end)

	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			local check = pedestalCheck
			if check then
				for _, player in ipairs(Players:GetPlayers()) do
					local data = PlayerData.GetData(player)
					if data and TutorialSteps.Current(data.tutorial) == "VisitPedestal" and check(player) then
						Tutorial.Notify(player, "VisitPedestal")
					end
				end
			end
		end
	end)
end

return Tutorial
