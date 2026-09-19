--!strict
-- 바닥 코인: 포물선 스폰 → 회전 → 자석 흡수. DevSpec §5-7.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)
local CoinSplit = require(Shared.Util.CoinSplit)
local AudioController = require(script.Parent.AudioController)

local CoinVisual = {}
CoinVisual.Priority = 40

type Coin = { part: BasePart, from: Vector3, to: Vector3, t: number, landed: boolean, spin: number }
local coins: { [number]: { [number]: Coin } } = {} -- plot → id → coin
local collecting: { { part: BasePart, target: BasePart, t: number } } = {}

local SPAWN_TIME = 0.5
local SPAWN_ARC = 4
local COLLECT_TIME = 0.2
local GOLD = Color3.fromRGB(255, 200, 40)
local PURPLE = Color3.fromRGB(190, 90, 255)

local function makeCoin(value: number): BasePart
	local tier = CoinSplit.tier(value, Economy.CoinDenoms)
	local n = #Economy.CoinDenoms
	local size = 0.8 + 0.28 * (tier - 1)
	local p = Instance.new("Part")
	p.Name = "Coin"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.18, size, size)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Metal
	p.Color = GOLD:Lerp(PURPLE, (tier - 1) / (n - 1))
	p.Parent = workspace
	return p
end

local function plotOwnerRoot(plot: number): BasePart?
	local plots = workspace:FindFirstChild("Plots")
	local pf = plots and plots:FindFirstChild("Plot" .. plot)
	local uid = pf and pf:GetAttribute("OwnerUserId") :: number?
	local player = uid and Players:GetPlayerByUserId(uid)
	local char = player and player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart? or nil
end

local function onSpawn(msg: any)
	local bucket = coins[msg.plot]
	if not bucket then
		bucket = {}
		coins[msg.plot] = bucket
	end
	for _, id in msg.remove or {} do
		local c = bucket[id]
		if c then
			c.part:Destroy()
			bucket[id] = nil
		end
	end
	for _, c in msg.coins do
		local part = makeCoin(c.value)
		part.Position = msg.origin
		bucket[c.id] =
			{ part = part, from = msg.origin, to = c.pos, t = 0, landed = false, spin = math.random() * math.pi * 2 }
	end
end

local function onCollect(msg: any)
	local bucket = coins[msg.plot]
	if not bucket then
		return
	end
	local target = plotOwnerRoot(msg.plot)
	local isLocal = target ~= nil and target.Parent == Players.LocalPlayer.Character
	for i, id in msg.ids do
		local c = bucket[id]
		if c then
			bucket[id] = nil
			if target then
				table.insert(collecting, { part = c.part, target = target, t = 0 })
			else
				c.part:Destroy()
			end
			if isLocal then
				task.delay(0.03 * (i - 1), function()
					AudioController:PlayLadder("Coin", 0.5)
				end)
			end
		end
	end
end

local function update(dt: number)
	local t = os.clock()
	for _, bucket in coins do
		for _, c in bucket do
			c.spin += dt * 3
			if c.landed then
				c.part.CFrame = CFrame.new(c.to) * CFrame.Angles(0, c.spin, math.pi / 2)
			else
				c.t = math.min(c.t + dt / SPAWN_TIME, 1)
				local a = c.t
				local mid = (c.from + c.to) / 2 + Vector3.new(0, SPAWN_ARC, 0)
				local p = c.from:Lerp(mid, a):Lerp(mid:Lerp(c.to, a), a)
				c.part.CFrame = CFrame.new(p) * CFrame.Angles(0, c.spin, math.pi / 2 + (1 - a) * math.pi * 2)
				if a >= 1 then
					c.landed = true
				end
			end
		end
	end
	for i = #collecting, 1, -1 do
		local k = collecting[i]
		k.t += dt / COLLECT_TIME
		local a = math.min(k.t, 1)
		local target = k.target.Position
		k.part.CFrame = CFrame.new(k.part.Position:Lerp(target, a)) * CFrame.Angles(0, t * 6, math.pi / 2)
		k.part.Size = k.part.Size * (1 - a * 0.5)
		if a >= 1 then
			k.part:Destroy()
			table.remove(collecting, i)
		end
	end
end

function CoinVisual:Start()
	Remotes.get("CoinSpawn").OnClientEvent:Connect(onSpawn)
	Remotes.get("CoinCollect").OnClientEvent:Connect(onCollect)
	RunService.Heartbeat:Connect(update)
end

return CoinVisual
