--!strict
-- 구역 정의. origin은 플롯 로컬 좌표 {x,y,z}. DevSpec §8-2, §12.
export type ZoneDef = {
	gateCost: number,
	minLevel: number,
	crops: { string }?,
	crop2Cost: number?,
	sellMult: number?,
	fieldGrid: { { number } }?, -- expansion 0..4 → {cols, rows}
	treeGrid: { { number } }?,
	expansionCost: { number }?,
	workerCost: { number }?,
	workerMax: number?,
	hasGrowPad: boolean?,
	growPadBase: number?,
	teaser: boolean?,
}

local Zones: { [string]: ZoneDef } = {
	Z1 = {
		gateCost = 0,
		minLevel = 1,
		crops = { "Wheat", "Rice" },
		crop2Cost = 150,
		sellMult = 1.0,
		fieldGrid = { { 3, 3 }, { 4, 4 }, { 5, 5 }, { 5, 6 }, { 5, 7 } },
		expansionCost = { 20, 45, 100, 200 },
		workerCost = { 400 },
		workerMax = 1,
		hasGrowPad = false,
	},
	Z2 = {
		gateCost = 800,
		minLevel = 3,
		crops = { "Corn", "Potato" },
		crop2Cost = 2000,
		sellMult = 1.2,
		fieldGrid = { { 3, 3 }, { 4, 4 }, { 5, 5 }, { 5, 6 }, { 5, 7 } },
		expansionCost = { 300, 600, 1200, 2000 },
		workerCost = { 3000 },
		workerMax = 1,
		hasGrowPad = true,
		growPadBase = 800,
	},
	Z3 = {
		gateCost = 8000,
		minLevel = 6,
		crops = { "Apple", "Orange" },
		crop2Cost = 15000,
		sellMult = 1.0,
		treeGrid = { { 2, 2 }, { 2, 3 }, { 3, 3 }, { 3, 4 }, { 3, 4 } },
		expansionCost = { 3000, 5000, 8000, 12000 },
		workerCost = { 10000, 20000 },
		workerMax = 2,
	},
	Z4 = {
		gateCost = 60000,
		minLevel = 10,
		teaser = true,
	},
}

-- 해금 순서 (게이트 순회용)
local Order = { "Z1", "Z2", "Z3", "Z4" }

return { Defs = Zones, Order = Order }
