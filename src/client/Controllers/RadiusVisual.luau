--!strict
-- 로컬 플레이어 발밑 수확 반경 링. 도구 등급색, 반경 변화 시 펄스. DevSpec §5-4.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Config.Assets)
local Layout = require(Shared.Config.Layout)
local Colors = require(Shared.Util.Colors)
local StateController = require(script.Parent.StateController)

local RadiusVisual = {}
RadiusVisual.Priority = 30

local ring: Part
local radius = 4.5
local IDLE_T = 0.65

local function setRadius(r: number, pulse: boolean)
	radius = r
	local target = Vector3.new(0.08, r * 2, r * 2)
	if pulse then
		ring.Size = target * 1.3
		ring.Transparency = 0.2
		TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = target,
			Transparency = IDLE_T,
		}):Play()
	else
		ring.Size = target
	end
end

local function applyStats(c: any)
	local d = StateController:Get()
	local star = d and d.gear.Tool and d.gear.Tool.star
	ring.Color = if star then Colors.hex(Assets.RarityColors[star]) else Color3.new(1, 1, 1)
	if c.radius ~= radius then
		setRadius(c.radius, true)
	end
end

-- 반경 변화 없이 링만 한 번 반짝 (수확속도 패드 완료 등)
function RadiusVisual:Pulse()
	if ring then
		setRadius(radius, true)
	end
end

function RadiusVisual:Start()
	ring = Instance.new("Part")
	ring.Name = "HarvestRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.new(1, 1, 1)
	ring.Transparency = IDLE_T
	ring.Parent = workspace
	setRadius(radius, false)

	StateController.StatsChanged:Connect(applyStats)
	local c = StateController:GetStats()
	if c then
		applyStats(c)
	end

	RunService.Heartbeat:Connect(function()
		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			ring.CFrame = CFrame.new(root.Position.X, Layout.GroundY + 0.06, root.Position.Z)
				* CFrame.Angles(0, 0, math.pi / 2)
			ring.Transparency = math.min(ring.Transparency, 0.95)
		else
			ring.CFrame = CFrame.new(0, -100, 0)
		end
	end)
end

return RadiusVisual
