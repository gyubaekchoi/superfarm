--!strict
-- 바닥 코인 생성·상한 병합·자석 획득. DevSpec §5-7.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Layout = require(Shared.Config.Layout)
local Remotes = require(Shared.Remotes)
local CoinSplit = require(Shared.Util.CoinSplit)
local Rng = require(Shared.Util.Rng)
local PlotService = require(script.Parent.PlotService)
local EconomyService = require(script.Parent.EconomyService)
local AntiCheatService = require(script.Parent.AntiCheatService)

type PlotRuntime = PlotService.PlotRuntime
type GroundCoin = PlotService.GroundCoin

local CoinService = {}
CoinService.Priority = 58

local rng = Rng.new()

local function scatterPos(rt: PlotRuntime, stand: BasePart): Vector3
	local S = Layout.CoinScatter
	local zone = stand:GetAttribute("Zone") :: string
	local fieldWorld = PlotService.zoneOriginWorld(rt, zone)
	local dir = fieldWorld - stand.Position
	dir = Vector3.new(dir.X, 0, dir.Z)
	dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.xAxis
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local base = Vector3.new(stand.Position.X, Layout.GroundY + 0.6, stand.Position.Z)
	return base
		+ dir * (stand.Size.Magnitude / 3 + rng:float(S.minDist, S.maxDist))
		+ side * rng:float(-S.halfWidth, S.halfWidth)
end

-- 상한 초과 시 가치가 가장 낮은 두 코인을 병합. 제거된 id 목록 반환
local function enforceCap(rt: PlotRuntime, incoming: number, removed: { number }, merged: { GroundCoin })
	while rt.coinCount + incoming > Economy.MaxGroundCoins and rt.coinCount >= 2 do
		local a: GroundCoin?, b: GroundCoin?
		for _, c in rt.coins do
			if not a or c.value < a.value then
				b = a
				a = c
			elseif not b or c.value < b.value then
				b = c
			end
		end
		if not a or not b then
			break
		end
		rt.coins[a.id] = nil
		rt.coins[b.id] = nil
		rt.coinCount -= 2
		table.insert(removed, a.id)
		table.insert(removed, b.id)
		local m: GroundCoin = { id = rt.nextCoinId, pos = (a.pos + b.pos) / 2, value = a.value + b.value }
		rt.nextCoinId += 1
		rt.coins[m.id] = m
		rt.coinCount += 1
		table.insert(merged, m)
	end
end

function CoinService:Spawn(rt: PlotRuntime, value: number, stand: BasePart)
	local owner = rt.owner
	if not owner or value <= 0 then
		return
	end
	local pieces = CoinSplit.split(value, Economy.CoinDenoms, Economy.MaxCoinsPerDeposit)
	local removed: { number } = {}
	local merged: { GroundCoin } = {}
	enforceCap(rt, #pieces, removed, merged)

	local spawned: { GroundCoin } = {}
	for _, v in pieces do
		local c: GroundCoin = { id = rt.nextCoinId, pos = scatterPos(rt, stand), value = v }
		rt.nextCoinId += 1
		rt.coins[c.id] = c
		rt.coinCount += 1
		table.insert(spawned, c)
	end
	for _, m in merged do
		table.insert(spawned, m)
	end
	Remotes.get("CoinSpawn"):FireAllClients({
		plot = rt.index,
		origin = stand.Position + Vector3.new(0, stand.Size.Y / 2, 0),
		coins = spawned,
		remove = removed,
	})
end

local function tickPlot(rt: PlotRuntime)
	local owner = rt.owner
	if not owner or rt.coinCount == 0 or AntiCheatService:IsSuspicious(owner) then
		return
	end
	local char = owner.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local pos = root.Position
	local r2 = Economy.CoinMagnetRadius * Economy.CoinMagnetRadius
	local ids: { number } = {}
	local total = 0
	for id, c in rt.coins do
		local d = c.pos - pos
		if d.X * d.X + d.Z * d.Z <= r2 then
			table.insert(ids, id)
			total += c.value
		end
	end
	if #ids == 0 then
		return
	end
	for _, id in ids do
		rt.coins[id] = nil
	end
	rt.coinCount -= #ids
	EconomyService:AddCoins(owner, total)
	Remotes.get("CoinCollect"):FireAllClients({ plot = rt.index, ids = ids, value = total })
end

function CoinService:Start()
	PlotService.Tick:Connect(function()
		for _, rt in PlotService:Owned() do
			tickPlot(rt)
		end
	end)
end

return CoinService
