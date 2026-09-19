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
local Signal = require(Packages.Signal)

export type CropState = {
	idx: number,
	zone: string,
	cropId: string,
	pos: Vector3,
	readyAt: number,
	part: BasePart,
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
	fogs: { [string]: BasePart },
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
end

local function buildFog(rt: PlotRuntime, zone: string)
	local size = v3(Layout.FogSize)
	local originLocal = v3(Layout.Zone[zone].Origin)
	local fog = makePart(
		"Fog_" .. zone,
		size,
		rt.origin * CFrame.new(originLocal + Vector3.new(0, size.Y / 2, 10)),
		Color3.fromRGB(200, 205, 215),
		rt.folder
	)
	fog.Transparency = 0.35
	fog.CanCollide = false
	fog.CanQuery = false
	fog.CastShadow = false
	fog.Material = Enum.Material.ForceField
	fog:SetAttribute("Zone", zone)
	rt.fogs[zone] = fog
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

	local hue = (index - 1) / n
	makePart(
		"Floor",
		Vector3.new(Layout.PlotSize, 1, Layout.PlotSize),
		origin * CFrame.new(v3(Layout.PlotCenterLocal) + Vector3.new(0, Layout.GroundY - 0.5, 0)),
		Color3.fromHSV(0.25 + hue * 0.08, 0.35, 0.75),
		folder
	)

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
