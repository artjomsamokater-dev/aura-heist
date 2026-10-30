--!strict
-- Точка входа клиента: запускает контроллеры.

local HudController = require(script.Controllers.HudController)
local HazardController = require(script.Controllers.HazardController)
local AnnouncementController = require(script.Controllers.AnnouncementController)

HudController.Start()
HazardController.Start()
task.spawn(AnnouncementController.Start) -- ждёт RemoteEvent от сервера, остальным не мешает
