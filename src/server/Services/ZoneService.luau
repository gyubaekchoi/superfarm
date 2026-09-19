--!strict
-- 구역 생명주기: 데이터 로드 시 해금된 구역 생성, 게이트 완료 시 해금 연출. 해금 전 구역은 존재하지 않는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)
local Remotes = require(Shared.Remotes)
local PlotService = require(script.Parent.PlotService)
local PadService = require(script.Parent.PadService)
local CropService = require(script.Parent.CropService)
local DataService = require(script.Parent.DataService)

type PlotRuntime = PlotService.PlotRuntime

local ZoneService = {}
ZoneService.Priority = 72

function ZoneService:Build(rt: PlotRuntime, zone: string, data: any)
	PlotService:BuildZone(rt, zone)
	PadService:BuildZonePads(rt, zone, data)
	CropService:BuildZone(rt, zone, data)
end

function ZoneService:BuildUnlocked(rt: PlotRuntime, data: any)
	for _, zone in Zones.Order do
		if data.zones[zone] then
			self:Build(rt, zone, data)
		end
	end
end

function ZoneService:Start()
	DataService.Loaded:Connect(function(player, data)
		local rt = PlotService:GetByPlayer(player)
		if rt then
			self:BuildUnlocked(rt, data)
		end
	end)
	PadService.ZoneUnlocked:Connect(function(player, rt, zone)
		local d = DataService:Get(player)
		if d then
			self:Build(rt, zone, d)
			Remotes.get("ZoneUnlocked"):FireAllClients({ plot = rt.index, zone = zone })
		end
	end)
end

return ZoneService
