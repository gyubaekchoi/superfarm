--!strict
-- 머리 위 작물 스택: 포물선 비행 → 안착 → 스프링 흔들림 → 판매대 흡입. 모든 플레이어 대상. DevSpec §5-5.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crops = require(Shared.Config.Crops)
local Remotes = require(Shared.Remotes)
local Spring = require(Shared.Util.Spring)
local Colors = require(Shared.Util.Colors)
local AudioController = require(script.Parent.AudioController)
local CropVisual = require(script.Parent.CropVisual)

local StackVisual = {}
StackVisual.Priority = 40

local ITEM_SIZE = Vector3.new(1.4, 0.45, 1.4)
local ITEM_H = 0.5
local HEAD_TOP = 0.7
local FLY_TIME = 0.25
local FLY_ARC = 3
local STAGGER = 0.03
local MAX_VISIBLE = 30
local TILT_GAIN = 0.012
local TILT_MAX = 0.55

type Fly = { part: BasePart, from: Vector3, t: number, delay: number }
type Stack = {
	userId: number,
	items: { BasePart },
	flying: { Fly },
	tilt: any,
	squash: any,
	full: boolean,
	count: number,
	cap: number,
	gui: BillboardGui,
	label: TextLabel,
	noEntry: Frame,
}

local stacks: { [number]: Stack } = {}
local localUserId = Players.LocalPlayer.UserId

local function makeItem(cropId: string): BasePart
	local def = Crops[cropId]
	local p = Instance.new("Part")
	p.Name = "StackItem"
	p.Size = ITEM_SIZE
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = def and Colors.rgb(def.color) or Color3.new(1, 1, 1)
	p.Parent = workspace
	return p
end

local function makeGui(): (BillboardGui, TextLabel, Frame)
	local gui = Instance.new("BillboardGui")
	gui.Name = "StackGui"
	gui.Size = UDim2.fromOffset(90, 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.5)
	label.Position = UDim2.fromScale(0, 0.5)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = ""
	label.Parent = gui

	-- 🚫 : 빨간 원 + 흰 사선 (텍스트 없음)
	local circle = Instance.new("Frame")
	circle.Name = "NoEntry"
	circle.Size = UDim2.fromOffset(28, 28)
	circle.AnchorPoint = Vector2.new(0.5, 0)
	circle.Position = UDim2.fromScale(0.5, 0)
	circle.BackgroundColor3 = Color3.fromRGB(230, 50, 50)
	circle.BorderSizePixel = 0
	circle.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = circle
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0.75, 0, 0, 5)
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromScale(0.5, 0.5)
	bar.Rotation = 45
	bar.BackgroundColor3 = Color3.new(1, 1, 1)
	bar.BorderSizePixel = 0
	bar.Parent = circle
	circle.Parent = gui
	return gui, label, circle
end

local function getStack(userId: number): Stack
	local s = stacks[userId]
	if s then
		return s
	end
	local gui, label, noEntry = makeGui()
	s = {
		userId = userId,
		items = {},
		flying = {},
		tilt = Spring.new(120, 10, Vector2.zero),
		squash = Spring.new(200, 12, 0),
		full = false,
		count = 0,
		cap = 0,
		gui = gui,
		label = label,
		noEntry = noEntry,
	}
	stacks[userId] = s
	return s
end

local function destroyStack(userId: number)
	local s = stacks[userId]
	if not s then
		return
	end
	for _, p in s.items do
		p:Destroy()
	end
	for _, f in s.flying do
		f.part:Destroy()
	end
	s.gui:Destroy()
	stacks[userId] = nil
end

local function headOf(userId: number): (BasePart?, BasePart?)
	local player = Players:GetPlayerByUserId(userId)
	local char = player and player.Character
	if not char then
		return nil, nil
	end
	return char:FindFirstChild("Head") :: BasePart?, char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function updateLabel(s: Stack)
	if s.cap > 0 then
		s.label.Text = ("%d/%d"):format(s.count, s.cap)
	else
		s.label.Text = tostring(s.count)
	end
	s.label.TextColor3 = if s.full then Color3.fromRGB(255, 120, 120) else Color3.new(1, 1, 1)
	s.noEntry.Visible = s.full
end

local function slotCFrame(base: CFrame, i: number, n: number, tilt: Vector2, squash: number): CFrame
	local frac = if n > 0 then i / n else 0
	local y = ITEM_H * (i - 0.5) - squash * math.min(i, 4) * 0.04
	return base * CFrame.Angles(tilt.X * frac, 0, tilt.Y * frac) * CFrame.new(0, y, 0)
end

local function cropPart(plot: number, zone: string, idx: number): BasePart?
	local plots = workspace:FindFirstChild("Plots")
	local pf = plots and plots:FindFirstChild("Plot" .. plot)
	local zf = pf and pf:FindFirstChild(zone)
	local cf = zf and zf:FindFirstChild("Crops")
	local part = cf and cf:FindFirstChild(("Crop_%s_%d"):format(zone, idx))
	return part :: BasePart?
end

local function standOf(plot: number, zone: string): BasePart?
	local plots = workspace:FindFirstChild("Plots")
	local pf = plots and plots:FindFirstChild("Plot" .. plot)
	local zf = pf and pf:FindFirstChild(zone or "Z1")
	return zf and zf:FindFirstChild("SellStand") :: BasePart? or nil
end

local function onHarvest(msg: any)
	local s = getStack(msg.userId)
	s.count = msg.stackCount
	s.cap = msg.cap or s.cap
	local isLocal = msg.userId == localUserId
	for i, item in msg.items do
		local src = cropPart(msg.plot, item.zone, item.idx)
		local from = src and src.Position
		if src and src:GetAttribute("Tree") then
			CropVisual:ShakeTree(src)
		end
		if #s.items + #s.flying < MAX_VISIBLE then
			local part = makeItem(item.crop)
			if from then
				part.Position = from
			end
			table.insert(s.flying, { part = part, from = from or Vector3.zero, t = 0, delay = STAGGER * (i - 1) })
		end
		if isLocal then
			task.delay(STAGGER * (i - 1), function()
				AudioController:PlayLadder("Harvest", 0.5)
			end)
		end
	end
	updateLabel(s)
end

local function onDeposit(msg: any)
	local s = stacks[msg.userId]
	if not s then
		return
	end
	s.count = msg.stackCount
	s.cap = msg.cap or s.cap
	local stand = standOf(msg.plot, msg.zone)
	for _ = 1, msg.count do
		local part = table.remove(s.items)
		if not part then
			break
		end
		if stand then
			local target = stand.Position + Vector3.new(0, stand.Size.Y / 2 + 0.5, 0)
			local from = part.CFrame
			local t0 = os.clock()
			local conn
			conn = RunService.Heartbeat:Connect(function()
				local a = math.min((os.clock() - t0) / 0.2, 1)
				part.CFrame = from:Lerp(CFrame.new(target), a)
				part.Size = ITEM_SIZE * (1 - a)
				if a >= 1 then
					conn:Disconnect()
					part:Destroy()
				end
			end)
		else
			part:Destroy()
		end
	end
	if msg.userId == localUserId then
		AudioController:Play("Deposit", 1, 0.4)
	end
	updateLabel(s)
end

local function onFull(msg: any)
	local s = getStack(msg.userId)
	s.full = msg.full
	if msg.full then
		s.tilt:impulse(Vector2.new(0, 1.2))
		if msg.userId == localUserId then
			AudioController:Play("StackFull", 1, 0.5)
		end
	end
	updateLabel(s)
end

local parts: { BasePart } = {}
local cframes: { CFrame } = {}

local function update(dt: number)
	table.clear(parts)
	table.clear(cframes)
	for userId, s in stacks do
		local head, root = headOf(userId)
		if not head or not root then
			-- 캐릭터 없음(리스폰 중): 숨김
			s.gui.Enabled = false
			continue
		end
		s.gui.Enabled = true
		if s.gui.Adornee ~= head then
			s.gui.Adornee = head
			s.gui.Parent = head
		end

		-- 이동 반대 방향으로 기울기
		local vLocal = head.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity)
		local target = Vector2.new(-vLocal.Z, vLocal.X) * TILT_GAIN
		if target.Magnitude > TILT_MAX then
			target = target.Unit * TILT_MAX
		end
		local tilt = s.tilt:update(dt, target)
		local squash = s.squash:update(dt, 0)

		local base = head.CFrame * CFrame.new(0, HEAD_TOP, 0)
		local n = #s.items
		for i, part in s.items do
			table.insert(parts, part)
			table.insert(cframes, slotCFrame(base, i, n, tilt, squash))
		end

		-- 비행 중 아이템
		for i = #s.flying, 1, -1 do
			local f = s.flying[i]
			if f.delay > 0 then
				f.delay -= dt
				continue
			end
			f.t += dt / FLY_TIME
			local slot = n + 1
			local to = slotCFrame(base, slot, slot, tilt, squash)
			if f.t >= 1 then
				table.remove(s.flying, i)
				table.insert(s.items, f.part)
				n += 1
				table.insert(parts, f.part)
				table.insert(cframes, to)
				s.squash:impulse(6)
			else
				local a = f.t
				local mid = (f.from + to.Position) / 2 + Vector3.new(0, FLY_ARC, 0)
				local p = f.from:Lerp(mid, a):Lerp(mid:Lerp(to.Position, a), a)
				table.insert(parts, f.part)
				table.insert(cframes, CFrame.new(p) * CFrame.Angles(0, a * math.pi * 4, 0) * (to - to.Position))
			end
		end

		s.gui.StudsOffset = Vector3.new(0, HEAD_TOP + ITEM_H * n + 1.2, 0)
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function StackVisual:Start()
	Remotes.get("HarvestBatch").OnClientEvent:Connect(onHarvest)
	Remotes.get("SellDeposit").OnClientEvent:Connect(onDeposit)
	Remotes.get("StackFull").OnClientEvent:Connect(onFull)
	Players.PlayerRemoving:Connect(function(p)
		destroyStack(p.UserId)
	end)
	-- 리스폰 시 서버 스택은 유지되지만 시각 스택은 Stack 어트리뷰트로 재동기화
	local function watch(player: Player)
		player:GetAttributeChangedSignal("Stack"):Connect(function()
			local s = stacks[player.UserId]
			local n = player:GetAttribute("Stack") :: number? or 0
			if s and n == 0 and #s.items > 0 and #s.flying == 0 then
				for _, part in s.items do
					part:Destroy()
				end
				table.clear(s.items)
				s.count = 0
				updateLabel(s)
			end
		end)
	end
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	RunService.Heartbeat:Connect(update)
end

return StackVisual
