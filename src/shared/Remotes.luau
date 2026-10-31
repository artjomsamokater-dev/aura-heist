--!strict
-- Remotes: имена всех RemoteEvent игры. Создаёт их только сервер (в ReplicatedStorage.Remotes),
-- клиент находит по этим же именам.
--
-- Направление у каждого события своё:
--   Announcement — только сервер → все клиенты (объявления о редком спавне).
--   SquadBonus   — только сервер → конкретный игрок («SQUAD BONUS!»).
--   Сервер их не слушает: что бы клиент туда ни прислал, ничего не произойдёт.
-- События клиент → сервер подключать только через RemoteGuard (правило 2.5).

local Remotes = table.freeze({
	Folder = "Remotes",
	Announcement = "Announcement",
	SquadBonus = "SquadBonus",
})

return Remotes
