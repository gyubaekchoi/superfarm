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
	-- 광장 → 각 플롯 스폰 길
	local n = Layout.PlotCount
	for i = 1, n do
		local theta = (i - 1) / n * math.pi * 2
		local dir = Vector3.new(math.sin(theta), 0, math.cos(theta))
		local from = Layout.Plaza.Radius - 4
		local to = Layout.PlotRingRadius - Layout.PlotSize / 2 + 30
		local len = to - from
		local mid = dir * (from + len / 2)
		local path = part(
			"Path",
			Vector3.new(7, 0.3, len),
			CFrame.lookAt(
				mid + Vector3.new(0, Layout.GroundY + 0.02, 0),
				mid + dir + Vector3.new(0, Layout.GroundY + 0.02, 0)
			),
			rgb(Models.Path),
			Enum.Material.SmoothPlastic,
			folder
		)
		path.CanCollide = false
		-- 길 옆 장식 (나무·바위 교대)
		for k = 1, 3 do
			local along = from + len * (k / 4)
			local side = Vector3.new(-dir.Z, 0, dir.X)
			for _, sgn in { -1, 1 } do
				local pos = dir * along + side * (7 * sgn) + Vector3.new(0, Layout.GroundY, 0)
				local list = if (k + (sgn > 0 and 1 or 0)) % 2 == 0 then Models.Decor.Trees else Models.Decor.Rocks
				local name = list[((i + k) % #list) + 1]
				Templates.spawn(name, CFrame.new(pos) * CFrame.Angles(0, (i * 7 + k) * 0.9, 0), folder)
			end
		end
	end
	-- 바깥 둘레 나무 띠
	local ringR = Layout.PlotRingRadius + Layout.PlotSize / 2 + 18
	for i = 1, 36 do
		local a = i / 36 * math.pi * 2
		local pos = Vector3.new(math.cos(a), 0, math.sin(a)) * (ringR + (i % 3) * 6) + Vector3.new(0, Layout.GroundY, 0)
		local name = Models.Decor.Trees[(i % #Models.Decor.Trees) + 1]
		Templates.spawn(name, CFrame.new(pos) * CFrame.Angles(0, a * 3, 0), folder)
	end
end

function WorldService:Init()
	setupLighting()
	setupGround()
end

return WorldService
