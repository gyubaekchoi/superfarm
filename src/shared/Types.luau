--!strict
-- 공용 타입 정의. DevSpec §2 참고.

export type GearSlot = "Tool" | "Shoes" | "Bag"
export type Gear = { star: number }

export type PadState = { level: number, paid: number }
export type FieldState = { expansion: number, paid: number, crop2: boolean, crop2Paid: number }
export type WorkerState = { count: number, level: number, paid: number }

export type PlayerData = {
	version: number,
	coins: number,
	stones: number,
	tickets: number,
	xp: number,
	level: number,

	zones: { [string]: boolean },
	gates: { [string]: number },
	pads: { [string]: PadState },
	fields: { [string]: FieldState },
	workers: { [string]: WorkerState },

	gear: { Tool: Gear?, Shoes: Gear?, Bag: Gear? },
	enhance: number,

	gacha: { freeCount: number, paidCount: number, pity: number },
	passes: { [string]: boolean },
	boosts: { coinX2Until: number },

	tutorial: number,
	daily: { lastChest: number },
	purchases: { string }, -- 처리한 영수증 PurchaseId (최근 50개, 중복 지급 방지)
	stats: { totalCoins: number, totalHarvest: number, playtimeSec: number, enhanceBursts: number },
}

-- 스탯 패드 단계 (계정 공용)
export type PadLevels = { Move: number, Harvest: number, Cap: number, Grow: number }

export type Computed = {
	speed: number, -- WalkSpeed
	interval: number, -- 수확 처리 간격(초)
	cap: number, -- 운반량
	radius: number, -- 수확 반경(studs)
	power: number, -- ⚡
}

export type DataPatch = { path: string, value: any }

return nil
