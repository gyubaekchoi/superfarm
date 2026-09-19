--!strict
-- 패드 말풍선(아이콘 + 이름 + 비용 + 게이지), 드레인 코인 스트림, 완료 연출. 로컬 플레이어 플롯만. DevSpec §8-4.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PadLogic = require(Shared.PadLogic)
local Zones = require(Shared.Config.Zones)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Util.Format)
local L = require(Shared.Util.L)
local StateController = require(script.Parent.StateController)
local AudioController = require(script.Parent.AudioController)
local RadiusVisual = require(script.Parent.RadiusVisual)
local Bubble = require(script.Parent.UI.Bubble)

local PadVisual = {}
PadVisual.Priority = 35

type PadUI = { part: BasePart, id: string, zone: string, bubble: Bubble.Bubble, baseColor: Color3 }
local pads: { [BasePart]: PadUI } = {}
local localPlayer = Players.LocalPlayer

local COST_OK = Color3.fromRGB(190, 120, 30)
local COST_LOW = Color3.fromRGB(150, 145, 155)
local BUBBLE_ON = Color3.fromRGB(255, 252, 245)
local BUBBLE_OFF = Color3.fromRGB(226, 222, 230)

local function isMine(part: BasePart): boolean
	return part:GetAttribute("Plot") == localPlayer:GetAttribute("Plot")
end

-- 패드 제목: 아이콘 옆에 함께 표기해 무엇을 사는 패드인지 바로 알게 한다.
local function titleOf(info: PadLogic.PadInfo): string
	if info.kind == "Stat" then
		return L("pad." .. info.key)
	elseif info.kind == "Expand" then
		return L("pad.Expand")
	elseif info.kind == "Crop2" then
		local crops = Zones.Defs[info.key].crops
		local second = crops and crops[2]
		return L("pad.Crop2", second and L("crop." .. second) or "")
	elseif info.kind == "Worker" then
		return L("pad.Worker")
	end
	return L("pad.Gate", L("zone." .. info.key))
end

local function badgeOf(info: PadLogic.PadInfo): (string?, Color3?)
	if info.maxed then
		return L("pad.Max"), Color3.fromRGB(110, 190, 110)
	end
	if info.kind == "Stat" or info.kind == "Expand" then
		if info.level > 0 then
			return L("pad.Level", info.level), nil
		end
	elseif info.kind == "Worker" and info.level > 0 then
		return L("pad.Level", info.level), nil
	end
	return nil, nil
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
		ui.bubble:setEnabled(false)
		ui.part.Transparency = if done then 1 else 0
		return
	end
	ui.part.Transparency = 0
	ui.bubble:setEnabled(true)
	ui.bubble:setHeader(info.icon, titleOf(info))
	local badgeText, badgeColor = badgeOf(info)
	ui.bubble:setBadge(badgeText, badgeColor)

	local costRow, costText = ui.bubble:row("Cost", 1, "Coin")
	local reqRow, reqText = ui.bubble:row("Req", 2, "Lock")
	local fill = ui.bubble:gauge(3)

	if info.maxed then
		costRow.Visible = false
		reqRow.Visible = false
		fill.Parent.Visible = false
		ui.bubble:setColor(BUBBLE_ON)
		ui.part.Color = ui.baseColor:Lerp(Color3.new(1, 1, 1), 0.5)
		return
	end

	local payable = PadLogic.canPay(info)
	local p = paid or info.paid
	local c = cost or info.cost or 1
	local remaining = math.max(0, c - p)

	costRow.Visible = true
	costText.Text = Format.short(remaining)
	local affordable = payable and d.coins >= remaining
	costText.TextColor3 = if affordable then COST_OK else COST_LOW

	if info.teaser then
		reqRow.Visible = true
		ui.bubble:setHeader("Construction", titleOf(info))
		reqText.Text = L("req.Soon")
	elseif not info.levelOk then
		reqRow.Visible = true
		reqText.Text = L("req.Level", info.minLevel)
	else
		reqRow.Visible = false
	end

	fill.Parent.Visible = p > 0
	fill.Size = UDim2.fromScale(math.clamp(p / c, 0, 1), 1)
	ui.bubble:setColor(if payable then BUBBLE_ON else BUBBLE_OFF)
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
	local bubble = Bubble.new(part, 3.4)
	bubble.gui.Parent = part
	local ui: PadUI = {
		part = part,
		id = id,
		zone = part:GetAttribute("Zone") :: string,
		bubble = bubble,
		baseColor = part.Color,
	}
	pads[part] = ui
	part:GetAttributeChangedSignal("Done"):Connect(function()
		refresh(ui)
	end)
	part.Destroying:Connect(function()
		pads[part] = nil
	end)
	refresh(ui)
	bubble:pop()
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
	ui.bubble:pop()
	AudioController:Play("PadComplete", 1, 0.6)
	if ui.id == "Harvest" then
		RadiusVisual:Pulse()
	end
end

local function trackTagged()
	for _, inst in CollectionService:GetTagged("Pad") do
		if inst:IsA("BasePart") then
			track(inst)
		end
	end
end

function PadVisual:Start()
	trackTagged()
	CollectionService:GetInstanceAddedSignal("Pad"):Connect(function(inst)
		if inst:IsA("BasePart") then
			track(inst)
		end
	end)
	localPlayer:GetAttributeChangedSignal("Plot"):Connect(trackTagged)
	StateController.Loaded:Connect(function()
		trackTagged()
		refreshAll()
	end)
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
		-- 게이지·색은 서버 이벤트가 갱신한다. 여기서는 새로 생긴 패드만 주워담는다.
	end)
end

return PadVisual
