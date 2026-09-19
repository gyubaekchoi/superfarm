-- Studio 커맨드바(편집 모드)에 붙여 넣어 실행: ReplicatedStorage/Assets 템플릿 폴더를 Creator Store 에셋 ID 로부터 재생성한다.
-- 각 에셋은 InsertService:LoadAsset 으로 받아 스크립트·제약·사운드를 제거하고, 스케일 후 바운딩 박스 바닥 중심으로 피벗을 맞춘다.
-- 실행 뒤 파일 → 저장(Ctrl+S)으로 플레이스에 보존할 것. 코드가 참조하는 이름은 src/shared/Config/Models.luau 와 일치해야 한다.
local InsertService = game:GetService("InsertService")
local RS = game:GetService("ReplicatedStorage")

local SOURCES = {
	-- name = { assetId, scale, collide }
	Tree_Apple = { 18935851411, 0.42, true },      -- Low Poly Apple Tree (Hiccup23454) → 사과 제거, 캐노피/트렁크 이름 지정
	Crop_Corn = { 14157917435, 0.28, false },      -- Corn-Moving (CanterCrow) → 제약 제거
	Crop_Potato = { 7092525084, 0.85, false },     -- potato plant (Omarh107)
	Stand_Stall = { 124928699810262, 0.36, true }, -- Low Poly Market Stall (XxZaydenG0ldenCircui)
	Stand_Truck = { 9149456007, 0.36, true },      -- Low Poly Truck (LAME FLAME!)
	Plaza_Gift = { 130249388617847, 8, false },    -- Present Box Gift (ZoomGpDrift3158743) → 코드에서 채색
	Plaza_Anvil = { 111454380542291, 1.4, false }, -- Anvil (KoBoIce)
	Plaza_Shop = { 134047234421874, 0.55, true },  -- Merchant Tent (WyattFlash4510)
	Decor_Windmill = { 18828754732, 0.35, true },  -- Low Poly Windmill (Manestronomer)
	Decor_Fence = { 134223238872685, 0.5, false }, -- Low Poly Wooden Fence (MasonCraft8709) — 현재 코드는 절차 생성 울타리를 사용
	-- Decor_Rock_L/M/S, Decor_Tree_A/B: Low Poly Nature Pack 9682467046 (Proudism) 에서 바위 3종·나무 2종을 골라 정규화
	-- Crop_Wheat, Crop_Rice, Worker_Robot: 절차 생성 (아래 함수)
	-- Sky: 528506487 (SixEightJake Cartoon Skybox) → Lighting.Sky. ID 는 Config/Assets.luau 의 Sky 에 기록됨
}

local Assets = RS:FindFirstChild("Assets") or Instance.new("Folder")
Assets.Name = "Assets"
Assets.Parent = RS

local function strip(m)
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Camera") or d:IsA("ValueBase") or d:IsA("Configuration") or d:IsA("Constraint")
			or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") or d:IsA("BodyMover") or d:IsA("Sound") or d:IsA("LayerCollector") then
			d:Destroy()
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false end
	end
end

local function normalize(m, name, scale, collide)
	strip(m)
	if scale ~= 1 then m:ScaleTo(m:GetScale() * scale) end
	local cf, size = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0))
	m:PivotTo(CFrame.new())
	if collide then for _, d in m:GetDescendants() do if d:IsA("BasePart") then d.CanCollide = true; d.CanQuery = true end end end
	local old = Assets:FindFirstChild(name); if old then old:Destroy() end
	m.Name = name
	m.Parent = Assets
	return m
end

for name, src in SOURCES do
	local ok, container = pcall(InsertService.LoadAsset, InsertService, src[1])
	if ok and container then
		local m = container:FindFirstChildOfClass("Model") or container
		m.Parent = workspace
		normalize(m, name, src[2], src[3])
		container:Destroy()
	else
		warn("LoadAsset failed: " .. name .. " " .. tostring(container))
	end
end

-- 나무: 사과(작은 메시) 제거 → 열매 템플릿으로, 캐노피/트렁크 이름 지정, 오렌지 나무 파생
local tree = Assets:FindFirstChild("Tree_Apple")
if tree then
	local apple
	for _, d in tree:GetDescendants() do
		if d:IsA("MeshPart") then
			if d.Size.Y < 2 then if not apple then apple = d:Clone() end; d:Destroy()
			elseif d.Size.X > 5 and d.Size.Y < 6 then d.Name = "Canopy"
			elseif d.Size.Y > 6 then d.Name = "Trunk"; tree.PrimaryPart = d end
		end
	end
	local orange = tree:Clone(); orange.Name = "Tree_Orange"
	local c = orange:FindFirstChild("Canopy"); if c then c.Color = Color3.fromRGB(96, 168, 60) end
	orange.Parent = Assets
	if apple then
		local fa = Instance.new("Model"); apple.Name = "Fruit"; apple.Parent = fa; fa.PrimaryPart = apple
		normalize(fa, "Fruit_Apple", 0.7, false)
		local fo = fa:Clone(); fo.Name = "Fruit_Orange"; fo.Fruit.Color = Color3.fromRGB(255, 140, 40); fo.Parent = Assets
	end
end

-- 절차 생성: 밀·벼
local function makeStalks(name, stalkColor, headColor, headShape, headSize)
	local m = Instance.new("Model"); m.Name = name
	local rng = Random.new(7)
	for i = 1, 5 do
		local a = (i - 1) / 5 * math.pi * 2
		local r = if i == 1 then 0 else 0.35
		local x, z = math.cos(a) * r, math.sin(a) * r
		local h = 1.6 + rng:NextNumber(-0.2, 0.3)
		local stalk = Instance.new("Part"); stalk.Shape = Enum.PartType.Cylinder
		stalk.Size = Vector3.new(h, 0.14, 0.14); stalk.Color = stalkColor
		stalk.CFrame = CFrame.new(x, h / 2, z) * CFrame.Angles(0, 0, math.rad(90))
		stalk.Anchored = true; stalk.CanCollide = false; stalk.Parent = m
		local head = Instance.new("Part"); head.Shape = headShape; head.Size = headSize; head.Color = headColor
		head.CFrame = CFrame.new(x, h + headSize.Y / 2 - 0.1, z)
		head.Anchored = true; head.CanCollide = false; head.Parent = m
	end
	return normalize(m, name, 1, false)
end
makeStalks("Crop_Wheat", Color3.fromRGB(214, 176, 74), Color3.fromRGB(246, 208, 96), Enum.PartType.Block, Vector3.new(0.34, 0.7, 0.34))
makeStalks("Crop_Rice", Color3.fromRGB(110, 190, 90), Color3.fromRGB(240, 240, 215), Enum.PartType.Ball, Vector3.new(0.4, 0.5, 0.4))

-- 절차 생성: 일꾼 로봇
do
	local m = Instance.new("Model"); m.Name = "Worker_Robot"
	local function p(name, shape, size, cf, color, mat)
		local x = Instance.new("Part"); x.Name = name; x.Shape = shape; x.Size = size; x.CFrame = cf; x.Color = color
		x.Material = mat or Enum.Material.SmoothPlastic; x.Anchored = true; x.CanCollide = false; x.Parent = m; return x
	end
	local body = p("Body", Enum.PartType.Block, Vector3.new(1.8, 1.6, 1.3), CFrame.new(0, 1.7, 0), Color3.fromRGB(240, 244, 250))
	p("Belly", Enum.PartType.Block, Vector3.new(1.2, 0.8, 0.2), CFrame.new(0, 1.6, -0.6), Color3.fromRGB(90, 200, 255), Enum.Material.Neon)
	p("Head", Enum.PartType.Ball, Vector3.new(1.5, 1.5, 1.5), CFrame.new(0, 3.1, 0), Color3.fromRGB(240, 244, 250))
	p("EyeL", Enum.PartType.Ball, Vector3.new(0.34, 0.34, 0.2), CFrame.new(-0.3, 3.2, -0.66), Color3.fromRGB(40, 60, 90))
	p("EyeR", Enum.PartType.Ball, Vector3.new(0.34, 0.34, 0.2), CFrame.new(0.3, 3.2, -0.66), Color3.fromRGB(40, 60, 90))
	p("Antenna", Enum.PartType.Cylinder, Vector3.new(0.6, 0.12, 0.12), CFrame.new(0, 4.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 130, 150))
	p("Bulb", Enum.PartType.Ball, Vector3.new(0.35, 0.35, 0.35), CFrame.new(0, 4.5, 0), Color3.fromRGB(255, 120, 90), Enum.Material.Neon)
	p("ArmL", Enum.PartType.Cylinder, Vector3.new(1.2, 0.35, 0.35), CFrame.new(-1.1, 1.7, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 130, 150))
	p("ArmR", Enum.PartType.Cylinder, Vector3.new(1.2, 0.35, 0.35), CFrame.new(1.1, 1.7, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 130, 150))
	p("Wheel", Enum.PartType.Cylinder, Vector3.new(0.6, 1.0, 1.0), CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 65, 80))
	m.PrimaryPart = body
	normalize(m, "Worker_Robot", 1, false)
end
print("Assets rebuilt: " .. #Assets:GetChildren() .. " templates")
