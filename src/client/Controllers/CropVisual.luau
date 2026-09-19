--!strict
-- 작물 성장 단계 렌더. 서버 Attribute(ReadyAt, GrowSec)를 시간 보간해 크기·바운스·색을 그린다. DevSpec §5-2.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crops = require(Shared.Config.Crops)
local Layout = require(Shared.Config.Layout)
local Colors = require(Shared.Util.Colors)

local CropVisual = {}
CropVisual.Priority = 50

type Tracked = {
	part: BasePart?, -- 프리미티브 대체일 때
	model: Model?, -- 템플릿일 때
	basePos: Vector3,
	basePivot: CFrame?,
	baseScale: number,
	lastScale: number,
	baseColor: Color3,
	readyColor: Color3,
	phase: number,
	state: number,
	tree: boolean,
	size: Vector3,
}
local tracked: { [Instance]: Tracked } = {}

local BASE = Vector3.new(Layout.CropBaseSize[1], Layout.CropBaseSize[2], Layout.CropBaseSize[3])
local LOD_DIST = 150
local SEED_SCALE = 0.35
local MID_SCALE = 0.85
local BOUNCE_AMP = 0.15
local BOUNCE_SPEED = 4

local function track(inst: Instance)
	if tracked[inst] then
		return
	end
	local cropId = inst:GetAttribute("Crop") :: string?
	local def = cropId and Crops[cropId]
	local tree = inst:GetAttribute("Tree") == true
	if inst:IsA("Model") then
		local pivot = inst:GetPivot()
		local baseColor = def and Colors.rgb(def.color) or Color3.new(1, 1, 1)
		tracked[inst] = {
			part = nil,
			model = inst,
			basePos = pivot.Position,
			basePivot = pivot,
			baseScale = inst:GetScale(),
			lastScale = -1,
			baseColor = baseColor,
			readyColor = baseColor,
			phase = (inst:GetAttribute("Idx") :: number? or 0) * 0.7,
			state = -1,
			tree = tree,
			size = Vector3.one,
		}
		return
	end
	if not inst:IsA("BasePart") then
		return
	end
	local part = inst
	local baseColor = def and Colors.rgb(def.color) or part.Color
	tracked[inst] = {
		part = part,
		model = nil,
		basePos = if tree then part.Position else part.Position - Vector3.new(0, part.Size.Y / 2, 0),
		basePivot = nil,
		baseScale = 1,
		lastScale = -1,
		baseColor = baseColor,
		readyColor = baseColor:Lerp(Color3.new(1, 1, 1), 0.25),
		phase = (part:GetAttribute("Idx") :: number? or 0) * 0.7,
		state = -1,
		tree = tree,
		size = part.Size,
	}
end

local function untrack(inst: Instance)
	tracked[inst] = nil
end

local function update()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	local now = workspace:GetServerTimeNow()
	local t = os.clock()
	for inst, tr in tracked do
		if not inst.Parent then
			tracked[inst] = nil
			continue
		end
		if (tr.basePos - camPos).Magnitude > LOD_DIST then
			continue
		end
		local readyAt = inst:GetAttribute("ReadyAt") :: number? or 0
		local growSec = inst:GetAttribute("GrowSec") :: number? or 1
		local p = 1 - (readyAt - now) / growSec
		local scale, yOff, state
		if tr.model then
			-- 템플릿 모델: 피벗(바닥 중심) 기준 스케일 + 준비 시 바운스
			if p >= 1 then
				scale, state = 1, 2
				yOff = (if tr.tree then 0.1 else BOUNCE_AMP) * (0.5 + 0.5 * math.sin(t * BOUNCE_SPEED + tr.phase))
			elseif p < 0.4 then
				scale, state, yOff = if tr.tree then 0.15 else SEED_SCALE, 0, 0
			else
				local a = (p - 0.4) / 0.6
				scale = if tr.tree then 0.15 + 0.85 * a else SEED_SCALE + (MID_SCALE - SEED_SCALE) * a
				state, yOff = 1, 0
			end
			if math.abs(scale - tr.lastScale) > 0.01 then
				tr.lastScale = scale
				tr.model:ScaleTo(tr.baseScale * scale)
			end
			tr.model:PivotTo((tr.basePivot :: CFrame) + Vector3.new(0, yOff, 0))
			tr.state = state
			continue
		end
		local part = tr.part :: BasePart
		if tr.tree then
			-- 열매: 작게 맺혀서 커진다. 중심 기준
			if p >= 1 then
				scale, state = 1, 2
			else
				scale, state = 0.15 + 0.85 * math.clamp(p, 0, 1), if p < 0.4 then 0 else 1
			end
			local size = tr.size * scale
			part.Size = size
			part.CFrame =
				CFrame.new(tr.basePos + Vector3.new(0, if state == 2 then 0.1 * math.sin(t * 3 + tr.phase) else 0, 0))
			if state ~= tr.state then
				tr.state = state
				part.Color = if state == 2 then tr.readyColor else tr.baseColor
			end
			continue
		end
		if p >= 1 then
			scale = 1
			yOff = BOUNCE_AMP * (0.5 + 0.5 * math.sin(t * BOUNCE_SPEED + tr.phase))
			state = 2
		elseif p < 0.4 then
			scale = SEED_SCALE
			yOff = 0
			state = 0
		else
			scale = SEED_SCALE + (MID_SCALE - SEED_SCALE) * ((p - 0.4) / 0.6)
			yOff = 0
			state = 1
		end
		local size = BASE * scale
		part.Size = size
		part.CFrame = CFrame.new(tr.basePos + Vector3.new(0, size.Y / 2 + yOff, 0))
		if state ~= tr.state then
			tr.state = state
			part.Color = if state == 2 then tr.readyColor else tr.baseColor
		end
	end
end

-- 나무 흔들기 (열매 수확 시). 나무 모델은 열매의 형제 폴더에 Tree_{zone}_{id}
local shaking: { [Model]: number } = {}
function CropVisual:ShakeTree(fruit: Instance)
	local zone = fruit:GetAttribute("Zone")
	local id = fruit:GetAttribute("TreeId")
	local zf = fruit.Parent and fruit.Parent.Parent
	local tree = zf and zf:FindFirstChild(("Tree_%s_%s"):format(tostring(zone), tostring(id)))
	if not tree or not tree:IsA("Model") then
		return
	end
	if shaking[tree] then
		shaking[tree] = 0
		return
	end
	shaking[tree] = 0
	local canopy = tree:FindFirstChild("Canopy") :: BasePart?
	if not canopy then
		shaking[tree] = nil
		return
	end
	local base = canopy.CFrame
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		local tt = (shaking[tree] or 0) + dt
		shaking[tree] = tt
		local amp = math.max(0, 1 - tt / 0.6)
		canopy.CFrame = base * CFrame.Angles(0, 0, math.rad(6) * amp * math.sin(tt * 30))
		if tt >= 0.6 then
			canopy.CFrame = base
			shaking[tree] = nil
			conn:Disconnect()
		end
	end)
end

function CropVisual:Start()
	for _, inst in CollectionService:GetTagged("Crop") do
		if inst:IsA("BasePart") then
			track(inst)
		end
	end
	CollectionService:GetInstanceAddedSignal("Crop"):Connect(function(inst)
		if inst:IsA("BasePart") then
			track(inst)
		end
	end)
	CollectionService:GetInstanceRemovedSignal("Crop"):Connect(function(inst)
		if inst:IsA("BasePart") then
			untrack(inst)
		end
	end)
	RunService.Heartbeat:Connect(update)
end

return CropVisual
