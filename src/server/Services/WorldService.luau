--!strict
-- 월드 배경: 조명·스카이박스·후처리·바닥·광장 주변 장식. 유행하는 밝은 로우폴리 스타일.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Config.Assets)
local Models = require(Shared.Config.Models)
local Layout = require(Shared.Config.Layout)
local Templates = require(Shared.Templates)

local WorldService = {}
WorldService.Priority = 92

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function setupLighting()
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 2.6
	Lighting.ExposureCompensation = 0.15
	Lighting.Ambient = Color3.fromRGB(140, 150, 175)
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 145, 170)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4

	local sky = Lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = Instance.new("Sky")
		sky.Name = "Sky"
		sky.Parent = Lighting
	end
	local S = Assets.Sky
	sky.SkyboxBk, sky.SkyboxDn, sky.SkyboxFt, sky.SkyboxLf, sky.SkyboxRt, sky.SkyboxUp =
		S.Bk, S.Dn, S.Ft, S.Lf, S.Rt, S.Up
	sky.SunAngularSize = 14
	sky.StarCount = 0

	for _, cls in { "Atmosphere", "BloomEffect", "ColorCorrectionEffect", "SunRaysEffect" } do
		local old = Lighting:FindFirstChildOfClass(cls)
		if old then
			old:Destroy()
		end
	end
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.16
	atm.Offset = 0.2
	atm.Color = Color3.fromRGB(199, 210, 235)
	atm.Decay = Color3.fromRGB(120, 160, 220)
	atm.Glare = 0.1
	atm.Haze = 0.5
	atm.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.55
	bloom.Size = 28
	bloom.Threshold = 1.4
	bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.22
	cc.Contrast = 0.08
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(255, 250, 240)
	cc.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.07
	rays.Spread = 0.6
	rays.Parent = Lighting
end

local function part(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function setupGround()
	local base = workspace:FindFirstChild("Baseplate")
	if base and base:IsA("BasePart") then
		base.Transparency = 1
		base.CanCollide = true
	end
	local folder = Instance.new("Folder")
	folder.Name = "World"
	folder.Parent = workspace
	-- 넓은 연두 바닥 (플롯·광장 아래)
	part(
		"Ground",
		Vector3.new(900, 2, 900),
		CFrame.new(0, Layout.GroundY - 1.0, 0),
		rgb(Models.Ground),
		Enum.Material.Grass,
		folder
	)
	-- 플롯 격자 사이·바깥 장식 (나무·바위)
	local rows = math.ceil(Layout.PlotCount / Layout.GridCols)
	local halfW = (Layout.GridCols * Layout.GridSpacing) / 2 + 30
	local halfH = (rows * Layout.GridSpacing) / 2 + 30
	local rng = Random.new(42)
	for i = 1, 70 do
		local side = i % 4
		local x, z
		if side == 0 then
			x, z = rng:NextNumber(-halfW, halfW), -halfH - rng:NextNumber(0, 20)
		elseif side == 1 then
			x, z = rng:NextNumber(-halfW, halfW), halfH + rng:NextNumber(0, 20)
		elseif side == 2 then
			x, z = -halfW - rng:NextNumber(0, 20), rng:NextNumber(-halfH, halfH)
		else
			x, z = halfW + rng:NextNumber(0, 20), rng:NextNumber(-halfH, halfH)
		end
		local list = if i % 3 == 0 then Models.Decor.Rocks else Models.Decor.Trees
		local name = list[(i % #list) + 1]
		Templates.spawn(
			name,
			CFrame.new(x, Layout.GroundY, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
			folder
		)
	end
	-- 플롯 사이 통로 (모래색)
	for c = 1, Layout.GridCols - 1 do
		local x = (c - Layout.GridCols / 2) * Layout.GridSpacing
		local pth = part(
			"Path",
			Vector3.new(Layout.GridSpacing - Layout.PlotSize, 0.4, rows * Layout.GridSpacing),
			CFrame.new(x, Layout.GroundY + 0.02, 0),
			rgb(Models.Path),
			Enum.Material.SmoothPlastic,
			folder
		)
		pth.CanCollide = false
	end
	if rows > 1 then
		local pth = part(
			"Path",
			Vector3.new(Layout.GridCols * Layout.GridSpacing, 0.4, Layout.GridSpacing - Layout.PlotSize),
			CFrame.new(0, Layout.GroundY + 0.02, 0),
			rgb(Models.Path),
			Enum.Material.SmoothPlastic,
			folder
		)
		pth.CanCollide = false
	end
end

function WorldService:Init()
	setupLighting()
	setupGround()
end

return WorldService
