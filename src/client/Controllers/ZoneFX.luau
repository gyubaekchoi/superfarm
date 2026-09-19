--!strict
-- 구역 해금 연출: 안개 페이드 → 카메라가 새 구역을 2초 훑고 복귀. DevSpec §5-2.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local AudioController = require(script.Parent.AudioController)

local ZoneFX = {}
ZoneFX.Priority = 30

local function play(msg: any)
	local plots = workspace:FindFirstChild("Plots")
	local pf = plots and plots:FindFirstChild("Plot" .. msg.plot)
	local fog = pf and pf:FindFirstChild("Fog_" .. msg.zone)
	local fogPivot: Vector3? = nil
	if fog then
		local parts = if fog:IsA("Model") then fog:GetDescendants() else { fog }
		if fog:IsA("Model") then
			fogPivot = fog:GetPivot().Position
		elseif fog:IsA("BasePart") then
			fogPivot = fog.Position
		end
		for i, part in parts do
			if part:IsA("BasePart") then
				TweenService:Create(part, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Transparency = 1,
					Size = part.Size * Vector3.new(1.3, 1.3, 1.3),
					CFrame = part.CFrame + Vector3.new(0, 14 + (i % 3) * 4, 0),
				}):Play()
			end
		end
	end
	local isMine = msg.plot == Players.LocalPlayer:GetAttribute("Plot")
	if not isMine or not fog then
		return
	end
	AudioController:Play("PadComplete", 0.8, 0.7)
	local cam = workspace.CurrentCamera
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not cam or not root then
		return
	end
	local target = (fogPivot or root.Position) - Vector3.new(0, 4, 0)
	local startCF = cam.CFrame
	cam.CameraType = Enum.CameraType.Scriptable
	local from = root.Position + Vector3.new(0, 18, 0) + (root.Position - target).Unit * 10
	local look = CFrame.lookAt(from, target)
	TweenService:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = look })
		:Play()
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
	Remotes.get("ZoneUnlocked").OnClientEvent:Connect(play)
end

return ZoneFX
