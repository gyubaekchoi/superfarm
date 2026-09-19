--!strict
-- 플레이어 데이터 로드·저장·패치. ProfileService 기반. DevSpec §2.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Types = require(Shared.Types)
local Remotes = require(Shared.Remotes)
local Signal = require(Packages.Signal)
local ProfileService = require(script.Parent.Parent.Vendor.ProfileService)

type PlayerData = Types.PlayerData
type DataPatch = Types.DataPatch

local STORE_NAME = "PlayerData_v1"
local CURRENT_VERSION = 2

local DEFAULT: PlayerData = {
	version = CURRENT_VERSION,
	coins = 0,
	stones = 0,
	tickets = 0,
	xp = 0,
	level = 1,
	zones = { Z1 = true },
	gates = {},
	pads = {},
	fields = { Z1 = { expansion = 0, paid = 0, crop2 = false, crop2Paid = 0 } },
	workers = {},
	gear = {},
	enhance = 0,
	gacha = { freeCount = 0, paidCount = 0, pity = 0 },
	passes = {},
	boosts = { coinX2Until = 0 },
	tutorial = 0,
	daily = { lastChest = 0 },
	purchases = {},
	stats = { totalCoins = 0, totalHarvest = 0, playtimeSec = 0, enhanceBursts = 0 },
}

-- [fromVersion] = function(data) → data를 fromVersion+1 형태로 변환
local Migrations: { [number]: (any) -> () } = {
	[1] = function(data)
		data.purchases = data.purchases or {}
	end,
}

local DataService = {}
DataService.Priority = 100
DataService.Loaded = Signal.new() -- (player, data)
DataService.Released = Signal.new() -- (player)
DataService.Patched = Signal.new() -- (player, patches)

local profiles: { [Player]: any } = {}
local joinedAt: { [Player]: number } = {}
local store: any

local function migrate(data: any)
	while data.version < CURRENT_VERSION do
		local fn = Migrations[data.version]
		if not fn then
			break
		end
		fn(data)
		data.version += 1
	end
end

local function onPlayerAdded(player: Player)
	local profile = store:LoadProfileAsync("Player_" .. player.UserId)
	if profile == nil then
		player:Kick("데이터를 불러오지 못했습니다. 잠시 후 다시 접속해 주세요.")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile:ListenToRelease(function()
		profiles[player] = nil
		if player:IsDescendantOf(Players) then
			player:Kick("다른 곳에서 접속되어 연결이 끊어졌습니다.")
		end
	end)
	if not player:IsDescendantOf(Players) then
		profile:Release()
		return
	end
	migrate(profile.Data)
	profiles[player] = profile
	joinedAt[player] = os.clock()
	Remotes.get("DataSync"):FireClient(player, profile.Data)
	print(("[DataService] loaded %s · lv%d · coins %d"):format(player.Name, profile.Data.level, profile.Data.coins))
	DataService.Loaded:Fire(player, profile.Data)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		local t0 = joinedAt[player]
		if t0 then
			profile.Data.stats.playtimeSec += math.floor(os.clock() - t0)
		end
		DataService.Released:Fire(player)
		profile:Release()
	end
	profiles[player] = nil
	joinedAt[player] = nil
end

function DataService:Init()
	store = ProfileService.GetProfileStore(STORE_NAME, DEFAULT)
	-- Studio에서 API 접근이 꺼져 있으면 ProfileService가 자동으로 mock 저장소를 사용한다.
	if RunService:IsStudio() then
		print("[DataService] Studio 환경 · API Services 미허용 시 mock 저장소로 동작")
	end
end

function DataService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
end

-- 조회 -----------------------------------------------------------------

function DataService:Get(player: Player): PlayerData?
	local p = profiles[player]
	return p and p.Data
end

-- 로드될 때까지 대기 (최대 timeout초). 실패 시 nil
function DataService:WaitFor(player: Player, timeout: number?): PlayerData?
	local deadline = os.clock() + (timeout or 15)
	while os.clock() < deadline do
		local d = self:Get(player)
		if d then
			return d
		end
		if not player:IsDescendantOf(Players) then
			return nil
		end
		task.wait(0.1)
	end
	return nil
end

function DataService:IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- 변경 -----------------------------------------------------------------

local function resolve(root: any, path: string): (any, string)
	local parts = string.split(path, ".")
	local node = root
	for i = 1, #parts - 1 do
		local nxt = node[parts[i]]
		if type(nxt) ~= "table" then
			nxt = {}
			node[parts[i]] = nxt
		end
		node = nxt
	end
	return node, parts[#parts]
end

-- 여러 경로를 갱신하고 클라이언트에 패치 전송. path 예: "coins", "pads.Move.level"
function DataService:Patch(player: Player, patches: { DataPatch })
	local d = self:Get(player)
	if not d then
		return
	end
	for _, p in patches do
		local node, key = resolve(d, p.path)
		node[key] = p.value
	end
	Remotes.get("DataPatch"):FireClient(player, patches)
	DataService.Patched:Fire(player, patches)
end

function DataService:Set(player: Player, path: string, value: any)
	self:Patch(player, { { path = path, value = value } })
end

-- 숫자 필드 증감. 결과값 반환
function DataService:Add(player: Player, path: string, delta: number): number?
	local d = self:Get(player)
	if not d then
		return nil
	end
	local node, key = resolve(d, path)
	local v = (node[key] or 0) + delta
	node[key] = v
	local patches = { { path = path, value = v } }
	Remotes.get("DataPatch"):FireClient(player, patches)
	DataService.Patched:Fire(player, patches)
	return v
end

DataService.DEFAULT = DEFAULT
return DataService
