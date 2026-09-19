--!strict
-- 공용 광장: 🎁 뽑기 상자, ⚒️ 강화대, 🛒 상점 키오스크. 플레이어 플롯 입구에서 가깝게 배치. DevSpec §12.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Models = require(Shared.Config.Models)
local Templates = require(Shared.Templates)
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

	local function ring(name, radius, y, color)
		local f = PlotService.makePart(
			name,
			Vector3.new(0.3, radius * 2, radius * 2),
			CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2),
			color,
			folder
		)
		f.Shape = Enum.PartType.Cylinder
		f.CanCollide = false
		return f
	end
	ring(
		"Floor",
		P.Radius,
		Layout.GroundY - 0.1,
		Color3.fromRGB(Models.PlazaFloor[1], Models.PlazaFloor[2], Models.PlazaFloor[3])
	)
	ring("Ring1", P.Radius * 0.66, Layout.GroundY - 0.08, Color3.fromRGB(226, 206, 160))
	ring("Ring2", P.Radius * 0.33, Layout.GroundY - 0.06, Color3.fromRGB(236, 222, 190))
	-- 가로등 6개
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + math.pi / 6
		local pos = Vector3.new(math.cos(a), 0, math.sin(a)) * (P.Radius - 3)
		local post = PlotService.makePart(
			"LampPost",
			Vector3.new(0.5, 7, 0.5),
			CFrame.new(pos + Vector3.new(0, Layout.GroundY + 3.5, 0)),
			Color3.fromRGB(70, 70, 90),
			folder
		)
		post.CanCollide = false
		local bulb = PlotService.makePart(
			"LampBulb",
			Vector3.new(1.4, 1.4, 1.4),
			CFrame.new(pos + Vector3.new(0, Layout.GroundY + 7.4, 0)),
			Color3.fromRGB(255, 230, 150),
			folder
		)
		bulb.Shape = Enum.PartType.Ball
		bulb.Material = Enum.Material.Neon
		bulb.CanCollide = false
		local light = Instance.new("PointLight")
		light.Range = 18
		light.Brightness = 0.8
		light.Color = Color3.fromRGB(255, 230, 170)
		light.Parent = bulb
	end
	local function visual(kind: string, groundPos: Vector3, logical: BasePart)
		local tname = Models.Plaza[kind]
		if tname and Templates.has(tname) then
			for _, c in logical:GetChildren() do
				if c:IsA("BasePart") then
					c:Destroy()
				end
			end
			logical.Transparency = 1
			local m = Templates.spawn(
				tname,
				CFrame.lookAt(groundPos, Vector3.new(0, groundPos.Y, 0)),
				folder,
				kind .. "Visual"
			)
			if m and kind == "Gacha" then
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") then
						local n = d.Name:lower()
						if n:find("ribbon") or n:find("bow") then
							d.Color = Color3.fromRGB(255, 220, 90)
						elseif n:find("lid") then
							d.Color = Color3.fromRGB(255, 120, 150)
						else
							d.Color = Color3.fromRGB(235, 80, 110)
						end
						d.Material = Enum.Material.SmoothPlastic
					end
				end
			end
		end
	end

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
	visual("Gacha", boxPos, box)

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
	visual("Enhance", anvilPos, anvil)

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
	visual("Shop", shopPos, shop)
end

return PlazaService
