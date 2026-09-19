--!strict
-- 아이콘 GuiObject 생성. 에셋 ID가 있으면 ImageLabel, 없으면 이모지 TextLabel 대체.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Config.Assets)
local Theme = require(script.Parent.Theme)

local Icon = {}
Icon.Font = Theme.Font
Icon.LineColor = Theme.Color.Ink

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
		img.ZIndex = 3
		return img
	end
	local lbl = Instance.new("TextLabel")
	lbl.Name = "Icon_" .. name
	lbl.Size = UDim2.fromOffset(px, px)
	lbl.BackgroundTransparency = 1
	lbl.Text = Assets.EmojiFallback[name] or "❔"
	lbl.TextScaled = true
	lbl.Font = Theme.Font
	lbl.TextColor3 = Theme.Color.TextLight
	lbl.ZIndex = 3
	return lbl
end

-- 숫자 라벨 (흰 글자 + 짙은 외곽선)
function Icon.number(px: number, width: number): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Name = "Number"
	lbl.Size = UDim2.fromOffset(width, px)
	lbl.BackgroundTransparency = 1
	lbl.Text = "0"
	lbl.TextScaled = true
	lbl.Font = Theme.Font
	lbl.TextColor3 = Theme.Color.TextLight
	lbl.TextStrokeTransparency = 1
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.ZIndex = 3
	local st = Instance.new("UIStroke")
	st.Thickness = math.max(2, px * 0.09)
	st.Color = Theme.Color.Ink
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	st.Parent = lbl
	return lbl
end

-- 제목/설명 글자
function Icon.label(text: string, px: number, color: Color3?): TextLabel
	local lbl = Theme.text(text, px, color or Theme.Color.TextLight)
	lbl.Name = "Label"
	lbl.TextXAlignment = Enum.TextXAlignment.Center
	return lbl
end

-- 두꺼운 외곽선
function Icon.outline(inst: GuiObject, px: number?, color: Color3?): UIStroke
	return Theme.stroke(inst, px or 3, color)
end

-- 가로 배치 컨테이너
function Icon.row(name: string, px: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.AutomaticSize = Enum.AutomaticSize.X
	f.Size = UDim2.fromOffset(0, px)
	f.ZIndex = 3
	Theme.list(f, true, 6)
	return f
end

return Icon
