local shim = require("./_shim")
local H = require("./_harness")
local Spring = shim.require("src/shared/Util/Spring")
local CoinSplit = shim.require("src/shared/Util/CoinSplit")
local Economy = shim.require("src/shared/Config/Economy")

print("Spring")
H.test("스프링은 목표로 수렴한다", function()
	local s = Spring.new(120, 10, 0)
	for _ = 1, 300 do
		s:update(1 / 60, 1)
	end
	H.near(s.x, 1, 1e-3)
end)

print("CoinSplit")
local D, MAX = Economy.CoinDenoms, Economy.MaxCoinsPerDeposit
H.test("7 → 5,1,1", function()
	local p = CoinSplit.split(7, D, MAX)
	H.eq(#p, 3)
	H.eq(p[1], 5)
end)
H.test("1000 → 500,500", function()
	local p = CoinSplit.split(1000, D, MAX)
	H.eq(#p, 2)
	H.eq(p[1] + p[2], 1000)
end)
H.test("최대 8조각, 합은 보존", function()
	local p = CoinSplit.split(9999, D, MAX)
	H.eq(#p, 8)
	local sum = 0
	for _, v in p do
		sum += v
	end
	H.eq(sum, 9999)
end)
H.test("0 → 빈 배열", function()
	H.eq(#CoinSplit.split(0, D, MAX), 0)
end)
H.test("tier", function()
	H.eq(CoinSplit.tier(1, D), 1)
	H.eq(CoinSplit.tier(24, D), 2)
	H.eq(CoinSplit.tier(2500, D), 6)
end)
