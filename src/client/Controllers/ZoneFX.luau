--!strict
-- 구역 해금 연출: 새 구역 오브젝트가 땅에서 솟아오르고(스케일 인) 카메라가 2초 훑은 뒤 복귀. 해금 전 구역은 존재하지 않는다.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local AudioController = require(script.Parent.AudioController)

local ZoneFX = {}
ZoneFX.Priority = 30

local function popIn(zf: Instance)
	-- 구역 폴더의 파트들을 바닥 아래에서 제자리로 (0.9s), 시차 적용
	local parts = {}
	for _, d in zf:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	table.sort(parts, function(a, b)
		return a.Position.Y < b.Position.Y
	end)
	local originals: { [BasePart]: CFrame } = {}
	for _, p in parts do
		originals[p] = p.CFrame
		p.CFrame = p.CFrame - Vector3.new(0, 12, 0)
	end
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		local done = true
		for i, p in parts do
			if not p.Parent then
				continue
			end
			local delay = math.min(i / #parts, 1) * 0.5
			local a = math.clamp((t - delay) / 0.6, 0, 1)
			local e = 1 - (1 - a) ^ 3
			p.CFrame = originals[p] - Vector3.new(0, 12 * (1 - e), 0)
			if a < 1 then
				done = false
			end
		end
		if done then
			conn:Disconnect()
		end
	end)
end

local function play(msg: any)
	local plots = workspace:FindFirstChild("Plots")
	local pf = plots and plots:FindFirstChild("Plot" .. msg.plot)
	local zf = pf and pf:FindFirstChild(msg.zone)
	if not zf then
		return
	end
	-- 서버 생성 파트가 복제되어 오는 시간을 잠깐 기다림
	task.wait(0.15)
	popIn(zf)
	local isMine = msg.plot == Players.LocalPlayer:GetAttribute("Plot")
	if not isMine then
		return
	end
	AudioController:Play("PadComplete", 0.8, 0.7)
	AudioController:Play("Tada", 1, 0.6)
	local cam = workspace.CurrentCamera
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local floor = zf:FindFirstChild("ZoneFloor") :: BasePart?
	if not cam or not root or not floor then
		return
	end
	local target = floor.Position
	local startCF = cam.CFrame
	cam.CameraType = Enum.CameraType.Scriptable
	local dir = (root.Position - target)
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local from = target + dir * 55 + Vector3.new(0, 34, 0)
	TweenService:Create(
		cam,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = CFrame.lookAt(from, target) }
	):Play()
	task.delay(2.0, function()
		local back = TweenService:Create(
			cam,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ CFrame = startCF }
		)
		back:Play()
		back.Completed:Wait()
		cam.CameraType = Enum.CameraType.Custom
	end)
end

function ZoneFX:Start()
	Remotes.get("ZoneUnlocked").OnClientEvent:Connect(function(msg)
		task.spawn(play, msg)
	end)
end

return ZoneFX
