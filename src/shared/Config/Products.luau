--!strict
-- 상점. id는 Roblox 대시보드 등록 후 채움. DevSpec §9.
local Products = {
	Passes = {
		SpeedPass = { id = 0, effect = "speed", mult = 1.5, icon = "ShoeGold", price = 149 },
		HarvestPass = { id = 0, effect = "harvest", mult = 2, icon = "SickleGold", price = 199 },
		BagPass = { id = 0, effect = "cap", mult = 2, icon = "BagGold", price = 149 },
		CoinPass = { id = 0, effect = "coin", mult = 2, icon = "CoinGold", price = 299 },
		WorkerPass = { id = 0, effect = "worker", mult = 2, icon = "RobotGold", price = 249 },
	},
	Products = {
		Stones50 = { id = 0, grant = { stones = 50 }, price = 49, icon = "Stone", amount = 50, order = 1 },
		Stones300 = { id = 0, grant = { stones = 300 }, price = 199, icon = "Stone", amount = 300, order = 2 },
		Ticket1 = {
			id = 0,
			grant = { tickets = 1 },
			price = 39,
			randomItem = true,
			icon = "Ticket",
			amount = 1,
			order = 3,
		},
		Ticket10 = {
			id = 0,
			grant = { tickets = 10 },
			price = 299,
			randomItem = true,
			icon = "Ticket",
			amount = 10,
			order = 4,
		},
		BoostX2 = { id = 0, grant = { coinX2Sec = 900 }, price = 29, icon = "CoinGold", amount = 2, order = 5 },
		GrowAll = { id = 0, grant = { growAll = true }, price = 19, icon = "Wheat", order = 6 },
	},
	PassOrder = { "SpeedPass", "HarvestPass", "BagPass", "CoinPass", "WorkerPass" },
	MaxPurchaseHistory = 50,
	RobuxIcon = "rbxasset://textures/ui/common/robux.png",
}

return Products
