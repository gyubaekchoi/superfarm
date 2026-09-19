--!strict
-- 월드 말풍선 빌보드: 둥근 흰 말풍선 + 꼬리 + 아이콘 + 글자.
-- 상호작용 가능한 오브젝트(패드·게이트·판매대·허브) 위에 띄워 "여기 뭔가 할 수 있다"를 한눈에 보여준다.
local TweenService = game:GetService("TweenService")
local Icon = require(script.Parent.Icon)
local Theme = require(script.Parent.Theme)

local Bubble = {}
Bubble.__index = Bubble

export type Bubble = typeof(setmetatable(
	{} :: {
		gui: BillboardGui,
		body: Frame,
		tail: Frame,
		header: Frame,
		icon: GuiObject,
		iconName: string,
		title: TextLabel,
		badge: TextLabel,
		rows: Frame,
		scale: UIScale,
	},
	Bubble
))

local BODY_COLOR = Theme.Color.Cream
local LINE = Theme.Color.Ink
local TITLE_COLOR = Theme.Color.TextDark

local function corner(inst: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

local function stroke(inst: GuiObject, t: number)
	local s = Instance.new("UIStroke")
	s.Thickness = t
	s.Color = LINE
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

-- adornee 위에 말풍선을 만든다. studsOffset 은 오브젝트 상단 여유.
function Bubble.new(adornee: BasePart, studsOffset: number, maxDistance: number?): Bubble
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Size = UDim2.fromOffset(260, 170)
	gui.StudsOffset = Vector3.new(0, studsOffset, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	gui.MaxDistance = maxDistance or 110
	gui.Adornee = adornee
	gui.ResetOnSpawn = false

	local scale = Instance.new("UIScale")
	scale.Parent = gui

	-- 꼬리 (아래 중앙, 45° 회전 사각형)
	local tail = Instance.new("Frame")
	tail.Name = "Tail"
	tail.Size = UDim2.fromOffset(20, 20)
	tail.AnchorPoint = Vector2.new(0.5, 1)
	tail.Position = UDim2.new(0.5, 0, 1, -6)
	tail.Rotation = 45
	tail.BackgroundColor3 = BODY_COLOR
	tail.BorderSizePixel = 0
	tail.ZIndex = 1
	stroke(tail, 3)
	tail.Parent = gui

	-- 본문
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.new(0.5, 0, 1, -16)
	body.AutomaticSize = Enum.AutomaticSize.XY
	body.Size = UDim2.fromOffset(0, 0)
	body.BackgroundColor3 = BODY_COLOR
	body.BorderSizePixel = 0
	body.ZIndex = 2
	corner(body, 18)
	stroke(body, 3)
	Theme.shadow(body, 5, 18)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = body
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = body
	body.Parent = gui

	-- 헤더: 아이콘 + 제목 + (배지)
	local header = Icon.row("Header", 34)
	header.LayoutOrder = 1
	header.ZIndex = 3
	local icon = Icon.new("Star", 34)
	icon.LayoutOrder = 1
	icon.ZIndex = 3
	icon.Parent = header
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.LayoutOrder = 2
	title.AutomaticSize = Enum.AutomaticSize.X
	title.Size = UDim2.fromOffset(0, 30)
	title.BackgroundTransparency = 1
	title.Font = Icon.Font
	title.TextSize = 24
	title.TextColor3 = TITLE_COLOR
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = ""
	title.ZIndex = 3
	title.Parent = header
	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.LayoutOrder = 3
	badge.AutomaticSize = Enum.AutomaticSize.X
	badge.Size = UDim2.fromOffset(0, 26)
	badge.BackgroundColor3 = Theme.Color.GoldDeep
	badge.BorderSizePixel = 0
	badge.Font = Icon.Font
	badge.TextSize = 20
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Text = ""
	badge.Visible = false
	badge.ZIndex = 3
	local bp = Instance.new("UIPadding")
	bp.PaddingLeft = UDim.new(0, 8)
	bp.PaddingRight = UDim.new(0, 8)
	bp.Parent = badge
	corner(badge, 8)
	badge.Parent = header
	header.Parent = body

	-- 추가 줄 (비용·요구 레벨·게이지)
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.LayoutOrder = 2
	rows.AutomaticSize = Enum.AutomaticSize.XY
	rows.Size = UDim2.fromOffset(0, 0)
	rows.BackgroundTransparency = 1
	rows.ZIndex = 3
	local rl = Instance.new("UIListLayout")
	rl.FillDirection = Enum.FillDirection.Vertical
	rl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rl.SortOrder = Enum.SortOrder.LayoutOrder
	rl.Padding = UDim.new(0, 5)
	rl.Parent = rows
	rows.Parent = body

	return setmetatable({
		gui = gui,
		body = body,
		tail = tail,
		header = header,
		icon = icon,
		iconName = "Star",
		title = title,
		badge = badge,
		rows = rows,
		scale = scale,
	}, Bubble)
end

function Bubble.setHeader(self: Bubble, iconName: string, text: string)
	if iconName ~= self.iconName then
		local old = self.icon
		self.icon = Icon.new(iconName, 34)
		self.icon.LayoutOrder = 1
		self.icon.ZIndex = 3
		self.icon.Parent = self.header
		self.iconName = iconName
		old:Destroy()
	end
	self.title.Text = text
end

function Bubble.setBadge(self: Bubble, text: string?, color: Color3?)
	self.badge.Visible = text ~= nil
	self.badge.Text = text or ""
	self.badge.BackgroundColor3 = color or Theme.Color.GoldDeep
end

function Bubble.setColor(self: Bubble, color: Color3)
	self.body.BackgroundColor3 = color
	self.tail.BackgroundColor3 = color
end

function Bubble.setEnabled(self: Bubble, on: boolean)
	self.gui.Enabled = on
end

-- 아이콘 + 글자 한 줄. key 로 구분해 재사용한다.
function Bubble.row(self: Bubble, key: string, order: number, iconName: string?, px: number?): (Frame, TextLabel)
	local existing = self.rows:FindFirstChild(key)
	if existing then
		return existing :: Frame, existing:FindFirstChild("Value") :: TextLabel
	end
	local size = px or 26
	local row = Icon.row(key, size)
	row.LayoutOrder = order
	row.ZIndex = 3
	if iconName then
		local ic = Icon.new(iconName, size)
		ic.LayoutOrder = 1
		ic.ZIndex = 3
		ic.Parent = row
	end
	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.LayoutOrder = 2
	value.AutomaticSize = Enum.AutomaticSize.X
	value.Size = UDim2.fromOffset(0, size)
	value.BackgroundTransparency = 1
	value.Font = Icon.Font
	value.TextSize = size - 4
	value.TextColor3 = TITLE_COLOR
	value.Text = ""
	value.ZIndex = 3
	value.Parent = row
	row.Parent = self.rows
	return row, value
end

function Bubble.gauge(self: Bubble, order: number): Frame
	local existing = self.rows:FindFirstChild("Gauge")
	if existing then
		return existing:FindFirstChild("Fill") :: Frame
	end
	local bg = Instance.new("Frame")
	bg.Name = "Gauge"
	bg.LayoutOrder = order
	bg.Size = UDim2.fromOffset(120, 11)
	bg.BackgroundColor3 = Theme.Color.CreamDeep
	bg.BorderSizePixel = 0
	bg.ZIndex = 3
	corner(bg, 6)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Theme.Color.Gold
	fill.BorderSizePixel = 0
	fill.ZIndex = 4
	corner(fill, 6)
	fill.Parent = bg
	bg.Parent = self.rows
	return fill
end

-- 주목 효과: 살짝 튀어오름
function Bubble.pop(self: Bubble)
	self.scale.Scale = 1.25
	TweenService:Create(self.scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

function Bubble.destroy(self: Bubble)
	self.gui:Destroy()
end

return Bubble
