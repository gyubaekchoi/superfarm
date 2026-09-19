--!strict
-- 판매대 근접 자동 투입 → 코인 생성 요청. 구역별 판매대, 판매대 구역의 배율 적용. DevSpec §5-7.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Signal = require(Packages.Signal)
local Economy = require(Shared.Config.Economy)
local Layout = require(Shared.Config.Layout)
local Crops = require(Shared.Config.Crops)
local Zones = require(Shared.Config.Zones)
local Remotes = require(Shared.Remotes)
local PlotService = require(script.Parent.PlotService)
local StatsService = require(script.Parent.StatsService)
local EconomyService = require(script.Parent.EconomyService)
local CoinService = require(script.Parent.CoinService)
local DataService = require(script.Parent.DataService)

type PlotRuntime = PlotService.PlotRuntime

local SellService = {}
SellService.Priority = 55
SellService.Sold = Signal.new() -- (player, count)

local function flush(rt: PlotRuntime)
	local whole = math.floor(rt.sellPending)
	if whole > 0 and rt.sellStandActive then
		rt.sellPending -= whole
		CoinService:Spawn(rt, whole, rt.sellStandActive)
	end
	rt.flushTimer = 0
end

local function nearStand(rt: PlotRuntime, pos: Vector3, d: any): BasePart?
	for zone, stand in rt.sellStands do
		if d.zones[zone] and (pos - stand.Position).Magnitude <= Economy.SellRadius + stand.Size.Magnitude / 2 then
			return stand
		end
	end
	return nil
end

local function tickPlot(rt: PlotRuntime, dt: number)
	local owner = rt.owner
	if not owner then
		return
	end
	local char = owner.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local d = DataService:Get(owner)
	if not root or not d then
		return
	end

	local stand = nearStand(rt, root.Position, d)
	if stand and #rt.stack > 0 then
		rt.sellStandActive = stand
		local zone = stand:GetAttribute("Zone") :: string
		local sellMult = Zones.Defs[zone].sellMult or 1
		rt.sellTimer += dt
		local mult = EconomyService:CoinMult(owner)
		local count = 0
		while rt.sellTimer >= Layout.DepositInterval and #rt.stack > 0 do
			rt.sellTimer -= Layout.DepositInterval
			local cropId = table.remove(rt.stack) :: string
			rt.sellPending += Crops[cropId].price * sellMult * mult
			count += 1
		end
		if count > 0 then
			owner:SetAttribute("Stack", #rt.stack)
			local st = StatsService:Get(owner)
			Remotes.get("SellDeposit"):FireAllClients({
				userId = owner.UserId,
				plot = rt.index,
				zone = zone,
				count = count,
				stackCount = #rt.stack,
				cap = st and st.cap or 0,
			})
			SellService.Sold:Fire(owner, count)
			if rt.full then
				rt.full = false
				Remotes.get("StackFull"):FireAllClients({ userId = owner.UserId, full = false })
			end
		end
	else
		rt.sellTimer = 0
	end

	if rt.sellPending >= 1 then
		rt.flushTimer += dt
		if rt.flushTimer >= Layout.CoinFlushInterval or #rt.stack == 0 or not stand then
			flush(rt)
		end
	end
end

function SellService:Start()
	PlotService.Tick:Connect(function(dt)
		for _, rt in PlotService:Owned() do
			tickPlot(rt, dt)
		end
	end)
end

return SellService
