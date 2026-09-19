--!strict
-- 퍼널 이벤트 기록. Roblox AnalyticsService:LogCustomEvent 래퍼 (Studio 에서는 출력만). DevSpec §15.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RobloxAnalytics = game:GetService("AnalyticsService")

local AnalyticsService = {}
AnalyticsService.Priority = 95

local joinedAt: { [Player]: number } = {}

function AnalyticsService:Log(player: Player, name: string, value: number?, fields: { [string]: any }?)
	local v = value or 1
	if RunService:IsStudio() then
		local parts = {}
		for k, f in fields or {} do
			table.insert(parts, k .. "=" .. tostring(f))
		end
		print(("[Analytics] %s %s=%s %s"):format(player.Name, name, tostring(v), table.concat(parts, " ")))
	end
	pcall(function()
		-- customFields 는 최대 3개, 값은 문자열
		local cf = {}
		local n = 0
		for k, f in fields or {} do
			n += 1
			if n > 3 then
				break
			end
			cf[k] = tostring(f)
		end
		RobloxAnalytics:LogCustomEvent(player, name, v, cf)
	end)
end

function AnalyticsService:SecSinceJoin(player: Player): number
	local t0 = joinedAt[player]
	return if t0 then math.floor(os.clock() - t0) else -1
end

function AnalyticsService:Init()
	Players.PlayerAdded:Connect(function(p)
		joinedAt[p] = os.clock()
	end)
	for _, p in Players:GetPlayers() do
		joinedAt[p] = os.clock()
	end
	Players.PlayerRemoving:Connect(function(p)
		joinedAt[p] = nil
	end)
end

-- 서비스 시그널 연결은 Start 에서 (모든 서비스 Init 이후)
function AnalyticsService:Start()
	local S = script.Parent
	local DataService = require(S.DataService)
	local HarvestService = require(S.HarvestService)
	local SellService = require(S.SellService)
	local EconomyService = require(S.EconomyService)
	local PadService = require(S.PadService)
	local GachaService = require(S.GachaService)
	local EnhanceService = require(S.EnhanceService)

	local firstHarvest: { [Player]: boolean } = {}
	local firstSell: { [Player]: boolean } = {}

	DataService.Loaded:Connect(function(player, d)
		self:Log(player, "Session_Start", 1, { isNew = d.stats.playtimeSec == 0, level = d.level })
	end)
	DataService.Released:Connect(function(player)
		local d = DataService:Get(player)
		if d then
			self:Log(player, "Session_End", self:SecSinceJoin(player), { level = d.level, coins = d.coins })
		end
		firstHarvest[player] = nil
		firstSell[player] = nil
	end)
	HarvestService.Harvested:Connect(function(player)
		if not firstHarvest[player] then
			firstHarvest[player] = true
			self:Log(player, "First_Harvest", self:SecSinceJoin(player))
		end
	end)
	SellService.Sold:Connect(function(player)
		if not firstSell[player] then
			firstSell[player] = true
			self:Log(player, "First_Sell", self:SecSinceJoin(player))
		end
	end)
	EconomyService.LeveledUp:Connect(function(player, level)
		self:Log(player, "Level_Up", level, { sec = self:SecSinceJoin(player) })
	end)
	PadService.Completed:Connect(function(player, padId, level)
		if padId:sub(1, 5) == "Gate:" then
			self:Log(player, "Zone_Unlock", self:SecSinceJoin(player), { zone = padId:sub(6) })
		else
			self:Log(player, "Pad_Complete", level, { pad = padId })
		end
	end)
	GachaService.Pulled:Connect(function(player, r)
		self:Log(player, "Gacha", r.star, { n = r.n, free = r.isFree, slot = r.slot })
	end)
	EnhanceService.Bursted:Connect(function(player, r)
		self:Log(player, "Enhance", r.to - r.from, { from = r.from, to = r.to, steps = #r.steps })
	end)
end

return AnalyticsService
