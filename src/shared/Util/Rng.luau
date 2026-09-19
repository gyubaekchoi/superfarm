--!strict
-- 시드 가능한 RNG. Roblox의 Random을 쓰고, Lune 등 비-Roblox 환경에서는 math.random으로 대체한다.
local Rng = {}
Rng.__index = Rng

type Source = { NextNumber: (any) -> number, NextInteger: (any, number, number) -> number }

local function makeSource(seed: number?): Source
	local ok, r = pcall(function()
		local R = Random :: any
		return if seed then R.new(seed) else R.new()
	end)
	if ok and r then
		return r
	end
	-- fallback
	if seed then
		math.randomseed(seed)
	end
	return {
		NextNumber = function()
			return math.random()
		end,
		NextInteger = function(_, a: number, b: number)
			return math.random(a, b)
		end,
	}
end

function Rng.new(seed: number?)
	return setmetatable({ _r = makeSource(seed) }, Rng)
end

function Rng:chance(p: number): boolean
	return self._r:NextNumber() < p
end

-- weights: {[key]=weight}. 키를 반환.
function Rng:weighted(weights: { [any]: number }): any
	local total = 0
	for _, w in weights do
		total += w
	end
	local roll = self._r:NextNumber() * total
	local acc = 0
	local last
	for k, w in weights do
		acc += w
		last = k
		if roll < acc then
			return k
		end
	end
	return last
end

function Rng:pick<T>(list: { T }): T
	return list[self._r:NextInteger(1, #list)]
end

-- [a, b) 실수. 인자 없으면 [0, 1)
function Rng:float(a: number?, b: number?): number
	local r = self._r:NextNumber()
	if a and b then
		return a + r * (b - a)
	end
	return r
end

function Rng:int(a: number, b: number): number
	return self._r:NextInteger(a, b)
end

return Rng
