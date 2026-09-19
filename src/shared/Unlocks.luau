--!strict
-- 기능 해금 순서. 처음부터 모든 버튼을 보여주지 않고 하나씩 드러내기 위한 가시성 규칙.
-- 해금 전 오브젝트는 월드에서 아예 보이지 않고(투명 + 말풍선 없음) 결제도 되지 않는다.
-- 1구역(Z1)만 튜토리얼처럼 한 단계씩 열리고, 2·3구역은 구역 게이트 자체가 관문이므로 열리는 즉시 전부 보인다.
local Types = require(script.Parent.Types)
local PadLogic = require(script.Parent.PadLogic)

type PlayerData = Types.PlayerData

local Unlocks = {}

local function padLevel(d: PlayerData, key: string): number
	local p = d.pads[key]
	return if p then p.level or 0 else 0
end

local function field(d: PlayerData, zone: string)
	return d.fields[zone] or {}
end

-- key → 조건. 순서대로 하나씩 열린다.
local COND: { [string]: (PlayerData) -> boolean } = {
	-- 1구역 튜토리얼 드립
	["Sell"] = function(d)
		return d.tutorial >= 1 -- 첫 수확을 하면 판매대가 나타난다
	end,
	["Pad:Move"] = function(d)
		return d.tutorial >= 2 -- 첫 판매를 하면 첫 업그레이드가 나타난다
	end,
	["Pad:Harvest"] = function(d)
		return padLevel(d, "Move") >= 1
	end,
	["Pad:Cap"] = function(d)
		return padLevel(d, "Harvest") >= 1
	end,
	["Pad:Expand"] = function(d)
		return padLevel(d, "Cap") >= 1
	end,
	["Pad:Crop2"] = function(d)
		return (field(d, "Z1").expansion or 0) >= 1
	end,
	["Pad:Worker"] = function(d)
		return field(d, "Z1").crop2 == true
	end,
	["Pad:Grow"] = function(d)
		return d.zones.Z2 == true
	end,
	-- 허브 오브젝트
	["Hub:Gacha"] = function(d)
		return d.level >= 2
	end,
	["Hub:Enhance"] = function(d)
		return d.level >= 4
	end,
	["Hub:Shop"] = function(d)
		return d.level >= 5
	end,
	-- 구역 게이트: 직전 구역을 연 뒤에만 다음 게이트가 보인다
	["Gate:Z2"] = function(d)
		return d.level >= 3
	end,
	["Gate:Z3"] = function(d)
		return d.zones.Z2 == true
	end,
	["Gate:Z4"] = function(d)
		return d.zones.Z3 == true
	end,
}

function Unlocks.has(d: PlayerData, key: string): boolean
	local fn = COND[key]
	if not fn then
		return true
	end
	local ok, result = pcall(fn, d)
	return ok and result == true
end

-- 패드 가시성. padId 예: "Move", "Expand:Z1", "Gate:Z2"
function Unlocks.padVisible(d: PlayerData, padId: string, zone: string): boolean
	local kind, key = PadLogic.parse(padId)
	if kind == "Gate" then
		return Unlocks.has(d, "Gate:" .. key)
	end
	if zone ~= "Z1" and zone ~= "Hub" then
		return true -- 2·3구역은 게이트를 연 시점에 전부 공개
	end
	local name = if kind == "Stat" then key else kind
	return Unlocks.has(d, "Pad:" .. name)
end

function Unlocks.hubVisible(d: PlayerData, kind: string): boolean
	return Unlocks.has(d, "Hub:" .. kind)
end

function Unlocks.sellVisible(d: PlayerData, zone: string): boolean
	return zone ~= "Z1" or Unlocks.has(d, "Sell")
end

return Unlocks
