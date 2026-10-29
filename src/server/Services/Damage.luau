--!strict
-- Damage: единственное место, где сервер наносит урон игрокам (ловушки, враги).
-- Клиент урон не присылает и не считает. Источник урона запоминается на Humanoid
-- (атрибут LastDamageSource), чтобы при смерти было видно, от чего она.

local Damage = {}

-- Наносит урон живому персонажу игрока. Вернёт true, если урон нанесён.
function Damage.Apply(player: Player, amount: number, source: string): boolean
	if amount <= 0 then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	humanoid:SetAttribute("LastDamageSource", source)
	humanoid:TakeDamage(amount)
	print(string.format("[Damage] %s −%d (%s), здоровье %d", player.Name, amount, source, math.floor(humanoid.Health)))
	return true
end

return Damage
