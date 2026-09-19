-- 60분 이상적 플레이어 경제 시뮬레이터. lune run tools/sim [minutes]
-- 가이드 우선순위대로 소비하고, 가장 비싼 열린 구역에서 수확→판매를 반복한다고 가정.
local process = require("@lune/process")
local shim = require("../tests/_shim")
local Crops = shim.require("src/shared/Config/Crops")
local Zones = shim.require("src/shared/Config/Zones")
local Pads = shim.require("src/shared/Config/Pads")
local Gacha = shim.require("src/shared/Config/Gacha")
local Enhance = shim.require("src/shared/Config/Enhance")
local Economy = shim.require("src/shared/Config/Economy")
local Layout = shim.require("src/shared/Config/Layout")
local Stats = shim.require("src/shared/Stats")
local PadLogic = shim.require("src/shared/PadLogic")

local MINUTES = tonumber(process.args[1]) or 60
local SEED = tonumber(process.args[2]) or 1
math.randomseed(SEED)

local d = {
	version = 1, coins = 0, stones = 0, tickets = 0, xp = 0, level = 1,
	zones = { Z1 = true }, gates = {}, pads = {}, fields = { Z1 = { expansion = 0, paid = 0, crop2 = false, crop2Paid = 0 } },
	workers = {}, gear = {}, enhance = 0,
	gacha = { freeCount = 0, paidCount = 0, pity = 0 }, passes = {}, boosts = { coinX2Until = 0 },
	tutorial = 0, daily = { lastChest = 0 },
	stats = { totalCoins = 0, totalHarvest = 0, playtimeSec = 0, enhanceBursts = 0 },
}

local t = 0
local log = {}
local bursts = 0
local function mark(msg) table.insert(log, ("%5.1fm  %s"):format(t / 60, msg)) end

-- 가챠 (무료 리깅 포함)
local function weightedStar()
	local r = math.random() * 100
	local acc = 0
	for star = 1, 4 do acc += Gacha.Weights[star]; if r < acc then return star end end
	return 4
end
local function pull()
	d.tickets -= 1
	local n = d.gacha.freeCount + 1
	local star = weightedStar()
	local rig = Gacha.FreeRig[n]
	if rig then star = math.max(star, rig.minStar) end
	if d.gacha.pity >= Gacha.Pity - 1 then star = math.max(star, 3) end
	d.gacha.pity = star >= 3 and 0 or d.gacha.pity + 1
	local slot = (rig and rig.forceSlot) or Gacha.Slots[math.random(1, 3)]
	local cur = d.gear[slot]
	if not cur or star > cur.star then
		if cur then d.stones += Gacha.Dismantle[cur.star] end
		d.gear[slot] = { star = star }
		mark(("🎁 #%d %s ★%d 장착"):format(n, slot, star))
	else
		d.stones += Gacha.Dismantle[star]
	end
	d.gacha.freeCount = n
end

local function tryEnhance()
	if Enhance.isActive(d.stones, d.enhance) then
		local from = d.enhance
		while d.enhance < Enhance.MaxLevel and d.stones >= Enhance.cost(d.enhance) do
			d.stones -= Enhance.cost(d.enhance)
			d.enhance += (math.random() < Enhance.CritChance) and 2 or 1
		end
		d.enhance = math.min(d.enhance, Enhance.MaxLevel)
		bursts += 1
		mark(("⚒️ 폭발 강화 +%d → +%d  ⚡%d"):format(from, d.enhance, Stats.fromData(d).power))
	end
end

local function checkLevel()
	local nl = Economy.levelForXP(d.xp)
	if nl > d.level then
		local r = Economy.rewardsBetween(d.level, nl)
		d.level = nl
		d.tickets += r.tickets
		d.stones += r.stones
		mark(("⭐ Lv%d  (+🎫%d +💎%d)  코인 %d"):format(nl, r.tickets, r.stones, d.coins))
		while d.tickets > 0 do pull() end
		tryEnhance()
	end
end

-- 구역 정보
local function zoneCrops(zone)
	local zdef = Zones.Defs[zone]
	local f = d.fields[zone] or { expansion = 0, crop2 = false }
	local n, width
	if zdef.treeGrid then
		local g = zdef.treeGrid[f.expansion + 1]
		n = g[1] * g[2] * (Crops[zdef.crops[1]].perTree or 5)
		width = g[2] * Layout.TreeSpacing
	else
		local g = zdef.fieldGrid[f.expansion + 1]
		n = g[1] * g[2]
		width = g[2] * Layout.CropSpacing
	end
	local fields = f.crop2 and 2 or 1
	return n, fields, width
end

local function bestZone()
	local best, bestPrice = "Z1", 0
	for _, z in Zones.Order do
		local zdef = Zones.Defs[z]
		if d.zones[z] and zdef.crops then
			local price = Crops[zdef.crops[1]].price * (zdef.sellMult or 1)
			if price > bestPrice then best, bestPrice = z, price end
		end
	end
	return best
end

-- 한 번의 수확→판매 트립
local function trip()
	local zone = bestZone()
	local zdef = Zones.Defs[zone]
	local st = Stats.fromData(d)
	local n, fields, width = zoneCrops(zone)
	local f = d.fields[zone] or { crop2 = false }
	local growMult = Pads.growMult(d.pads.Grow and d.pads.Grow.level or 0)
	-- 밭 왕복 + 밭 가로지르기
	local walk = (24 + width * fields) / st.speed
	-- 재성장 제약: 트립 주기 동안 다시 자라는 작물 수
	local crops = { zdef.crops[1] }
	if f.crop2 then table.insert(crops, zdef.crops[2]) end
	local total = 0
	local harvested = 0
	local room = st.cap
	for _, cropId in crops do
		local c = Crops[cropId]
		local grow = c.growSec * growMult
		local est = walk + room * st.interval
		local ready = math.min(n, n * math.max(est, 1) / grow + (t < 5 and n or 0))
		local take = math.floor(math.min(room, ready))
		room -= take
		harvested += take
		total += take * c.price * (zdef.sellMult or 1)
	end
	if harvested == 0 then harvested = 1; total = Crops[crops[1]].price end
	local dt = walk + harvested * st.interval + harvested * Layout.DepositInterval
	t += dt
	local income = math.floor(total)
	d.coins += income
	d.xp += income
	d.stats.totalCoins += income
	d.stats.totalHarvest += harvested
	for _ = 1, harvested do if math.random() < Economy.StoneDropRate then d.stones += 1 end end
	-- 일꾼 수입 (구역별)
	for z, w in d.workers do
		local zd = Zones.Defs[z]
		if d.zones[z] and w.count > 0 and zd.crops then
			local price = Crops[zd.crops[1]].price * (zd.sellMult or 1)
			local rate = Layout.Worker.Cap / (30 / Layout.Worker.Speed + Layout.Worker.Cap * Layout.Worker.Interval)
			local nz = zoneCrops(z)
			rate = math.min(rate, nz / (Crops[zd.crops[1]].growSec * growMult) * 0.5)
			local winc = math.floor(rate * price * dt * w.count)
			d.coins += winc
			d.xp += winc
		end
	end
	checkLevel()
	return dt
end

-- 소비: 게이트 우선, 이후 가장 싼 결제 가능 패드 반복
local ALL_PADS = {}
for _, z in Zones.Order do
	local zdef = Zones.Defs[z]
	if z ~= "Z1" then table.insert(ALL_PADS, { id = "Gate:" .. z, zone = z }) end
	if not zdef.teaser then
		for key in Layout.zoneValue(z, "Pads") do table.insert(ALL_PADS, { id = key, zone = z }) end
		table.insert(ALL_PADS, { id = "Expand:" .. z, zone = z })
		if zdef.crops and zdef.crops[2] then table.insert(ALL_PADS, { id = "Crop2:" .. z, zone = z }) end
		if zdef.workerMax and zdef.workerMax > 0 then table.insert(ALL_PADS, { id = "Worker:" .. z, zone = z }) end
	end
end

local function pay(pad)
	local info = PadLogic.info(d, pad.id)
	d.coins -= PadLogic.remaining(info)
	if info.kind == "Stat" then
		d.pads[info.key] = { level = info.level + 1, paid = 0 }
	elseif info.kind == "Expand" then
		d.fields[info.key] = d.fields[info.key] or { expansion = 0, paid = 0, crop2 = false, crop2Paid = 0 }
		d.fields[info.key].expansion += 1
	elseif info.kind == "Crop2" then
		d.fields[info.key] = d.fields[info.key] or { expansion = 0, paid = 0, crop2 = false, crop2Paid = 0 }
		d.fields[info.key].crop2 = true
	elseif info.kind == "Worker" then
		d.workers[info.key] = d.workers[info.key] or { count = 0, level = 0, paid = 0 }
		d.workers[info.key].count += 1
		mark(("🤖 일꾼 %s #%d"):format(info.key, d.workers[info.key].count))
	else
		d.zones[info.key] = true
		mark(("🔓 %s 해금  (코인 %d 남음)"):format(info.key, d.coins))
	end
	t += 1.5 + 6 -- 패드까지 걷기 + 드레인
end

local CHEAP_RATIO = tonumber(process.args[3]) or 0.2
local function spend()
	for _ = 1, 20 do
		-- 게이트 목표(레벨 OK, 미해금)가 있으면 저축: 게이트 잔액의 CHEAP_RATIO 이하 패드만 구매
		local gateRem = nil
		for _, pad in ALL_PADS do
			local info = PadLogic.info(d, pad.id)
			if info.kind == "Gate" and PadLogic.canPay(info) then
				local rem = PadLogic.remaining(info)
				if not gateRem or rem < gateRem then gateRem = rem end
			end
		end
		local gate, cheapest, cheapRem = nil, nil, math.huge
		for _, pad in ALL_PADS do
			if PadLogic.zoneOpen(d, pad.id, pad.zone) and PadLogic.affordable(d, pad.id) then
				local info = PadLogic.info(d, pad.id)
				if info.kind == "Gate" then gate = gate or pad
				else
					local rem = PadLogic.remaining(info)
					if rem < cheapRem and (not gateRem or rem <= gateRem * CHEAP_RATIO) then cheapRem, cheapest = rem, pad end
				end
			end
		end
		local pick = gate or cheapest
		if not pick then return end
		pay(pick)
	end
end

-- 메인 루프
local nextReport = 300
local cum = {}
while t < MINUTES * 60 do
	trip()
	spend()
	tryEnhance()
	if t >= nextReport then
		table.insert(cum, ("%dm:%d"):format(nextReport / 60, d.stats.totalCoins))
		nextReport += 300
	end
end
print("누적 코인(=XP) 5분 단위: " .. table.concat(cum, "  "))

print(("=== SIM %d min (seed %d) ==="):format(MINUTES, SEED))
for _, l in log do print(l) end
local st = Stats.fromData(d)
print(("\n최종: Lv%d  ⚡%d  코인 %d (누적 %d)  💎 %d  강화 +%d  폭발 %d회  수확 %d회"):format(d.level, st.power, d.coins, d.stats.totalCoins, d.stones, d.enhance, bursts, d.stats.totalHarvest))
local pl = {}
for k, v in d.pads do table.insert(pl, k .. "=" .. v.level) end
table.sort(pl)
print("패드: " .. table.concat(pl, " "))
for _, z in Zones.Order do
	local f = d.fields[z]
	if f then print(("%s: 확장 %d, 2번째 작물 %s, 일꾼 %d"):format(z, f.expansion, tostring(f.crop2), d.workers[z] and d.workers[z].count or 0)) end
end
