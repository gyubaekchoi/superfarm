--!strict
-- 일꾼 로봇 위치 보간(서버 leg 정보), 운반 카운트, 입금 +💰 팝업. DevSpec §8-5.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Util.Format)
local Icon = require(script.Parent.UI.Icon)

local WorkerVisual = {}
WorkerVisual.Priority = 35

type Leg = {
	model: Model?,
	plot: number,
	zone: string,
	idx: number,
	state: string,
	from: Vector3,
	to: Vector3,
	t0: number,
	dur: number,
	carry: number,
	bob: number,
	gui: BillboardGui?,
	label: TextLabel?,
}
local legs: { [string]: Leg } = {}

local function key(msg: any): string
	return ("%d:%s:%d"):format(msg.plot, msg.zone, msg.idx)
end

local function findModel(msg: any): Model?
	local plots = workspace:FindFirstChild("Plots")
	local pf = plots and plots:FindFirstChild("Plot" .. msg.plot)
	local zf = pf and pf:FindFirstChild(msg.zone)
	local m = zf and zf:FindFirstChild(("Worker_%s_%d"):format(msg.zone, msg.idx))
	return m :: Model?
end

local function ensureGui(leg: Leg)
	if leg.gui or not leg.model then
		return
	end
	local head = leg.model:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(60, 24)
	gui.StudsOffset = Vector3.new(0, 1.2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local label = Icon.number(22, 60)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = gui
	gui.Adornee = head
	gui.Parent = head
	leg.gui = gui
	leg.label = label
end

local function depositPopup(leg: Leg, value: number)
	local model = leg.model
	local head = model and model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(90, 30)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = head
	gui.Parent = head
	local row = Icon.row("Pop", 26)
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.5)
	local ic = Icon.new("Coin", 24)
	ic.Parent = row
	local num = Icon.number(26, 60)
	num.Text = Format.short(value)
	num.TextColor3 = Color3.fromRGB(255, 230, 120)
	num.Parent = row
	row.Parent = gui
	TweenService:Create(
		gui,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffset = Vector3.new(0, 4, 0) }
	):Play()
	task.delay(0.9, function()
		gui:Destroy()
	end)
end

local function onState(msg: any)
	local k = key(msg)
	local leg = legs[k]
	if not leg then
		leg = {
			plot = msg.plot,
			zone = msg.zone,
			idx = msg.idx,
			state = "",
			from = msg.from,
			to = msg.to,
			t0 = msg.t0,
			dur = msg.dur,
			carry = 0,
			bob = 0,
			model = nil,
		}
		legs[k] = leg
	end
	leg.state = msg.state
	leg.from, leg.to, leg.t0, leg.dur = msg.from, msg.to, msg.t0, msg.dur
	leg.carry = msg.carry or 0
	if not leg.model or not leg.model.Parent then
		leg.model = findModel(msg)
		leg.gui = nil
	end
	ensureGui(leg)
	if leg.label then
		leg.label.Text = leg.carry > 0 and tostring(leg.carry) or ""
	end
	if msg.state == "Deposit" and msg.value then
		depositPopup(leg, msg.value)
	end
end

local function update(dt: number)
	local now = workspace:GetServerTimeNow()
	for k, leg in legs do
		local model = leg.model
		if not model or not model.Parent then
			if model then
				legs[k] = nil
			end
			continue
		end
		local a = math.clamp((now - leg.t0) / leg.dur, 0, 1)
		local pos = leg.from:Lerp(leg.to, a)
		local moving = a < 1 and (leg.state == "GoField" or leg.state == "GoSell")
		leg.bob = if moving then leg.bob + dt * 14 else 0
		local bobY = if moving then math.abs(math.sin(leg.bob)) * 0.25 else 0
		local dir = leg.to - leg.from
		local look = if dir.Magnitude > 0.05 then CFrame.lookAt(pos, pos + dir) else model:GetPivot().Rotation + pos
		if leg.state == "Harvest" then
			look = look * CFrame.Angles(0, math.sin(now * 8) * 0.15, 0)
		end
		local lift = if model:GetAttribute("PivotBottom") then 0 else 1.6
		model:PivotTo(CFrame.new(pos + Vector3.new(0, lift + bobY, 0)) * look.Rotation)
	end
end

function WorkerVisual:Start()
	Remotes.get("WorkerState").OnClientEvent:Connect(onState)
	RunService.Heartbeat:Connect(update)
end

return WorkerVisual
