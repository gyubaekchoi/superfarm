--!strict
-- 뽑기 판정 (순수 함수, 데이터를 직접 변경). 서버 GachaService 와 Lune 테스트가 공유. DevSpec §6-2.
local Types = require(script.Parent.Types)
local Gacha = require(script.Parent.Config.Gacha)

export type Result = {
	slot: Types.GearSlot,
	star: number,
	equipped: boolean,
	stonesGained: number,
	isFirst: boolean,
	isFree: boolean,
	n: number,
	previousStar: number?,
}

local GachaLogic = {}

-- rng: Rng 인스턴스 (weighted, pick)
function GachaLogic.roll(d: Types.PlayerData, isFree: boolean, rng: any): Result
	local n = if isFree then d.gacha.freeCount + 1 else d.gacha.paidCount + 1

	-- 등급
	local star: number = rng:weighted(Gacha.Weights)
	local rig = if isFree then Gacha.FreeRig[n] else nil
	if rig then
		star = math.max(star, rig.minStar)
	end
	if d.gacha.pity >= Gacha.Pity - 1 then
		star = math.max(star, 3)
	end
	d.gacha.pity = if star >= 3 then 0 else d.gacha.pity + 1

	-- 슬롯
	local slot: Types.GearSlot = (rig and rig.forceSlot or rng:pick(Gacha.Slots)) :: Types.GearSlot

	-- 장착: 더 높은 ★만 교체. 같거나 낮으면 분해
	local cur = d.gear[slot]
	local equipped, gained = false, 0
	if not cur or star > cur.star then
		if cur then
			gained = Gacha.Dismantle[cur.star]
		end
		d.gear[slot] = { star = star }
		equipped = true
	else
		gained = Gacha.Dismantle[star]
	end
	d.stones += gained

	if isFree then
		d.gacha.freeCount = n
	else
		d.gacha.paidCount = n
	end

	return {
		slot = slot,
		star = star,
		equipped = equipped,
		stonesGained = gained,
		isFirst = isFree and n == 1,
		isFree = isFree,
		n = n,
		previousStar = cur and cur.star or nil,
	}
end

-- 지불 가능 여부
function GachaLogic.canPay(d: Types.PlayerData, currency: string): boolean
	if currency == "Ticket" then
		return d.tickets >= 1
	elseif currency == "Stones" then
		return d.stones >= Gacha.StoneCost
	end
	return false
end

-- 지불 (성공 시 true). 티켓 = 무료 뽑기, 💎 = 유료 확률 그대로
function GachaLogic.pay(d: Types.PlayerData, currency: string): boolean
	if not GachaLogic.canPay(d, currency) then
		return false
	end
	if currency == "Ticket" then
		d.tickets -= 1
	else
		d.stones -= Gacha.StoneCost
	end
	return true
end

return GachaLogic
