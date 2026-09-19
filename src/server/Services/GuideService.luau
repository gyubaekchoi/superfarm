--!strict
-- 다음 목표 산출(1Hz) → GuideTarget. 튜토리얼 단계 카운트. DevSpec §10.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PadLogic = require(Shared.PadLogic)
local Remotes = require(Shared.Remotes)
local PlotService = require(script.Parent.PlotService)
local PadService = require(script.Parent.PadService)
local PlazaService = require(script.Parent.PlazaService)
local EnhanceLogic = require(Shared.EnhanceLogic)
local HarvestService = require(script.Parent.HarvestService)
local SellService = require(script.Parent.SellService)
local EconomyService = require(script.Parent.EconomyService)
local DataService = require(script.Parent.DataService)

type PlotRuntime = PlotService.PlotRuntime

local GuideService = {}
GuideService.Priority = 50
GuideService.CheapPadRatio = 0.2

local INTERVAL = 1
local lastSent: { [Player]: string } = {}

-- 튜토리얼 단계: 1 첫 수확, 2 첫 판매, 3 첫 패드 완료, 4 첫 레벨업
local function advance(player: Player, step: number)
	local d = DataService:Get(player)
	if d and d.tutorial < step then
		DataService:Set(player, "tutorial", step)
	end
end

local function nearestReadyField(rt: PlotRuntime, pos: Vector3): (Instance?, Vector3?)
	local now = workspace:GetServerTimeNow()
	local best: Instance? = nil
	local bestD = math.huge
	for _, list in rt.crops do
		for _, crop in list do
			if crop.readyAt <= now then
				local dist = (crop.pos - pos).Magnitude
				if dist < bestD then
					bestD = dist
					best = crop.part
				end
			end
		end
	end
	return best, nil
end

local function computeTarget(rt: PlotRuntime, owner: Player): { kind: string, target: Instance?, icon: string }?
	local d = DataService:Get(owner)
	local char = owner.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not d or not root then
		return nil
	end
	-- 1. 만땅 → 가장 가까운 열린 판매대
	if rt.full or #rt.stack > 0 and d.tutorial < 2 then
		local best, bestD = nil, math.huge
		for zone, stand in rt.sellStands do
			if d.zones[zone] then
				local dist = (stand.Position - root.Position).Magnitude
				if dist < bestD then
					bestD, best = dist, stand
				end
			end
		end
		if best then
			return {
				kind = "Sell",
				target = best,
				icon = if best:GetAttribute("Zone") == "Z2" then "Truck" else "Stall",
			}
		end
	end
	-- 2. 티켓 보유 → 광장 🎁
	if d.tickets > 0 and PlazaService.GachaBox then
		return { kind = "Gacha", target = PlazaService.GachaBox, icon = "Ticket" }
	end
	-- 3. 폭발 강화 가능 → 광장 ⚒️
	if EnhanceLogic.canBurst(d) and PlazaService.EnhanceStation then
		return { kind = "Enhance", target = PlazaService.EnhanceStation, icon = "Stone" }
	end
	-- 4. 게이트 목표: 레벨 조건을 만족한 다음 게이트가 있으면 잔액이 부족해도 목표로 제시한다 (저축 유도)
	--    단, 아주 싼 패드(게이트 잔액의 20% 이하)는 계속 안내한다.
	local gatePad, gateRemaining = nil, math.huge
	local bestPad, bestRemaining = nil, math.huge
	for _, pad in PadService:GetPads(rt) do
		if not PadLogic.zoneOpen(d, pad.id, pad.zone) then
			continue
		end
		local info = PadLogic.info(d, pad.id)
		if not PadLogic.canPay(info) then
			continue
		end
		local remaining = PadLogic.remaining(info)
		if pad.kind == "Gate" then
			if remaining < gateRemaining then
				gateRemaining, gatePad = remaining, pad
			end
		elseif d.coins >= remaining and remaining < bestRemaining then
			bestRemaining = remaining
			bestPad = pad
		end
	end
	if gatePad then
		if d.coins >= gateRemaining then
			return { kind = "Gate", target = gatePad.part, icon = "Unlock" }
		end
		if bestPad and bestRemaining <= gateRemaining * GuideService.CheapPadRatio then
			return { kind = "Pad", target = bestPad.part, icon = PadLogic.info(d, bestPad.id).icon }
		end
		-- 저축 중: 밭으로 유도하되 마커는 게이트에 (다음 단계에서 화살표만 밭, 마커는 게이트로 분리)
		local crop = nearestReadyField(rt, root.Position)
		if crop then
			return { kind = "Harvest", target = crop, icon = "Sickle", goal = gatePad.part }
		end
		return { kind = "Gate", target = gatePad.part, icon = "Lock" }
	end
	if bestPad then
		return { kind = "Pad", target = bestPad.part, icon = PadLogic.info(d, bestPad.id).icon }
	end
	-- 6. 가장 가까운 수확 가능 작물
	local crop = nearestReadyField(rt, root.Position)
	if crop then
		return { kind = "Harvest", target = crop, icon = "Sickle" }
	end
	return nil
end

local function tick()
	for owner, rt in PlotService:Owned() do
		local t = computeTarget(rt, owner)
		local key = t and (t.kind .. ":" .. tostring(t.target and t.target:GetFullName())) or "none"
		-- Harvest 목표는 작물이 계속 바뀌므로 매초 갱신, 그 외는 변경 시에만
		if key ~= lastSent[owner] or (t and t.kind == "Harvest") then
			lastSent[owner] = key
			Remotes.get("GuideTarget"):FireClient(owner, t or { kind = "None" })
		end
	end
end

function GuideService:Start()
	HarvestService.Harvested:Connect(function(player)
		advance(player, 1)
	end)
	SellService.Sold:Connect(function(player)
		advance(player, 2)
	end)
	PadService.Completed:Connect(function(player)
		advance(player, 3)
	end)
	EconomyService.LeveledUp:Connect(function(player)
		advance(player, 4)
	end)
	PlotService.Released:Connect(function(player)
		lastSent[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(INTERVAL)
			tick()
		end
	end)
end

return GuideService
