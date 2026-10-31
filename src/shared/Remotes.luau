--!strict
-- Remotes: имена всех RemoteEvent игры. Создаёт их только сервер (в ReplicatedStorage.Remotes),
-- клиент находит по этим же именам.
--
-- Направление у каждого события своё:
--   Announcement — только сервер → все клиенты (объявления о редком спавне).
--   SquadBonus   — только сервер → конкретный игрок («SQUAD BONUS!»).
--   ExtractionResult — только сервер → игрок: экран результата (Id принесённых, время вылазки, бонус отряда).
--   Эти три сервер не слушает: что бы клиент туда ни прислал, ничего не произойдёт.
--   TutorialSkip — клиент → сервер, без аргументов: «пропустить туториал».
-- События клиент → сервер подключать только через RemoteGuard.ConnectRemote (правило 2.5).

local Remotes = table.freeze({
	Folder = "Remotes",
	Announcement = "Announcement",
	SquadBonus = "SquadBonus",
	ExtractionResult = "ExtractionResult",
	TutorialSkip = "TutorialSkip",
})

return Remotes
