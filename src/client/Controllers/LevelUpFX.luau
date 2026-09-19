--!strict
-- 레벨업: 화면 중앙 ⭐ 폭발 + 레벨 숫자 + 보상 아이콘이 HUD로 날아감. DevSpec §5-1.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local AudioController = require(script.Parent.AudioController)
local HUDController = require(script.Parent.HUDController)
local Icon = require(script.Parent.UI.Icon)

local LevelUpFX = {}
LevelUpFX.Priority = 10

local gui: ScreenGui

local function flyReward(iconName: string, amount: number, delay: number)
	task.delay(delay, function()
		local row = Icon.row("Reward", 40)
		row.AnchorPoint = Vector2.new(0.5, 0.5)
		row.Position = UDim2.fromScale(0.5, 0.62)
		local ic = Icon.new(iconName, 40)
		ic.Parent = row
		local num = Icon.number(40, 60)
		num.Text = tostring(amount)
		num.Parent = row
		row.Parent = gui
		local scale = Instance.new("UIScale")
		scale.Scale = 0.2
		scale.Parent = row
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
		task.delay(0.9, function()
			local dest = HUDController:SlotPosition(iconName)
			local pos = if dest then UDim2.fromOffset(dest.X, dest.Y) else UDim2.fromScale(1, 0)
			TweenService
				:Create(row, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = pos })
				:Play()
			TweenService:Create(scale, TweenInfo.new(0.5), { Scale = 0.3 }):Play()
			task.delay(0.55, function()
				row:Destroy()
			end)
		end)
	end)
end

local function play(msg: any)
	AudioController:Play("LevelUp", 1, 0.7)
	local star = Icon.new("Star", 160)
	star.AnchorPoint = Vector2.new(0.5, 0.5)
	star.Position = UDim2.fromScale(0.5, 0.42)
	star.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = star
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()

	local lvl = Icon.number(64, 120)
	lvl.Text = tostring(msg.level)
	lvl.TextXAlignment = Enum.TextXAlignment.Center
	lvl.AnchorPoint = Vector2.new(0.5, 0.5)
	lvl.Position = UDim2.fromScale(0.5, 0.42)
	lvl.TextColor3 = Color3.fromRGB(60, 40, 10)
	lvl.TextStrokeTransparency = 1
	lvl.Parent = gui

	local r = msg.rewards or {}
	local delay = 0.4
	if (r.tickets or 0) > 0 then
		flyReward("Ticket", r.tickets, delay)
		delay += 0.25
	end
	if (r.stones or 0) > 0 then
		flyReward("Stone", r.stones, delay)
	end
	task.delay(1.6, function()
		TweenService:Create(scale, TweenInfo.new(0.3), { Scale = 0 }):Play()
		TweenService:Create(lvl, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		task.delay(0.35, function()
			star:Destroy()
			lvl:Destroy()
		end)
	end)
end

function LevelUpFX:Start()
	gui = Instance.new("ScreenGui")
	gui.Name = "LevelUpFX"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	Remotes.get("LevelUp").OnClientEvent:Connect(play)
	Remotes.get("Reward").OnClientEvent:Connect(function(msg)
		AudioController:Play("PadComplete", 1.1, 0.6)
		local delay = 0.1
		if (msg.stones or 0) > 0 then
			flyReward("Stone", msg.stones, delay)
			delay += 0.25
		end
		if (msg.tickets or 0) > 0 then
			flyReward("Ticket", msg.tickets, delay)
			delay += 0.25
		end
		if msg.boostSec then
			flyReward("CoinGold", math.floor(msg.boostSec / 60), delay)
		end
		if msg.growAll then
			flyReward("Wheat", 1, delay)
		end
	end)
end

return LevelUpFX
