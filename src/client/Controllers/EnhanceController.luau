--!strict
-- 강화 화면(홀드 버튼) + 폭발 연출 P0~P4 + 강화대 빌보드. 글자 없음. DevSpec §7-6, §7-7.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enhance = require(Shared.Config.Enhance)
local Assets = require(Shared.Config.Assets)
local Layout = require(Shared.Config.Layout)
local EnhanceLogic = require(Shared.EnhanceLogic)
local Remotes = require(Shared.Remotes)
local Colors = require(Shared.Util.Colors)
local L = require(Shared.Util.L)
local StateController = require(script.Parent.StateController)
local AudioController = require(script.Parent.AudioController)
local HUDController = require(script.Parent.HUDController)
local GearVisual = require(script.Parent.GearVisual)
local Icon = require(script.Parent.UI.Icon)

local EnhanceController = {}
EnhanceController.Priority = 15

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
local flash: Frame
local levelNum: TextLabel
local stoneNum: TextLabel
local powerNum: TextLabel
local deltaRow: Frame
local deltaNum: TextLabel
local holdBtn: TextButton
local holdRing: Frame
local holdNum: TextLabel
local needRow: Frame
local needNum: TextLabel
local gearRow: Frame
local itemIcon: GuiObject
local hammer: GuiObject
local closeBtn: TextButton
local stationGui: BillboardGui?

local isOpen = false
local busy = false
local fxStarted = false
local holding = false
local holdT = 0
local nearStation = false
local HOLD_SEC = 0.3

local SLOT_ICON = { Tool = "Sickle", Shoes = "Shoe", Bag = "Bag" }

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

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "EnhanceScreen"
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
	flash.ZIndex = 6
	flash.Parent = gui

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(420, 540)
	panel.BackgroundColor3 = Color3.fromRGB(40, 36, 48)
	panel.BorderSizePixel = 0
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 24)
	pc.Parent = panel
	Icon.outline(panel, 3)
	panel.Parent = gui

	-- 상단: ⚒️ +N
	local top = Icon.row("Top", 44)
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.fromScale(0.5, 0.04)
	local anvil = Icon.new("Anvil", 44)
	anvil.LayoutOrder = 1
	anvil.Parent = top
	local topTitle = Icon.label(L("title.Enhance"), 30)
	topTitle.LayoutOrder = 2
	topTitle.Parent = top
	levelNum = Icon.number(44, 110)
	levelNum.LayoutOrder = 3
	levelNum.Parent = top
	top.Parent = panel

	-- 장비 3슬롯 (아이콘 + ★ 개수)
	gearRow = Icon.row("Gear", 36)
	gearRow.AnchorPoint = Vector2.new(0.5, 0)
	gearRow.Position = UDim2.fromScale(0.5, 0.14)
	local grl = gearRow:FindFirstChildOfClass("UIListLayout")
	if grl then
		grl.Padding = UDim.new(0, 22)
	end
	gearRow.Parent = panel

	-- 중앙: 강화 대상 아이콘 + 망치
	itemIcon = Icon.new("Sickle", 150)
	itemIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	itemIcon.Position = UDim2.fromScale(0.5, 0.42)
	itemIcon.ZIndex = 3
	itemIcon.Parent = panel
	hammer = Icon.new("Anvil", 70)
	hammer.AnchorPoint = Vector2.new(0.5, 1)
	hammer.Position = UDim2.fromScale(0.68, 0.30)
	hammer.Rotation = -30
	hammer.Visible = false
	hammer.ZIndex = 4
	hammer.Parent = panel

	-- 💎 보유
	local stoneRow = Icon.row("Stones", 30)
	stoneRow.AnchorPoint = Vector2.new(0.5, 0)
	stoneRow.Position = UDim2.fromScale(0.5, 0.58)
	local sIc = Icon.new("Stone", 30)
	sIc.Parent = stoneRow
	stoneNum = Icon.number(30, 90)
	stoneNum.Parent = stoneRow
	stoneRow.Parent = panel

	-- 홀드 버튼 (⚒️ ▲ +N) + 원형 게이지(테두리 굵기로 표현)
	holdBtn = Instance.new("TextButton")
	holdBtn.Name = "Hold"
	holdBtn.Text = ""
	holdBtn.AutoButtonColor = false
	holdBtn.AnchorPoint = Vector2.new(0.5, 0)
	holdBtn.Position = UDim2.fromScale(0.5, 0.66)
	holdBtn.Size = UDim2.fromOffset(300, 74)
	holdBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	holdBtn.BorderSizePixel = 0
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(0, 20)
	hc.Parent = holdBtn
	Icon.outline(holdBtn, 3)
	holdRing = Instance.new("Frame")
	holdRing.Name = "Ring"
	holdRing.AnchorPoint = Vector2.new(0, 1)
	holdRing.Position = UDim2.fromScale(0, 1)
	holdRing.Size = UDim2.fromScale(0, 0.12)
	holdRing.BackgroundColor3 = Color3.new(1, 1, 1)
	holdRing.BorderSizePixel = 0
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(1, 0)
	rc.Parent = holdRing
	holdRing.Parent = holdBtn
	local hrow = Icon.row("Row", 40)
	hrow.AnchorPoint = Vector2.new(0.5, 0.5)
	hrow.Position = UDim2.fromScale(0.5, 0.46)
	local hIc = Icon.new("Anvil", 40)
	hIc.LayoutOrder = 1
	hIc.Parent = hrow
	local up = Icon.number(40, 30)
	up.Text = "▲"
	up.LayoutOrder = 2
	up.TextColor3 = Color3.fromRGB(60, 40, 10)
	up.TextStrokeTransparency = 1
	up.Parent = hrow
	holdNum = Icon.number(40, 80)
	holdNum.LayoutOrder = 3
	holdNum.TextColor3 = Color3.fromRGB(60, 40, 10)
	holdNum.TextStrokeTransparency = 1
	holdNum.Parent = hrow
	local holdCap = Icon.label(L("btn.Enhance"), 30, Color3.fromRGB(60, 40, 10))
	holdCap.LayoutOrder = 4
	local hs = holdCap:FindFirstChildOfClass("UIStroke")
	if hs then
		hs.Enabled = false
	end
	holdCap.Parent = hrow
	hrow.Parent = holdBtn
	holdBtn.Parent = panel

	-- 비활성 시 필요량: 💎 12 / 20
	needRow = Icon.row("Need", 26)
	needRow.AnchorPoint = Vector2.new(0.5, 0)
	needRow.Position = UDim2.fromScale(0.5, 0.81)
	local nIc = Icon.new("Stone", 24)
	nIc.Parent = needRow
	needNum = Icon.number(26, 140)
	needNum.Parent = needRow
	needRow.Parent = panel

	-- ⚡ 파워 + ▲ 증가분
	local prow = Icon.row("Power", 40)
	prow.AnchorPoint = Vector2.new(0.5, 1)
	prow.Position = UDim2.new(0.5, 0, 1, -14)
	local bolt = Icon.new("Bolt", 40)
	bolt.Parent = prow
	powerNum = Icon.number(40, 120)
	powerNum.Parent = prow
	prow.Parent = panel
	deltaRow = Icon.row("Delta", 26)
	deltaRow.AnchorPoint = Vector2.new(0.5, 1)
	deltaRow.Position = UDim2.new(0.5, 110, 1, -20)
	local dUp = Icon.number(26, 24)
	dUp.Text = "▲"
	dUp.TextColor3 = Color3.fromRGB(255, 220, 90)
	dUp.Parent = deltaRow
	deltaNum = Icon.number(26, 80)
	deltaNum.TextColor3 = Color3.fromRGB(255, 220, 90)
	deltaNum.Parent = deltaRow
	deltaRow.Visible = false
	deltaRow.Parent = panel

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
end

local function refreshGearRow(d: any)
	gearRow:ClearAllChildren()
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Padding = UDim.new(0, 22)
	l.Parent = gearRow
	for i, slot in { "Tool", "Shoes", "Bag" } do
		local cell = Icon.row("Slot_" .. slot, 36)
		cell.LayoutOrder = i
		local cl = cell:FindFirstChildOfClass("UIListLayout")
		if cl then
			cl.Padding = UDim.new(0, 2)
		end
		local ic = Icon.new(SLOT_ICON[slot], 36)
		local g = d.gear[slot]
		if not g then
			ic.Visible = true
			if ic:IsA("TextLabel") then
				ic.TextTransparency = 0.6
			end
		end
		ic.Parent = cell
		if g then
			for _ = 1, g.star do
				local st = Icon.new("Star", 16)
				if st:IsA("TextLabel") then
					st.TextColor3 = Colors.hex(Assets.RarityColors[g.star])
				end
				st.Parent = cell
			end
		end
		cell.Parent = gearRow
	end
end

local function refresh()
	local d = StateController:Get()
	if not d then
		return
	end
	levelNum.Text = "+" .. d.enhance
	stoneNum.Text = tostring(d.stones)
	local st = StateController:GetStats()
	if not busy then
		powerNum.Text = tostring(st and st.power or 0)
	end
	local levels, spent = Enhance.previewLevels(d.stones, d.enhance)
	local active = EnhanceLogic.canBurst(d) and not busy
	holdNum.Text = "+" .. levels
	holdBtn.BackgroundColor3 = if active then Color3.fromRGB(255, 200, 60) else Color3.fromRGB(95, 90, 100)
	holdBtn.Active = active
	needRow.Visible = not active and not busy
	if not active then
		-- 최소 3단계 비용
		local need = 0
		for i = 0, Enhance.MinBurst - 1 do
			need += Enhance.cost(d.enhance + i)
		end
		needNum.Text = ("%d / %d"):format(math.min(d.stones, need), need)
		if not EnhanceLogic.unlocked(d) then
			needNum.Text = "⭐ 4"
		end
	end
	if spent == 0 then
		holdRing.Size = UDim2.fromScale(0, 0.12)
	end
	refreshGearRow(d)
end

function EnhanceController:Open()
	if isOpen then
		return
	end
	isOpen = true
	gui.Enabled = true
	setWalk(false)
	refresh()
	panel.Size = UDim2.fromOffset(380, 490)
	TweenService:Create(
		panel,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(420, 540) }
	):Play()
end

function EnhanceController:Close()
	if not isOpen or busy then
		return
	end
	isOpen = false
	holding = false
	gui.Enabled = false
	setWalk(true)
end

-- 카메라 흔들림 (RenderStep, 카메라 이후 우선순위)
local shakeAmp, shakeT = 0, 0
RunService:BindToRenderStep("EnhanceShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shakeT <= 0 then
		return
	end
	shakeT -= dt
	local cam = workspace.CurrentCamera
	if cam then
		local a = shakeAmp * math.max(shakeT, 0) * 4
		cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0)
	end
end)
local function shake(amp: number, dur: number)
	shakeAmp, shakeT = amp, dur
end

local function popup(text: string, color: Color3, big: boolean)
	local lbl = Icon.number(if big then 56 else 36, 120)
	lbl.Text = text
	lbl.TextColor3 = color
	lbl.TextXAlignment = Enum.TextXAlignment.Center
	lbl.AnchorPoint = Vector2.new(0.5, 0.5)
	lbl.Position = UDim2.new(0.5, (math.random() - 0.5) * 80, 0.36, 0)
	lbl.ZIndex = 5
	lbl.Parent = panel
	TweenService:Create(lbl, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = lbl.Position - UDim2.fromOffset(0, 90),
		TextTransparency = 1,
	}):Play()
	task.delay(0.5, function()
		lbl:Destroy()
	end)
end

local function bodyAura(seq: ColorSequence?, sec: number)
	local char = localPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not seq then
		return
	end
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "BurstAura"
	pe.Color = seq
	pe.LightEmission = 0.9
	pe.Size = NumberSequence.new(0.8, 0)
	pe.Transparency = NumberSequence.new(0.1, 1)
	pe.Lifetime = NumberRange.new(0.5, 0.9)
	pe.Rate = 60
	pe.Speed = NumberRange.new(2, 4)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Parent = root
	task.delay(sec, function()
		pe.Enabled = false
		task.delay(1, function()
			pe:Destroy()
		end)
	end)
end

-- 연출 P0~P4 (DevSpec §7-7)
local function play(msg: any)
	busy = true
	fxStarted = true
	HUDController:HoldPower(true)
	refresh()
	local n = #msg.steps
	local stepTime = math.clamp(Enhance.TotalTimeCap / math.max(n, 1), Enhance.StepTimeMin, Enhance.StepTimeMax)
	local fast = stepTime <= 0.12
	local itemScale = itemIcon:FindFirstChildOfClass("UIScale")
	if not itemScale then
		itemScale = Instance.new("UIScale")
		itemScale.Parent = itemIcon
	end

	-- P0 흡수: HUD 💎 → 중앙 아이템 (나선)
	AudioController:Play("PadDrain", 0.8, 0.6)
	local from = HUDController:SlotPosition("Stone") or Vector2.new(0, 0)
	local cnt = math.min(msg.stonesSpent, 40)
	for i = 1, cnt do
		task.delay((i - 1) * (0.4 / cnt), function()
			local s = Icon.new("Stone", 26)
			s.AnchorPoint = Vector2.new(0.5, 0.5)
			s.Position = UDim2.fromOffset(from.X, from.Y)
			s.ZIndex = 7
			s.Parent = gui
			local target = itemIcon.AbsolutePosition + itemIcon.AbsoluteSize / 2
			local t0 = os.clock()
			local conn
			conn = RunService.Heartbeat:Connect(function()
				local a = math.min((os.clock() - t0) / 0.45, 1)
				local p = from:Lerp(target, a)
				local ang = a * math.pi * 2 + i
				local r = (1 - a) * 90
				s.Position = UDim2.fromOffset(p.X + math.cos(ang) * r, p.Y + math.sin(ang) * r)
				if a >= 1 then
					conn:Disconnect()
					s:Destroy()
				end
			end)
		end)
	end
	task.wait(0.5)

	-- P1 타격
	hammer.Visible = true
	local level = msg.from
	local auraName = EnhanceLogic.auraFor(level)
	for i, step in msg.steps do
		local crit = step.crit
		-- 망치 낙하 → 복귀
		hammer.Rotation = -30
		TweenService:Create(
			hammer,
			TweenInfo.new(stepTime * 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Rotation = 25 }
		):Play()
		task.wait(stepTime * 0.55)
		-- 펀치 + 숫자
		itemScale.Scale = if crit then 1.4 else 1.25
		TweenService:Create(itemScale, TweenInfo.new(stepTime * 0.45), { Scale = 1 }):Play()
		level += step.gain
		levelNum.Text = "+" .. level
		popup("+" .. step.gain, if crit then Color3.fromRGB(255, 210, 60) else Color3.new(1, 1, 1), crit)
		AudioController:Play(if fast then "HammerFast" else "HammerSlow", math.min(0.8 + 0.06 * i, 1.7), 0.6)
		if crit then
			AudioController:Play("Crit", 1, 0.8)
			shake(0.35, 0.25)
			flash.BackgroundColor3 = Color3.fromRGB(255, 210, 60)
			flash.BackgroundTransparency = 0.6
			TweenService:Create(flash, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		end
		-- 오라 임계 통과
		local newAura = EnhanceLogic.auraFor(level)
		if newAura ~= auraName then
			auraName = newAura
			local seq = GearVisual.auraColor(newAura)
			if seq then
				flash.BackgroundColor3 = seq.Keypoints[1].Value
				flash.BackgroundTransparency = 0.5
				TweenService:Create(flash, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
				AudioController:Play("Boom", 1.3, 0.4)
			end
		end
		TweenService:Create(hammer, TweenInfo.new(stepTime * 0.45), { Rotation = -30 }):Play()
		task.wait(stepTime * 0.45)
	end
	hammer.Visible = false

	-- P2 폭발: 링 웨이브 + 카메라 줌 펀치
	AudioController:Play("Boom", 1, 0.8)
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = itemIcon.Position
	ring.Size = UDim2.fromOffset(20, 20)
	ring.BackgroundTransparency = 1
	ring.BorderSizePixel = 0
	ring.ZIndex = 5
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 6
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = ring
	local rcorner = Instance.new("UICorner")
	rcorner.CornerRadius = UDim.new(1, 0)
	rcorner.Parent = ring
	ring.Parent = panel
	TweenService:Create(
		ring,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(520, 520) }
	):Play()
	TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
	task.delay(0.45, function()
		ring:Destroy()
	end)
	local cam = workspace.CurrentCamera
	if cam then
		local fov = cam.FieldOfView
		TweenService:Create(cam, TweenInfo.new(0.15), { FieldOfView = fov - 7 }):Play()
		task.delay(0.15, function()
			TweenService:Create(cam, TweenInfo.new(0.25), { FieldOfView = fov }):Play()
		end)
	end
	shake(0.5, 0.3)
	task.wait(0.4)

	-- P3 파워 롤링 (화면 + HUD 동시)
	local t0 = os.clock()
	local lastTick = 0
	while os.clock() - t0 < 1.0 do
		local a = 1 - (1 - math.min((os.clock() - t0) / 1.0, 1)) ^ 4
		local v = math.floor(msg.powerFrom + (msg.powerTo - msg.powerFrom) * a)
		powerNum.Text = tostring(v)
		powerNum.TextColor3 = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 210, 60), a)
		if os.clock() - lastTick > 1 / 12 then
			lastTick = os.clock()
			AudioController:Play("RollTick", 1 + a * 0.5, 0.3)
		end
		RunService.Heartbeat:Wait()
	end
	powerNum.Text = tostring(msg.powerTo)
	HUDController:HoldPower(false, 1.0)
	deltaNum.Text = tostring(msg.powerTo - msg.powerFrom)
	deltaRow.Visible = true
	AudioController:Play("Tada", 1, 0.7)
	task.delay(0.6, function()
		deltaRow.Visible = false
	end)

	-- P4 여운: 캐릭터 오라 3초
	bodyAura(GearVisual.auraColor(EnhanceLogic.auraFor(msg.to)) or ColorSequence.new(Color3.new(1, 1, 1)), 3)
	busy = false
	refresh()
end

local function request()
	if busy or not isOpen then
		return
	end
	local d = StateController:Get()
	if not d or not EnhanceLogic.canBurst(d) then
		return
	end
	busy = true
	fxStarted = false
	refresh()
	Remotes.get("RequestEnhance"):FireServer()
	task.delay(2, function()
		if busy and not fxStarted then
			busy = false
			refresh()
		end
	end)
end

-- 광장 강화대 빌보드: 잠김(🔒 ⭐4) / 열림(⚒️, 활성 시 펄스)
local function ensureStationGui(): BillboardGui?
	if stationGui and stationGui.Parent then
		return stationGui
	end
	local station = hubPart("EnhanceStation")
	if not station then
		return nil
	end
	local g = Instance.new("BillboardGui")
	g.Name = "StationGui"
	g.Size = UDim2.fromOffset(110, 90)
	g.StudsOffset = Vector3.new(0, 3.5, 0)
	g.AlwaysOnTop = false
	g.MaxDistance = 90
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 4)
	list.Parent = g
	g.Parent = station
	stationGui = g
	return g
end

local function refreshStation()
	local g = ensureStationGui()
	local d = StateController:Get()
	if not g or not d then
		return
	end
	for _, c in g:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	if not EnhanceLogic.unlocked(d) then
		local lock = Icon.new("Lock", 44)
		lock.LayoutOrder = 1
		lock.Parent = g
		local row = Icon.row("Req", 22)
		row.LayoutOrder = 2
		local st = Icon.new("Star", 20)
		st.Parent = row
		local n = Icon.number(22, 30)
		n.Text = "4"
		n.Parent = row
		row.Parent = g
	else
		local anvil = Icon.new("Anvil", 52)
		anvil.LayoutOrder = 1
		anvil.Parent = g
		if EnhanceLogic.canBurst(d) then
			local sc = Instance.new("UIScale")
			sc.Parent = anvil
			anvil:SetAttribute("Pulse", true)
		end
	end
end

local function updateProximity()
	local d = StateController:Get()
	local char = localPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local station = hubPart("EnhanceStation")
	if not d or not root or not station then
		return
	end
	local dp = station.Position - root.Position
	local near = dp.X * dp.X + dp.Z * dp.Z <= Layout.Hub.OpenRadius ^ 2
	if near and not nearStation and EnhanceLogic.unlocked(d) then
		EnhanceController:Open()
	end
	nearStation = near
end

function EnhanceController:Start()
	build()
	StateController.Loaded:Connect(function()
		refresh()
		refreshStation()
	end)
	StateController.Changed:Connect(function(path)
		if path == "stones" or path == "enhance" or path == "level" or path:sub(1, 4) == "gear" then
			if isOpen then
				refresh()
			end
			refreshStation()
		end
	end)
	StateController.StatsChanged:Connect(function()
		if isOpen and not busy then
			refresh()
		end
	end)
	closeBtn.Activated:Connect(function()
		self:Close()
	end)
	-- 홀드 입력
	holdBtn.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if holdBtn.Active and not busy then
				holding = true
				holdT = 0
			end
		end
	end)
	holdBtn.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			holding = false
			if not busy then
				TweenService:Create(holdRing, TweenInfo.new(0.15), { Size = UDim2.fromScale(0, 0.12) }):Play()
			end
		end
	end)
	Remotes.get("EnhanceResult").OnClientEvent:Connect(function(msg)
		if not isOpen then
			self:Open()
		end
		task.spawn(play, msg)
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if holding and not busy then
			holdT += dt
			holdRing.Size = UDim2.fromScale(math.min(holdT / HOLD_SEC, 1), 0.12)
			-- 💎 아이콘이 버튼 주변으로 모임
			if math.random() < dt * 20 then
				local s = Icon.new("Stone", 18)
				s.AnchorPoint = Vector2.new(0.5, 0.5)
				local ang = math.random() * math.pi * 2
				s.Position = UDim2.new(0.5, math.cos(ang) * 160, 0.5, math.sin(ang) * 90)
				s.Parent = holdBtn
				TweenService:Create(
					s,
					TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Position = UDim2.fromScale(0.5, 0.5) }
				):Play()
				task.delay(0.3, function()
					s:Destroy()
				end)
			end
			if holdT >= HOLD_SEC then
				holding = false
				request()
			end
		end
		-- 강화대 빌보드 펄스
		if stationGui then
			for _, c in stationGui:GetChildren() do
				if c:GetAttribute("Pulse") then
					local sc = c:FindFirstChildOfClass("UIScale")
					if sc then
						sc.Scale = 1 + 0.12 * math.sin(acc * 6)
					end
				end
			end
		end
		if acc % 0.25 < dt then
			updateProximity()
			if not stationGui then
				refreshStation()
			end
		end
	end)
end

function EnhanceController:IsOpen(): boolean
	return isOpen
end

return EnhanceController
