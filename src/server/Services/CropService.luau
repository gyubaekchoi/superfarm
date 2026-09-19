--!strict
-- 작물·나무 배치, 성장 상태. 파트 Attribute(ReadyAt, GrowSec, Crop, Tree)로 클라이언트에 전달. DevSpec §5-2.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Crops = require(Shared.Config.Crops)
local Zones = require(Shared.Config.Zones)
local Pads = require(Shared.Config.Pads)
local Types = require(Shared.Types)
local PlotService = require(script.Parent.PlotService)
local DataService = require(script.Parent.DataService)

type PlotRuntime = PlotService.PlotRuntime
type CropState = PlotService.CropState

local CropService = {}
CropService.Priority = 80

local CELL = Layout.CropSpacing
local v3 = PlotService.v3

local function cellKey(p: Vector3): string
	return math.floor(p.X / CELL) .. "," .. math.floor(p.Z / CELL)
end
CropService.cellKey = cellKey

local function cropColor(cropId: string): Color3
	local c = Crops[cropId].color
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function basePart(name: string, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function tagCrop(p: BasePart, zone: string, idx: number, cropId: string)
	p:SetAttribute("Zone", zone)
	p:SetAttribute("Idx", idx)
	p:SetAttribute("Crop", cropId)
	p:SetAttribute("GrowSec", Crops[cropId].growSec)
	p:SetAttribute("ReadyAt", 0)
	CollectionService:AddTag(p, "Crop")
end

local function addToGrid(rt: PlotRuntime, crop: CropState)
	local key = cellKey(crop.pos)
	local bucket = rt.grid[key]
	if not bucket then
		bucket = {}
		rt.grid[key] = bucket
	end
	table.insert(bucket, crop)
end

local function makeTile(rt: PlotRuntime, zone: string, name: string, centerLocal: Vector3, w: number, l: number)
	local tileH = Layout.FieldTileHeight
	local tile = basePart("Tile_" .. name, rt.zoneFolders[zone])
	tile.Size = Vector3.new(w, tileH, l)
	tile.CFrame = rt.origin * CFrame.new(centerLocal + Vector3.new(0, Layout.GroundY + tileH / 2, 0))
	tile.Color = Color3.fromRGB(105, 75, 45)
	tile.CanQuery = true
end

-- 밭 (격자 작물)
local function buildField(
	rt: PlotRuntime,
	zone: string,
	cropId: string,
	centerLocal: Vector3,
	cols: number,
	rows: number,
	startIdx: number
): number
	makeTile(rt, zone, zone .. "_" .. cropId, centerLocal, cols * CELL + 1, rows * CELL + 1)
	local cropsFolder = rt.zoneFolders[zone]:FindFirstChild("Crops") :: Folder
	local size = v3(Layout.CropBaseSize)
	local baseY = Layout.GroundY + Layout.FieldTileHeight
	local idx = startIdx
	for r = 1, rows do
		for c = 1, cols do
			local off = Vector3.new((c - (cols + 1) / 2) * CELL, 0, (r - (rows + 1) / 2) * CELL)
			local basePos = rt.origin:PointToWorldSpace(centerLocal + off + Vector3.new(0, baseY, 0))
			local part = basePart(("Crop_%s_%d"):format(zone, idx), cropsFolder)
			part.Size = size
			part.CFrame = CFrame.new(basePos + Vector3.new(0, size.Y / 2, 0))
			part.Color = cropColor(cropId)
			tagCrop(part, zone, idx, cropId)
			local crop: CropState = { idx = idx, zone = zone, cropId = cropId, pos = basePos, readyAt = 0, part = part }
			table.insert(rt.crops[zone], crop)
			addToGrid(rt, crop)
			idx += 1
		end
	end
	return idx
end

-- 과수원 (나무 + 열매)
local function buildOrchard(
	rt: PlotRuntime,
	zone: string,
	cropId: string,
	centerLocal: Vector3,
	cols: number,
	rows: number,
	startIdx: number,
	treeStart: number
): (number, number)
	local S = Layout.TreeSpacing
	makeTile(rt, zone, zone .. "_" .. cropId, centerLocal, cols * S + 2, rows * S + 2)
	local zf = rt.zoneFolders[zone]
	local cropsFolder = zf:FindFirstChild("Crops") :: Folder
	local def = Crops[cropId]
	local perTree = def.perTree or 5
	local idx, treeId = startIdx, treeStart
	local baseY = Layout.GroundY + Layout.FieldTileHeight
	for r = 1, rows do
		for c = 1, cols do
			local off = Vector3.new((c - (cols + 1) / 2) * S, 0, (r - (rows + 1) / 2) * S)
			local baseLocal = centerLocal + off + Vector3.new(0, baseY, 0)
			local baseWorld = rt.origin:PointToWorldSpace(baseLocal)

			local tree = Instance.new("Model")
			tree.Name = ("Tree_%s_%d"):format(zone, treeId)
			tree:SetAttribute("TreeId", treeId)
			local trunk = basePart("Trunk", tree)
			trunk.Size = Vector3.new(1.2, 4.5, 1.2)
			trunk.CFrame = CFrame.new(baseWorld + Vector3.new(0, 2.25, 0))
			trunk.Color = Color3.fromRGB(110, 70, 40)
			trunk.CanCollide = true
			local canopy = basePart("Canopy", tree)
			canopy.Shape = Enum.PartType.Ball
			canopy.Size = Vector3.new(5.5, 5.5, 5.5)
			canopy.CFrame = CFrame.new(baseWorld + Vector3.new(0, Layout.FruitHeight, 0))
			canopy.Color = Color3.fromRGB(70, 150, 70)
			tree.PrimaryPart = trunk
			tree.Parent = zf

			for k = 1, perTree do
				local a = (k - 1) / perTree * math.pi * 2
				local fruitPos = baseWorld
					+ Vector3.new(
						math.cos(a) * Layout.FruitRing,
						Layout.FruitHeight - 1 + (k % 2) * 1.2,
						math.sin(a) * Layout.FruitRing
					)
				local fruit = basePart(("Crop_%s_%d"):format(zone, idx), cropsFolder)
				fruit.Shape = Enum.PartType.Ball
				fruit.Size = Vector3.new(Layout.FruitSize, Layout.FruitSize, Layout.FruitSize)
				fruit.CFrame = CFrame.new(fruitPos)
				fruit.Color = cropColor(cropId)
				tagCrop(fruit, zone, idx, cropId)
				fruit:SetAttribute("Tree", true)
				fruit:SetAttribute("TreeId", treeId)
				local crop: CropState = {
					idx = idx,
					zone = zone,
					cropId = cropId,
					pos = fruitPos,
					readyAt = 0,
					part = fruit,
					treeId = treeId,
				}
				table.insert(rt.crops[zone], crop)
				addToGrid(rt, crop)
				idx += 1
			end
			treeId += 1
		end
	end
	return idx, treeId
end

-- 구역 전체를 데이터 기준으로 (재)생성. 생성 직후 모든 작물은 Ready.
function CropService:BuildZone(rt: PlotRuntime, zone: string, data: Types.PlayerData)
	self:ClearZone(rt, zone)
	local zdef = Zones.Defs[zone]
	if not zdef.crops or not data.zones[zone] then
		return
	end
	local field = data.fields[zone] or { expansion = 0, crop2 = false }
	rt.crops[zone] = {}
	local f1 = v3(Layout.pos(zone, "Field1"))
	local f2 = v3(Layout.pos(zone, "Field2"))
	if zdef.treeGrid then
		local grid = zdef.treeGrid[field.expansion + 1]
		local nextIdx, nextTree = buildOrchard(rt, zone, zdef.crops[1], f1, grid[1], grid[2], 1, 1)
		if field.crop2 and zdef.crops[2] then
			buildOrchard(rt, zone, zdef.crops[2], f2, grid[1], grid[2], nextIdx, nextTree)
		end
	else
		local grid = (zdef.fieldGrid :: any)[field.expansion + 1]
		local nextIdx = buildField(rt, zone, zdef.crops[1], f1, grid[1], grid[2], 1)
		if field.crop2 and zdef.crops[2] then
			buildField(rt, zone, zdef.crops[2], f2, grid[1], grid[2], nextIdx)
		end
	end
	local now = workspace:GetServerTimeNow()
	for _, crop in rt.crops[zone] do
		crop.readyAt = now
		crop.part:SetAttribute("ReadyAt", now)
	end
end

function CropService:BuildAll(rt: PlotRuntime, data: Types.PlayerData)
	for _, zone in Zones.Order do
		self:BuildZone(rt, zone, data)
	end
end

function CropService:ClearZone(rt: PlotRuntime, zone: string)
	local zf = rt.zoneFolders[zone]
	if zf then
		local cropsFolder = zf:FindFirstChild("Crops")
		if cropsFolder then
			cropsFolder:ClearAllChildren()
		end
		for _, child in zf:GetChildren() do
			if child.Name:sub(1, 5) == "Tile_" or child.Name:sub(1, 5) == "Tree_" then
				child:Destroy()
			end
		end
	end
	for key, bucket in rt.grid do
		for i = #bucket, 1, -1 do
			if bucket[i].zone == zone then
				table.remove(bucket, i)
			end
		end
		if #bucket == 0 then
			rt.grid[key] = nil
		end
	end
	rt.crops[zone] = {}
end

function CropService:ClearPlot(rt: PlotRuntime)
	for zone in rt.zoneFolders do
		self:ClearZone(rt, zone)
	end
end

function CropService:Harvest(_rt: PlotRuntime, crop: CropState, growLevel: number, now: number)
	local def = Crops[crop.cropId]
	crop.readyAt = now + def.growSec * Pads.growMult(growLevel)
	crop.part:SetAttribute("ReadyAt", crop.readyAt)
end

-- 위치 주변 Ready 작물 (일꾼·가이드용)
function CropService:ReadyNear(rt: PlotRuntime, pos: Vector3, radius: number, zone: string?): { CropState }
	local now = workspace:GetServerTimeNow()
	local out = {}
	local cx, cz = math.floor(pos.X / CELL), math.floor(pos.Z / CELL)
	local n = math.ceil(radius / CELL)
	for dx = -n, n do
		for dz = -n, n do
			local bucket = rt.grid[(cx + dx) .. "," .. (cz + dz)]
			if bucket then
				for _, crop in bucket do
					if crop.readyAt <= now and (zone == nil or crop.zone == zone) then
						local d = crop.pos - pos
						if d.X * d.X + d.Z * d.Z <= radius * radius then
							table.insert(out, crop)
						end
					end
				end
			end
		end
	end
	return out
end

function CropService:Start()
	DataService.Loaded:Connect(function(player, data)
		local rt = PlotService:GetByPlayer(player)
		if rt then
			PlotService:SyncFog(rt, data.zones)
			self:BuildAll(rt, data)
		end
	end)
	PlotService.Released:Connect(function(_player, rt)
		self:ClearPlot(rt)
	end)
end

return CropService
