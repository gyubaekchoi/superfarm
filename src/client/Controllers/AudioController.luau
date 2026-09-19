--!strict
-- 효과음 풀 + 피치 사다리. 에셋 ID가 0이면 재생을 건너뛴다. DevSpec §5-6.
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Config.Assets)

local AudioController = {}
AudioController.Priority = 90

local POOL_SIZE = 8
local pool: { Sound } = {}
local nextSlot = 1

type Ladder = { combo: number, lastAt: number, base: number, step: number, max: number, reset: number }
local ladders: { [string]: Ladder } = {
	Harvest = { combo = 0, lastAt = 0, base = 1.0, step = 0.05, max = 20, reset = 0.6 },
	Coin = { combo = 0, lastAt = 0, base = 0.9, step = 0.045, max = 20, reset = 0.6 },
}

local function isValid(id: string): boolean
	return id ~= nil and id ~= "" and not id:match("://0$")
end

function AudioController:Play(name: string, pitch: number?, volume: number?)
	local id = Assets.SFX[name]
	if not isValid(id) then
		return
	end
	local s = pool[nextSlot]
	nextSlot = nextSlot % POOL_SIZE + 1
	s:Stop()
	s.SoundId = id
	s.PlaybackSpeed = pitch or 1
	s.Volume = volume or 0.5
	s:Play()
end

-- 연속 재생 시 피치가 계단식으로 오르는 사운드
function AudioController:PlayLadder(name: string, volume: number?)
	local L = ladders[name]
	if not L then
		self:Play(name, 1, volume)
		return
	end
	local now = os.clock()
	if now - L.lastAt > L.reset then
		L.combo = 0
	end
	L.combo = math.min(L.combo + 1, L.max)
	L.lastAt = now
	self:Play(name, L.base + L.step * L.combo, volume)
end

function AudioController:Init()
	local group = Instance.new("SoundGroup")
	group.Name = "SFX"
	group.Parent = SoundService
	if isValid(Assets.BGM) then
		local music = Instance.new("SoundGroup")
		music.Name = "Music"
		music.Volume = 0.35
		music.Parent = SoundService
		local bgm = Instance.new("Sound")
		bgm.Name = "BGM"
		bgm.SoundId = Assets.BGM
		bgm.Looped = true
		bgm.Volume = 0.5
		bgm.SoundGroup = music
		bgm.Parent = SoundService
		bgm:Play()
	end
	for i = 1, POOL_SIZE do
		local s = Instance.new("Sound")
		s.Name = "Pool" .. i
		s.SoundGroup = group
		s.Parent = SoundService
		pool[i] = s
	end
end

return AudioController
