--!strict
-- 폭발 강화 판정 (순수 함수, 데이터 직접 변경). DevSpec §7-4.
local Types = require(script.Parent.Types)
local Enhance = require(script.Parent.Config.Enhance)
local Economy = require(script.Parent.Config.Economy)

export type Step = { gain: number, crit: boolean }
export type Result = { from: number, to: number, steps: { Step }, stonesSpent: number }

local EnhanceLogic = {}

-- 강화대 사용 가능 레벨
function EnhanceLogic.unlocked(d: Types.PlayerData): boolean
	for lv, key in Economy.LevelUnlocks do
		if key == "Enhance" then
			return d.level >= lv
		end
	end
	return true
end

function EnhanceLogic.canBurst(d: Types.PlayerData): boolean
	return EnhanceLogic.unlocked(d) and Enhance.isActive(d.stones, d.enhance)
end

-- rng: chance(p)
function EnhanceLogic.burst(d: Types.PlayerData, rng: any): Result?
	if not EnhanceLogic.canBurst(d) then
		return nil
	end
	local from = d.enhance
	local steps: { Step } = {}
	local spent = 0
	while d.enhance < Enhance.MaxLevel and d.stones >= Enhance.cost(d.enhance) do
		local cost = Enhance.cost(d.enhance)
		d.stones -= cost
		spent += cost
		local crit = rng:chance(Enhance.CritChance)
		local gain = if crit then Enhance.CritGain else 1
		gain = math.min(gain, Enhance.MaxLevel - d.enhance)
		d.enhance += gain
		table.insert(steps, { gain = gain, crit = crit })
	end
	d.stats.enhanceBursts += 1
	return { from = from, to = d.enhance, steps = steps, stonesSpent = spent }
end

-- 오라 등급 이름 (해당 단계 이하 최고 임계)
function EnhanceLogic.auraFor(level: number): string?
	local best, bestLv = nil, -1
	for lv, name in Enhance.Aura do
		if level >= lv and lv > bestLv then
			best, bestLv = name, lv
		end
	end
	return best
end

return EnhanceLogic
