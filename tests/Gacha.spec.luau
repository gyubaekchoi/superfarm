local shim = require("./_shim")
local H = require("./_harness")
local GachaLogic = shim.require("src/shared/GachaLogic")
local Gacha = shim.require("src/shared/Config/Gacha")
local Rng = shim.require("src/shared/Util/Rng")

local function base()
	return {
		version = 1,
		coins = 0,
		stones = 0,
		tickets = 99,
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

print("Gacha")
H.test("무료 1회차는 1,000회 모두 ★3 이상 + Tool", function()
	local rng = Rng.new(7)
	for i = 1, 1000 do
		local d = base()
		local r = GachaLogic.roll(d, true, rng)
		H.truthy(r.star >= 3, "star " .. r.star .. " at " .. i)
		H.eq(r.slot, "Tool")
		H.eq(r.equipped, true)
		H.eq(r.isFirst, true)
		H.eq(d.gear.Tool.star, r.star)
	end
end)

H.test("무료 3회차는 ★2 이상 보장", function()
	local rng = Rng.new(11)
	for _ = 1, 1000 do
		local d = base()
		GachaLogic.roll(d, true, rng)
		GachaLogic.roll(d, true, rng)
		local r = GachaLogic.roll(d, true, rng)
		H.truthy(r.star >= 2, "3rd star " .. r.star)
	end
end)

H.test("천장: 연속 10회 안에 반드시 ★3 이상 (무료·유료 10만 회)", function()
	local rng = Rng.new(3)
	local d = base()
	d.gacha.freeCount = 10 -- 리깅 구간 지난 상태
	local since = 0
	for _ = 1, 100000 do
		local r = GachaLogic.roll(d, false, rng)
		if r.star >= 3 then
			since = 0
		else
			since += 1
			H.truthy(since < Gacha.Pity, "no ★3 in " .. since)
		end
	end
end)

H.test("유료 확률 분포 (10만 회, 천장 미고려 원시 분포 ±1.5%p)", function()
	-- 천장이 분포를 왜곡하므로 pity 를 매번 0으로 리셋해 원시 분포만 측정
	local rng = Rng.new(5)
	local counts = { 0, 0, 0, 0 }
	local N = 100000
	local d = base()
	d.gacha.freeCount = 10
	for _ = 1, N do
		d.gacha.pity = 0
		d.gear = {}
		local r = GachaLogic.roll(d, false, rng)
		counts[r.star] += 1
	end
	for star = 1, 4 do
		local pct = counts[star] / N * 100
		H.near(pct, Gacha.Weights[star], 1.5, "★" .. star)
	end
end)

H.test("중복/하위 장비는 분해되어 💎 지급, 상위는 교체 후 기존 장비 분해", function()
	local rng = Rng.new(1)
	local d = base()
	d.gear.Tool = { star = 3 }
	d.gacha.freeCount = 10
	-- 강제로 결과를 만들기 위해 weighted 를 고정하는 가짜 rng
	local fake = {
		weighted = function()
			return 2
		end,
		pick = function()
			return "Tool"
		end,
	}
	local r = GachaLogic.roll(d, false, fake)
	H.eq(r.equipped, false)
	H.eq(r.stonesGained, Gacha.Dismantle[2])
	H.eq(d.gear.Tool.star, 3)
	local fake4 = {
		weighted = function()
			return 4
		end,
		pick = function()
			return "Tool"
		end,
	}
	local r2 = GachaLogic.roll(d, false, fake4)
	H.eq(r2.equipped, true)
	H.eq(r2.previousStar, 3)
	H.eq(r2.stonesGained, Gacha.Dismantle[3])
	H.eq(d.gear.Tool.star, 4)
	H.truthy(rng ~= nil)
end)

H.test("지불: 티켓/💎", function()
	local d = base()
	d.tickets = 1
	d.stones = 49
	H.eq(GachaLogic.pay(d, "Ticket"), true)
	H.eq(d.tickets, 0)
	H.eq(GachaLogic.pay(d, "Ticket"), false)
	H.eq(GachaLogic.pay(d, "Stones"), false)
	d.stones = 50
	H.eq(GachaLogic.pay(d, "Stones"), true)
	H.eq(d.stones, 0)
end)
