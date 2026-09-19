--!strict
-- 허브 오브젝트(🎁 뽑기 · ⚒️ 강화 · 🛒 상점)와 판매대 위 말풍선. 아이콘 + 이름 + 한 줄 안내로 어포던스를 준다.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnhanceLogic = require(Shared.EnhanceLogic)
local Gacha = require(Shared.Config.Gacha)
local L = require(Shared.Util.L)
local StateController = require(script.Parent.StateController)
local Bubble = require(script.Parent.UI.Bubble)

local InteractVisual = {}
InteractVisual.Priority = 34

type Entry = { part: BasePart, kind: string, bubble: Bubble.Bubble, alert: boolean }
local entries: { [BasePart]: Entry } = {}
local localPlayer = Players.LocalPlayer

local HUB_ICON = { Gacha = "Gift", Enhance = "Anvil", Shop = "Shop" }
local HUB_HINT = { Gacha = "hint.Gacha", Enhance = "hint.Enhance", Shop = "hint.Shop" }
local ALERT_COLOR = Color3.fromRGB(255, 244, 205)
local IDLE_COLOR = Color3.fromRGB(255, 252, 245)

local function myPlot(): number?
	return localPlayer:GetAttribute("Plot") :: number?
end

-- 이 파트가 내 플롯 안에 있는지 (조상 Plot 폴더의 Index 로 판단)
local function isMine(part: BasePart): boolean
	local plot = myPlot()
	if not plot then
		return false
	end
	local node: Instance? = part
	while node do
		if node:GetAttribute("Index") == plot then
			return true
		end
		node = node.Parent
	end
	return false
end

local function kindOf(part: BasePart): string?
	local hub = part:GetAttribute("Kind") :: string?
	if hub then
		return hub
	end
	if part.Name == "SellStand" then
		return "Sell"
	end
	return nil
end

local function refresh(e: Entry)
	local d = StateController:Get()
	if not d then
		return
	end
	local alert = false
	if e.kind == "Sell" then
		local zone = e.part:GetAttribute("Zone") :: string?
		e.bubble:setHeader(if zone == "Z2" then "Truck" else "Stall", L("hub.Sell"))
		local _, hint = e.bubble:row("Hint", 1)
		hint.Text = L("hint.Stand")
		alert = (localPlayer:GetAttribute("Stack") :: number? or 0) > 0
	else
		e.bubble:setHeader(HUB_ICON[e.kind] or "Star", L("hub." .. e.kind))
		local _, hint = e.bubble:row("Hint", 1)
		hint.Text = L(HUB_HINT[e.kind] or "hint.Shop")
		if e.kind == "Gacha" then
			alert = d.tickets > 0 or d.stones >= Gacha.StoneCost
			local row, value = e.bubble:row("Count", 2, "Ticket")
			row.Visible = d.tickets > 0
			value.Text = tostring(d.tickets)
		elseif e.kind == "Enhance" then
			alert = EnhanceLogic.canBurst(d)
			local row, value = e.bubble:row("Count", 2, "Stone")
			row.Visible = alert
			value.Text = tostring(d.stones)
		end
	end
	e.bubble:setColor(if alert then ALERT_COLOR else IDLE_COLOR)
	if alert and not e.alert then
		e.bubble:pop()
	end
	e.alert = alert
end

local function track(part: BasePart)
	if entries[part] or not isMine(part) then
		return
	end
	local kind = kindOf(part)
	if not kind then
		return
	end
	if not StateController:Get() then
		StateController.Loaded:Once(function()
			track(part)
		end)
		return
	end
	local height = part.Size.Y + 2.2
	local bubble = Bubble.new(part, height)
	bubble.gui.Parent = part
	local e: Entry = { part = part, kind = kind, bubble = bubble, alert = false }
	entries[part] = e
	part.Destroying:Connect(function()
		entries[part] = nil
	end)
	refresh(e)
	bubble:pop()
end

local function trackAll()
	for _, tag in { "HubObject", "Interact" } do
		for _, inst in CollectionService:GetTagged(tag) do
			if inst:IsA("BasePart") then
				track(inst)
			end
		end
	end
end

local function refreshAll()
	for _, e in entries do
		refresh(e)
	end
end

function InteractVisual:Start()
	trackAll()
	for _, tag in { "HubObject", "Interact" } do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
			if inst:IsA("BasePart") then
				track(inst)
			end
		end)
	end
	localPlayer:GetAttributeChangedSignal("Plot"):Connect(trackAll)
	localPlayer:GetAttributeChangedSignal("Stack"):Connect(refreshAll)
	StateController.Loaded:Connect(function()
		trackAll()
		refreshAll()
	end)
	StateController.Changed:Connect(function(path: string)
		if path == "tickets" or path == "stones" or path == "enhance" or path == "level" then
			refreshAll()
		end
	end)
	-- 새 구역이 해금되면 판매대가 늦게 생기므로 주기적으로 주워담는다
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 then
			acc = 0
			trackAll()
		end
	end)
end

return InteractVisual
