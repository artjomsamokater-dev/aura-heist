--!strict
-- SecretRule: награда за секретный паркур (задача 7.3). Чистые функции — их проверяют тесты.
--   • первый раз дошёл до острова — Secret-мемлинг ("secret"), ровно один раз за всю игру;
--   • потом — немного Aura ("daily"), не чаще раза в cooldown секунд;
--   • иначе — ничего ("none").

local SecretRule = {}

export type Reward = "secret" | "daily" | "none"

function SecretRule.Decide(found: boolean, lastDailyAt: number, now: number, cooldown: number): Reward
	if not found then
		return "secret"
	end
	if now - lastDailyAt >= cooldown then
		return "daily"
	end
	return "none"
end

-- Какой чекпоинт теперь последний: дальний из пройденных (назад по паркуру не откатывает)
function SecretRule.NextCheckpoint(current: number, reached: number): number
	return math.max(current, reached)
end

return SecretRule
