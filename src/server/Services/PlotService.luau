--!strict
-- 플롯 생성·할당·스폰, 구역 정적 오브젝트(판매대·안개·게이트), 공용 10Hz Tick. DevSpec §12.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
	inst: Instance, -- Model(템플릿) 또는 Part(대체)
	treeId: number?,
}

export type GroundCoin = { id: number, pos: Vector3, value: number }

export type PlotRuntime = {
	index: number,
	owner: Player?,
	origin: CFrame,
	folder: Folder,
	zoneFolders: { [string]: Folder },
	sellStands: { [string]: BasePart },
	fogs: { [string]: Instance },
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

function PlotService.toWorld(rt: PlotRuntime, localPos: Vector3): Vector3
	return rt.origin:PointToWorldSpace(localPos)
end

-- 구역 원점의 월드 좌표 (바닥 높이)
function PlotService.zoneOriginWorld(rt: PlotRuntime, zone: string): Vector3
	return rt.origin:PointToWorldSpace(v3(Layout.Zone[zone].Origin) + Vector3.new(0, Layout.GroundY, 0))
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

local STAND_COLORS =
	{ Z1 = Color3.fromRGB(150, 95, 50), Z2 = Color3.fromRGB(70, 110, 190), Z3 = Color3.fromRGB(150, 95, 50) }

local function buildZoneStatics(rt: PlotRuntime, zone: string)
	local zdef = Zones.Defs[zone]
	local zf = Instance.new("Folder")
	zf.Name = zone
	zf.Parent = rt.folder
	rt.zoneFolders[zone] = zf
	if zdef.teaser then
		return
	end
	local cropsFolder = Instance.new("Folder")
	cropsFolder.Name = "Crops"
	cropsFolder.Parent = zf

	local standSize = v3(Layout.zoneValue(zone, "SellStandSize"))
	local standLocal = v3(Layout.pos(zone, "SellStand")) + Vector3.new(0, Layout.GroundY + standSize.Y / 2, 0)
	local stand =
		makePart("SellStand", standSize, rt.origin * CFrame.new(standLocal), STAND_COLORS[zone] or STAND_COLORS.Z1, zf)
	stand:SetAttribute("Zone", zone)
	rt.sellStands[zone] = stand
	-- 시각 템플릿: 밭(구역 원점) 방향을 바라보게
	local tname = Models.Stands[zone]
	if tname and Templates.has(tname) then
		stand.Transparency = 1
		stand.CanCollide = false
		local groundPos =
			rt.origin:PointToWorldSpace(v3(Layout.pos(zone, "SellStand")) + Vector3.new(0, Layout.GroundY, 0))
		local fieldPos = rt.origin:PointToWorldSpace(v3(Layout.pos(zone, "Field1")) + Vector3.new(0, Layout.GroundY, 0))
		Templates.spawn(tname, CFrame.lookAt(groundPos, fieldPos), zf, "SellStandVisual")
	end
	-- 구역 바닥 (테마색)
	local theme = Models.ZoneTheme[zone]
	if theme then
		local origin = v3(Layout.Zone[zone].Origin)
		local floor = makePart(
			"ZoneFloor",
			Vector3.new(66, 0.2, 76),
			rt.origin * CFrame.new(origin + Vector3.new(0, Layout.GroundY + 0.01, 12)),
			Color3.fromRGB(theme.floor[1], theme.floor[2], theme.floor[3]),
			zf
		)
		floor.Material = Enum.Material.Grass
		floor.CanCollide = false
	end
end

local function buildFog(rt: PlotRuntime, zone: string)
	local size = v3(Layout.FogSize)
	local originLocal = v3(Layout.Zone[zone].Origin)
	local fog = Instance.new("Model")
	fog.Name = "Fog_" .. zone
	fog:SetAttribute("Zone", zone)
	-- 바닥 흐림
	local tint = makePart(
		"Tint",
		Vector3.new(size.X, 0.3, size.Z),
		rt.origin * CFrame.new(originLocal + Vector3.new(0, Layout.GroundY + 0.05, 10)),
		Color3.fromRGB(225, 230, 240),
		fog
	)
	tint.Transparency = 0.35
	tint.CanCollide = false
	tint.CanQuery = false
	-- 구름 덩어리 (결정적 난수)
	local rng = Random.new(zone:byte(2) * 31 + rt.index)
	for i = 1, 14 do
		local px = rng:NextNumber(-size.X / 2 + 8, size.X / 2 - 8)
		local pz = rng:NextNumber(-size.Z / 2 + 8, size.Z / 2 - 8) + 10
		local r = rng:NextNumber(9, 16)
		local cloud = makePart(
			"Cloud",
			Vector3.new(r, r * 0.7, r),
			rt.origin * CFrame.new(originLocal + Vector3.new(px, Layout.GroundY + 5 + r * 0.35, pz)),
			Color3.fromRGB(250, 252, 255),
			fog
		)
		cloud.Shape = Enum.PartType.Ball
		cloud.Transparency = 0.12
		cloud.CanCollide = false
		cloud.CanQuery = false
		cloud.CastShadow = false
		cloud:SetAttribute("Bob", i)
	end
	fog.Parent = rt.folder
	rt.fogs[zone] = fog
end

local FENCE_WHITE = Color3.fromRGB(245, 240, 232)
local FENCE_POST = 8
local function buildFence(origin: CFrame, folder: Folder, c: Vector3, half: number)
	local y = Layout.GroundY
	local fence = Instance.new("Model")
	fence.Name = "Fence"
	-- 4변: 각 변마다 레일 2개 + 말뚝. 입구(플롯 로컬 -X 쪽, 스폰 방향) 가운데는 비움
	for _, edge in
		{ { axis = "x", z = -half }, { axis = "x", z = half }, { axis = "z", x = -half }, { axis = "z", x = half } }
	do
		local isEntrance = edge.axis == "z" and edge.x == -half
		local segments = if isEntrance then { { -half, -8 }, { 8, half } } else { { -half, half } }
		for _, seg in segments do
			local a, b = seg[1], seg[2]
			local len = b - a
			local mid = (a + b) / 2
			for _, railY in { 1.1, 2.1 } do
				local size = if edge.axis == "x" then Vector3.new(len, 0.35, 0.25) else Vector3.new(0.25, 0.35, len)
				local pos = if edge.axis == "x"
					then Vector3.new(mid, y + railY, edge.z)
					else Vector3.new(edge.x, y + railY, mid)
				local rail = makePart("Rail", size, origin * CFrame.new(c + pos), FENCE_WHITE, fence)
				rail.CanCollide = false
			end
			local n = math.floor(len / FENCE_POST)
			for k = 0, n do
				local t = a + k * (len / math.max(n, 1))
				local pos = if edge.axis == "x"
					then Vector3.new(t, y + 1.5, edge.z)
					else Vector3.new(edge.x, y + 1.5, t)
				local post =
					makePart("Post", Vector3.new(0.6, 3, 0.6), origin * CFrame.new(c + pos), FENCE_WHITE, fence)
				post.CanCollide = false
				local cap = makePart(
					"Cap",
					Vector3.new(0.8, 0.3, 0.8),
					origin * CFrame.new(c + pos + Vector3.new(0, 1.6, 0)),
					Color3.fromRGB(220, 205, 190),
					fence
				)
				cap.CanCollide = false
			end
		end
	end
	fence.Parent = folder
end

local function buildPlot(index: number, root: Folder): PlotRuntime
	local n = Layout.PlotCount
	local theta = (index - 1) / n * math.pi * 2
	local center = Vector3.new(math.sin(theta), 0, math.cos(theta)) * Layout.PlotRingRadius
	local origin = CFrame.new(center) * CFrame.Angles(0, theta, 0) * CFrame.new(-v3(Layout.PlotCenterLocal))

	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. index
	folder:SetAttribute("Index", index)
	folder.Parent = root

	local floorPart = makePart(
		"Floor",
		Vector3.new(Layout.PlotSize, 1, Layout.PlotSize),
		origin * CFrame.new(v3(Layout.PlotCenterLocal) + Vector3.new(0, Layout.GroundY - 0.5, 0)),
		Color3.fromRGB(128, 196, 96),
		folder
	)
	floorPart.Material = Enum.Material.Grass
	-- 플롯 둘레 흰 말뚝 울타리 (광장 쪽 가운데 12 studs 는 입구로 비움)
	local half = Layout.PlotSize / 2
	local c = v3(Layout.PlotCenterLocal)
	buildFence(origin, folder, c, half)
	for k, corner in
		{
			Vector3.new(-half + 10, 0, -half + 10),
			Vector3.new(half - 10, 0, -half + 10),
			Vector3.new(-half + 10, 0, half - 10),
			Vector3.new(half - 10, 0, half - 10),
		}
	do
		local tree = Models.Decor.Trees[(k % #Models.Decor.Trees) + 1]
		Templates.spawn(
			tree,
			origin * CFrame.new(c + corner + Vector3.new(0, Layout.GroundY, 0)) * CFrame.Angles(0, k * 1.3, 0),
			folder
		)
		local rock = Models.Decor.Rocks[(k % #Models.Decor.Rocks) + 1]
		Templates.spawn(
			rock,
			origin * CFrame.new(c + corner * 0.8 + Vector3.new(6, Layout.GroundY, -4)) * CFrame.Angles(0, k * 2.1, 0),
			folder
		)
	end
	-- Z2 풍차
	local wm = v3(Layout.Zone.Z2.Origin) + Vector3.new(26, Layout.GroundY, -26)
	Templates.spawn(Models.Decor.Windmill, origin * CFrame.new(wm) * CFrame.Angles(0, math.pi / 4, 0), folder)

	local rt: PlotRuntime = {
		index = index,
		owner = nil,
		origin = origin,
		folder = folder,
		zoneFolders = {},
		sellStands = {},
		fogs = {},
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
		buildZoneStatics(rt, zone)
		if zone ~= "Z1" then
			buildFog(rt, zone)
		end
	end

	local spawnLocal = v3(Layout.pos("Z1", "Spawn")) + Vector3.new(0, Layout.GroundY + 3, 0)
	local lookLocal = v3(Layout.pos("Z1", "Field1")) + Vector3.new(0, Layout.GroundY + 3, 0)
	rt.spawnCFrame = CFrame.lookAt(origin:PointToWorldSpace(spawnLocal), origin:PointToWorldSpace(lookLocal))
	return rt
end

-- 구역 해금 시: 안개 제거 (클라 연출 후)
function PlotService:RemoveFog(rt: PlotRuntime, zone: string, delay: number)
	local fog = rt.fogs[zone]
	if not fog then
		return
	end
	rt.fogs[zone] = nil
	task.delay(delay, function()
		fog:Destroy()
	end)
end

-- 새 소유자 데이터에 맞춰 안개 복원/제거 (즉시)
function PlotService:SyncFog(rt: PlotRuntime, zonesUnlocked: { [string]: boolean })
	for _, zone in Zones.Order do
		if zone == "Z1" then
			continue
		end
		local unlocked = zonesUnlocked[zone] == true
		local fog = rt.fogs[zone]
		if unlocked and fog then
			rt.fogs[zone] = nil
			fog:Destroy()
		elseif not unlocked and not fog then
			buildFog(rt, zone)
		end
	end
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
	PlotService:SyncFog(rt, {})
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
