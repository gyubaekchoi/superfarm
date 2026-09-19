--!strict
-- 패드 상태 계산 (서버·클라 공용 순수 함수).
-- padId: "Move"|"Harvest"|"Cap"|"Grow" (계정 공용 스탯) | "Expand:Z1" | "Crop2:Z1" | "Worker:Z1" | "Gate:Z2"
local Types = require(script.Parent.Types)
local Pads = require(script.Parent.Config.Pads)
local Zones = require(script.Parent.Config.Zones)

export type PadKind = "Stat" | "Expand" | "Crop2" | "Worker" | "Gate"
export type PadInfo = {
	kind: PadKind,
	key: string,
	level: number,
	paid: number,
	cost: number?, -- nil = 최대/완료
	maxed: boolean,
	icon: string,
	minLevel: number, -- 요구 레벨 (게이트)
	levelOk: boolean,
	teaser: boolean, -- 결제 불가 (준비중)
}

local PadLogic = {}

function PadLogic.parse(padId: string): (PadKind, string)
	local kind, key = padId:match("^(%w+):(%w+)$")
	if kind then
		return kind :: PadKind, key
	end
	return "Stat", padId
end

local function field(d: Types.PlayerData, zone: string)
	return d.fields[zone] or { expansion = 0, paid = 0, crop2 = false, crop2Paid = 0 }
end

function PadLogic.info(d: Types.PlayerData, padId: string): PadInfo
	local kind, key = PadLogic.parse(padId)
	local base = { kind = kind, key = key, minLevel = 1, levelOk = true, teaser = false }
	if kind == "Stat" then
		local def = Pads.Defs[key]
		local st = d.pads[key] or { level = 0, paid = 0 }
		local maxed = (st.level or 0) >= def.max
		base.level, base.paid, base.maxed, base.icon = st.level or 0, st.paid or 0, maxed, def.icon
		base.cost = if maxed then nil else Pads.cost(def, st.level + 1)
	elseif kind == "Expand" then
		local zdef = Zones.Defs[key]
		local f = field(d, key)
		local cost = (zdef.expansionCost or {})[(f.expansion or 0) + 1]
		base.level, base.paid, base.cost, base.maxed, base.icon =
			f.expansion or 0, f.paid or 0, cost, cost == nil, "Field"
	elseif kind == "Crop2" then
		local zdef = Zones.Defs[key]
		local f = field(d, key)
		base.level, base.paid, base.maxed = if f.crop2 then 1 else 0, f.crop2Paid or 0, f.crop2 == true
		base.cost = if f.crop2 then nil else zdef.crop2Cost
		base.icon = (zdef.crops or {})[2] or "Lock"
	elseif kind == "Worker" then
		local zdef = Zones.Defs[key]
		local w = d.workers[key] or { count = 0, level = 0, paid = 0 }
		local count = w.count or 0
		local cost = (zdef.workerCost or {})[count + 1]
		local maxed = cost == nil or count >= (zdef.workerMax or 0)
		base.level, base.paid, base.cost, base.maxed, base.icon =
			count, w.paid or 0, if maxed then nil else cost, maxed, "Robot"
	else -- Gate
		local zdef = Zones.Defs[key]
		local unlocked = d.zones[key] == true
		base.level, base.paid, base.maxed = if unlocked then 1 else 0, d.gates[key] or 0, unlocked
		base.cost = if unlocked then nil else zdef.gateCost
		base.minLevel = zdef.minLevel
		base.levelOk = d.level >= zdef.minLevel
		base.teaser = zdef.teaser == true
		base.icon = if zdef.teaser then "Construction" elseif base.levelOk then "Unlock" else "Lock"
	end
	return base :: any
end

function PadLogic.remaining(info: PadInfo): number
	if info.maxed or not info.cost then
		return 0
	end
	return math.max(0, info.cost - info.paid)
end

-- 지금 결제를 진행할 수 있는가 (레벨·티저 조건)
function PadLogic.canPay(info: PadInfo): boolean
	return not info.maxed and info.cost ~= nil and info.levelOk and not info.teaser
end

-- 잔액 전부 지불 가능 여부
function PadLogic.affordable(d: Types.PlayerData, padId: string): boolean
	local info = PadLogic.info(d, padId)
	return PadLogic.canPay(info) and d.coins >= PadLogic.remaining(info)
end

-- 이 패드가 속한 구역이 열려 있는가 (게이트는 항상 true)
function PadLogic.zoneOpen(d: Types.PlayerData, padId: string, zone: string): boolean
	local kind = PadLogic.parse(padId)
	if kind == "Gate" or zone == "Hub" then
		return true
	end
	return d.zones[zone] == true
end

return PadLogic
