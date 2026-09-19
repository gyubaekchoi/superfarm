--!strict
-- 스탯 패드. 계정 공용 단계. DevSpec §8-3.
export type PadDef = { base: number, mult: number, max: number, icon: string }

local Pads = {
	Defs = {
		Move = { base = 30, mult = 1.45, max = 15, icon = "Shoe" },
		Harvest = { base = 40, mult = 1.45, max = 15, icon = "Sickle" },
		Cap = { base = 25, mult = 1.45, max = 15, icon = "Bag" },
		Grow = { base = 800, mult = 1.8, max = 5, icon = "Drop" },
	} :: { [string]: PadDef },
}

-- lv: 다음에 올라갈 단계 (1부터). 현재 0단계면 cost(def, 1)
function Pads.cost(def: PadDef, lv: number): number
	return math.floor(def.base * def.mult ^ (lv - 1))
end

-- 패드 위에 서 있을 때 초당 빠져나가는 코인. 총비용 기준 선형 → 어떤 패드도 1.5초 안에 채워진다.
Pads.DrainSeconds = 1.5
function Pads.drainPerSec(cost: number): number
	return math.max(5, cost / Pads.DrainSeconds)
end

-- 성장속도 패드 배율 (Grow 단계 → growSec 배율)
function Pads.growMult(growLevel: number): number
	return 1 - 0.08 * growLevel
end

return Pads
