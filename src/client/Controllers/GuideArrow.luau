--!strict
-- 바닥 화살표 빔 + 목표 위 아이콘 바운스 + 튜토리얼 유령 손가락. 글자 없음. DevSpec §10.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Remotes = require(Shared.Remotes)
local StateController = require(script.Parent.StateController)
local Icon = require(script.Parent.UI.Icon)

local GuideArrow = {}
GuideArrow.Priority = 25

local DASHES = 6
local SPACING = 3
local HIDE_DIST = 6
local TUTORIAL_HAND_UNTIL = 3

local dashes: { BasePart } = {}
local target: Instance? = nil
local targetKind = "None"
local marker: BillboardGui
local markerIcon: GuiObject?
local hand: BillboardGui
local anchor: Part -- 마커/손가락을 붙일 이동식 앵커
local goal: Instance? = nil -- 저축 목표(게이트): 화살표는 밭, 보조 마커는 게이트
local goalAnchor: Part
local goalMarker: BillboardGui

local function makeDash(): BasePart
	local p = Instance.new("Part")
	p.Name = "GuideDash"
	p.Size = Vector3.new(1.2, 0.12, 1.8)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 235, 120)
	p.Transparency = 1
	p.Parent = workspace
	return p
end

local function setIcon(name: string)
	if markerIcon then
		markerIcon:Destroy()
	end
	markerIcon = Icon.new(name, 56)
	markerIcon.AnchorPoint = Vector2.new(0.5, 1)
	markerIcon.Position = UDim2.fromScale(0.5, 1)
	markerIcon.Parent = marker
end

local function targetPosition(): Vector3?
	if not target or not target.Parent then
		return nil
	end
	if target:IsA("BasePart") then
		return target.Position
	elseif target:IsA("Model") then
		return target:GetPivot().Position
	end
	return nil
end

local function hideAll()
	for _, d in dashes do
		d.Transparency = 1
	end
	marker.Enabled = false
	hand.Enabled = false
end

local function updateGoal(t: number)
	if goal and goal.Parent and goal:IsA("BasePart") then
		goalAnchor.Position = goal.Position + Vector3.new(0, 5 + 0.3 * math.sin(t * 3), 0)
		goalMarker.Enabled = true
	else
		goalMarker.Enabled = false
	end
end

local function update()
	updateGoal(os.clock())
	local pos = targetPosition()
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not pos or not root then
		hideAll()
		return
	end
	local from = Vector3.new(root.Position.X, Layout.Y.Dash, root.Position.Z)
	local to = Vector3.new(pos.X, Layout.Y.Dash, pos.Z)
	local delta = to - from
	local dist = delta.Magnitude
	if dist <= HIDE_DIST then
		hideAll()
		return
	end
	local dir = delta.Unit
	local t = os.clock()
	local offset = (t * 4) % SPACING
	local count = math.min(DASHES, math.floor((dist - 2) / SPACING))
	for i, d in dashes do
		if i <= count then
			local along = 2 + (i - 1) * SPACING + offset
			local p = from + dir * along
			d.CFrame = CFrame.lookAt(p, p + dir)
			d.Transparency = 0.15 + 0.6 * (along / dist)
		else
			d.Transparency = 1
		end
	end
	-- 마커: 목표 위에서 바운스
	anchor.Position = Vector3.new(pos.X, pos.Y + 3 + 0.4 * math.sin(t * 5), pos.Z)
	marker.Enabled = true
	local d = StateController:Get()
	hand.Enabled = d ~= nil and d.tutorial < TUTORIAL_HAND_UNTIL
	if hand.Enabled then
		local tap = (math.sin(t * 6) + 1) / 2
		hand.StudsOffset = Vector3.new(1.2, 0.8 - 0.6 * tap, 0)
	end
end

function GuideArrow:Start()
	for i = 1, DASHES do
		dashes[i] = makeDash()
	end
	anchor = Instance.new("Part")
	anchor.Name = "GuideAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Parent = workspace

	marker = Instance.new("BillboardGui")
	marker.Name = "GuideMarker"
	marker.Size = UDim2.fromOffset(64, 64)
	marker.AlwaysOnTop = true
	marker.LightInfluence = 0
	marker.Adornee = anchor
	marker.Parent = anchor
	setIcon("Arrow")

	hand = Instance.new("BillboardGui")
	hand.Name = "GuideHand"
	hand.Size = UDim2.fromOffset(48, 48)
	hand.AlwaysOnTop = true
	hand.LightInfluence = 0
	hand.Adornee = anchor
	hand.Parent = anchor
	local handIcon = Icon.new("Hand", 48)
	handIcon.Rotation = -20
	handIcon.Parent = hand

	goalAnchor = anchor:Clone()
	goalAnchor.Name = "GuideGoalAnchor"
	goalAnchor.Parent = workspace
	goalMarker = Instance.new("BillboardGui")
	goalMarker.Name = "GuideGoal"
	goalMarker.Size = UDim2.fromOffset(56, 56)
	goalMarker.AlwaysOnTop = true
	goalMarker.LightInfluence = 0
	goalMarker.Adornee = goalAnchor
	goalMarker.Enabled = false
	goalMarker.Parent = goalAnchor
	local goalIcon = Icon.new("Lock", 56)
	goalIcon.Parent = goalMarker

	Remotes.get("GuideTarget").OnClientEvent:Connect(function(msg)
		targetKind = msg.kind or "None"
		target = msg.target
		goal = msg.goal
		if msg.icon then
			setIcon(msg.icon)
		end
	end)
	RunService.Heartbeat:Connect(update)
end

function GuideArrow:Kind(): string
	return targetKind
end

return GuideArrow
