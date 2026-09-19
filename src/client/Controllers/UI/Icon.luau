--!strict
-- 아이콘 GuiObject 생성. 에셋 ID가 있으면 ImageLabel, 없으면 이모지 TextLabel 대체.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Config.Assets)

local Icon = {}
Icon.Font = Enum.Font.FredokaOne
Icon.LineColor = Color3.fromRGB(52, 40, 70)

-- 두꺼운 외곽선 (패널·버튼)
function Icon.outline(inst: GuiObject, px: number?, color: Color3?): UIStroke
	local st = Instance.new("UIStroke")
	st.Thickness = px or 3
	st.Color = color or Icon.LineColor
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = inst
	return st
end

local function valid(id: string?): boolean
	return id ~= nil and id ~= "" and not id:match("://0$")
end

function Icon.new(name: string, px: number): GuiObject
	local id = Assets.Icons[name]
	if valid(id) then
		local img = Instance.new("ImageLabel")
		img.Name = "Icon_" .. name
		img.Size = UDim2.fromOffset(px, px)
		img.BackgroundTransparency = 1
		img.Image = id
		img.ScaleType = Enum.ScaleType.Fit
		return img
	end
	local lbl = Instance.new("TextLabel")
	lbl.Name = "Icon_" .. name
	lbl.Size = UDim2.fromOffset(px, px)
	lbl.BackgroundTransparency = 1
	lbl.Text = Assets.EmojiFallback[name] or "❔"
	lbl.TextScaled = true
	lbl.Font = Icon.Font
	lbl.TextColor3 = Color3.new(1, 1, 1)
	return lbl
end

-- 숫자 라벨 (숫자만 허용)
function Icon.number(px: number, width: number): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Name = "Number"
	lbl.Size = UDim2.fromOffset(width, px)
	lbl.BackgroundTransparency = 1
	lbl.Text = "0"
	lbl.TextScaled = true
	lbl.Font = Icon.Font
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextStrokeTransparency = 1
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	local st = Instance.new("UIStroke")
	st.Thickness = 2.5
	st.Color = Icon.LineColor
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	st.Parent = lbl
	return lbl
end

-- 가로 배치 컨테이너
function Icon.row(name: string, px: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.AutomaticSize = Enum.AutomaticSize.X
	f.Size = UDim2.fromOffset(0, px)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = f
	return f
end

return Icon
