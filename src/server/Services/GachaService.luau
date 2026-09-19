--!strict
-- 뽑기 요청 처리: 지불 → GachaLogic.roll → 데이터 패치 → GachaResult. 정책(유료 랜덤 아이템) 캐시. DevSpec §6-2.
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Gacha = require(Shared.Config.Gacha)
local GachaLogic = require(Shared.GachaLogic)
local Remotes = require(Shared.Remotes)
local Rng = require(Shared.Util.Rng)
local Signal = require(Packages.Signal)
local DataService = require(script.Parent.DataService)

local GachaService = {}
GachaService.Priority = 65
GachaService.Pulled = Signal.new() -- (player, result)

local rng = Rng.new()
local lastPull: { [Player]: number } = {}
local restricted: { [Player]: boolean } = {}

local function fetchPolicy(player: Player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	local flag = ok and info and info.ArePaidRandomItemsRestricted == true
	restricted[player] = flag
	player:SetAttribute("PaidRandomRestricted", flag)
end

function GachaService:IsPaidRandomRestricted(player: Player): boolean
	return restricted[player] == true
end

function GachaService:Pull(player: Player, currency: string): GachaLogic.Result?
	local d = DataService:Get(player)
	if not d then
		return nil
	end
	local now = os.clock()
	if now - (lastPull[player] or 0) < Gacha.PullCooldown then
		return nil
	end
	if not GachaLogic.pay(d, currency) then
		return nil
	end
	lastPull[player] = now
	local isFree = currency == "Ticket"
	local r = GachaLogic.roll(d, isFree, rng)

	-- roll 이 데이터를 직접 바꿨으므로 바뀐 필드를 클라에 통지
	local patches = {
		{ path = "tickets", value = d.tickets },
		{ path = "stones", value = d.stones },
		{ path = "gacha.freeCount", value = d.gacha.freeCount },
		{ path = "gacha.paidCount", value = d.gacha.paidCount },
		{ path = "gacha.pity", value = d.gacha.pity },
	}
	if r.equipped then
		table.insert(patches, { path = "gear." .. r.slot, value = { star = r.star } })
	end
	DataService:Patch(player, patches)

	Remotes.get("GachaResult"):FireClient(player, {
		slot = r.slot,
		star = r.star,
		equipped = r.equipped,
		stonesGained = r.stonesGained,
		isFirst = r.isFirst,
		isFree = r.isFree,
		n = r.n,
		previousStar = r.previousStar,
	})
	GachaService.Pulled:Fire(player, r)
	print(
		("[Gacha] %s #%d %s → %s ★%d %s"):format(
			player.Name,
			r.n,
			if isFree then "free" else "paid",
			r.slot,
			r.star,
			if r.equipped then "equip" else "+" .. r.stonesGained .. "💎"
		)
	)
	return r
end

function GachaService:Start()
	Remotes.onServer("RequestGacha", function(player, msg)
		local currency = type(msg) == "table" and msg.currency or msg
		if currency ~= "Ticket" and currency ~= "Stones" then
			return
		end
		self:Pull(player, currency)
	end)
	Players.PlayerAdded:Connect(function(p)
		task.spawn(fetchPolicy, p)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(fetchPolicy, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		lastPull[p] = nil
		restricted[p] = nil
	end)
end

return GachaService
