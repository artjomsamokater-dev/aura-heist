--!strict
-- Тесты туториала (задача 5.1): шаги по порядку, только по реальному действию, пропуск, старые игроки.

local TutorialSteps = require("../src/shared/Util/TutorialSteps")
local TestKit = require("./TestKit")

local test, equal = TestKit.test, TestKit.equal

local function fresh(): TutorialSteps.State
	return { step = 1, completed = false }
end

print("TutorialSteps")

test("6 шагов: портал, подбор, EXTRACT, постамент, Collect, улучшение", function()
	equal(TutorialSteps.Count(), 6)
	equal(TutorialSteps.Steps[1], "EnterZone")
	equal(TutorialSteps.Steps[6], "BuyUpgrade")
end)

test("весь путь по порядку — туториал пройден и больше не показывается", function()
	local state = fresh()
	for _, action in ipairs(TutorialSteps.Steps) do
		equal(TutorialSteps.Advance(state, action), true, action)
	end
	equal(state.completed, true)
	equal(TutorialSteps.Visible(state), 0)
	equal(TutorialSteps.Current(state), nil)
end)

test("действие не по порядку шаг не засчитывает", function()
	local state = fresh()
	equal(TutorialSteps.Advance(state, "Collect"), false)
	equal(state.step, 1)
	equal(TutorialSteps.Advance(state, "EnterZone"), true)
	equal(TutorialSteps.Advance(state, "EnterZone"), false, "тот же шаг второй раз не считается")
	equal(state.step, 2)
end)

test("пропуск — сразу пройден, дальше ничего не засчитывается", function()
	local state = fresh()
	TutorialSteps.Skip(state)
	equal(TutorialSteps.Visible(state), 0)
	equal(TutorialSteps.Advance(state, "EnterZone"), false)
end)

test("старый игрок с эвакуациями туториал не видит, новичок — видит", function()
	local veteran = fresh()
	TutorialSteps.CompleteForVeteran(veteran, 3)
	equal(veteran.completed, true)
	local newbie = fresh()
	TutorialSteps.CompleteForVeteran(newbie, 0)
	equal(newbie.completed, false)
	local halfway: TutorialSteps.State = { step = 4, completed = false }
	TutorialSteps.CompleteForVeteran(halfway, 1)
	equal(halfway.completed, false, "проходит туториал сейчас — не трогаем")
end)

return nil
