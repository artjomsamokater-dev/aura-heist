--!strict
-- RemoteGuard: общие проверки любого запроса от игрока
-- (ProximityPrompt сейчас, RemoteEvent позже). Клиенту не верим ни в чём.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SecurityConfig = require(ReplicatedStorage.Shared.Config.SecurityConfig)

local RemoteGuard = {}

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

return RemoteGuard
