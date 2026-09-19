--!strict
-- 폭발 강화. 장비 세트 단일 단계. DevSpec §7-2.
local Enhance = {
	MaxLevel = 30,
	PerLevel = 0.03,
	MinBurst = 3,
	CritChance = 0.15,
	CritGain = 2,
	Aura = { [5] = "White", [10] = "BlueFlame", [15] = "Gold", [20] = "Rainbow", [30] = "Galaxy" },
	StepTimeMax = 0.20,
	StepTimeMin = 0.08,
	TotalTimeCap = 3.2,
	BurstCooldown = 4,
}

-- lv → lv+1 로 올리는 비용
function Enhance.cost(lv: number): number
	return 2 + lv
end

-- 보유 💎로 현재 단계에서 몇 단계 올릴 수 있는지 (크리티컬 미포함)
function Enhance.previewLevels(stones: number, lv: number): (number, number)
	local n, spent = 0, 0
	while lv + n < Enhance.MaxLevel and stones - spent >= Enhance.cost(lv + n) do
		spent += Enhance.cost(lv + n)
		n += 1
	end
	return n, spent
end

function Enhance.isActive(stones: number, lv: number): boolean
	local n = Enhance.previewLevels(stones, lv)
	return n >= Enhance.MinBurst
end

return Enhance
