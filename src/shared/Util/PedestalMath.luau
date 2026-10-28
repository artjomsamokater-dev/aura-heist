--!strict
-- PedestalMath: сколько Aura накоплено на постаменте. Чистая математика без Roblox,
-- поэтому её проверяют тесты в tests/ (их запускает scripts/check.ps1).
--
-- Постамент помнит только lastCollect — момент, с которого копится Aura.
-- Накоплено = (сейчас − lastCollect) × доход, но не больше лимита хранилища.
-- Так же считается офлайн-доход: игрок вышел, lastCollect остался в профиле,
-- при следующем входе накопленное просто посчитается от него и упрётся в лимит.

local PedestalMath = {}

-- Сколько Aura на постаменте сейчас (может быть дробным; игроку показываем округлённое вниз)
function PedestalMath.GetStored(rate: number, lastCollect: number, now: number, capacitySeconds: number): number
	if rate <= 0 then
		return 0
	end
	-- Время назад (часы другого сервера) даёт отрицательное — считаем как ноль
	return math.clamp((now - lastCollect) * rate, 0, rate * capacitySeconds)
end

-- Сбор: сколько целых Aura начислить и каким станет lastCollect.
-- Дробный остаток не пропадает — он продолжает копиться. Если собирать нечего, вернёт (0, lastCollect).
function PedestalMath.Collect(rate: number, lastCollect: number, now: number, capacitySeconds: number): (number, number)
	local stored = PedestalMath.GetStored(rate, lastCollect, now, capacitySeconds)
	local amount = math.floor(stored)
	if amount < 1 then
		return 0, lastCollect
	end
	return amount, now - (stored - amount) / rate
end

return PedestalMath
