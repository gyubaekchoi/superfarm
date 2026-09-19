--!strict
-- HUD: 상단 레벨·XP 캡슐, 그 아래 "지금 할 일" 튜토리얼 배너, 우상 지갑, 하단 네비 바. DevSpec §11-1.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local EnhanceLogic = require(Shared.EnhanceLogic)
local Remotes = require(Shared.Remotes)
local L = require(Shared.Util.L)
local StateController = require(script.Parent.StateController)
local Icon = require(script.Parent.UI.Icon)
local Theme = require(script.Parent.UI.Theme)
local NumberRoller = require(script.Parent.UI.NumberRoller)
local PadText = require(script.Parent.UI.PadText)

local HUDController = {}
HUDController.Priority = 20

local C = Theme.Color
local localPlayer = Players.LocalPlayer

local gui: ScreenGui
local rollers: { [string]: NumberRoller.Roller } = {}
local slots: { [string]: GuiObject } = {}
local xpFill: Frame
local xpText: TextLabel
local levelText: TextLabel
local goalIconHolder: Frame
local goalIcon: GuiObject
local goalIconName = ""
local goalText: TextLabel
local goalScale: UIScale
local anvilBadge: GuiObject
local nav: Frame

local powerHold = false
local pendingPower: number? = nil
local pulse = 0
local lastGoal: any = nil

local PAD = 12

-- 상단: ⭐ 레벨 배지 + XP 캡슐
local function buildLevelRow(parent: Instance): Frame
	local row = Instance.new("Frame")
	row.Name = "LevelRow"
	row.LayoutOrder = 1
	row.Size = UDim2.fromOffset(330, 54)
	row.BackgroundTransparency = 1
	row.ZIndex = 2

	local bar, fill, text = Theme.progress("Xp", row, 296, 40)
	bar.Position = UDim2.fromOffset(34, 7)
	bar.ZIndex = 2
	xpFill, xpText = fill, text

	local star = Instance.new("Frame")
	star.Name = "Star"
	star.Size = UDim2.fromOffset(56, 56)
	star.BackgroundTransparency = 1
	star.ZIndex = 5
	local si = Icon.new("Star", 56)
	si.ZIndex = 5
	si.Parent = star
	levelText = Theme.text("1", 24, C.TextDark)
	levelText.AutomaticSize = Enum.AutomaticSize.None
	levelText.Size = UDim2.fromScale(1, 1)
	levelText.Position = UDim2.fromOffset(0, 2)
	levelText.TextXAlignment = Enum.TextXAlignment.Center
	levelText.ZIndex = 6
	levelText.Parent = star
	star.Parent = row
	slots.Star = star

	row.Parent = parent
	return row
end

-- 상단 둘째 줄: 지금 할 일 (튜토리얼 배너)
local function buildGoal(parent: Instance): Frame
	local card = Theme.card("Goal", parent, C.Cream, 18)
	card.LayoutOrder = 2
	card.AutomaticSize = Enum.AutomaticSize.XY
	card.ZIndex = 2
	Theme.padding(card, 16, 8)
	Theme.list(card, false, 1)
	goalScale = Instance.new("UIScale")
	goalScale.Parent = card

	local caption = Theme.text(L("goal.Title"), 15, C.InkSoft, false)
	caption.LayoutOrder = 1
	caption.ZIndex = 3
	caption.Parent = card

	local body = Icon.row("Body", 34)
	body.LayoutOrder = 2
	goalIconHolder = body
	goalIcon = Icon.new("Sickle", 34)
	goalIcon.LayoutOrder = 1
	goalIcon.Parent = body
	goalText = Theme.text("", 24, C.TextDark, false)
	goalText.LayoutOrder = 2
	goalText.ZIndex = 3
	goalText.Parent = body
	body.Parent = card
	return card
end

-- 우상 지갑
local function walletRow(parent: Instance, iconName: string, px: number, order: number, short: boolean)
	local row = Icon.row("Row_" .. iconName, px)
	row.LayoutOrder = order
	local ic = Icon.new(iconName, px)
	ic.LayoutOrder = 1
	ic.Parent = row
	local num = Icon.number(px, 104)
	num.LayoutOrder = 2
	num.Parent = row
	row.Parent = parent
	slots[iconName] = ic
	rollers[iconName] = NumberRoller.new(num, short)
end

local function build()
	gui = Theme.screen("HUD", localPlayer:WaitForChild("PlayerGui"), 10)

	local top = Instance.new("Frame")
	top.Name = "Top"
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, PAD)
	top.AutomaticSize = Enum.AutomaticSize.XY
	top.Size = UDim2.fromOffset(0, 0)
	top.BackgroundTransparency = 1
	top.ZIndex = 2
	Theme.list(top, false, 10)
	top.Parent = gui
	buildLevelRow(top)
	buildGoal(top)

	local wallet = Theme.darkCard("Wallet", gui, 18)
	wallet.AnchorPoint = Vector2.new(1, 0)
	wallet.Position = UDim2.new(1, -PAD, 0, PAD)
	wallet.AutomaticSize = Enum.AutomaticSize.XY
	Theme.padding(wallet, 14, 8)
	local wl = Theme.list(wallet, false, 3)
	wl.HorizontalAlignment = Enum.HorizontalAlignment.Left
	walletRow(wallet, "Coin", 30, 1, true)
	walletRow(wallet, "Stone", 28, 2, true)
	walletRow(wallet, "Bolt", 28, 3, false)
	anvilBadge = Icon.new("Anvil", 24)
	anvilBadge.LayoutOrder = 3
	anvilBadge.Visible = false
	anvilBadge.Parent = wallet:FindFirstChild("Row_Stone")

	nav = Instance.new("Frame")
	nav.Name = "Nav"
	nav.AnchorPoint = Vector2.new(0.5, 1)
	nav.Position = UDim2.new(0.5, 0, 1, -PAD)
	nav.AutomaticSize = Enum.AutomaticSize.X
	nav.Size = UDim2.fromOffset(0, 78)
	nav.BackgroundTransparency = 1
	nav.ZIndex = 2
	Theme.list(nav, true, 12)
	nav.Parent = gui
end

local function refreshXP(d: any)
	local lv = d.level
	local cur = Economy.LevelXP[lv] or 0
	local nxt = Economy.LevelXP[lv + 1]
	local frac = if nxt then math.clamp((d.xp - cur) / (nxt - cur), 0, 1) else 1
	xpFill.Size = UDim2.fromScale(frac, 1)
	levelText.Text = tostring(lv)
	xpText.Text = if nxt then ("%d / %d"):format(math.max(0, d.xp - cur), nxt - cur) else L("pad.Max")
end

local function refreshAnvil(d: any)
	anvilBadge.Visible = EnhanceLogic.canBurst(d)
end

local function refreshAll(d: any, instant: boolean)
	rollers.Coin:set(d.coins, instant)
	rollers.Stone:set(d.stones, instant)
	refreshXP(d)
	refreshAnvil(d)
end

local function setGoal(msg: any)
	local d = StateController:Get()
	if not d then
		return
	end
	lastGoal = msg
	local iconName, text = PadText.goal(d, msg)
	if iconName ~= goalIconName then
		local old = goalIcon
		goalIcon = Icon.new(iconName, 34)
		goalIcon.LayoutOrder = 1
		goalIcon.Parent = goalIconHolder
		goalIconName = iconName
		old:Destroy()
	end
	if goalText.Text ~= text then
		goalText.Text = text
		goalScale.Scale = 1.15
		TweenService
			:Create(goalScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
end

function HUDController:Start()
	build()
	local d = StateController:Get()
	if d then
		refreshAll(d, true)
	end
	StateController.Loaded:Connect(function(data)
		refreshAll(data, true)
		if lastGoal then
			setGoal(lastGoal)
		end
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
	local c = StateController:GetStats()
	if c then
		rollers.Bolt:set(c.power, true)
	end
	Remotes.get("GuideTarget").OnClientEvent:Connect(setGoal)

	RunService.Heartbeat:Connect(function(dt)
		pulse += dt
		if anvilBadge.Visible then
			local sc = anvilBadge:FindFirstChildOfClass("UIScale")
			if not sc then
				sc = Instance.new("UIScale")
				sc.Parent = anvilBadge
			end
			sc.Scale = 1 + 0.15 * math.sin(pulse * 6)
		end
		-- 목표 아이콘이 천천히 숨쉬어 시선을 끈다
		local gs = goalIcon:FindFirstChildOfClass("UIScale")
		if not gs then
			gs = Instance.new("UIScale")
			gs.Parent = goalIcon
		end
		gs.Scale = 1 + 0.08 * math.sin(pulse * 3.2)
	end)
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

-- 보상 아이콘이 날아갈 HUD 목표 지점
function HUDController:SlotPosition(iconName: string): Vector2?
	local s = slots[iconName] or slots.Coin
	if not s then
		return nil
	end
	return s.AbsolutePosition + s.AbsoluteSize / 2
end

-- 하단 네비 바 슬롯. 다른 컨트롤러가 버튼을 여기에 넣는다.
function HUDController:NavSlot(order: number): Frame
	local f = Instance.new("Frame")
	f.Name = "Slot" .. order
	f.LayoutOrder = order
	f.Size = UDim2.fromOffset(74, 74)
	f.BackgroundTransparency = 1
	f.ZIndex = 2
	f.Parent = nav
	return f
end

function HUDController:Gui(): ScreenGui
	return gui
end

return HUDController
