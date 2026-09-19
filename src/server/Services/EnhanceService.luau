--!strict
-- 폭발 강화 요청 처리. DevSpec §7-4.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Enhance = require(Shared.Config.Enhance)
local EnhanceLogic = require(Shared.EnhanceLogic)
local Stats = require(Shared.Stats)
local Remotes = require(Shared.Remotes)
local Rng = require(Shared.Util.Rng)
local Signal = require(Packages.Signal)
local DataService = require(script.Parent.DataService)

local EnhanceService = {}
EnhanceService.Priority = 65
EnhanceService.Bursted = Signal.new() -- (player, result)

local rng = Rng.new()
local lastBurst: { [Player]: number } = {}

function EnhanceService:Burst(player: Player): EnhanceLogic.Result?
	local d = DataService:Get(player)
	if not d then
		return nil
	end
	local now = os.clock()
	if now - (lastBurst[player] or 0) < Enhance.BurstCooldown then
		return nil
	end
	local powerFrom = Stats.fromData(d).power
	local r = EnhanceLogic.burst(d, rng)
	if not r then
		return nil
	end
	lastBurst[player] = now
	local powerTo = Stats.fromData(d).power
	DataService:Patch(player, {
		{ path = "stones", value = d.stones },
		{ path = "enhance", value = d.enhance },
		{ path = "stats.enhanceBursts", value = d.stats.enhanceBursts },
	})
	local crits = 0
	for _, s in r.steps do
		if s.crit then
			crits += 1
		end
	end
	Remotes.get("EnhanceResult"):FireClient(player, {
		from = r.from,
		to = r.to,
		steps = r.steps,
		stonesSpent = r.stonesSpent,
		powerFrom = powerFrom,
		powerTo = powerTo,
	})
	EnhanceService.Bursted:Fire(player, r)
	print(
		("[Enhance] %s +%d → +%d (%d steps, %d crit, -%d💎) ⚡%d→%d"):format(
			player.Name,
			r.from,
			r.to,
			#r.steps,
			crits,
			r.stonesSpent,
			powerFrom,
			powerTo
		)
	)
	return r
end

function EnhanceService:Start()
	Remotes.onServer("RequestEnhance", function(player)
		self:Burst(player)
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastBurst[p] = nil
	end)
end

return EnhanceService
