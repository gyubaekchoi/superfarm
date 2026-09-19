--!strict
-- 근접 자동 수확 판정 (서버 권위, 10Hz). DevSpec §5-3.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Signal = require(Packages.Signal)
local Economy = require(Shared.Config.Economy)
local Layout = require(Shared.Config.Layout)
local Remotes = require(Shared.Remotes)
local Rng = require(Shared.Util.Rng)
local PlotService = require(script.Parent.PlotService)
local CropService = require(script.Parent.CropService)
local StatsService = require(script.Parent.StatsService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local AntiCheatService = require(script.Parent.AntiCheatService)

type PlotRuntime = PlotService.PlotRuntime
type CropState = PlotService.CropState

local HarvestService = {}
HarvestService.Priority = 60
HarvestService.Harvested = Signal.new() -- (player, count)

local rng = Rng.new()
local CELL = Layout.CropSpacing
local NEIGHBOR = 2 -- 반경 최대 7 → ±2셀

local candidates: { CropState } = {}

local function tickPlot(rt: PlotRuntime, dt: number)
	local owner = rt.owner
	if not owner then
		return
	end
	local char = owner.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local st = StatsService:Get(owner)
	local data = DataService:Get(owner)
	if not st or not data or AntiCheatService:IsSuspicious(owner) then
		return
	end

	-- 쿨다운은 만땅이어도 흐른다 (판매 직후 즉시 수확 재개)
	rt.harvestCooldown -= dt
	if rt.full then
		rt.harvestCooldown = math.max(rt.harvestCooldown, 0)
		return
	end
	local budget = 0
	while rt.harvestCooldown <= 0 do
		budget += 1
		rt.harvestCooldown += st.interval
	end
	if budget == 0 then
		return
	end

	local pos = root.Position
	local now = workspace:GetServerTimeNow()
	local cx, cz = math.floor(pos.X / CELL), math.floor(pos.Z / CELL)
	table.clear(candidates)
	for dx = -NEIGHBOR, NEIGHBOR do
		for dz = -NEIGHBOR, NEIGHBOR do
			local bucket = rt.grid[(cx + dx) .. "," .. (cz + dz)]
			if bucket then
				for _, crop in bucket do
					if crop.readyAt <= now then
						local d = crop.pos - pos
						if d.X * d.X + d.Z * d.Z <= st.radius * st.radius then
							table.insert(candidates, crop)
						end
					end
				end
			end
		end
	end
	if #candidates == 0 then
		return
	end
	table.sort(candidates, function(a, b)
		return (a.pos - pos).Magnitude < (b.pos - pos).Magnitude
	end)

	local growLevel = data.pads.Grow and data.pads.Grow.level or 0
	local room = st.cap - #rt.stack
	local n = math.min(budget, #candidates, room)
	local items = table.create(n)
	local stones = 0
	for i = 1, n do
		local crop = candidates[i]
		table.insert(rt.stack, crop.cropId)
		CropService:Harvest(rt, crop, growLevel, now)
		items[i] = { zone = crop.zone, idx = crop.idx, crop = crop.cropId }
		if rng:chance(Economy.StoneDropRate) then
			stones += 1
		end
	end
	if n > 0 then
		owner:SetAttribute("Stack", #rt.stack)
		Remotes.get("HarvestBatch"):FireAllClients({
			userId = owner.UserId,
			plot = rt.index,
			items = items,
			stackCount = #rt.stack,
			cap = st.cap,
		})
		DataService:Add(owner, "stats.totalHarvest", n)
		HarvestService.Harvested:Fire(owner, n)
		if stones > 0 then
			EconomyService:AddStones(owner, stones, candidates[1].pos)
		end
	end
	if #rt.stack >= st.cap then
		rt.full = true
		Remotes.get("StackFull"):FireAllClients({ userId = owner.UserId, full = true })
	end
end

function HarvestService:Start()
	PlotService.Tick:Connect(function(dt)
		for _, rt in PlotService:Owned() do
			tickPlot(rt, dt)
		end
	end)
end

return HarvestService
