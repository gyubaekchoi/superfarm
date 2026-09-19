--!strict
-- 이동 속도 검증. 허용 속도 초과 시 0.5초간 수확·코인 획득 무효. 킥 없음, 3회 누적마다 로그. DevSpec §14.
local Players = game:GetService("Players")

local PlotService = require(script.Parent.PlotService)
local StatsService = require(script.Parent.StatsService)

local AntiCheatService = {}
AntiCheatService.Priority = 84

type Track = { lastPos: Vector3?, strikes: number, suspiciousUntil: number, graceUntil: number }
local tracks: { [Player]: Track } = {}

local TOLERANCE_MULT = 1.4
local TOLERANCE_ADD = 6 -- studs/s (점프·경사 보정)
local GRACE_AFTER_SPAWN = 3
local SUSPICIOUS_SEC = 0.5

local function track(player: Player): Track
	local t = tracks[player]
	if not t then
		t = { lastPos = nil, strikes = 0, suspiciousUntil = 0, graceUntil = os.clock() + GRACE_AFTER_SPAWN }
		tracks[player] = t
	end
	return t
end

-- 서버가 의도적으로 순간이동시킬 때 (스폰·디버그) 호출
function AntiCheatService:Grace(player: Player, sec: number?)
	local t = track(player)
	t.graceUntil = os.clock() + (sec or GRACE_AFTER_SPAWN)
	t.lastPos = nil
end

function AntiCheatService:IsSuspicious(player: Player): boolean
	local t = tracks[player]
	return t ~= nil and os.clock() < t.suspiciousUntil
end

local function check(player: Player, dt: number)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local t = track(player)
	local pos = root.Position
	local now = os.clock()
	if t.lastPos and now >= t.graceUntil then
		local d = pos - t.lastPos
		local horiz = math.sqrt(d.X * d.X + d.Z * d.Z)
		local st = StatsService:Get(player)
		local allowed = ((st and st.speed or 16) * TOLERANCE_MULT + TOLERANCE_ADD) * dt
		if horiz > allowed then
			t.strikes += 1
			t.suspiciousUntil = now + SUSPICIOUS_SEC
			if t.strikes % 3 == 0 then
				warn(
					("[AntiCheat] %s moved %.1f studs in %.2fs (allowed %.1f) · strikes %d"):format(
						player.Name,
						horiz,
						dt,
						allowed,
						t.strikes
					)
				)
			end
		end
	end
	t.lastPos = pos
end

function AntiCheatService:Start()
	Players.PlayerAdded:Connect(function(p)
		track(p)
		p.CharacterAdded:Connect(function()
			self:Grace(p)
		end)
	end)
	for _, p in Players:GetPlayers() do
		track(p)
		p.CharacterAdded:Connect(function()
			self:Grace(p)
		end)
	end
	Players.PlayerRemoving:Connect(function(p)
		tracks[p] = nil
	end)
	PlotService.Tick:Connect(function(dt)
		for owner in PlotService:Owned() do
			check(owner, dt)
		end
	end)
end

return AntiCheatService
