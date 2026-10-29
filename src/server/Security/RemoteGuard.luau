--!strict
-- RemoteGuard: общие проверки любого запроса от игрока. Клиенту не верим ни в чём.
--
-- Сейчас клиент «стучится» на сервер только через ProximityPrompt (RemoteEvent в игре нет).
-- Каждую кнопку подключаем через RemoteGuard.ConnectPrompt — это первый слой защиты:
--   • общий лимит на любые действия игрока (SecurityConfig.RateLimits.AnyAction),
--   • игрок в игре и его персонаж жив,
--   • персонаж рядом с кнопкой (её MaxActivationDistance + запас на задержку сети).
-- Второй слой — в обработчике: свой лимит действия, свой участок, состояние, цена, «уже выдано».
-- Когда появятся RemoteEvent, их тоже подключать через этот модуль (ID проверять IsId).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SecurityConfig = require(ReplicatedStorage.Shared.Config.SecurityConfig)
local RateLimiter = require(script.Parent.RateLimiter)

local RemoteGuard = {}

local anyActionLimiter = RateLimiter.new(
	SecurityConfig.RateLimits.AnyAction.MaxRequests,
	SecurityConfig.RateLimits.AnyAction.WindowSeconds
)
local lastSpamWarnAt: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any

-- Похоже ли значение на ID: непустая строка разумной длины
function RemoteGuard.IsId(value: unknown): boolean
	return type(value) == "string" and #value > 0 and #value <= SecurityConfig.MaxIdLength
end

-- Игрок ещё в игре и его персонаж жив. Возвращает (character, rootPart) или nil
function RemoteGuard.GetAliveCharacter(player: Player): (Model?, BasePart?)
	if player.Parent == nil then
		return nil, nil
	end
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return character, root
end

-- Персонаж не дальше maxDistance от точки (с небольшим запасом на задержку сети)
function RemoteGuard.IsNear(root: BasePart, position: Vector3, maxDistance: number): boolean
	return (root.Position - position).Magnitude <= maxDistance + SecurityConfig.DistanceToleranceStuds
end

-- Спам виден в Output, но не чаще раза в SpamWarnSeconds на игрока
local function warnSpam(player: Player, action: string)
	local now = os.clock()
	local last = lastSpamWarnAt[player]
	if last == nil or now - last >= SecurityConfig.SpamWarnSeconds then
		lastSpamWarnAt[player] = now
		warn(string.format("[RemoteGuard] %s слишком часто жмёт кнопки (%s) — лишние запросы отброшены", player.Name, action))
	end
end

-- Подключает обработчик кнопки через общие проверки. action — имя для Output.
-- Обработчик вызывается, только если игрок прошёл общий лимит, жив и стоит рядом с кнопкой.
function RemoteGuard.ConnectPrompt(prompt: ProximityPrompt, action: string, handler: (player: Player) -> ())
	prompt.Triggered:Connect(function(player: Player)
		if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then
			return
		end
		if not anyActionLimiter.Allow(player) then
			warnSpam(player, action)
			return
		end
		local _, root = RemoteGuard.GetAliveCharacter(player)
		if root == nil then
			return
		end
		local target = prompt.Parent
		if target == nil or not target:IsA("BasePart") then
			return
		end
		if not RemoteGuard.IsNear(root, target.Position, prompt.MaxActivationDistance) then
			return
		end
		handler(player)
	end)
end

return RemoteGuard
