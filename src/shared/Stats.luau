--!strict
-- 최종 스탯 계산. 서버·클라 공용 순수 함수. DevSpec §3.
local Types = require(script.Parent.Types)
local Gacha = require(script.Parent.Config.Gacha)
local Enhance = require(script.Parent.Config.Enhance)
local Economy = require(script.Parent.Config.Economy)

type PlayerData = Types.PlayerData
type PadLevels = Types.PadLevels
type Computed = Types.Computed

local Stats = {}

function Stats.compute(d: PlayerData, pads: PadLevels): Computed
	local enh = 1 + Enhance.PerLevel * d.enhance

	local tool = d.gear.Tool and Gacha.Effect.Tool[d.gear.Tool.star] or 0
	local shoes = d.gear.Shoes and Gacha.Effect.Shoes[d.gear.Shoes.star] or 0
	local bag = d.gear.Bag and Gacha.Effect.Bag[d.gear.Bag.star] or 0
	local radiusBonus = d.gear.Tool and Gacha.Radius[d.gear.Tool.star] or 0

	local speed = (Economy.BaseSpeed + Economy.PadMoveStep * pads.Move) * (1 + shoes * enh)
	if d.passes.SpeedPass then
		speed *= 1.5
	end

	local interval = (Economy.BaseInterval - Economy.PadHarvestStep * pads.Harvest) / (1 + tool * enh)
	if d.passes.HarvestPass then
		interval /= 2
	end

	local cap = Economy.BaseCap + Economy.PadCapStep * pads.Cap + bag * enh
	if d.passes.BagPass then
		cap *= 2
	end
	cap = math.floor(cap)

	local radius = Economy.BaseRadius + radiusBonus

	speed = math.clamp(speed, Economy.BaseSpeed, Economy.MaxSpeed)
	interval = math.max(interval, Economy.MinInterval)

	local power = math.floor(
		100 * (speed / Economy.BaseSpeed)
			+ 100 * (Economy.BaseInterval / interval)
			+ 100 * (cap / Economy.BaseCap)
			- 200
	)

	return { speed = speed, interval = interval, cap = cap, radius = radius, power = power }
end

-- PlayerData.pads → PadLevels
function Stats.padLevels(d: PlayerData): PadLevels
	local function lv(key: string): number
		local p = d.pads[key]
		return p and p.level or 0
	end
	return { Move = lv("Move"), Harvest = lv("Harvest"), Cap = lv("Cap"), Grow = lv("Grow") }
end

function Stats.fromData(d: PlayerData): Computed
	return Stats.compute(d, Stats.padLevels(d))
end

return Stats
