--!strict
-- 뽑기. DevSpec §6-1. 색은 HEX 문자열(클라 변환).
local Gacha = {
	Weights = { [1] = 55, [2] = 30, [3] = 12, [4] = 3 },
	Pity = 10,
	Effect = {
		Tool = { 0.10, 0.25, 0.50, 1.00 }, -- 수확속도 배율 가산
		Shoes = { 0.10, 0.20, 0.35, 0.60 }, -- 이동속도 배율 가산
		Bag = { 5, 15, 30, 60 }, -- 운반량 가산
	},
	Radius = { 0.5, 1.0, 2.0, 3.0 }, -- 도구 ★별 수확 반경 추가
	Dismantle = { 1, 3, 10, 30 }, -- 분해 시 💎
	StoneCost = 50,
	Slots = { "Tool", "Shoes", "Bag" },
	-- 무료 티켓 n회차 리깅
	FreeRig = {
		[1] = { minStar = 3, forceSlot = "Tool" },
		[3] = { minStar = 2 },
	} :: { [number]: { minStar: number, forceSlot: string? } },
	Colors = { "#AAAAAA", "#5AC85A", "#468CFF", "#FFC828" },
	PullCooldown = 1.5,
}

return Gacha
