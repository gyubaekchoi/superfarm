--!strict
-- 일꾼 로봇: Idle → GoField → Harvest → GoSell → Deposit. 서버는 논리 위치만 갖고, 클라가 구간(leg) 정보로 보간한다. DevSpec §8-5.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Zones = require(Shared.Config.Zones)
local Crops = require(Shared.Config.Crops)
local Remotes = require(Shared.Remotes)
local PlotService = require(script.Parent.PlotService)
local CropService = require(script.Parent.CropService)
local PadService = require(script.Parent.PadService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

type PlotRuntime = PlotService.PlotRuntime
type CropState = PlotService.CropState

type Worker = {
	idx: number,
	zone: string,
	state: "Idle" | "GoField" | "Harvest" | "GoSell" | "Deposit",
	pos: Vector3,
	from: Vector3,
	to: Vector3,
	t0: number,
	dur: number,
	carry: { string },
	timer: number,
	model: Model,
}

local WorkerService = {}
WorkerService.Priority = 52

local workers: { [number]: { Worker } } = {} -- plot index → list
local W = Layout.Worker
local v3 = PlotService.v3

local function makeModel(rt: PlotRuntime, zone: string, idx: number, pos: Vector3): Model
	local m = Instance.new("Model")
	m.Name = ("Worker_%s_%d"):format(zone, idx)
	m:SetAttribute("Zone", zone)
	m:SetAttribute("Idx", idx)
	local body = PlotService.makePart(
		"Body",
		Vector3.new(1.6, 2, 1.2),
		CFrame.new(pos + Vector3.new(0, 1.6, 0)),
		Color3.fromRGB(150, 160, 180),
		m
	)
	body.CanCollide = false
	body.CanQuery = false
	local head = PlotService.makePart(
		"Head",
		Vector3.new(1.2, 1, 1.2),
		CFrame.new(pos + Vector3.new(0, 3.1, 0)),
		Color3.fromRGB(200, 210, 230),
		m
	)
	head.CanCollide = false
	head.CanQuery = false
	local eye = PlotService.makePart(
		"Eye",
		Vector3.new(0.8, 0.25, 0.1),
		CFrame.new(pos + Vector3.new(0, 3.2, -0.62)),
		Color3.fromRGB(80, 220, 255),
		m
	)
	eye.Material = Enum.Material.Neon
	eye.CanCollide = false
	eye.CanQuery = false
	m.PrimaryPart = body
	m.Parent = rt.zoneFolders[zone]
	return m
end

local function send(rt: PlotRuntime, w: Worker, extra: any?)
	local msg = {
		plot = rt.index,
		zone = w.zone,
		idx = w.idx,
		state = w.state,
		from = w.from,
		to = w.to,
		t0 = w.t0,
		dur = w.dur,
		carry = #w.carry,
	}
	if extra then
		for k, v in extra do
			msg[k] = v
		end
	end
	Remotes.get("WorkerState"):FireAllClients(msg)
end

local function setLeg(rt: PlotRuntime, w: Worker, state: any, to: Vector3)
	w.from = w.pos
	w.to = Vector3.new(to.X, Layout.GroundY, to.Z)
	w.t0 = workspace:GetServerTimeNow()
	w.dur = math.max((w.to - w.from).Magnitude / W.Speed, 0.05)
	w.state = state
	w.timer = 0
	send(rt, w)
end

local function currentPos(w: Worker): Vector3
	local a = math.clamp((workspace:GetServerTimeNow() - w.t0) / w.dur, 0, 1)
	return w.from:Lerp(w.to, a)
end

local function arrived(w: Worker): boolean
	return workspace:GetServerTimeNow() - w.t0 >= w.dur
end

local function pickTarget(rt: PlotRuntime, w: Worker): CropState?
	-- 구역 전체 Ready 작물 중 가장 가까운 것
	local best, bestD = nil, math.huge
	local now = workspace:GetServerTimeNow()
	for _, crop in rt.crops[w.zone] or {} do
		if crop.readyAt <= now then
			local d = (crop.pos - w.pos).Magnitude
			if d < bestD then
				bestD, best = d, crop
			end
		end
	end
	return best
end

local function tickWorker(rt: PlotRuntime, owner: Player, d: any, w: Worker, dt: number)
	w.pos = currentPos(w)
	if w.state == "Idle" then
		w.timer += dt
		if w.timer < 0.5 then
			return
		end
		local target = pickTarget(rt, w)
		if target then
			setLeg(rt, w, "GoField", target.pos)
		else
			w.timer = 0
		end
	elseif w.state == "GoField" then
		if arrived(w) then
			w.state = "Harvest"
			w.timer = 0
			send(rt, w)
		end
	elseif w.state == "Harvest" then
		w.timer += dt
		if w.timer >= W.Interval then
			w.timer -= W.Interval
			local near = CropService:ReadyNear(rt, w.pos, W.HarvestRadius, w.zone)
			if #near > 0 and #w.carry < W.Cap then
				local crop = near[1]
				local growLevel = d.pads.Grow and d.pads.Grow.level or 0
				CropService:Harvest(rt, crop, growLevel, workspace:GetServerTimeNow())
				table.insert(w.carry, crop.cropId)
				send(rt, w, { harvested = { zone = crop.zone, idx = crop.idx } })
			else
				local target = if #w.carry < W.Cap then pickTarget(rt, w) else nil
				if target then
					setLeg(rt, w, "GoField", target.pos)
				elseif #w.carry > 0 then
					local stand = rt.sellStands[w.zone]
					if stand then
						local dir = PlotService.zoneOriginWorld(rt, w.zone) - stand.Position
						dir = Vector3.new(dir.X, 0, dir.Z)
						dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.xAxis
						setLeg(rt, w, "GoSell", stand.Position + dir * (stand.Size.Magnitude / 2 + 1))
					end
				else
					w.state = "Idle"
					w.timer = 0
					send(rt, w)
				end
			end
		end
	elseif w.state == "GoSell" then
		if arrived(w) then
			local zdef = Zones.Defs[w.zone]
			local value = 0
			for _, cropId in w.carry do
				value += Crops[cropId].price * (zdef.sellMult or 1)
			end
			value = math.floor(value * EconomyService:CoinMult(owner) * (d.passes.WorkerPass and 2 or 1))
			EconomyService:AddCoins(owner, value)
			w.carry = {}
			w.state = "Deposit"
			w.timer = 0
			send(rt, w, { value = value })
		end
	elseif w.state == "Deposit" then
		w.timer += dt
		if w.timer >= 0.6 then
			w.state = "Idle"
			w.timer = 0
			send(rt, w)
		end
	end
end

-- 데이터 기준으로 일꾼 수 맞추기
local function syncWorkers(rt: PlotRuntime, d: any)
	local list = workers[rt.index]
	if not list then
		list = {}
		workers[rt.index] = list
	end
	for _, zone in Zones.Order do
		local want = d.zones[zone] and d.workers[zone] and d.workers[zone].count or 0
		local have = 0
		for _, w in list do
			if w.zone == zone then
				have += 1
			end
		end
		for i = have + 1, want do
			local spawnLocal = v3(Layout.pos(zone, "WorkerPad"))
				+ v3(W.SpawnOffset) * 0
				+ Vector3.new(0, Layout.GroundY, 0)
			local pos = rt.origin:PointToWorldSpace(spawnLocal + Vector3.new(i * 2, 0, 0))
			local w: Worker = {
				idx = i,
				zone = zone,
				state = "Idle",
				pos = pos,
				from = pos,
				to = pos,
				t0 = workspace:GetServerTimeNow(),
				dur = 0.05,
				carry = {},
				timer = 0,
				model = makeModel(rt, zone, i, pos),
			}
			table.insert(list, w)
			send(rt, w)
		end
	end
end

local function clearWorkers(rt: PlotRuntime)
	for _, w in workers[rt.index] or {} do
		w.model:Destroy()
	end
	workers[rt.index] = {}
end

function WorkerService:Start()
	DataService.Loaded:Connect(function(player, data)
		local rt = PlotService:GetByPlayer(player)
		if rt then
			syncWorkers(rt, data)
		end
	end)
	PadService.Completed:Connect(function(player, padId)
		if padId:sub(1, 7) == "Worker:" or padId:sub(1, 5) == "Gate:" then
			local rt = PlotService:GetByPlayer(player)
			local d = DataService:Get(player)
			if rt and d then
				syncWorkers(rt, d)
			end
		end
	end)
	PlotService.Released:Connect(function(_p, rt)
		clearWorkers(rt)
	end)
	PlotService.Tick:Connect(function(dt)
		for owner, rt in PlotService:Owned() do
			local d = DataService:Get(owner)
			if not d then
				continue
			end
			for _, w in workers[rt.index] or {} do
				tickWorker(rt, owner, d, w, dt)
			end
		end
	end)
end

-- 클라이언트 접속 직후 현재 상태 재전송용
function WorkerService:Resend(rt: PlotRuntime)
	for _, w in workers[rt.index] or {} do
		send(rt, w)
	end
end

return WorkerService
