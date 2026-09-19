--!strict
-- 아이콘 전용 HUD: ⭐Lv+XP바 / ⚡파워 / 💰코인 / 💎강화석. DevSpec §11-1.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local EnhanceLogic = require(Shared.EnhanceLogic)
local StateController = require(script.Parent.StateController)
local Icon = require(script.Parent.UI.Icon)
local NumberRoller = require(script.Parent.UI.NumberRoller)

local HUDController = {}
HUDController.Priority = 20

local gui: ScreenGui
local rollers: { [string]: NumberRoller.Roller } = {}
local xpBar: Frame
local slots: { [string]: GuiObject } = {}

local PX = 34
local PAD = 12
local powerHold = false
local pendingPower: number? = nil
local anvilBadge: GuiObject
local anvilPulse = 0

local function panel(name: string, anchor: Vector2, pos: UDim2): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = anchor
	f.Position = pos
	f.AutomaticSize = Enum.AutomaticSize.XY
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BackgroundTransparency = 0.45
	f.BorderSizePixel = 0
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = f
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, 10)
	p.PaddingRight = UDim.new(0, 12)
	p.PaddingTop = UDim.new(0, 6)
	p.PaddingBottom = UDim.new(0, 6)
	p.Parent = f
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, 4)
	l.Parent = f
	f.Parent = gui
	return f
end

local function statRow(parent: Instance, iconName: string, px: number, width: number, short: boolean): TextLabel
	local row = Icon.row("Row_" .. iconName, px)
	local ic = Icon.new(iconName, px)
	ic.LayoutOrder = 1
	ic.Parent = row
	local num = Icon.number(px, width)
	num.LayoutOrder = 2
	num.Parent = row
	row.Parent = parent
	slots[iconName] = ic
	rollers[iconName] = NumberRoller.new(num, short)
	return num
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- 좌상: ⭐ Lv + XP 바
	local left = panel("Level", Vector2.new(0, 0), UDim2.fromOffset(PAD, PAD))
	statRow(left, "Star", PX, 70, false)
	local barBg = Instance.new("Frame")
	barBg.Name = "XPBar"
	barBg.Size = UDim2.fromOffset(240, 14)
	barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	barBg.BorderSizePixel = 0
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(1, 0)
	bc.Parent = barBg
	xpBar = Instance.new("Frame")
	xpBar.Name = "Fill"
	xpBar.Size = UDim2.fromScale(0, 1)
	xpBar.BackgroundColor3 = Color3.fromRGB(255, 210, 60)
	xpBar.BorderSizePixel = 0
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = xpBar
	xpBar.Parent = barBg
	barBg.Parent = left

	-- 중앙 상단: ⚡
	local center = panel("Power", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, PAD))
	statRow(center, "Bolt", 44, 120, false)

	-- 우상: 💰 / 💎
	local right = panel("Wallet", Vector2.new(1, 0), UDim2.new(1, -PAD, 0, PAD))
	statRow(right, "Coin", PX, 130, true)
	statRow(right, "Stone", 28, 110, true)
	-- 💎 옆 ⚒️ 미니 배지: 폭발 강화 가능할 때만 표시·펄스
	anvilBadge = Icon.new("Anvil", 24)
	anvilBadge.LayoutOrder = 3
	anvilBadge.Visible = false
	anvilBadge.Parent = right:FindFirstChild("Row_Stone")
end

local function refreshAnvil(d: any)
	local active = EnhanceLogic.canBurst(d)
	anvilBadge.Visible = active
end

local function refreshXP(d: any)
	local lv = d.level
	local cur = Economy.LevelXP[lv] or 0
	local nxt = Economy.LevelXP[lv + 1]
	local frac = if nxt then math.clamp((d.xp - cur) / (nxt - cur), 0, 1) else 1
	xpBar.Size = UDim2.fromScale(frac, 1)
end

local function refreshAll(d: any, instant: boolean)
	rollers.Star:set(d.level, instant)
	rollers.Coin:set(d.coins, instant)
	rollers.Stone:set(d.stones, instant)
	refreshXP(d)
	refreshAnvil(d)
end

function HUDController:Start()
	build()
	local d = StateController:Get()
	if d then
		refreshAll(d, true)
	end
	StateController.Loaded:Connect(function(data)
		refreshAll(data, true)
	end)
	StateController.Changed:Connect(function(path)
		local data = StateController:Get()
		if not data then
			return
		end
		if path == "coins" then
			rollers.Coin:set(data.coins)
		elseif path == "stones" then
			rollers.Stone:set(data.stones)
			refreshAnvil(data)
		elseif path == "level" then
			rollers.Star:set(data.level)
			refreshXP(data)
			refreshAnvil(data)
		elseif path == "xp" then
			refreshXP(data)
		elseif path == "enhance" then
			refreshAnvil(data)
		end
	end)
	StateController.StatsChanged:Connect(function(c)
		if powerHold then
			pendingPower = c.power
		else
			rollers.Bolt:set(c.power)
		end
	end)
	game:GetService("RunService").Heartbeat:Connect(function(dt)
		if anvilBadge.Visible then
			anvilPulse += dt
			local sc = anvilBadge:FindFirstChildOfClass("UIScale")
			if not sc then
				sc = Instance.new("UIScale")
				sc.Parent = anvilBadge
			end
			sc.Scale = 1 + 0.15 * math.sin(anvilPulse * 6)
		end
	end)
	local c = StateController:GetStats()
	if c then
		rollers.Bolt:set(c.power, true)
	end
end

-- 연출 동기화: 강화 연출 중 ⚡ 롤링을 보류하고, 해제 시 최신 값으로 롤링
function HUDController:HoldPower(hold: boolean, duration: number?)
	powerHold = hold
	if not hold and pendingPower then
		local r = rollers.Bolt
		r.dur = duration or 0.3
		r:set(pendingPower)
		pendingPower = nil
		task.delay(r.dur, function()
			r.dur = 0.3
		end)
	end
end

-- 다른 컨트롤러가 HUD 슬롯 화면 위치를 얻을 때 (레벨업 보상 비행 목표)
function HUDController:SlotPosition(iconName: string): Vector2?
	local s = slots[iconName]
	if not s then
		return nil
	end
	return s.AbsolutePosition + s.AbsoluteSize / 2
end

function HUDController:Gui(): ScreenGui
	return gui
end

return HUDController
