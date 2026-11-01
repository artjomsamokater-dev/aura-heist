--!strict
-- ExtractTarget: к какой точке эвакуации вести игрока — к ближайшей доступной (ExtractionRule).
-- Основной EXTRACT доступен всегда; медленная точка у входа закрыта, если сервер выставил
-- атрибут SideExtractionBlocked (в руках Epic/Legendary). Решает всё равно сервер — это только подсказка.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local TextConfig = require(ReplicatedStorage.Shared.Config.TextConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local StyleConfig = require(ReplicatedStorage.Shared.Config.StyleConfig)
local ExtractionRule = require(ReplicatedStorage.Shared.Util.ExtractionRule)

local ExtractTarget = {}

export type Target = { Position: Vector3, Radius: number, Marker: string, Color: Color3 }

local player = Players.LocalPlayer

-- Ближайшая доступная точка от позиции from — в зоне, где сейчас игрок (атрибут RaidZone от сервера)
function ExtractTarget.Get(from: Vector3): Target
	local zoneId = player:GetAttribute("RaidZone")
	local zone = MapConfig.Zones[if type(zoneId) == "string" then zoneId else ZoneConfig.FirstZone] or MapConfig.Zones[ZoneConfig.FirstZone]
	local main: Target = {
		Position = zone.ExtractionPosition,
		Radius = ZoneConfig.EvacuationDistance,
		Marker = TextConfig.ExtractMarker,
		Color = StyleConfig.Extraction.Color,
	}
	local side: Target = {
		Position = zone.SideExtractionPosition,
		Radius = ZoneConfig.SideEvacuation.Distance,
		Marker = TextConfig.SideExtractMarker,
		Color = StyleConfig.Extraction.SideColor,
	}
	local targets = { main, side }
	local index = ExtractionRule.Nearest({
		{ X = main.Position.X, Z = main.Position.Z, Allowed = true },
		{ X = side.Position.X, Z = side.Position.Z, Allowed = player:GetAttribute("SideExtractionBlocked") ~= true },
	}, from.X, from.Z)
	return targets[index or 1]
end

return ExtractTarget
