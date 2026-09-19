--!strict
-- 플롯 생성·할당·스폰, 중앙 관리 허브, 구역 정적 오브젝트(해금 시에만 생성), 공용 10Hz Tick. DevSpec §12 (v2).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Layout = require(Shared.Config.Layout)
local Zones = require(Shared.Config.Zones)
local Economy = require(Shared.Config.Economy)
local Models = require(Shared.Config.Models)
local Templates = require(Shared.Templates)
local Signal = require(Packages.Signal)

export type CropState = {
	idx: number,
	zone: string,
	cropId: string,
	pos: Vector3,
	readyAt: number,
	inst: Instance,
	treeId: number?,
}

export type GroundCoin = { id: number, pos: Vector3, value: number }

export type PlotRuntime = {
	index: number,
	owner: Player?,
	origin: CFrame,
	folder: Folder,
	zoneFolders: { [string]: Folder },
	zoneBuilt: { [string]: boolean },
	sellStands: { [string]: BasePart },
	hub: { gacha: BasePart, enhance: BasePart, shop: BasePart },
	spawnCFrame: CFrame,

	crops: { [string]: { CropState } },
	grid: { [string]: { CropState } },

	stack: { string },
	full: boolean,
	harvestCooldown: number,

	sellTimer: number,
	sellPending: number,
	flushTimer: number,
	sellStandActive: BasePart?,

	coins: { [number]: GroundCoin },
	coinCount: number,
	nextCoinId: number,
}

local PlotService = {}
PlotService.Priority = 90
PlotService.Assigned = Signal.new() -- (player, rt)
PlotService.Released = Signal.new() -- (player, rt)
PlotService.Tick = Signal.new() -- (dt)

local plots: { PlotRuntime } = {}
local byPlayer: { [Player]: PlotRuntime } = {}

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end
PlotService.v3 = v3

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

function PlotService.toWorld(rt: PlotRuntime, localPos: Vector3): Vector3
	return rt.origin:PointToWorldSpace(localPos)
end

-- 구역 원점 월드 좌표 (바닥 높이)
function PlotService.zoneOriginWorld(rt: PlotRuntime, zone: string): Vector3
	return rt.origin:PointToWorldSpace(v3(Layout.origin(zone)) + Vector3.new(0, Layout.GroundY, 0))
end

-- 구역 프레임 → 월드 CFrame (구역 방향을 바라봄)
function PlotService.zoneCFrame(rt: PlotRuntime, zone: string, rel: { number }): CFrame
	local pos = rt.origin:PointToWorldSpace(v3(Layout.rel(zone, rel)) + Vector3.new(0, Layout.GroundY, 0))
	return CFrame.new(pos) * rt.origin.Rotation * CFrame.Angles(0, Layout.yaw(zone), 0)
end

local function makePart(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
PlotService.makePart = makePart

local FENCE_WHITE = Color3.fromRGB(245, 240, 232)
local FENCE_POST = 8

-- 플롯 둘레 흰 말뚝 울타리 (모든 변 닫힘: 플롯은 독립 공간)
local function buildFence(origin: CFrame, folder: Folder, half: number)
	local y = Layout.GroundY
	local fence = Instance.new("Model")
	fence.Name = "Fence"
	for _, edge in
		{ { axis = "x", z = -half }, { axis = "x", z = half }, { axis = "z", x = -half }, { axis = "z", x = half } }
	do
		local a, b = -half, half
		local len = b - a
		for _, railY in { 1.1, 2.1 } do
			local size = if edge.axis == "x" then Vector3.new(len, 0.35, 0.25) else Vector3.new(0.25, 0.35, len)
			local pos = if edge.axis == "x"
				then Vector3.new(0, y + railY, edge.z)
				else Vector3.new(edge.x, y + railY, 0)
			local rail = makePart("Rail", size, origin * CFrame.new(pos), FENCE_WHITE, fence)
			rail.CanCollide = false
		end
		local n = math.floor(len / FENCE_POST)
		for k = 0, n do
			local t = a + k * (len / math.max(n, 1))
			local pos = if edge.axis == "x" then Vector3.new(t, y + 1.5, edge.z) else Vector3.new(edge.x, y + 1.5, t)
			local post = makePart("Post", Vector3.new(0.6, 3, 0.6), origin * CFrame.new(pos), FENCE_WHITE, fence)
			post.CanCollide = false
			local cap = makePart(
				"Cap",
				Vector3.new(0.8, 0.3, 0.8),
				origin * CFrame.new(pos + Vector3.new(0, 1.6, 0)),
				Color3.fromRGB(220, 205, 190),
				fence
			)
			cap.CanCollide = false
		end
	end
	fence.Parent = folder
end

-- 허브 오브젝트 (논리 파트 + 시각 템플릿)
local function hubObject(
	rt: PlotRuntime,
	folder: Folder,
	name: string,
	kind: string,
	rel: { number },
	size: Vector3,
	color: Color3
): BasePart
	local groundPos = rt.origin:PointToWorldSpace(v3(rel) + Vector3.new(0, Layout.GroundY, 0))
	local part = makePart(name, size, CFrame.new(groundPos + Vector3.new(0, size.Y / 2, 0)), color, folder)
	part.CanCollide = false
	part:SetAttribute("Kind", kind)
	CollectionService:AddTag(part, "HubObject")
	local tname = Models.Plaza[kind]
	if tname and Templates.has(tname) then
		part.Transparency = 1
		local center = rt.origin:PointToWorldSpace(Vector3.new(0, Layout.GroundY, 0))
		local m = Templates.spawn(
			tname,
			CFrame.lookAt(groundPos, Vector3.new(center.X, groundPos.Y, center.Z)),
			folder,
			kind .. "Visual"
		)
		if m and kind == "Gacha" then
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					local n = d.Name:lower()
					if n:find("ribbon") or n:find("bow") then
						d.Color = Color3.fromRGB(255, 220, 90)
					elseif n:find("lid") then
						d.Color = Color3.fromRGB(255, 120, 150)
					else
						d.Color = Color3.fromRGB(235, 80, 110)
					end
					d.Material = Enum.Material.SmoothPlastic
				end
			end
		end
	end
	return part
end

-- 작은 마을: 흙빛 광장 + 집 3채 + 가로등 + 통·상자. 스폰 → 마을 → 밭으로 이어진다.
local function buildHouse(rt: PlotRuntime, parent: Instance, spec: { number })
	local pos = Vector3.new(spec[1], spec[2], spec[3])
	local yaw = spec[4]
	local roof = Models.HouseRoof[spec[5]] or Models.HouseRoof[1]
	local base = rt.origin * CFrame.new(pos + Vector3.new(0, Layout.GroundY, 0)) * CFrame.Angles(0, yaw, 0)
	local house = Instance.new("Model")
	house.Name = "House"

	local W, D, H = 9, 8, 6
	local wall = makePart("Wall", Vector3.new(W, H, D), base * CFrame.new(0, H / 2, 0), rgb(Models.HouseWall), house)
	wall.CanCollide = true
	wall.Material = Enum.Material.WoodPlanks
	-- 모서리 기둥
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local beam = makePart(
				"Beam",
				Vector3.new(0.8, H, 0.8),
				base * CFrame.new(sx * (W / 2 - 0.3), H / 2, sz * (D / 2 - 0.3)),
				rgb(Models.HouseBeam),
				house
			)
			beam.CanCollide = false
		end
	end
	-- 박공 지붕 (쐐기 두 장). 쐐기의 수직면이 용마루 쪽을 보도록 ±90° 돌린다.
	local roofH, half = 3.2, 5.4
	for _, sx in { -1, 1 } do
		local w = Instance.new("WedgePart")
		w.Name = "Roof"
		w.Size = Vector3.new(D + 1.6, roofH, half)
		w.CFrame = base * CFrame.new(sx * (half / 2), H + roofH / 2, 0) * CFrame.Angles(0, -sx * math.pi / 2, 0)
		w.Anchored = true
		w.CanCollide = false
		w.Color = rgb(roof)
		w.Material = Enum.Material.SmoothPlastic
		w.Parent = house
	end
	-- 문·창문
	local door = makePart(
		"Door",
		Vector3.new(2.6, 4, 0.3),
		base * CFrame.new(0, 2, -(D / 2 + 0.05)),
		rgb(Models.HouseBeam),
		house
	)
	door.CanCollide = false
	for _, sx in { -1, 1 } do
		local win = makePart(
			"Window",
			Vector3.new(2, 2, 0.3),
			base * CFrame.new(sx * 3.2, 4.6, -(D / 2 + 0.05)),
			Color3.fromRGB(255, 226, 150),
			house
		)
		win.CanCollide = false
		win.Material = Enum.Material.Neon
	end
	house.Parent = parent
end

local function buildProp(rt: PlotRuntime, parent: Instance, pos: { number }, i: number)
	local base = rt.origin * CFrame.new(Vector3.new(pos[1], Layout.GroundY, pos[3]))
	if i % 2 == 1 then
		local barrel =
			makePart("Barrel", Vector3.new(2.4, 3, 2.4), base * CFrame.new(0, 1.5, 0), rgb(Models.Barrel), parent)
		barrel.Shape = Enum.PartType.Cylinder
		barrel.CFrame = base * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.pi / 2)
		barrel.CanCollide = false
	else
		for k = 0, 1 do
			local crate = makePart(
				"Crate",
				Vector3.new(2.6, 2.6, 2.6),
				base * CFrame.new(k * 0.6, 1.3 + k * 2.6, k * 0.4) * CFrame.Angles(0, k * 0.5, 0),
				rgb(Models.HouseBeam),
				parent
			)
			crate.CanCollide = false
		end
	end
end

local function buildHub(rt: PlotRuntime)
	local H = Layout.Hub
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = rt.folder

	local RING_THICK = 0.3
	local function ring(name, radius, top, color)
		local f = makePart(
			name,
			Vector3.new(RING_THICK, radius * 2, radius * 2),
			rt.origin * CFrame.new(0, top - RING_THICK / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			color,
			hub
		)
		f.Shape = Enum.PartType.Cylinder
		f.Material = Enum.Material.Ground
		f.CanCollide = false
	end
	ring("Floor", H.Radius, Layout.Y.HubRing[1], rgb(Models.PlazaFloor))
	ring("Ring1", H.Radius * 0.72, Layout.Y.HubRing[2], rgb(Models.PlazaRing))
	ring("Ring2", H.Radius * 0.34, Layout.Y.HubRing[3], rgb(Models.PlazaInner))

	for _, spec in H.Houses do
		buildHouse(rt, hub, spec)
	end
	for i, pos in H.Props do
		buildProp(rt, hub, pos, i)
	end

	for i = 1, H.Lamps do
		local a = i / H.Lamps * math.pi * 2 + math.pi / H.Lamps
		local pos = Vector3.new(math.cos(a), 0, math.sin(a)) * (H.Radius - 2)
		local post = makePart(
			"LampPost",
			Vector3.new(0.5, 7, 0.5),
			rt.origin * CFrame.new(pos + Vector3.new(0, Layout.GroundY + 3.5, 0)),
			rgb(Models.HouseBeam),
			hub
		)
		post.CanCollide = false
		local bulb = makePart(
			"LampBulb",
			Vector3.new(1.4, 1.4, 1.4),
			rt.origin * CFrame.new(pos + Vector3.new(0, Layout.GroundY + 7.4, 0)),
			Color3.fromRGB(255, 220, 140),
			hub
		)
		bulb.Shape = Enum.PartType.Ball
		bulb.Material = Enum.Material.Neon
		bulb.CanCollide = false
		local light = Instance.new("PointLight")
		light.Range = 18
		light.Brightness = 0.9
		light.Color = Color3.fromRGB(255, 214, 150)
		light.Parent = bulb
	end

	rt.hub = {
		gacha = hubObject(rt, hub, "GachaBox", "Gacha", H.Gacha, Vector3.new(4, 3.2, 4), Color3.fromRGB(235, 80, 110)),
		enhance = hubObject(
			rt,
			hub,
			"EnhanceStation",
			"Enhance",
			H.Enhance,
			Vector3.new(4, 2.4, 3),
			Color3.fromRGB(80, 80, 95)
		),
		shop = hubObject(rt, hub, "ShopKiosk", "Shop", H.Shop, Vector3.new(4, 4, 3), Color3.fromRGB(90, 150, 230)),
	}
end

local STAND_COLORS =
	{ Z1 = Color3.fromRGB(150, 95, 50), Z2 = Color3.fromRGB(70, 110, 190), Z3 = Color3.fromRGB(150, 95, 50) }

-- 구역 정적 오브젝트: 해금 시에만 생성 (바닥·판매대·장식). 패드는 PadService, 작물은 CropService.
function PlotService:BuildZone(rt: PlotRuntime, zone: string)
	if rt.zoneBuilt[zone] then
		return
	end
	local zdef = Zones.Defs[zone]
	if not zdef or zdef.teaser then
		return
	end
	local zf = rt.zoneFolders[zone]
	rt.zoneBuilt[zone] = true

	local theme = Models.ZoneTheme[zone]
	local fsize = v3(Layout.zoneValue(zone, "FloorSize"))
	local floor = makePart(
		"ZoneFloor",
		fsize,
		PlotService.zoneCFrame(rt, zone, Layout.zoneValue(zone, "FloorCenter"))
			+ Vector3.new(0, Layout.Y.Zone - fsize.Y / 2 - Layout.GroundY, 0),
		if theme then rgb(theme.floor) else Color3.fromRGB(120, 190, 90),
		zf
	)
	floor.Material = Enum.Material.Grass
	floor.CanCollide = false

	local standSize = v3(Layout.zoneValue(zone, "SellStandSize"))
	local standCF = PlotService.zoneCFrame(rt, zone, Layout.zoneValue(zone, "SellStand"))
	local stand = makePart(
		"SellStand",
		standSize,
		standCF + Vector3.new(0, standSize.Y / 2, 0),
		STAND_COLORS[zone] or STAND_COLORS.Z1,
		zf
	)
	stand:SetAttribute("Zone", zone)
	CollectionService:AddTag(stand, "Interact")
	rt.sellStands[zone] = stand
	local tname = Models.Stands[zone]
	if tname and Templates.has(tname) then
		stand.Transparency = 1
		stand.CanCollide = false
		local fieldPos = PlotService.zoneCFrame(rt, zone, Layout.zoneValue(zone, "Field1")).Position
		Templates.spawn(
			tname,
			CFrame.lookAt(standCF.Position, Vector3.new(fieldPos.X, standCF.Position.Y, fieldPos.Z)),
			zf,
			"SellStandVisual"
		)
	end

	-- 장식
	for k, rel in Layout.zoneValue(zone, "Decor") do
		local list = if k % 2 == 1 then Models.Decor.Trees else Models.Decor.Rocks
		local name = list[((rt.index + k) % #list) + 1]
		Templates.spawn(name, PlotService.zoneCFrame(rt, zone, rel) * CFrame.Angles(0, k * 1.9, 0), zf)
	end
	local wm = Layout.zoneValue(zone, "Windmill")
	if wm and zone == "Z2" then
		Templates.spawn(Models.Decor.Windmill, PlotService.zoneCFrame(rt, zone, wm), zf)
	end
end

function PlotService:ClearZone(rt: PlotRuntime, zone: string)
	local zf = rt.zoneFolders[zone]
	if zf then
		zf:ClearAllChildren()
		local crops = Instance.new("Folder")
		crops.Name = "Crops"
		crops.Parent = zf
	end
	rt.zoneBuilt[zone] = false
	rt.sellStands[zone] = nil
end

local function buildPlot(index: number, root: Folder): PlotRuntime
	local center = v3(Layout.plotCenter(index))
	local origin = CFrame.new(center)

	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. index
	folder:SetAttribute("Index", index)
	folder.Parent = root

	local floorPart = makePart(
		"Floor",
		Vector3.new(Layout.PlotSize, 1, Layout.PlotSize),
		origin * CFrame.new(0, Layout.GroundY - 0.5, 0),
		Color3.fromRGB(128, 196, 96),
		folder
	)
	floorPart.Material = Enum.Material.Grass
	buildFence(origin, folder, Layout.PlotSize / 2)

	local rt: PlotRuntime = {
		index = index,
		owner = nil,
		origin = origin,
		folder = folder,
		zoneFolders = {},
		zoneBuilt = {},
		sellStands = {},
		hub = nil :: any,
		spawnCFrame = CFrame.new(),
		crops = {},
		grid = {},
		stack = {},
		full = false,
		harvestCooldown = 0,
		sellTimer = 0,
		sellPending = 0,
		flushTimer = 0,
		sellStandActive = nil,
		coins = {},
		coinCount = 0,
		nextCoinId = 1,
	}

	for _, zone in Zones.Order do
		local zf = Instance.new("Folder")
		zf.Name = zone
		zf.Parent = folder
		rt.zoneFolders[zone] = zf
		local crops = Instance.new("Folder")
		crops.Name = "Crops"
		crops.Parent = zf
	end
	buildHub(rt)

	local spawnPos = origin:PointToWorldSpace(v3(Layout.Hub.Spawn) + Vector3.new(0, Layout.GroundY + 3, 0))
	local lookPos = origin:PointToWorldSpace(v3(Layout.origin("Z1")) + Vector3.new(0, Layout.GroundY + 3, 0))
	rt.spawnCFrame = CFrame.lookAt(spawnPos, lookPos)
	return rt
end

local function spawnCharacter(player: Player, rt: PlotRuntime, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root then
		return
	end
	local AntiCheat = require(script.Parent.AntiCheatService)
	AntiCheat:Grace(player)
	character:PivotTo(rt.spawnCFrame)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Once(function()
			task.delay(Layout.RespawnDelay, function()
				if player.Parent then
					player:LoadCharacter()
				end
			end)
		end)
	end
end

local function assign(player: Player)
	for _, rt in plots do
		if rt.owner == nil then
			rt.owner = player
			byPlayer[player] = rt
			rt.folder:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("Plot", rt.index)
			player:SetAttribute("Stack", 0)
			player.CharacterAdded:Connect(function(char)
				spawnCharacter(player, rt, char)
			end)
			if player.Character then
				spawnCharacter(player, rt, player.Character)
			else
				player:LoadCharacter()
			end
			PlotService.Assigned:Fire(player, rt)
			print(("[PlotService] %s → Plot%d"):format(player.Name, rt.index))
			return
		end
	end
	player:Kick("서버가 가득 찼습니다.")
end

local function release(player: Player)
	local rt = byPlayer[player]
	if not rt then
		return
	end
	PlotService.Released:Fire(player, rt)
	rt.owner = nil
	rt.folder:SetAttribute("OwnerUserId", nil)
	rt.stack = {}
	rt.full = false
	rt.sellPending = 0
	rt.coins = {}
	rt.coinCount = 0
	for _, zone in Zones.Order do
		PlotService:ClearZone(rt, zone)
	end
	byPlayer[player] = nil
end

function PlotService:Init()
	Players.CharacterAutoLoads = false
	local root = Instance.new("Folder")
	root.Name = "Plots"
	root.Parent = workspace
	for i = 1, Layout.PlotCount do
		plots[i] = buildPlot(i, root)
	end
end

function PlotService:Start()
	Players.PlayerAdded:Connect(assign)
	Players.PlayerRemoving:Connect(release)
	for _, p in Players:GetPlayers() do
		assign(p)
	end

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= Economy.ServerTick then
			local step = acc
			acc = 0
			PlotService.Tick:Fire(step)
		end
	end)
end

function PlotService:GetByPlayer(player: Player): PlotRuntime?
	return byPlayer[player]
end

function PlotService:Get(index: number): PlotRuntime?
	return plots[index]
end

function PlotService:Owned(): { [Player]: PlotRuntime }
	return byPlayer
end

return PlotService
