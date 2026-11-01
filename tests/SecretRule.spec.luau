--!strict
-- Тесты секретного паркура (задача 7.3): Secret — ровно один раз, потом Aura раз в сутки.

local SecretRule = require("../src/shared/Util/SecretRule")
local EconomyConfig = require("../src/shared/Config/EconomyConfig")
local MemelingConfig = require("../src/shared/Config/MemelingConfig")
local TestKit = require("./TestKit")

local test, equal = TestKit.test, TestKit.equal

local DAY = EconomyConfig.SecretObby.CooldownSeconds
local NOW = 1_800_000_000

print("SecretRule")

test("первый раз дошёл — Secret-мемлинг", function()
	equal(SecretRule.Decide(false, 0, NOW, DAY), "secret")
end)

test("Secret выдаётся ровно один раз: после выдачи — только ежедневная награда", function()
	-- выдали Secret и запомнили время
	local found, last = true, NOW
	equal(SecretRule.Decide(found, last, NOW + 60, DAY), "none", "в тот же день — ничего")
	equal(SecretRule.Decide(found, last, NOW + DAY - 1, DAY), "none", "за секунду до суток — ничего")
	equal(SecretRule.Decide(found, last, NOW + DAY, DAY), "daily", "через сутки — Aura")
end)

test("ежедневная награда — не чаще раза в сутки", function()
	local last = NOW + DAY -- получил ежедневную
	equal(SecretRule.Decide(true, last, last + 10, DAY), "none")
	equal(SecretRule.Decide(true, last, last + DAY, DAY), "daily")
end)

test("Secret: доход как у Legendary ×2, в зонах не появляется, сутки — 86 400 с", function()
	equal(MemelingConfig.Rarities.Secret.AuraPerSecond, MemelingConfig.Rarities.Legendary.AuraPerSecond * 2)
	local kitten = MemelingConfig.Memelings[EconomyConfig.SecretObby.MemelingId]
	equal(kitten.Rarity, "Secret")
	equal(kitten.Zone, nil)
	equal(DAY, 86400)
end)

test("чекпоинты", function()
	equal(SecretRule.NextCheckpoint(0, 1), 1)
	equal(SecretRule.NextCheckpoint(2, 1), 2, "назад не откатывает")
end)

return nil
