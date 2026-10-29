--!strict
-- Точка входа клиента: запускает контроллеры.

local HudController = require(script.Controllers.HudController)
local HazardController = require(script.Controllers.HazardController)

HudController.Start()
HazardController.Start()
