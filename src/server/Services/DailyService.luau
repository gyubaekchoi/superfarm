--!strict
-- 일일 상자: 접속 시 쿨다운이 지났으면 💎10 (+30% 🎫1) 자동 지급. DevSpec §8-3.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)
local Rng = require(Shared.Util.Rng)
local DataService = require(script.Parent.DataService)

local DailyService = {}
DailyService.Priority = 45

local rng = Rng.new()

function DailyService:TryClaim(player: Player): boolean
	local d = DataService:Get(player)
	if not d then
		return false
	end
	local now = os.time()
	if now - d.daily.lastChest < Economy.DailyChest.cooldownSec then
		return false
	end
	local stones = Economy.DailyChest.stones
	local tickets = if rng:chance(Economy.DailyChest.ticketChance) then 1 else 0
	DataService:Patch(player, {
		{ path = "daily.lastChest", value = now },
		{ path = "stones", value = d.stones + stones },
		{ path = "tickets", value = d.tickets + tickets },
	})
	Remotes.get("Reward"):FireClient(player, { kind = "Daily", stones = stones, tickets = tickets })
	return true
end

function DailyService:Start()
	DataService.Loaded:Connect(function(player)
		task.delay(4, function() -- 로딩 연출 뒤
			if player.Parent then
				self:TryClaim(player)
			end
		end)
	end)
	Remotes.onServer("ClaimDaily", function(player)
		self:TryClaim(player)
	end)
end

return DailyService
