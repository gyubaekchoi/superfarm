--!strict
-- 경제·진행. DevSpec §8-1.
local Economy = {
	XPPerCoin = 1,
	-- 누적 XP
	LevelXP = {
		[2] = 150,
		[3] = 1000,
		[4] = 4000,
		[5] = 8000,
		[6] = 14000,
		[7] = 28000,
		[8] = 42000,
		[9] = 65000,
		[10] = 100000,
	},
	MaxLevel = 10,
	LevelRewards = {
		[2] = { tickets = 1 },
		[3] = { stones = 10 },
		[4] = { tickets = 1, stones = 10 },
		[5] = { stones = 20 },
		[6] = { tickets = 2 },
		[7] = { stones = 30 },
		[8] = { tickets = 2, stones = 30 },
		[9] = { stones = 40 },
		[10] = { tickets = 3 },
	} :: { [number]: { tickets: number?, stones: number? } },
	LevelUnlocks = { [2] = "Gacha", [3] = "GateZ2", [4] = "Enhance", [6] = "GateZ3", [10] = "GateZ4Teaser" },
	StoneDropRate = 0.01,
	CoinDenoms = { 1, 5, 25, 100, 500, 2500 },
	MaxGroundCoins = 30,
	MaxCoinsPerDeposit = 8,
	DailyChest = { stones = 10, ticketChance = 0.3, cooldownSec = 72000 },
	TimerChest = { everySec = 1200, stonesMin = 5, stonesMax = 15 },

	-- 기준 스탯
	BaseSpeed = 16,
	BaseInterval = 0.25,
	BaseCap = 10,
	BaseRadius = 4.5, -- 간격 4 밭에서 가운데 줄을 걸으면 양옆 줄까지 닿도록 (4면 경계값에서 누락)
	MaxSpeed = 40,
	MinInterval = 0.03,
	PadMoveStep = 1, -- 단계당 +1 studs/s
	PadHarvestStep = 0.013, -- 단계당 −0.013s
	PadCapStep = 4, -- 단계당 +4

	-- 판정 거리
	SellRadius = 5,
	CoinMagnetRadius = 6,
	PadRadius = 3,
	ServerTick = 0.1,
}

-- (oldLv, newLv] 구간 보상 합산
function Economy.rewardsBetween(oldLv: number, newLv: number): { tickets: number, stones: number }
	local r = { tickets = 0, stones = 0 }
	for lv = oldLv + 1, newLv do
		local rw = Economy.LevelRewards[lv]
		if rw then
			r.tickets += rw.tickets or 0
			r.stones += rw.stones or 0
		end
	end
	return r
end

function Economy.levelForXP(xp: number): number
	local lv = 1
	for level = 2, Economy.MaxLevel do
		if xp >= Economy.LevelXP[level] then
			lv = level
		else
			break
		end
	end
	return lv
end

return Economy
