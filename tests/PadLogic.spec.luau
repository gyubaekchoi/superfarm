local shim = require("./_shim")
local H = require("./_harness")
local PadLogic = shim.require("src/shared/PadLogic")
local Pads = shim.require("src/shared/Config/Pads")
local Economy = shim.require("src/shared/Config/Economy")

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
		fields = { Z1 = { expansion = 0, paid = 0, crop2 = false, crop2Paid = 0 } },
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

print("Pads")
H.test("비용 곡선: Move 1단계 30, 2단계 43, 15단계 ≈ 5,4xx", function()
	local def = Pads.Defs.Move
	H.eq(Pads.cost(def, 1), 30)
	H.eq(Pads.cost(def, 2), 43)
	H.truthy(Pads.cost(def, 15) > 5000 and Pads.cost(def, 15) < 6000)
end)
H.test("drainPerSec: 총비용/1.5 선형, 최소 5/s", function()
	H.eq(Pads.drainPerSec(3), 5)
	H.eq(Pads.drainPerSec(300), 200)
end)

print("PadLogic")
H.test("스탯 패드 초기 정보", function()
	local i = PadLogic.info(base(), "Move")
	H.eq(i.kind, "Stat")
	H.eq(i.level, 0)
	H.eq(i.cost, 30)
	H.eq(i.maxed, false)
	H.eq(i.icon, "Shoe")
end)
H.test("스탯 패드 최대 단계", function()
	local d = base()
	d.pads.Move = { level = 15, paid = 0 }
	local i = PadLogic.info(d, "Move")
	H.eq(i.maxed, true)
	H.eq(i.cost, nil)
	H.eq(PadLogic.remaining(i), 0)
end)
H.test("밭 확장 4단계 후 최대", function()
	local d = base()
	H.eq(PadLogic.info(d, "Expand:Z1").cost, 20)
	d.fields.Z1.expansion = 4
	H.eq(PadLogic.info(d, "Expand:Z1").maxed, true)
end)
H.test("벼 해금 패드", function()
	local d = base()
	local i = PadLogic.info(d, "Crop2:Z1")
	H.eq(i.cost, 150)
	H.eq(i.icon, "Rice")
	d.fields.Z1.crop2 = true
	H.eq(PadLogic.info(d, "Crop2:Z1").maxed, true)
end)
H.test("affordable 은 잔액 기준", function()
	local d = base()
	d.pads.Move = { level = 0, paid = 25 }
	d.coins = 5
	H.eq(PadLogic.affordable(d, "Move"), true)
	d.coins = 4
	H.eq(PadLogic.affordable(d, "Move"), false)
end)

print("Economy.rewardsBetween")
H.test("Lv1→4 보상: 🎫2 💎20", function()
	local r = Economy.rewardsBetween(1, 4)
	H.eq(r.tickets, 2)
	H.eq(r.stones, 20)
end)
H.test("동일 레벨은 0", function()
	local r = Economy.rewardsBetween(3, 3)
	H.eq(r.tickets + r.stones, 0)
end)

print("PadLogic – Gate / Worker")
H.test("게이트: 레벨 부족이면 canPay false, 아이콘 Lock", function()
	local d = base()
	d.coins = 99999
	local i = PadLogic.info(d, "Gate:Z2")
	H.eq(i.cost, 800)
	H.eq(i.minLevel, 3)
	H.eq(i.levelOk, false)
	H.eq(i.icon, "Lock")
	H.eq(PadLogic.canPay(i), false)
	H.eq(PadLogic.affordable(d, "Gate:Z2"), false)
end)
H.test("게이트: 레벨 충족 + 코인 → affordable, 해금 후 maxed", function()
	local d = base()
	d.level = 3
	d.coins = 800
	H.eq(PadLogic.affordable(d, "Gate:Z2"), true)
	H.eq(PadLogic.info(d, "Gate:Z2").icon, "Unlock")
	d.zones.Z2 = true
	H.eq(PadLogic.info(d, "Gate:Z2").maxed, true)
end)
H.test("Z4 티저 게이트는 결제 불가", function()
	local d = base()
	d.level = 10
	d.coins = 1e6
	local i = PadLogic.info(d, "Gate:Z4")
	H.eq(i.teaser, true)
	H.eq(i.icon, "Construction")
	H.eq(PadLogic.canPay(i), false)
end)
H.test("일꾼 패드: Z1 1명 400, 고용 후 maxed", function()
	local d = base()
	local i = PadLogic.info(d, "Worker:Z1")
	H.eq(i.cost, 400)
	H.eq(i.icon, "Robot")
	d.workers.Z1 = { count = 1, level = 0, paid = 0 }
	H.eq(PadLogic.info(d, "Worker:Z1").maxed, true)
	H.eq(PadLogic.info(d, "Worker:Z3").cost, 10000)
end)
H.test("zoneOpen: 잠긴 구역 패드는 닫힘, 게이트는 열림", function()
	local d = base()
	H.eq(PadLogic.zoneOpen(d, "Move", "Z2"), false)
	H.eq(PadLogic.zoneOpen(d, "Gate:Z2", "Z2"), true)
	H.eq(PadLogic.zoneOpen(d, "Expand:Z1", "Z1"), true)
end)

print("Layout")
local Layout = shim.require("src/shared/Config/Layout")
H.test("구역 원점: 북·동·남·서", function()
	local o1, o2, o3, o4 = Layout.origin("Z1"), Layout.origin("Z2"), Layout.origin("Z3"), Layout.origin("Z4")
	H.near(o1[3], -34, 1e-6) -- 북 = -Z
	H.near(o2[1], 34, 1e-6) -- 동 = +X
	H.near(o3[3], 34, 1e-6) -- 남 = +Z
	H.near(o4[1], -34, 1e-6) -- 서 = -X
end)
H.test("구역 상대 좌표 회전: Z3 은 항등, Z2 는 +Z→+X", function()
	local f = Layout.pos("Z3", "Field1")
	H.near(f[1], 0, 1e-6)
	H.near(f[3], 46, 1e-6)
	local g = Layout.pos("Z2", "Gate")
	H.near(g[1], 20, 1e-6) -- 허브 가장자리 (34-14)
	H.near(g[3], 0, 1e-6)
	local s2 = Layout.pos("Z2", "SellStand") -- rel(-18,0,6) → (6, 0, 18) + (34,0,0)
	H.near(s2[1], 40, 1e-6)
	H.near(s2[3], 18, 1e-6)
	H.truthy(Layout.padPos("Z2", "Grow") ~= nil)
	H.eq(Layout.padPos("Z1", "Grow"), nil)
	H.eq(Layout.zoneValue("Z2", "SellStandSize")[1], 8)
end)
H.test("플롯 격자 3×2", function()
	local c1, c6 = Layout.plotCenter(1), Layout.plotCenter(6)
	H.near(c1[1], -230, 1e-6)
	H.near(c1[3], -115, 1e-6)
	H.near(c6[1], 230, 1e-6)
	H.near(c6[3], 115, 1e-6)
end)
