--!strict
-- 감쇠 스프링 (semi-implicit Euler). number / Vector2 / Vector3 모두 사용 가능.
local Spring = {}
Spring.__index = Spring

export type Spring<T> = typeof(setmetatable({} :: { x: T, v: T, k: number, c: number }, Spring))

function Spring.new<T>(stiffness: number, damping: number, initial: T): Spring<T>
	local zero: any = (initial :: any) * 0
	return setmetatable({ x = initial, v = zero, k = stiffness, c = damping }, Spring) :: any
end

function Spring.update<T>(self: Spring<T>, dt: number, target: T): T
	-- 큰 dt에서 폭주 방지: 최대 1/30초 단위로 서브스텝
	local steps = math.max(1, math.ceil(dt / (1 / 30)))
	local h = dt / steps
	local x: any, v: any = self.x, self.v
	for _ = 1, steps do
		local a = (target :: any - x) * self.k - v * self.c
		v = v + a * h
		x = x + v * h
	end
	self.x = x
	self.v = v
	return x
end

function Spring.impulse<T>(self: Spring<T>, dv: T)
	self.v = (self.v :: any) + dv
end

function Spring.set<T>(self: Spring<T>, x: T)
	self.x = x
	self.v = (x :: any) * 0
end

return Spring
