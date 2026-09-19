--!strict
-- 업그레이드 패드(구역별 스탯·확장·2번째 작물·일꾼) + 게이트. 위에 서 있으면 코인이 빠져나가고 완료 시 효과 적용. DevSpec §8-4.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Layout = require(Shared.Config.Layout)
local Zones = require(Shared.Config.Zones)
local Pads = require(Shared.Config.Pads)
local Economy = require(Shared.Config.Economy)
local PadLogic = require(Shared.PadLogic)
local Remotes = require(Shared.Remotes)
local Signal = require(Packages.Signal)
local PlotService = require(script.Parent.PlotService)
local CropService = require(script.Parent.CropService)
local DataService = require(script.Parent.DataService)

type PlotRuntime = PlotService.PlotRuntime
export type PadRuntime = { part: BasePart, id: string, zone: string, kind: PadLogic.PadKind }

local PadService = {}
PadService.Priority = 75
PadService.Completed = Signal.new() -- (player, padId, newLevel)
PadService.ZoneUnlocked = Signal.new() -- (player, rt, zone)

local padsByPlot: { [number]: { PadRuntime } } = {}
local v3 = PlotService.v3
local _ = CropService -- 확장·2번째 작물 완료 시 재생성에 사용

local PAD_COLORS: { [string]: Color3 } = {
	Move = Color3.fromRGB(90, 170, 255),
	Harvest = Color3.fromRGB(120, 200, 90),
	Cap = Color3.fromRGB(230, 150, 70),
	Grow = Color3.fromRGB(80, 200, 220),
	Expand = Color3.fromRGB(160, 120, 80),
	Crop2 = Color3.fromRGB(200, 200, 150),
	Worker = Color3.fromRGB(120, 120, 140),
	Gate = Color3.fromRGB(90, 90, 100),
}

local function makePad(
	rt: PlotRuntime,
	id: string,
	zone: string,
	cf: CFrame,
	color: Color3,
	parent: Instance
): PadRuntime
	local size = v3(Layout.PadSize)
	local p = Instance.new("Part")
	p.Name = "Pad_" .. id:gsub(":", "_")
	p.Size = size
	p.CFrame = cf + Vector3.new(0, size.Y / 2, 0)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p:SetAttribute("PadId", id)
	p:SetAttribute("Plot", rt.index)
	p:SetAttribute("Zone", zone)
	CollectionService:AddTag(p, "Pad")
	p.Parent = parent
	local kind = PadLogic.parse(id)
	return { part = p, id = id, zone = zone, kind = kind }
end

local function buildGate(rt: PlotRuntime, zone: string, list: { PadRuntime })
	local zf = rt.zoneFolders[zone]
	local gateCF = PlotService.zoneCFrame(rt, zone, Layout.zoneValue(zone, "Gate"))
	local pad = makePad(rt, "Gate:" .. zone, zone, gateCF, PAD_COLORS.Gate, rt.folder:FindFirstChild("Hub") or zf)
	table.insert(list, pad)
	for _, sgn in { -1, 1 } do
		PlotService.makePart(
			"GatePillar",
			Vector3.new(1.4, 8, 1.4),
			gateCF * CFrame.new(3.5 * sgn, Layout.GroundY + 4, 0),
			Color3.fromRGB(120, 120, 130),
			pad.part.Parent
		)
	end
end

-- 구역 패드: 해금 시 생성 (스탯 3~4종, 확장, 2번째 작물, 일꾼)
function PadService:BuildZonePads(rt: PlotRuntime, zone: string, data: any)
	local list = padsByPlot[rt.index]
	for _, pad in list do
		if pad.zone == zone and pad.kind ~= "Gate" then
			return -- 이미 생성됨
		end
	end
	local zdef = Zones.Defs[zone]
	if zdef.teaser then
		return
	end
	local zf = rt.zoneFolders[zone]
	for key in Layout.zoneValue(zone, "Pads") do
		local rel = Layout.zoneValue(zone, "Pads")[key]
		table.insert(list, makePad(rt, key, zone, PlotService.zoneCFrame(rt, zone, rel), PAD_COLORS[key], zf))
	end
	table.insert(
		list,
		makePad(
			rt,
			"Expand:" .. zone,
			zone,
			PlotService.zoneCFrame(rt, zone, Layout.zoneValue(zone, "ExpandPad")),
			PAD_COLORS.Expand,
			zf
		)
	)
	if zdef.crops and zdef.crops[2] then
		local pad = makePad(
			rt,
			"Crop2:" .. zone,
			zone,
			PlotService.zoneCFrame(rt, zone, Layout.zoneValue(zone, "Crop2Pad")),
			PAD_COLORS.Crop2,
			zf
		)
		pad.part:SetAttribute("Done", data and PadLogic.info(data, pad.id).maxed or false)
		table.insert(list, pad)
	end
	if zdef.workerMax and zdef.workerMax > 0 then
		table.insert(
			list,
			makePad(
				rt,
				"Worker:" .. zone,
				zone,
				PlotService.zoneCFrame(rt, zone, Layout.zoneValue(zone, "WorkerPad")),
				PAD_COLORS.Worker,
				zf
			)
		)
	end
end

-- 구역 패드 제거 (플롯 반납 시). 게이트는 유지
function PadService:ClearZonePads(rt: PlotRuntime)
	local list = padsByPlot[rt.index]
	for i = #list, 1, -1 do
		if list[i].kind ~= "Gate" then
			table.remove(list, i)
		end
	end
end

local function buildPads(rt: PlotRuntime)
	local list: { PadRuntime } = {}
	padsByPlot[rt.index] = list
	for _, zone in Zones.Order do
		if zone ~= "Z1" then
			buildGate(rt, zone, list)
		end
	end
end

local function paidPath(info: PadLogic.PadInfo): string
	if info.kind == "Stat" then
		return "pads." .. info.key .. ".paid"
	elseif info.kind == "Expand" then
		return "fields." .. info.key .. ".paid"
	elseif info.kind == "Crop2" then
		return "fields." .. info.key .. ".crop2Paid"
	elseif info.kind == "Worker" then
		return "workers." .. info.key .. ".paid"
	end
	return "gates." .. info.key
end

-- 데이터에 하위 테이블이 없으면 만들어 두기 위한 초기화 패치
local function ensurePatches(d: any, info: PadLogic.PadInfo): { any }
	local out = {}
	if info.kind == "Stat" and not d.pads[info.key] then
		table.insert(out, { path = "pads." .. info.key .. ".level", value = 0 })
	elseif (info.kind == "Expand" or info.kind == "Crop2") and not d.fields[info.key] then
		table.insert(out, { path = "fields." .. info.key .. ".expansion", value = 0 })
		table.insert(out, { path = "fields." .. info.key .. ".crop2", value = false })
		table.insert(out, { path = "fields." .. info.key .. ".paid", value = 0 })
		table.insert(out, { path = "fields." .. info.key .. ".crop2Paid", value = 0 })
	elseif info.kind == "Worker" and not d.workers[info.key] then
		table.insert(out, { path = "workers." .. info.key .. ".count", value = 0 })
		table.insert(out, { path = "workers." .. info.key .. ".level", value = 0 })
	end
	return out
end

local function complete(rt: PlotRuntime, owner: Player, pad: PadRuntime, info: PadLogic.PadInfo)
	local d = DataService:Get(owner)
	if not d then
		return
	end
	local newLevel = info.level + 1
	if info.kind == "Stat" then
		DataService:Patch(owner, {
			{ path = "pads." .. info.key .. ".level", value = newLevel },
			{ path = "pads." .. info.key .. ".paid", value = 0 },
		})
	elseif info.kind == "Expand" then
		DataService:Patch(owner, {
			{ path = "fields." .. info.key .. ".expansion", value = newLevel },
			{ path = "fields." .. info.key .. ".paid", value = 0 },
		})
		CropService:BuildZone(rt, info.key, d)
	elseif info.kind == "Crop2" then
		DataService:Patch(owner, {
			{ path = "fields." .. info.key .. ".crop2", value = true },
			{ path = "fields." .. info.key .. ".crop2Paid", value = 0 },
		})
		CropService:BuildZone(rt, info.key, d)
		pad.part:SetAttribute("Done", true)
	elseif info.kind == "Worker" then
		DataService:Patch(owner, {
			{ path = "workers." .. info.key .. ".count", value = newLevel },
			{ path = "workers." .. info.key .. ".paid", value = 0 },
		})
	else -- Gate
		DataService:Patch(owner, {
			{ path = "zones." .. info.key, value = true },
			{ path = "gates." .. info.key, value = 0 },
		})
		PadService.ZoneUnlocked:Fire(owner, rt, info.key) -- ZoneService 가 구역을 생성하고 연출을 보낸다
	end
	Remotes.get("PadComplete"):FireClient(owner, { padId = pad.id, level = newLevel })
	PadService.Completed:Fire(owner, pad.id, newLevel)
end

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
	local d = DataService:Get(owner)
	if not d or d.coins <= 0 then
		return
	end
	local vel = root.AssemblyLinearVelocity
	if vel.X * vel.X + vel.Z * vel.Z > 16 then
		return
	end
	local pos = root.Position
	local r2 = Economy.PadRadius * Economy.PadRadius
	for _, pad in padsByPlot[rt.index] or {} do
		local dp = pad.part.Position - pos
		if dp.X * dp.X + dp.Z * dp.Z > r2 then
			continue
		end
		if not PadLogic.zoneOpen(d, pad.id, pad.zone) then
			continue
		end
		local info = PadLogic.info(d, pad.id)
		if not PadLogic.canPay(info) then
			continue
		end
		local remaining = PadLogic.remaining(info)
		local amount = math.min(d.coins, remaining, math.ceil(Pads.drainPerSec(info.cost :: number) * dt))
		if amount <= 0 then
			continue
		end
		local paid = info.paid + amount
		local patches = ensurePatches(d, info)
		table.insert(patches, { path = "coins", value = d.coins - amount })
		table.insert(patches, { path = paidPath(info), value = paid })
		DataService:Patch(owner, patches)
		Remotes.get("PadProgress"):FireClient(owner, { padId = pad.id, paid = paid, cost = info.cost, delta = amount })
		if paid >= (info.cost :: number) then
			complete(rt, owner, pad, info)
		end
		return
	end
end

function PadService:Init()
	for i = 1, Layout.PlotCount do
		local rt = PlotService:Get(i)
		if rt then
			buildPads(rt)
		end
	end
end

function PadService:Start()
	PlotService.Tick:Connect(function(dt)
		for _, rt in PlotService:Owned() do
			tickPlot(rt, dt)
		end
	end)
	PlotService.Released:Connect(function(_p, rt)
		self:ClearZonePads(rt)
	end)
end

function PadService:GetPads(rt: PlotRuntime): { PadRuntime }
	return padsByPlot[rt.index] or {}
end

return PadService
