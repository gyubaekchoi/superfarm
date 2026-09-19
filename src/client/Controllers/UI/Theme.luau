--!strict
-- UI 공통 테마. 레퍼런스(체인소 주스킹 계열) 스타일:
--   · 따뜻한 짙은 갈색 외곽선(검정 아님) + 아래로 떨어지는 단색 그림자 → "스티커" 느낌
--   · 크림/골드 면, 캡슐형 배지, 큼직한 둥근 모서리
--   · 숫자는 흰 글자 + 짙은 외곽선, 골드 위 글자는 짙은 갈색
-- 그림자는 자식 프레임을 부모보다 낮은 ZIndex 로 두어 만든다 → 모든 Gui 는 ZIndexBehavior.Global 이어야 한다.
local Theme = {}

Theme.Font = Enum.Font.FredokaOne

Theme.Color = {
	Ink = Color3.fromRGB(74, 56, 38), -- 외곽선 (따뜻한 짙은 갈색)
	InkSoft = Color3.fromRGB(120, 94, 64),
	Shadow = Color3.fromRGB(56, 40, 26),

	Cream = Color3.fromRGB(255, 246, 224), -- 밝은 패널
	CreamDeep = Color3.fromRGB(244, 226, 190),
	Paper = Color3.fromRGB(255, 252, 244),

	Gold = Color3.fromRGB(255, 200, 60),
	GoldDeep = Color3.fromRGB(240, 158, 40),
	GoldPale = Color3.fromRGB(255, 226, 140),

	Dark = Color3.fromRGB(58, 66, 54), -- 반투명 짙은 패널
	DarkDeep = Color3.fromRGB(42, 48, 40),

	Green = Color3.fromRGB(126, 200, 80),
	Red = Color3.fromRGB(240, 96, 96),
	Blue = Color3.fromRGB(92, 172, 240),
	Violet = Color3.fromRGB(150, 120, 230),

	TextDark = Color3.fromRGB(74, 56, 38),
	TextLight = Color3.fromRGB(255, 252, 244),
	TextMuted = Color3.fromRGB(150, 140, 128),
}

local C = Theme.Color

function Theme.corner(inst: GuiObject, r: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
	return c
end

function Theme.pillCorner(inst: GuiObject): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = inst
	return c
end

function Theme.stroke(inst: GuiObject, thickness: number?, color: Color3?): UIStroke
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = color or C.Ink
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = inst
	return s
end

-- 아래로 떨어지는 단색 그림자. ZIndexBehavior.Global 필요.
function Theme.shadow(inst: GuiObject, offsetY: number?, radius: number?): Frame
	local sh = Instance.new("Frame")
	sh.Name = "Shadow"
	sh.Size = UDim2.fromScale(1, 1)
	sh.Position = UDim2.fromOffset(0, offsetY or 5)
	sh.BackgroundColor3 = C.Shadow
	sh.BackgroundTransparency = 0.3
	sh.BorderSizePixel = 0
	sh.ZIndex = inst.ZIndex - 1
	if radius == -1 then
		Theme.pillCorner(sh)
	else
		Theme.corner(sh, radius or 16)
	end
	sh.Parent = inst
	return sh
end

function Theme.padding(inst: GuiObject, x: number, y: number): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, x)
	p.PaddingRight = UDim.new(0, x)
	p.PaddingTop = UDim.new(0, y)
	p.PaddingBottom = UDim.new(0, y)
	p.Parent = inst
	return p
end

function Theme.list(inst: GuiObject, horizontal: boolean, gap: number): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, gap)
	l.Parent = inst
	return l
end

-- 카드(패널) 면. radius = -1 이면 캡슐
function Theme.surface(inst: GuiObject, color: Color3, radius: number?, strokePx: number?, shadowY: number?): GuiObject
	inst.BackgroundColor3 = color
	inst.BorderSizePixel = 0
	if radius == -1 then
		Theme.pillCorner(inst)
	else
		Theme.corner(inst, radius or 16)
	end
	Theme.stroke(inst, strokePx or 3)
	if shadowY ~= 0 then
		Theme.shadow(inst, shadowY or 5, radius)
	end
	return inst
end

function Theme.card(name: string, parent: Instance?, color: Color3?, radius: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.ZIndex = 2
	Theme.surface(f, color or C.Cream, radius or 18)
	f.Parent = parent
	return f
end

-- 반투명 짙은 패널 (HUD 지갑·목표 바)
function Theme.darkCard(name: string, parent: Instance?, radius: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.ZIndex = 2
	Theme.surface(f, C.Dark, radius or 18)
	f.BackgroundTransparency = 0.12
	f.Parent = parent
	return f
end

-- 글자. 골드/크림 위에는 dark, 짙은 면 위에는 light 를 쓴다.
function Theme.text(str: string, size: number, color: Color3?, outline: boolean?): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.fromOffset(0, size + 6)
	t.BackgroundTransparency = 1
	t.Font = Theme.Font
	t.TextSize = size
	t.TextColor3 = color or C.TextLight
	t.Text = str
	t.ZIndex = 3
	if outline ~= false then
		local s = Instance.new("UIStroke")
		s.Thickness = math.max(2, size * 0.09)
		s.Color = C.Ink
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		s.Parent = t
	end
	return t
end

-- 골드 버튼 (누르면 살짝 내려앉는다)
function Theme.button(name: string, parent: Instance?, color: Color3?, radius: number?): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.AutoButtonColor = false
	b.ZIndex = 2
	Theme.surface(b, color or C.Gold, radius or 18)
	b.Parent = parent
	local shadow = b:FindFirstChild("Shadow") :: Frame?
	local baseY = 0
	b.MouseButton1Down:Connect(function()
		b.Position += UDim2.fromOffset(0, 3)
		if shadow then
			shadow.Position = UDim2.fromOffset(0, 2)
		end
		baseY += 3
	end)
	local function release()
		if baseY > 0 then
			b.Position -= UDim2.fromOffset(0, baseY)
			baseY = 0
			if shadow then
				shadow.Position = UDim2.fromOffset(0, 5)
			end
		end
	end
	b.MouseButton1Up:Connect(release)
	b.MouseLeave:Connect(release)
	return b
end

-- 캡슐 배지 (아이콘 + 숫자). 골드 면 + 짙은 글자
function Theme.badge(name: string, parent: Instance?, color: Color3?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AutomaticSize = Enum.AutomaticSize.X
	f.ZIndex = 2
	Theme.surface(f, color or C.Gold, -1, 3, 4)
	Theme.padding(f, 10, 3)
	Theme.list(f, true, 4)
	f.Parent = parent
	return f
end

-- 진행 캡슐 (XP·게이지). 반환: fill, label
function Theme.progress(name: string, parent: Instance?, width: number, height: number): (Frame, Frame, TextLabel)
	local bg = Instance.new("Frame")
	bg.Name = name
	bg.Size = UDim2.fromOffset(width, height)
	bg.ZIndex = 2
	Theme.surface(bg, C.DarkDeep, -1, 3, 4)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = C.Gold
	fill.BorderSizePixel = 0
	fill.ZIndex = 3
	Theme.pillCorner(fill)
	fill.Parent = bg
	local label = Theme.text("", math.floor(height * 0.56), C.TextLight)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.Size = UDim2.fromScale(1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.ZIndex = 4
	label.Parent = bg
	bg.Parent = parent
	return bg, fill, label
end

-- ZIndex 전역 모드 ScreenGui (그림자가 부모 뒤로 가려면 필요)
function Theme.screen(name: string, parent: Instance, displayOrder: number?): ScreenGui
	local g = Instance.new("ScreenGui")
	g.Name = name
	g.ResetOnSpawn = false
	g.ZIndexBehavior = Enum.ZIndexBehavior.Global
	g.DisplayOrder = displayOrder or 10
	g.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	g.Parent = parent
	return g
end

return Theme
