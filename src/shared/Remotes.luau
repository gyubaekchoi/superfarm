--!strict
-- Remote 정의·생성·조회. 이름 문자열 직접 사용 금지. DevSpec §4.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

type Kind = "Reliable" | "Unreliable"

-- 서버 → 클라
local S2C: { [string]: Kind } = {
	DataSync = "Reliable",
	DataPatch = "Reliable",
	CropReset = "Unreliable",
	HarvestBatch = "Unreliable",
	StackFull = "Reliable",
	SellDeposit = "Unreliable",
	CoinSpawn = "Reliable",
	CoinCollect = "Unreliable",
	StoneDrop = "Reliable",
	PadProgress = "Unreliable",
	PadComplete = "Reliable",
	ZoneUnlocked = "Reliable",
	LevelUp = "Reliable",
	GachaResult = "Reliable",
	EnhanceResult = "Reliable",
	GuideTarget = "Reliable",
	WorkerState = "Unreliable",
	Reward = "Reliable", -- 일일 상자·상품 지급 연출 { kind, stones?, tickets?, boostSec? }
}

-- 클라 → 서버 (초당 허용 횟수)
local C2S: { [string]: number } = {
	RequestGacha = 2,
	RequestEnhance = 1,
	RequestPurchase = 2,
	ClaimDaily = 1,
	GuideAck = 5,
}

local Remotes = {}
Remotes.S2C = S2C
Remotes.C2S = C2S

local folder: Folder

if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for name, kind in S2C do
		local inst = Instance.new(if kind == "Unreliable" then "UnreliableRemoteEvent" else "RemoteEvent")
		inst.Name = name
		inst.Parent = folder
	end
	for name in C2S do
		local inst = Instance.new("RemoteEvent")
		inst.Name = name
		inst.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.get(name: string): RemoteEvent
	assert(S2C[name] or C2S[name], "unknown remote: " .. name)
	return folder:WaitForChild(name) :: RemoteEvent
end

-- 서버 전용: 레이트리밋이 걸린 클라→서버 핸들러 등록
function Remotes.onServer(name: string, handler: (Player, ...any) -> ())
	assert(RunService:IsServer(), "server only")
	local perSec = assert(C2S[name], "not a C2S remote: " .. name)
	local buckets: { [Player]: { count: number, windowStart: number } } = {}
	Remotes.get(name).OnServerEvent:Connect(function(player, ...)
		local now = os.clock()
		local b = buckets[player]
		if not b or now - b.windowStart >= 1 then
			b = { count = 0, windowStart = now }
			buckets[player] = b
		end
		b.count += 1
		if b.count > perSec then
			warn(("[Remotes] rate limit %s by %s"):format(name, player.Name))
			return
		end
		handler(player, ...)
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		buckets[p] = nil
	end)
end

return Remotes
