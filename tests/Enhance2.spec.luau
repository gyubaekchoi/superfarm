local shim = require("./_shim")
local H = require("./_harness")
local EnhanceLogic = shim.require("src/shared/EnhanceLogic")
local Enhance = shim.require("src/shared/Config/Enhance")
local Rng = shim.require("src/shared/Util/Rng")

local function base(stones, level)
	return {
		version = 1,
		coins = 0,
		stones = stones or 0,
		tickets = 0,
		xp = 0,
		level = level or 4,
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
local noCrit = {
	chance = function()
		return false
	end,
}
local allCrit = {
	chance = function()
		return true
	end,
}

print("EnhanceLogic")
H.test("Lv3 이하는 강화대 잠김", function()
	H.eq(EnhanceLogic.unlocked(base(100, 3)), false)
	H.eq(EnhanceLogic.unlocked(base(100, 4)), true)
	H.eq(EnhanceLogic.burst(base(100, 3), noCrit), nil)
end)
H.test("💎 8 은 비활성(nil), 9 는 +3", function()
	H.eq(EnhanceLogic.burst(base(8), noCrit), nil)
	local d = base(9)
	local r = EnhanceLogic.burst(d, noCrit)
	H.eq(r.to, 3)
	H.eq(#r.steps, 3)
	H.eq(r.stonesSpent, 9)
	H.eq(d.stones, 0)
	H.eq(d.stats.enhanceBursts, 1)
end)
H.test("크리티컬은 💎 추가 소모 없이 +2 (건너뛴 단계의 비용은 다음 단계 기준)", function()
	-- 9💎: 0→2 (비용 2), 2→4 (비용 4), 남은 3 < cost(4)=6 → 종료
	local d = base(9)
	local r = EnhanceLogic.burst(d, allCrit)
	H.eq(r.to, 4)
	H.eq(#r.steps, 2)
	H.eq(r.stonesSpent, 6)
	H.eq(d.stones, 3)
	for _, s in r.steps do
		H.eq(s.gain, 2)
		H.eq(s.crit, true)
	end
end)
H.test("상한 30 을 넘지 않고 남는 💎 유지", function()
	local d = base(10000)
	local r = EnhanceLogic.burst(d, allCrit)
	H.eq(r.to, 30)
	H.truthy(d.stones > 0)
	H.eq(EnhanceLogic.burst(d, noCrit), nil)
end)
H.test("크리티컬률 15% ±0.5%p (10만 step)", function()
	local rng = Rng.new(9)
	local crits, total = 0, 0
	while total < 100000 do
		local d = base(9)
		local r = EnhanceLogic.burst(d, rng)
		for _, s in r.steps do
			total += 1
			if s.crit then
				crits += 1
			end
		end
	end
	H.near(crits / total * 100, Enhance.CritChance * 100, 0.5)
end)
H.test("오라 등급", function()
	H.eq(EnhanceLogic.auraFor(4), nil)
	H.eq(EnhanceLogic.auraFor(5), "White")
	H.eq(EnhanceLogic.auraFor(14), "BlueFlame")
	H.eq(EnhanceLogic.auraFor(30), "Galaxy")
end)
