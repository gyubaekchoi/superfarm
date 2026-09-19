--!strict
-- 숫자 라벨 롤링: 목표값까지 0.3초에 걸쳐 보간. 값 상승 시 스케일 펀치.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Util.Format)

local NumberRoller = {}
NumberRoller.__index = NumberRoller

export type Roller = typeof(setmetatable(
	{} :: {
		label: TextLabel,
		shown: number,
		target: number,
		from: number,
		t: number,
		dur: number,
		punch: number,
		short: boolean,
	},
	NumberRoller
))

local active: { Roller } = {}

function NumberRoller.new(label: TextLabel, short: boolean?, duration: number?): Roller
	local self = setmetatable({
		label = label,
		shown = 0,
		target = 0,
		from = 0,
		t = 1,
		dur = duration or 0.3,
		punch = 0,
		short = short ~= false,
	}, NumberRoller)
	table.insert(active, self)
	label.Text = "0"
	return self
end

function NumberRoller.set(self: Roller, value: number, instant: boolean?)
	if instant then
		self.shown = value
		self.target = value
		self.t = 1
		self.label.Text = if self.short then Format.short(value) else tostring(math.floor(value))
		return
	end
	if value ~= self.target then
		if value > self.target then
			self.punch = 1
		end
		self.from = self.shown
		self.target = value
		self.t = 0
	end
end

RunService.Heartbeat:Connect(function(dt)
	for _, r in active do
		if r.t < 1 then
			r.t = math.min(r.t + dt / r.dur, 1)
			local a = 1 - (1 - r.t) ^ 3
			r.shown = r.from + (r.target - r.from) * a
			r.label.Text = if r.short then Format.short(r.shown) else tostring(math.floor(r.shown + 0.5))
		end
		if r.punch > 0 then
			r.punch = math.max(r.punch - dt * 4, 0)
			local s = 1 + 0.25 * r.punch
			r.label.Size =
				UDim2.new(r.label.Size.X.Scale, r.label.Size.X.Offset, r.label.Size.Y.Scale, r.label.Size.Y.Offset)
			local scale = r.label:FindFirstChildOfClass("UIScale")
			if not scale then
				scale = Instance.new("UIScale")
				scale.Parent = r.label
			end
			scale.Scale = s
		end
	end
end)

return NumberRoller
