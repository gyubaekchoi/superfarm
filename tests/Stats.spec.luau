local shim = require("./_shim")
local H = require("./_harness")
local Stats = shim.require("src/shared/Stats")

local function base()
	return {
		version = 1,
		coins = 0,
		stones = 0,
		tickets = 0,
		xp = 0,
		level = 1,
		zones = { Z1 = true },
		gates = {},
		pads = {},
		fields = {},
		workers = {},
		gear = {},
		enhance = 0,
		gacha = { freeCount = 0, paidCount = 0, pity = 0 },
		passes = {},
		boosts = { coinX2Until = 0 },
		tutorial = 0,
		daily = { lastChest = 0 },
		stats = { totalCoins = 0, totalHarvest = 0, playtimeSec = 0, enhanceBursts = 0 },
	}
end
local P0 = { Move = 0, Harvest = 0, Cap = 0, Grow = 0 }

print("Stats")
H.test("기준 스탯은 ⚡100", function()
	local c = Stats.compute(base(), P0)
	H.eq(c.speed, 16, "speed")
	H.near(c.interval, 0.25, 1e-9, "interval")
	H.eq(c.cap, 10, "cap")
	H.eq(c.radius, 4.5, "radius")
	H.eq(c.power, 100, "power")
end)

H.test("첫 뽑기 ★3 도구 → ⚡150, 반경 6.5", function()
	local d = base()
	d.gear.Tool = { star = 3 }
	local c = Stats.compute(d, P0)
	H.near(c.interval, 0.25 / 1.5, 1e-9, "interval")
	H.eq(c.power, 150, "power")
	H.eq(c.radius, 6.5, "radius")
end)

H.test("강화 +5 는 장비 효과에 ×1.15 로 곱해진다", function()
	local d = base()
	d.gear.Tool = { star = 3 }
	d.enhance = 5
	local c = Stats.compute(d, P0)
	H.near(c.interval, 0.25 / (1 + 0.5 * 1.15), 1e-9, "interval")
end)

H.test("강화만 있고 장비가 없으면 효과 없음", function()
	local d = base()
	d.enhance = 30
	H.eq(Stats.compute(d, P0).power, 100)
end)

H.test("이동속도 상한 40", function()
	local d = base()
	d.gear.Shoes = { star = 4 }
	d.enhance = 30
	d.passes.SpeedPass = true
	local c = Stats.compute(d, { Move = 15, Harvest = 0, Cap = 0, Grow = 0 })
	H.eq(c.speed, 40)
end)

H.test("수확 간격 하한 0.03", function()
	local d = base()
	d.gear.Tool = { star = 4 }
	d.enhance = 30
	d.passes.HarvestPass = true
	local c = Stats.compute(d, { Move = 0, Harvest = 15, Cap = 0, Grow = 0 })
	H.near(c.interval, 0.03, 1e-9)
end)

H.test("패드 단계 반영 (Move 5 → 21, Cap 3 → 22)", function()
	local c = Stats.compute(base(), { Move = 5, Harvest = 0, Cap = 3, Grow = 0 })
	H.eq(c.speed, 21, "speed")
	H.eq(c.cap, 22, "cap")
end)

H.test("가방 패스는 운반량 ×2", function()
	local d = base()
	d.passes.BagPass = true
	H.eq(Stats.compute(d, P0).cap, 20)
end)

H.test("padLevels 는 없는 패드를 0으로", function()
	local d = base()
	d.pads.Move = { level = 4, paid = 0 }
	local p = Stats.padLevels(d)
	H.eq(p.Move, 4)
	H.eq(p.Harvest, 0)
end)
