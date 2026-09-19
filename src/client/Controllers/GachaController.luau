--!strict
-- 뽑기 화면 + 연출 타임라인 + 상자 근접 자동 오픈 + HUD 🎁 버튼. 글자 없음. DevSpec §6-3, §6-4.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gacha = require(Shared.Config.Gacha)
local Layout = require(Shared.Config.Layout)
local Remotes = require(Shared.Remotes)
local Colors = require(Shared.Util.Colors)
local L = require(Shared.Util.L)
local StateController = require(script.Parent.StateController)
local AudioController = require(script.Parent.AudioController)
local HUDController = require(script.Parent.HUDController)
local Icon = require(script.Parent.UI.Icon)

local GachaController = {}
GachaController.Priority = 15

local localPlayer = Players.LocalPlayer

-- 내 플롯의 허브 오브젝트 (해금 여부 무관, 항상 존재)
local function hubPart(name: string): BasePart?
	local plotIdx = localPlayer:GetAttribute("Plot")
	local plots = workspace:FindFirstChild("Plots")
	local pf = plotIdx and plots and plots:FindFirstChild("Plot" .. tostring(plotIdx))
	local hub = pf and pf:FindFirstChild("Hub")
	local part = hub and hub:FindFirstChild(name)
	return part :: BasePart?
end
local gui: ScreenGui
local panel: Frame
local box: GuiObject
local beam: Frame
local flash: Frame
local resultIcon: GuiObject?
local stars: { GuiObject } = {}
local ticketBtn: TextButton
local stoneBtn: TextButton
local ticketNum: TextLabel
local stoneNum: TextLabel
local closeBtn: TextButton
local hudBtn: TextButton
local hudBadge: TextLabel

local isOpen = false
local busy = false
local skipRequested = false
local nearBox = false
local SLOT_ICON = { Tool = "Sickle", Shoes = "Shoe", Bag = "Bag" }

local function rarity(star: number): Color3
	return Colors.hex(Gacha.Colors[star])
end

local function setWalk(enabled: boolean)
	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if enabled then
		local st = StateController:GetStats()
		hum.WalkSpeed = st and st.speed or 16
	else
		hum.WalkSpeed = 0
	end
end

local function makeButton(iconName: string, px: number, caption: string): (TextButton, TextLabel)
	local btn = Instance.new("TextButton")
	btn.Name = "Btn_" .. iconName
	btn.Text = ""
	btn.AutoButtonColor = true
	btn.Size = UDim2.fromOffset(196, px + 16)
	btn.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	btn.BorderSizePixel = 0
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 14)
	c.Parent = btn
	Icon.outline(btn, 3)
	local row = Icon.row("Row", px)
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.5)
	local ic = Icon.new(iconName, px)
	ic.Parent = row
	local num = Icon.number(px, 54)
	num.LayoutOrder = 2
	num.TextColor3 = Color3.fromRGB(60, 40, 10)
	num.TextStrokeTransparency = 1
	num.Parent = row
	local cap = Icon.label(caption, px - 8, Color3.fromRGB(60, 40, 10))
	cap.LayoutOrder = 3
	local capStroke = cap:FindFirstChildOfClass("UIStroke")
	if capStroke then
		capStroke.Enabled = false
	end
	cap.Parent = row
	row.Parent = btn
	return btn, num
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "GachaScreen"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.Enabled = false
	gui.IgnoreGuiInset = true
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.BorderSizePixel = 0
	dim.Parent = gui

	flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 5
	flash.Parent = gui

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(420, 520)
	panel.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
	panel.BorderSizePixel = 0
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 24)
	pc.Parent = panel
	Icon.outline(panel, 3)

	local heading = Icon.label(L("title.Gacha"), 30)
	heading.AnchorPoint = Vector2.new(0.5, 0)
	heading.Position = UDim2.fromScale(0.5, 0.035)
	heading.Parent = panel
	panel.Parent = gui

	-- 빛기둥 (상자 뒤)
	beam = Instance.new("Frame")
	beam.Name = "Beam"
	beam.AnchorPoint = Vector2.new(0.5, 1)
	beam.Position = UDim2.fromScale(0.5, 0.62)
	beam.Size = UDim2.fromOffset(120, 0)
	beam.BackgroundColor3 = Color3.new(1, 1, 1)
	beam.BackgroundTransparency = 0.3
	beam.BorderSizePixel = 0
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	grad.Parent = beam
	beam.Parent = panel

	box = Icon.new("Gift", 180)
	box.Name = "Box"
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.42)
	box.ZIndex = 2
	box.Parent = panel

	-- ★ 4개
	local starRow = Icon.row("Stars", 34)
	starRow.AnchorPoint = Vector2.new(0.5, 0)
	starRow.Position = UDim2.fromScale(0.5, 0.66)
	starRow.ZIndex = 3
	for i = 1, 4 do
		local s = Icon.new("Star", 34)
		s.Visible = false
		s.LayoutOrder = i
		s.Parent = starRow
		stars[i] = s
	end
	local srl = starRow:FindFirstChildOfClass("UIListLayout")
	if srl then
		srl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	starRow.Size = UDim2.new(1, 0, 0, 34)
	starRow.AutomaticSize = Enum.AutomaticSize.None
	starRow.Parent = panel

	-- 버튼 2개
	local btnRow = Icon.row("Buttons", 44)
	btnRow.AnchorPoint = Vector2.new(0.5, 0)
	btnRow.Position = UDim2.fromScale(0.5, 0.76)
	local brl = btnRow:FindFirstChildOfClass("UIListLayout")
	if brl then
		brl.Padding = UDim.new(0, 16)
	end
	ticketBtn, ticketNum = makeButton("Ticket", 36, L("btn.Draw"))
	ticketBtn.LayoutOrder = 1
	ticketBtn.Parent = btnRow
	stoneBtn, stoneNum = makeButton("Stone", 36, L("btn.Draw"))
	stoneBtn.LayoutOrder = 2
	stoneBtn.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
	stoneBtn.Parent = btnRow
	btnRow.Parent = panel

	-- 확률 표 (아이콘 + 숫자만)
	local odds = Icon.row("Odds", 20)
	odds.AnchorPoint = Vector2.new(0.5, 1)
	odds.Position = UDim2.new(0.5, 0, 1, -14)
	local orl = odds:FindFirstChildOfClass("UIListLayout")
	if orl then
		orl.Padding = UDim.new(0, 14)
	end
	for star = 1, 4 do
		local cell = Icon.row("Odd" .. star, 20)
		cell.LayoutOrder = star
		local sl = cell:FindFirstChildOfClass("UIListLayout")
		if sl then
			sl.Padding = UDim.new(0, 2)
		end
		local s = Icon.new("Star", 18)
		if s:IsA("TextLabel") then
			s.TextColor3 = rarity(star)
		end
		s.Parent = cell
		local n = Icon.number(20, 40)
		n.Text = tostring(Gacha.Weights[star])
		n.TextColor3 = rarity(star)
		n.Parent = cell
		local pct = Icon.new("Percent", 16)
		pct.Parent = cell
		cell.Parent = odds
	end
	odds.Parent = panel

	-- 닫기
	closeBtn = Instance.new("TextButton")
	closeBtn.Name = "Close"
	closeBtn.Text = ""
	closeBtn.Size = UDim2.fromOffset(44, 44)
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.Position = UDim2.new(1, -10, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(80, 70, 95)
	closeBtn.BorderSizePixel = 0
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(1, 0)
	cc.Parent = closeBtn
	local x = Icon.new("Close", 28)
	x.AnchorPoint = Vector2.new(0.5, 0.5)
	x.Position = UDim2.fromScale(0.5, 0.5)
	x.Parent = closeBtn
	closeBtn.Parent = panel

	-- HUD 🎁 버튼 (좌하 PC / 좌상 모바일)
	local hudGui = Instance.new("ScreenGui")
	hudGui.Name = "GachaHUD"
	hudGui.ResetOnSpawn = false
	hudGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	hudGui.Parent = localPlayer:WaitForChild("PlayerGui")
	hudBtn = Instance.new("TextButton")
	hudBtn.Name = "GachaButton"
	hudBtn.Text = ""
	hudBtn.Size = UDim2.fromOffset(72, 72)
	if UserInputService.TouchEnabled then
		hudBtn.AnchorPoint = Vector2.new(0, 0)
		hudBtn.Position = UDim2.fromOffset(12, 110)
	else
		hudBtn.AnchorPoint = Vector2.new(0, 1)
		hudBtn.Position = UDim2.new(0, 12, 1, -12)
	end
	hudBtn.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
	hudBtn.BackgroundTransparency = 0.3
	hudBtn.BorderSizePixel = 0
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(0, 18)
	hc.Parent = hudBtn
	Icon.outline(hudBtn, 3)
	local gift = Icon.new("Gift", 52)
	gift.AnchorPoint = Vector2.new(0.5, 0.5)
	gift.Position = UDim2.fromScale(0.5, 0.5)
	gift.Parent = hudBtn
	hudBadge = Icon.number(24, 40)
	hudBadge.AnchorPoint = Vector2.new(1, 0)
	hudBadge.Position = UDim2.new(1, 6, 0, -6)
	hudBadge.TextXAlignment = Enum.TextXAlignment.Center
	hudBadge.BackgroundColor3 = Color3.fromRGB(230, 60, 60)
	hudBadge.BackgroundTransparency = 0
	hudBadge.Size = UDim2.fromOffset(30, 24)
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(1, 0)
	bc.Parent = hudBadge
	hudBadge.Parent = hudBtn
	hudBtn.Parent = hudGui
end

local function refreshButtons()
	local d = StateController:Get()
	if not d then
		return
	end
	ticketNum.Text = tostring(d.tickets)
	stoneNum.Text = tostring(Gacha.StoneCost)
	local canTicket = d.tickets > 0 and not busy
	local canStone = d.stones >= Gacha.StoneCost and not busy
	ticketBtn.BackgroundColor3 = if canTicket then Color3.fromRGB(255, 200, 60) else Color3.fromRGB(90, 85, 80)
	stoneBtn.BackgroundColor3 = if canStone then Color3.fromRGB(120, 200, 255) else Color3.fromRGB(90, 85, 80)
	ticketBtn.Active = canTicket
	stoneBtn.Active = canStone
	hudBadge.Visible = d.tickets > 0
	hudBadge.Text = tostring(d.tickets)
end

local function resetStage()
	beam.Size = UDim2.fromOffset(120, 0)
	beam.BackgroundColor3 = Color3.new(1, 1, 1)
	box.Rotation = 0
	box.Position = UDim2.fromScale(0.5, 0.42)
	box.Visible = true
	for _, s in stars do
		s.Visible = false
	end
	if resultIcon then
		resultIcon:Destroy()
		resultIcon = nil
	end
end

function GachaController:Open()
	if isOpen then
		return
	end
	isOpen = true
	skipRequested = false
	resetStage()
	refreshButtons()
	gui.Enabled = true
	setWalk(false)
	panel.Size = UDim2.fromOffset(380, 470)
	TweenService:Create(
		panel,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(420, 520) }
	):Play()
end

function GachaController:Close()
	if not isOpen or busy then
		return
	end
	isOpen = false
	gui.Enabled = false
	setWalk(true)
end

local function waitOrSkip(sec: number, skippable: boolean)
	local t0 = os.clock()
	while os.clock() - t0 < sec do
		if skippable and skipRequested then
			return true
		end
		RunService.Heartbeat:Wait()
	end
	return false
end

-- 연출 타임라인 (DevSpec §6-4)
local function playResult(msg: any)
	busy = true
	refreshButtons()
	resetStage()
	local star = msg.star
	local high = star >= 3
	local canSkip = not msg.isFirst
	local color = rarity(star)

	AudioController:Play("DrumRoll", 1, 0.5)
	-- 0.0–0.9 진동 (진폭·속도 증가)
	local t0 = os.clock()
	while os.clock() - t0 < 0.9 do
		local a = (os.clock() - t0) / 0.9
		box.Rotation = math.sin(os.clock() * (20 + 40 * a)) * (2 + 10 * a)
		box.Position = UDim2.new(0.5, math.sin(os.clock() * 37) * 6 * a, 0.42, 0)
		RunService.Heartbeat:Wait()
	end
	box.Rotation = 0
	-- 0.9 흰 빛 새어나옴
	TweenService:Create(beam, TweenInfo.new(0.3), { Size = UDim2.fromOffset(120, 220) }):Play()
	if waitOrSkip(0.3, canSkip) then
		skipRequested = false
	end
	-- 1.2 등급색 전환 (+ ★3 이상 플래시·슬로모)
	TweenService:Create(beam, TweenInfo.new(0.2), { BackgroundColor3 = color, Size = UDim2.fromOffset(180, 300) })
		:Play()
	AudioController:Play(if star == 4 then "GachaLegend" elseif star == 3 then "GachaRare" else "StarPing", 1, 0.7)
	local slow = 1
	if high then
		flash.BackgroundTransparency = 0
		TweenService:Create(flash, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
		slow = 2
	end
	waitOrSkip(0.3 * slow, canSkip)
	-- 뚜껑 팝: 상자 축소 → 장비 아이콘 솟아 회전
	TweenService
		:Create(
			box,
			TweenInfo.new(0.2 * slow),
			{ Size = UDim2.fromOffset(120, 120), Position = UDim2.fromScale(0.5, 0.5) }
		)
		:Play()
	resultIcon = Icon.new(SLOT_ICON[msg.slot] or "Sickle", 150)
	resultIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	resultIcon.Position = UDim2.fromScale(0.5, 0.5)
	resultIcon.ZIndex = 4
	resultIcon.Parent = panel
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = resultIcon
	TweenService:Create(
		resultIcon,
		TweenInfo.new(0.6 * slow, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.fromScale(0.5, 0.36), Rotation = 720 }
	):Play()
	TweenService
		:Create(scale, TweenInfo.new(0.5 * slow, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	-- ★ 순차 점등
	for i = 1, star do
		stars[i].Visible = true
		if stars[i]:IsA("TextLabel") then
			stars[i].TextColor3 = color
		end
		local ss = Instance.new("UIScale")
		ss.Scale = 1.8
		ss.Parent = stars[i]
		TweenService:Create(ss, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
		AudioController:Play("StarPing", 1 + 0.12 * i, 0.5)
		waitOrSkip(0.1 * slow, canSkip)
	end
	waitOrSkip(0.6 * slow, canSkip)
	-- 장비가 캐릭터로 날아감 (화면 아래 중앙 → 실제 장착은 서버 어트리뷰트로 GearVisual 이 처리)
	TweenService:Create(
		resultIcon,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.fromScale(0.5, 1.1) }
	):Play()
	TweenService:Create(scale, TweenInfo.new(0.35), { Scale = 0.3 }):Play()
	AudioController:Play("Equip", 1, 0.6)
	waitOrSkip(0.4, false)
	-- 분해 💎 → HUD
	if msg.stonesGained > 0 then
		local row = Icon.row("Gain", 36)
		row.AnchorPoint = Vector2.new(0.5, 0.5)
		row.Position = UDim2.fromScale(0.5, 0.5)
		row.ZIndex = 4
		local ic = Icon.new("Stone", 36)
		ic.Parent = row
		local n = Icon.number(36, 60)
		n.Text = "+" .. msg.stonesGained
		n.Parent = row
		row.Parent = gui
		local dest = HUDController:SlotPosition("Stone")
		TweenService:Create(row, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = if dest then UDim2.fromOffset(dest.X, dest.Y) else UDim2.fromScale(1, 0),
		}):Play()
		task.delay(0.65, function()
			row:Destroy()
		end)
		waitOrSkip(0.4, false)
	end
	-- 첫 뽑기: 효과 배지 (🌾 +50 %) 2초
	if msg.isFirst and msg.equipped then
		local badge = Icon.row("FirstBadge", 40)
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.fromScale(0.5, 0.58)
		badge.ZIndex = 4
		local ic = Icon.new("Sickle", 40)
		ic.Parent = badge
		local n = Icon.number(40, 90)
		n.Text = "+" .. math.floor(Gacha.Effect.Tool[star] * 100)
		n.TextColor3 = color
		n.Parent = badge
		local pct = Icon.new("Percent", 30)
		pct.Parent = badge
		badge.Parent = panel
		waitOrSkip(1.6, false)
		badge:Destroy()
	end
	busy = false
	refreshButtons()
	if msg.isFirst then
		GachaController:Close()
	end
end

local function request(currency: string)
	if busy or not isOpen then
		return
	end
	local d = StateController:Get()
	if not d then
		return
	end
	if currency == "Ticket" and d.tickets <= 0 then
		return
	end
	if currency == "Stones" and d.stones < Gacha.StoneCost then
		return
	end
	busy = true
	refreshButtons()
	Remotes.get("RequestGacha"):FireServer({ currency = currency })
	-- 서버 응답이 없으면 2초 후 해제
	task.delay(2, function()
		if busy and not resultIcon then
			busy = false
			refreshButtons()
		end
	end)
end

local function updateProximity()
	local d = StateController:Get()
	local char = localPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local boxPart = hubPart("GachaBox")
	if not d or not root or not boxPart then
		return
	end
	local dp = boxPart.Position - root.Position
	local near = dp.X * dp.X + dp.Z * dp.Z <= Layout.Hub.OpenRadius ^ 2
	if near and not nearBox then
		if d.tickets > 0 or d.stones >= Gacha.StoneCost then
			GachaController:Open()
		end
	end
	nearBox = near
end

function GachaController:Start()
	build()
	refreshButtons()
	StateController.Loaded:Connect(refreshButtons)
	StateController.Changed:Connect(function(path)
		if path == "tickets" or path == "stones" then
			refreshButtons()
		end
	end)
	ticketBtn.Activated:Connect(function()
		request("Ticket")
	end)
	stoneBtn.Activated:Connect(function()
		request("Stones")
	end)
	closeBtn.Activated:Connect(function()
		self:Close()
	end)
	hudBtn.Activated:Connect(function()
		if isOpen then
			self:Close()
		else
			self:Open()
		end
	end)
	gui.Dim.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			skipRequested = true
		end
	end)
	Remotes.get("GachaResult").OnClientEvent:Connect(function(msg)
		if not isOpen then
			self:Open()
		end
		task.spawn(playResult, msg)
	end)
	-- HUD 버튼 펄스 (티켓 있을 때)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		local d = StateController:Get()
		if d and d.tickets > 0 then
			local s = hudBtn:FindFirstChildOfClass("UIScale")
			if not s then
				s = Instance.new("UIScale")
				s.Parent = hudBtn
			end
			s.Scale = 1 + 0.06 * math.sin(acc * 5)
		end
		if acc % 0.25 < dt then
			updateProximity()
		end
	end)
end

function GachaController:IsOpen(): boolean
	return isOpen
end

return GachaController
