--!strict
-- 패드 빌보드(아이콘 + 💰숫자 + 게이지), 드레인 코인 스트림, 완료 플래시. 로컬 플레이어 플롯만. DevSpec §8-4.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PadLogic = require(Shared.PadLogic)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Util.Format)
local StateController = require(script.Parent.StateController)
local AudioController = require(script.Parent.AudioController)
local RadiusVisual = require(script.Parent.RadiusVisual)
local Icon = require(script.Parent.UI.Icon)

local PadVisual = {}
PadVisual.Priority = 35

type PadUI = {
	part: BasePart,
	id: string,
	gui: BillboardGui,
	icon: GuiObject,
	cost: TextLabel,
	fill: Frame,
	costRow: Frame,
	check: GuiObject,
	baseColor: Color3,
}
local pads: { [BasePart]: PadUI } = {}
local localPlayer = Players.LocalPlayer

local function isMine(part: BasePart): boolean
	return part:GetAttribute("Plot") == localPlayer:GetAttribute("Plot")
end

local function buildGui(part: BasePart, id: string): PadUI
	local gui = Instance.new("BillboardGui")
	gui.Name = "PadGui"
	gui.Size = UDim2.fromOffset(120, 110)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 80

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 4)
	list.Parent = gui

	local info = PadLogic.info(StateController:Get() :: any, id)
	local icon = Icon.new(info.icon, 48)
	icon.LayoutOrder = 1
	icon.Parent = gui

	local costRow = Icon.row("Cost", 26)
	costRow.LayoutOrder = 2
	local coinIc = Icon.new("Coin", 24)
	coinIc.Parent = costRow
	local cost = Icon.number(26, 70)
	cost.Parent = costRow
	costRow.Parent = gui

	local barBg = Instance.new("Frame")
	barBg.Name = "Gauge"
	barBg.LayoutOrder = 3
	barBg.Size = UDim2.fromOffset(100, 10)
	barBg.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	barBg.BorderSizePixel = 0
	local c1 = Instance.new("UICorner")
	c1.CornerRadius = UDim.new(1, 0)
	c1.Parent = barBg
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 210, 60)
	fill.BorderSizePixel = 0
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = UDim.new(1, 0)
	c2.Parent = fill
	fill.Parent = barBg
	barBg.Parent = gui

	-- 게이트 요구 레벨: ⭐ + 숫자 (레벨 부족일 때만)
	local levelRow = Icon.row("Level", 22)
	levelRow.LayoutOrder = 4
	local starIc = Icon.new("Star", 20)
	starIc.Parent = levelRow
	local levelNum = Icon.number(22, 40)
	levelNum.Parent = levelRow
	levelRow.Visible = false
	levelRow.Parent = gui

	local check = Icon.new("Check", 40)
	check.LayoutOrder = 5
	check.Visible = false
	check.Parent = gui

	gui.Parent = part
	return {
		part = part,
		id = id,
		zone = part:GetAttribute("Zone") :: string,
		gui = gui,
		icon = icon,
		iconName = info.icon,
		cost = cost,
		fill = fill,
		costRow = costRow,
		levelRow = levelRow,
		levelNum = levelNum,
		check = check,
		baseColor = part.Color,
	}
end

local function refresh(ui: PadUI, paid: number?, cost: number?)
	local d = StateController:Get()
	if not d then
		return
	end
	local info = PadLogic.info(d, ui.id)
	local done = ui.part:GetAttribute("Done") == true
	local zoneOpen = PadLogic.zoneOpen(d, ui.id, ui.zone)
	if done or not zoneOpen then
		ui.gui.Enabled = false
		ui.part.Transparency = if done then 1 else 0
		return
	end
	ui.part.Transparency = 0
	ui.gui.Enabled = true
	-- 아이콘이 상태에 따라 바뀌는 패드(게이트 🔒/🔓/🚧)
	if info.icon ~= ui.iconName then
		ui.icon:Destroy()
		ui.icon = Icon.new(info.icon, 48)
		ui.icon.LayoutOrder = 1
		ui.icon.Parent = ui.gui
		ui.iconName = info.icon
	end
	ui.levelRow.Visible = not info.levelOk
	ui.levelNum.Text = tostring(info.minLevel)
	if info.maxed then
		ui.costRow.Visible = false
		ui.fill.Parent.Visible = false
		ui.check.Visible = true
		ui.part.Color = ui.baseColor:Lerp(Color3.new(1, 1, 1), 0.5)
		return
	end
	local p = paid or info.paid
	local c = cost or info.cost or 1
	ui.costRow.Visible = true
	ui.fill.Parent.Visible = true
	ui.check.Visible = false
	ui.cost.Text = Format.short(math.max(0, c - p))
	ui.fill.Size = UDim2.fromScale(math.clamp(p / c, 0, 1), 1)
	-- 결제 가능하면 밝게, 조건 미달(레벨/티저)이면 회색
	local affordable = PadLogic.canPay(info) and d.coins >= (c - p)
	ui.cost.TextColor3 = if affordable
		then Color3.fromRGB(255, 240, 150)
		elseif not PadLogic.canPay(info) then Color3.fromRGB(140, 140, 140)
		else Color3.fromRGB(200, 200, 200)
end

local function refreshAll()
	for _, ui in pads do
		refresh(ui)
	end
end

local function track(part: BasePart)
	if pads[part] or not isMine(part) then
		return
	end
	if not StateController:Get() then
		StateController.Loaded:Once(function()
			track(part)
		end)
		return
	end
	local id = part:GetAttribute("PadId") :: string
	local ui = buildGui(part, id)
	pads[part] = ui
	part:GetAttributeChangedSignal("Done"):Connect(function()
		refresh(ui)
	end)
	refresh(ui)
end

local function byId(id: string): { PadUI }
	local out = {}
	for _, ui in pads do
		if ui.id == id then
			table.insert(out, ui)
		end
	end
	return out
end

-- 캐릭터에 가장 가까운 동일 ID 패드 (스탯 패드는 구역마다 있음)
local function nearestById(id: string): PadUI?
	local char = localPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local best, bestD = nil, math.huge
	for _, ui in byId(id) do
		local dist = root and (ui.part.Position - root.Position).Magnitude or 0
		if dist < bestD then
			bestD, best = dist, ui
		end
	end
	return best
end

-- 캐릭터 → 패드로 코인 조각이 흘러가는 연출
local function drainFX(ui: PadUI, delta: number)
	local char = localPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local n = math.clamp(math.ceil(delta / 5), 1, 3)
	for i = 1, n do
		task.delay((i - 1) * 0.03, function()
			local p = Instance.new("Part")
			p.Size = Vector3.new(0.4, 0.4, 0.4)
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.Material = Enum.Material.Neon
			p.Color = Color3.fromRGB(255, 210, 60)
			p.CFrame = root.CFrame * CFrame.new(math.random() - 0.5, -0.5, math.random() - 0.5)
			p.Parent = workspace
			local target = ui.part.Position + Vector3.new(0, 0.5, 0)
			TweenService:Create(p, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = CFrame.new(target),
				Size = Vector3.new(0.1, 0.1, 0.1),
			}):Play()
			task.delay(0.26, function()
				p:Destroy()
			end)
		end)
	end
	AudioController:Play("PadDrain", 1 + math.random() * 0.2, 0.3)
end

local function completeFX(ui: PadUI)
	local part = ui.part
	part.Material = Enum.Material.Neon
	part.Color = Color3.new(1, 1, 1)
	TweenService:Create(part, TweenInfo.new(0.35), { Color = ui.baseColor }):Play()
	task.delay(0.35, function()
		part.Material = Enum.Material.SmoothPlastic
	end)
	local scale = ui.icon:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = ui.icon
	end
	scale.Scale = 1.5
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	AudioController:Play("PadComplete", 1, 0.6)
	if ui.id == "Harvest" then
		RadiusVisual:Pulse()
	end
end

function PadVisual:Start()
	for _, inst in CollectionService:GetTagged("Pad") do
		if inst:IsA("BasePart") then
			track(inst)
		end
	end
	CollectionService:GetInstanceAddedSignal("Pad"):Connect(function(inst)
		if inst:IsA("BasePart") then
			track(inst)
		end
	end)
	localPlayer:GetAttributeChangedSignal("Plot"):Connect(function()
		for _, inst in CollectionService:GetTagged("Pad") do
			if inst:IsA("BasePart") then
				track(inst)
			end
		end
	end)
	StateController.Loaded:Connect(refreshAll)
	StateController.Changed:Connect(function(path: string)
		if
			path == "coins"
			or path == "level"
			or path:sub(1, 4) == "pads"
			or path:sub(1, 6) == "fields"
			or path:sub(1, 7) == "workers"
			or path:sub(1, 5) == "zones"
			or path:sub(1, 5) == "gates"
		then
			refreshAll()
		end
	end)
	Remotes.get("PadProgress").OnClientEvent:Connect(function(msg)
		for _, ui in byId(msg.padId) do
			refresh(ui, msg.paid, msg.cost)
		end
		local near = nearestById(msg.padId)
		if near and msg.delta > 0 then
			drainFX(near, msg.delta)
		end
	end)
	Remotes.get("PadComplete").OnClientEvent:Connect(function(msg)
		local near = nearestById(msg.padId)
		if near then
			completeFX(near)
		end
		for _, ui in byId(msg.padId) do
			refresh(ui)
		end
	end)
	RunService.Heartbeat:Connect(function()
		-- 게이지는 서버 진행 이벤트가 담당. 여기서는 빌보드 거리 페이드만.
	end)
end

return PadVisual
