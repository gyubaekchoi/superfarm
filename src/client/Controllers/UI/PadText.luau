--!strict
-- 패드 이름 짓기. 말풍선과 목표 배너가 같은 문구를 쓰도록 한 곳에 모은다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PadLogic = require(Shared.PadLogic)
local Zones = require(Shared.Config.Zones)
local L = require(Shared.Util.L)

local PadText = {}

function PadText.fromInfo(info: PadLogic.PadInfo): string
	if info.kind == "Stat" then
		return L("pad." .. info.key)
	elseif info.kind == "Expand" then
		return L("pad.Expand")
	elseif info.kind == "Crop2" then
		local crops = Zones.Defs[info.key].crops
		local second = crops and crops[2]
		return L("pad.Crop2", second and L("crop." .. second) or "")
	elseif info.kind == "Worker" then
		return L("pad.Worker")
	end
	return L("pad.Gate", L("zone." .. info.key))
end

function PadText.title(d: any, padId: string): string
	return PadText.fromInfo(PadLogic.info(d, padId))
end

-- 목표 배너 문구
function PadText.goal(d: any, msg: any): (string, string)
	local kind = msg and msg.kind or "None"
	local icon = msg and msg.icon or "Sickle"
	if msg and msg.saving then
		return icon, L("goal.Save")
	end
	if kind == "Harvest" then
		return icon, L("goal.Harvest")
	elseif kind == "Sell" then
		return icon, L("goal.Sell")
	elseif kind == "Gacha" then
		return icon, L("goal.Gacha")
	elseif kind == "Enhance" then
		return icon, L("goal.Enhance")
	elseif kind == "Pad" and msg.padId then
		return icon, L("goal.Pad", PadText.title(d, msg.padId))
	elseif kind == "Gate" and msg.padId then
		local _, key = PadLogic.parse(msg.padId)
		return icon, L("goal.Gate", L("zone." .. key))
	end
	return "Drop", L("goal.Idle")
end

return PadText
