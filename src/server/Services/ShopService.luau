--!strict
-- 게임패스·개발자 상품: 소유 동기화, 구매 프롬프트(서버), 영수증 처리(중복 방지), 정책 분기. DevSpec §9.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Products = require(Shared.Config.Products)
local Remotes = require(Shared.Remotes)
local Signal = require(Packages.Signal)
local DataService = require(script.Parent.DataService)
local GachaService = require(script.Parent.GachaService)
local PlotService = require(script.Parent.PlotService)

local ShopService = {}
ShopService.Priority = 60
ShopService.Purchased = Signal.new() -- (player, key, robux)

local passByAssetId: { [number]: string } = {}
local productById: { [number]: string } = {}

local function syncPasses(player: Player)
	local d = DataService:WaitFor(player, 15)
	if not d then
		return
	end
	local patches = {}
	for key, def in Products.Passes do
		if def.id ~= 0 and not d.passes[key] then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, def.id)
			if ok and owns then
				table.insert(patches, { path = "passes." .. key, value = true })
			end
		end
	end
	if #patches > 0 then
		DataService:Patch(player, patches)
	end
end

-- 상품 효과 적용 (영수증·디버그 공용)
function ShopService:Grant(player: Player, key: string): boolean
	local def = Products.Products[key]
	local d = DataService:Get(player)
	if not def or not d then
		return false
	end
	local g = def.grant
	local patches = {}
	local reward: { [string]: any } = { kind = "Product", key = key }
	if g.stones then
		table.insert(patches, { path = "stones", value = d.stones + g.stones })
		reward.stones = g.stones
	end
	if g.tickets then
		table.insert(patches, { path = "tickets", value = d.tickets + g.tickets })
		reward.tickets = g.tickets
	end
	if g.coinX2Sec then
		local base = math.max(d.boosts.coinX2Until, os.time())
		table.insert(patches, { path = "boosts.coinX2Until", value = base + g.coinX2Sec })
		reward.boostSec = g.coinX2Sec
	end
	if g.growAll then
		local rt = PlotService:GetByPlayer(player)
		if rt then
			local now = workspace:GetServerTimeNow()
			for _, list in rt.crops do
				for _, crop in list do
					crop.readyAt = now
					crop.part:SetAttribute("ReadyAt", now)
				end
			end
		end
		reward.growAll = true
	end
	if #patches > 0 then
		DataService:Patch(player, patches)
	end
	Remotes.get("Reward"):FireClient(player, reward)
	return true
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local d = DataService:WaitFor(player, 10)
	if not d then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local pid = tostring(receipt.PurchaseId)
	if table.find(d.purchases, pid) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key = productById[receipt.ProductId]
	if not key then
		warn("[Shop] unknown product id " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not ShopService:Grant(player, key) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(d.purchases, pid)
	while #d.purchases > Products.MaxPurchaseHistory do
		table.remove(d.purchases, 1)
	end
	DataService:Set(player, "purchases", d.purchases)
	ShopService.Purchased:Fire(player, key, receipt.CurrencySpent)
	print(("[Shop] %s bought %s (%d R$)"):format(player.Name, key, receipt.CurrencySpent or 0))
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService:Prompt(player: Player, key: string)
	local pass = Products.Passes[key]
	if pass then
		if pass.id == 0 then
			return
		end
		local d = DataService:Get(player)
		if d and d.passes[key] then
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
		return
	end
	local prod = Products.Products[key]
	if prod then
		if prod.id == 0 then
			return
		end
		if prod.randomItem and GachaService:IsPaidRandomRestricted(player) then
			return
		end
		MarketplaceService:PromptProductPurchase(player, prod.id)
	end
end

function ShopService:Init()
	for key, def in Products.Passes do
		if def.id ~= 0 then
			passByAssetId[def.id] = key
		end
	end
	for key, def in Products.Products do
		if def.id ~= 0 then
			productById[def.id] = key
		end
	end
end

function ShopService:Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passByAssetId[passId]
		if purchased and key then
			DataService:Set(player, "passes." .. key, true)
			ShopService.Purchased:Fire(player, key, Products.Passes[key].price)
			print(("[Shop] %s bought pass %s"):format(player.Name, key))
		end
	end)
	Remotes.onServer("RequestPurchase", function(player, msg)
		local key = type(msg) == "table" and msg.productKey or msg
		if type(key) == "string" then
			self:Prompt(player, key)
		end
	end)
	DataService.Loaded:Connect(function(player)
		task.spawn(syncPasses, player)
	end)
end

return ShopService
