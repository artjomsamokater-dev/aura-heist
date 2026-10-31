--!strict
-- Точка входа клиента: запускает контроллеры.

local HudController = require(script.Controllers.HudController)
local HazardController = require(script.Controllers.HazardController)
local AnnouncementController = require(script.Controllers.AnnouncementController)
local TutorialController = require(script.Controllers.TutorialController)
local ResultController = require(script.Controllers.ResultController)
local PromptController = require(script.Controllers.PromptController)
local ActionButtonsController = require(script.Controllers.ActionButtonsController)

HudController.Start()
HazardController.Start()
PromptController.Start()
-- Эти ждут RemoteEvent от сервера — в отдельном потоке, чтобы не задерживать остальных
task.spawn(AnnouncementController.Start)
task.spawn(TutorialController.Start)
task.spawn(ResultController.Start)
task.spawn(ActionButtonsController.Start)
