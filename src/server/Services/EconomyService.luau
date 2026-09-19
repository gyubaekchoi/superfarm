--!strict
-- 코인·XP·💎 지급. 레벨업은 3단계에서 추가.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)
local Signal = require(Packages.Signal)
local DataService = require(script.Parent.DataService)

local EconomyService = {}
EconomyService.Priority = 70
EconomyService.LeveledUp = Signal.new() -- (player, newLevel, rewards)

-- XP 기준 레벨 재계산. 올랐으면 보상 지급 + LevelUp 전송
function EconomyService:CheckLevel(player: Player)
	local d = DataService:Get(player)
	if not d then
		return
	end
	local newLv = Economy.levelForXP(d.xp)
	if newLv <= d.level then
		return
	end
	local rewards = Economy.rewardsBetween(d.level, newLv)
	DataService:Patch(player, {
		{ path = "level", value = newLv },
		{ path = "tickets", value = d.tickets + rewards.tickets },
		{ path = "stones", value = d.stones + rewards.stones },
	})
	Remotes.get("LevelUp"):FireClient(player, { level = newLv, rewards = rewards })
	EconomyService.LeveledUp:Fire(player, newLv, rewards)
	print(("[Economy] %s → Lv%d (+🎫%d +💎%d)"):format(player.Name, newLv, rewards.tickets, rewards.stones))
end

function EconomyService:AddCoins(player: Player, amount: number)
	local d = DataService:Get(player)
	if not d or amount <= 0 then
		return
	end
	DataService:Patch(player, {
		{ path = "coins", value = d.coins + amount },
		{ path = "xp", value = d.xp + amount * Economy.XPPerCoin },
		{ path = "stats.totalCoins", value = d.stats.totalCoins + amount },
	})
	self:CheckLevel(player)
end

-- 코인 소비. 부족하면 false
function EconomyService:SpendCoins(player: Player, amount: number): boolean
	local d = DataService:Get(player)
	if not d or d.coins < amount then
		return false
	end
	DataService:Set(player, "coins", d.coins - amount)
	return true
end

function EconomyService:AddStones(player: Player, amount: number, worldPos: Vector3?)
	DataService:Add(player, "stones", amount)
	Remotes.get("StoneDrop"):FireClient(player, { pos = worldPos, amount = amount })
end

-- 코인 배율 (부스트/패스)
function EconomyService:CoinMult(player: Player): number
	local d = DataService:Get(player)
	if not d then
		return 1
	end
	if d.passes.CoinPass or d.boosts.coinX2Until > os.time() then
		return 2
	end
	return 1
end

return EconomyService
