--!strict
-- TutorialSteps: шаги туториала и как они засчитываются. Чистые функции без Roblox,
-- их проверяют тесты в tests/TutorialSteps.spec.luau.
--
-- Шаг засчитывает сервер по РЕАЛЬНОМУ действию игрока: действие должно совпасть с текущим шагом.
-- Действия не по порядку ничего не меняют. После последнего шага туториал пройден и больше не показывается.

local TutorialSteps = {}

-- Порядок шагов (номер шага = место в списке). Имена — это и названия действий
TutorialSteps.Steps = table.freeze({
	"EnterZone", -- войти в портал
	"PickUp", -- подобрать мемлинга
	"Extract", -- эвакуироваться
	"VisitPedestal", -- подойти к постаменту с мемлингом
	"Collect", -- собрать Aura
	"BuyUpgrade", -- купить улучшение
})

export type State = {
	step: number, -- текущий шаг (1..#Steps)
	completed: boolean,
}

function TutorialSteps.Count(): number
	return #TutorialSteps.Steps
end

-- Имя текущего шага или nil, если туториал пройден
function TutorialSteps.Current(state: State): string?
	if state.completed then
		return nil
	end
	return TutorialSteps.Steps[state.step]
end

-- Игрок сделал действие action. Вернёт true, если это засчитало текущий шаг
function TutorialSteps.Advance(state: State, action: string): boolean
	if state.completed or TutorialSteps.Steps[state.step] ~= action then
		return false
	end
	state.step += 1
	if state.step > #TutorialSteps.Steps then
		state.completed = true
	end
	return true
end

-- Пропуск: туториал считается пройденным
function TutorialSteps.Skip(state: State)
	state.completed = true
end

-- Номер шага для HUD: 0 — показывать нечего
function TutorialSteps.Visible(state: State): number
	return if state.completed then 0 else state.step
end

-- Игрок, который уже эвакуировался до появления туториала, проходить его не должен
function TutorialSteps.CompleteForVeteran(state: State, extractions: number)
	if not state.completed and state.step == 1 and extractions > 0 then
		state.completed = true
	end
end

return TutorialSteps
