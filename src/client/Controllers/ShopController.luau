--!strict
-- 상점 화면: 패스 5 + 상품 6 카드(아이콘 + 수량 + Robux 가격). 키오스크 근접·HUD 🛒 버튼으로 오픈. 글자 없음. DevSpec §9.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared.Config.Products)
local Layout = require(Shared.Config.Layout)
local Remotes = require(Shared.Remotes)
local StateController = require(script.Parent.StateController)
local AudioController = require(script.Parent.AudioController)
local Icon = require(script.Parent.UI.Icon)

local ShopController = {}
ShopController.Priority = 15

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
local passRow: Frame
local productRow: Frame
local closeBtn: TextButton
local hudBtn: TextButton
local cards: { [string]: { btn: TextButton, owned: GuiObject, soon: GuiObject } } = {}
local isOpen = false
local nearKiosk = false

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

local function robuxRow(price: number): Frame
	local row = Icon.row("Price", 22)
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromOffset(20, 20)
	img.BackgroundTransparency = 1
	img.Image = Products.RobuxIcon
	img.Parent = row
	local n = Icon.number(22, 60)
	n.Text = tostring(price)
	n.Parent = row
	return row
end

local function card(
	key: string,
	iconName: string,
	amount: number?,
	price: number,
	order: number,
	isPass: boolean
): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = "Card_" .. key
	btn.Text = ""
	btn.LayoutOrder = order
	btn.Size = UDim2.fromOffset(120, 150)
	btn.BackgroundColor3 = if isPass then Color3.fromRGB(60, 50, 90) else Color3.fromRGB(45, 60, 80)
	btn.BorderSizePixel = 0
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 16)
	c.Parent = btn
	Icon.outline(btn, 3)
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.Parent = btn

	local ic = Icon.new(iconName, 56)
	ic.LayoutOrder = 1
	ic.Parent = btn
	if amount then
		local row = Icon.row("Amount", 24)
		row.LayoutOrder = 2
		local x = Icon.number(24, 20)
		x.Text = "×"
		x.Parent = row
		local n = Icon.number(24, 60)
		n.Text = tostring(amount)
		n.Parent = row
		row.Parent = btn
	end
	local pr = robuxRow(price)
	pr.LayoutOrder = 3
	pr.Parent = btn

	-- 소유(패스) 오버레이 ✅
	local owned = Icon.new("Check", 56)
	owned.AnchorPoint = Vector2.new(1, 0)
	owned.Position = UDim2.new(1, -4, 0, 4)
	owned.Visible = false
	owned.ZIndex = 3
	owned.Parent = btn
	-- 미등록(id 0) 오버레이 🚧
	local soon = Icon.new("Construction", 40)
	soon.AnchorPoint = Vector2.new(0.5, 0.5)
	soon.Position = UDim2.fromScale(0.5, 0.5)
	soon.Visible = false
	soon.ZIndex = 3
	soon.Parent = btn
	cards[key] = { btn = btn, owned = owned, soon = soon }
	btn.Activated:Connect(function()
		if btn.Active then
			AudioController:Play("StarPing", 1, 0.4)
			Remotes.get("RequestPurchase"):FireServer({ productKey = key })
		end
	end)
	return btn
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "ShopScreen"
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

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(720, 440)
	panel.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
	panel.BorderSizePixel = 0
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 24)
	pc.Parent = panel
	Icon.outline(panel, 3)
	panel.Parent = gui

	local function scrollRow(name: string, y: number): Frame
		local sf = Instance.new("ScrollingFrame")
		sf.Name = name
		sf.AnchorPoint = Vector2.new(0.5, 0)
		sf.Position = UDim2.fromScale(0.5, y)
		sf.Size = UDim2.new(1, -40, 0, 170)
		sf.BackgroundTransparency = 1
		sf.BorderSizePixel = 0
		sf.ScrollingDirection = Enum.ScrollingDirection.X
		sf.AutomaticCanvasSize = Enum.AutomaticSize.X
		sf.CanvasSize = UDim2.new()
		sf.ScrollBarThickness = 6
		local l = Instance.new("UIListLayout")
		l.FillDirection = Enum.FillDirection.Horizontal
		l.Padding = UDim.new(0, 14)
		l.VerticalAlignment = Enum.VerticalAlignment.Center
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Parent = sf
		sf.Parent = panel
		return sf :: any
	end
	passRow = scrollRow("Passes", 0.08)
	productRow = scrollRow("Products", 0.52)

	for i, key in Products.PassOrder do
		local def = Products.Passes[key]
		card(key, def.icon, nil, def.price, i, true).Parent = passRow
	end
	for key, def in Products.Products do
		card(key, def.icon, def.amount, def.price, def.order, false).Parent = productRow
	end

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

	-- HUD 🛒 (우하)
	local hudGui = Instance.new("ScreenGui")
	hudGui.Name = "ShopHUD"
	hudGui.ResetOnSpawn = false
	hudGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	hudGui.Parent = localPlayer:WaitForChild("PlayerGui")
	hudBtn = Instance.new("TextButton")
	hudBtn.Name = "ShopButton"
	hudBtn.Text = ""
	hudBtn.Size = UDim2.fromOffset(72, 72)
	hudBtn.AnchorPoint = Vector2.new(1, 1)
	hudBtn.Position = UDim2.new(1, -12, 1, -12)
	hudBtn.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
	hudBtn.BackgroundTransparency = 0.3
	hudBtn.BorderSizePixel = 0
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(0, 18)
	hc.Parent = hudBtn
	Icon.outline(hudBtn, 3)
	local cart = Icon.new("Shop", 52)
	cart.AnchorPoint = Vector2.new(0.5, 0.5)
	cart.Position = UDim2.fromScale(0.5, 0.5)
	cart.Parent = hudBtn
	hudBtn.Parent = hudGui
end

local function refresh()
	local d = StateController:Get()
	if not d then
		return
	end
	local restricted = localPlayer:GetAttribute("PaidRandomRestricted") == true
	for key, def in Products.Passes do
		local c = cards[key]
		local ownedNow = d.passes[key] == true
		c.owned.Visible = ownedNow
		c.soon.Visible = def.id == 0
		c.btn.Active = def.id ~= 0 and not ownedNow
		c.btn.BackgroundTransparency = if c.btn.Active then 0 else 0.4
	end
	for key, def in Products.Products do
		local c = cards[key]
		c.btn.Visible = not (def.randomItem and restricted)
		c.soon.Visible = def.id == 0
		c.btn.Active = def.id ~= 0
		c.btn.BackgroundTransparency = if c.btn.Active then 0 else 0.4
	end
end

function ShopController:Open()
	if isOpen then
		return
	end
	isOpen = true
	refresh()
	gui.Enabled = true
	setWalk(false)
	panel.Size = UDim2.fromOffset(660, 400)
	TweenService:Create(
		panel,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(720, 440) }
	):Play()
end

function ShopController:Close()
	if not isOpen then
		return
	end
	isOpen = false
	gui.Enabled = false
	setWalk(true)
end

local function updateProximity()
	local char = localPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local kiosk = hubPart("ShopKiosk")
	if not root or not kiosk then
		return
	end
	local dp = kiosk.Position - root.Position
	local near = dp.X * dp.X + dp.Z * dp.Z <= Layout.Hub.OpenRadius ^ 2
	if near and not nearKiosk then
		ShopController:Open()
	end
	nearKiosk = near
end

function ShopController:Start()
	build()
	StateController.Loaded:Connect(refresh)
	StateController.Changed:Connect(function(path)
		if path:sub(1, 6) == "passes" then
			refresh()
		end
	end)
	localPlayer:GetAttributeChangedSignal("PaidRandomRestricted"):Connect(refresh)
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
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc % 0.25 < dt then
			updateProximity()
		end
	end)
end

return ShopController
