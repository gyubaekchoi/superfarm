--!strict
-- 공용 광장: 🎁 뽑기 상자, ⚒️ 강화대, 🛒 상점 키오스크. 플레이어 플롯 입구에서 가깝게 배치. DevSpec §12.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local PlotService = require(script.Parent.PlotService)

local PlazaService = {}
PlazaService.Priority = 88
PlazaService.GachaBox = nil :: BasePart?
PlazaService.EnhanceStation = nil :: BasePart?
PlazaService.ShopKiosk = nil :: BasePart?

local v3 = PlotService.v3

function PlazaService:Init()
	local P = Layout.Plaza
	local folder = Instance.new("Folder")
	folder.Name = "Plaza"
	folder.Parent = workspace

	local floor = PlotService.makePart(
		"Floor",
		Vector3.new(1, P.Radius * 2, P.Radius * 2),
		CFrame.new(0, Layout.GroundY - 0.5 + 0.02, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(215, 200, 170),
		folder
	)
	floor.Shape = Enum.PartType.Cylinder

	-- 🎁 상자: 몸통 + 뚜껑 + 리본
	local boxPos = v3(P.GachaBox) + Vector3.new(0, Layout.GroundY, 0)
	local box = PlotService.makePart(
		"GachaBox",
		Vector3.new(4, 3.2, 4),
		CFrame.new(boxPos + Vector3.new(0, 1.6, 0)),
		Color3.fromRGB(235, 80, 110),
		folder
	)
	box.CanCollide = false
	box:SetAttribute("Kind", "Gacha")
	CollectionService:AddTag(box, "PlazaObject")
	local lid = PlotService.makePart(
		"GachaLid",
		Vector3.new(4.4, 0.8, 4.4),
		CFrame.new(boxPos + Vector3.new(0, 3.6, 0)),
		Color3.fromRGB(255, 120, 150),
		box
	)
	lid.CanCollide = false
	local ribbon = PlotService.makePart(
		"Ribbon",
		Vector3.new(0.6, 4.2, 4.6),
		CFrame.new(boxPos + Vector3.new(0, 2, 0)),
		Color3.fromRGB(255, 220, 90),
		box
	)
	ribbon.CanCollide = false
	PlazaService.GachaBox = box

	-- ⚒️ 강화대 (6단계에서 기능 연결)
	local anvilPos = v3(P.EnhanceStation) + Vector3.new(0, Layout.GroundY, 0)
	local anvil = PlotService.makePart(
		"EnhanceStation",
		Vector3.new(4, 2.4, 3),
		CFrame.new(anvilPos + Vector3.new(0, 1.2, 0)),
		Color3.fromRGB(80, 80, 95),
		folder
	)
	anvil.CanCollide = false
	anvil:SetAttribute("Kind", "Enhance")
	CollectionService:AddTag(anvil, "PlazaObject")
	PlazaService.EnhanceStation = anvil

	-- 🛒 상점 (7단계)
	local shopPos = v3(P.ShopKiosk) + Vector3.new(0, Layout.GroundY, 0)
	local shop = PlotService.makePart(
		"ShopKiosk",
		Vector3.new(4, 4, 3),
		CFrame.new(shopPos + Vector3.new(0, 2, 0)),
		Color3.fromRGB(90, 150, 230),
		folder
	)
	shop.CanCollide = false
	shop:SetAttribute("Kind", "Shop")
	CollectionService:AddTag(shop, "PlazaObject")
	PlazaService.ShopKiosk = shop
end

return PlazaService
