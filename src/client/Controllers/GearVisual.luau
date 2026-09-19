--!strict
-- 장비 외형: 플레이어 어트리뷰트(GearTool/GearShoes/GearBag, Enhance)를 읽어 도구·신발·가방을 캐릭터에 붙인다. 등급색·크기·트레일. DevSpec §6-4.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Config.Assets)
local Colors = require(Shared.Util.Colors)
local EnhanceLogic = require(Shared.EnhanceLogic)

local GearVisual = {}
GearVisual.Priority = 38

local SCALE = { 1.0, 1.15, 1.3, 1.5 }
local attached: { [Player]: { [string]: Instance } } = {}

local function rarityColor(star: number): Color3
	return Colors.hex(Assets.RarityColors[math.clamp(star, 1, 4)])
end

local function weldTo(part: BasePart, target: BasePart, offset: CFrame)
	part.CFrame = target.CFrame * offset
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = target
	weld.Part1 = part
	weld.Parent = part
end

local function clear(player: Player, slot: string)
	local map = attached[player]
	if map and map[slot] then
		map[slot]:Destroy()
		map[slot] = nil
	end
end

local function buildTool(char: Model, star: number): Instance?
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return nil
	end
	local s = SCALE[star]
	local model = Instance.new("Model")
	model.Name = "GearTool"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 2.2 * s, 0.3)
	handle.Color = Color3.fromRGB(120, 80, 45)
	handle.Material = Enum.Material.Wood
	handle.Parent = model
	weldTo(handle, hand, CFrame.new(0, -0.2, 0) * CFrame.Angles(math.rad(90), 0, 0))
	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = Vector3.new(1.4 * s, 0.12, 0.5 * s)
	blade.Color = rarityColor(star)
	blade.Material = if star >= 3 then Enum.Material.Neon else Enum.Material.Metal
	blade.Parent = model
	weldTo(blade, hand, CFrame.new(0.6 * s, -0.2, -1.1 * s) * CFrame.Angles(math.rad(90), 0, 0))
	if star >= 3 then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(-0.7 * s, 0, 0)
		a0.Parent = blade
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0.7 * s, 0, 0)
		a1.Parent = blade
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(rarityColor(star))
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Lifetime = 0.25
		trail.WidthScale = NumberSequence.new(1, 0)
		trail.Parent = blade
	end
	model.Parent = char
	return model
end

local function buildShoes(char: Model, star: number): Instance?
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "GearShoes"
	for i, name in { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" } do
		local foot = char:FindFirstChild(name)
		if foot and foot:IsA("BasePart") then
			local p = Instance.new("Part")
			p.Name = "Shoe" .. i
			p.Size = Vector3.new(foot.Size.X + 0.15, 0.35, foot.Size.Z + 0.3)
			p.Color = rarityColor(star)
			p.Material = if star >= 3 then Enum.Material.Neon else Enum.Material.SmoothPlastic
			p.Parent = model
			weldTo(p, foot, CFrame.new(0, -foot.Size.Y / 2 + 0.15, -0.05))
		end
	end
	model.Parent = char
	return model
end

local function buildBag(char: Model, star: number): Instance?
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return nil
	end
	local s = SCALE[star]
	local p = Instance.new("Part")
	p.Name = "GearBag"
	p.Size = Vector3.new(1.4 * s, 1.5 * s, 0.7 * s)
	p.Color = rarityColor(star)
	p.Material = if star >= 3 then Enum.Material.Neon else Enum.Material.Fabric
	p.Parent = char
	weldTo(p, torso, CFrame.new(0, 0.1, torso.Size.Z / 2 + 0.35 * s))
	return p
end

local BUILDERS = { Tool = buildTool, Shoes = buildShoes, Bag = buildBag }

-- 강화 오라: 도구 날에 등급색 파티클 (+5 White, +10 BlueFlame, +15 Gold, +20 Rainbow, +30 Galaxy)
function GearVisual.auraColor(name: string?): ColorSequence?
	if not name then
		return nil
	end
	local hex = Assets.AuraColors[name]
	if hex == "RAINBOW" then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 80)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 120, 255)),
		})
	end
	return ColorSequence.new(Colors.hex(hex))
end

local function applyAura(player: Player)
	local map = attached[player]
	local tool = map and map.Tool
	local blade = tool and tool:FindFirstChild("Blade")
	if not blade or not blade:IsA("BasePart") then
		return
	end
	local old = blade:FindFirstChild("Aura")
	if old then
		old:Destroy()
	end
	local level = player:GetAttribute("Enhance") :: number? or 0
	local name = EnhanceLogic.auraFor(level)
	local seq = GearVisual.auraColor(name)
	if not seq then
		return
	end
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Aura"
	pe.Color = seq
	pe.LightEmission = 0.8
	pe.Size = NumberSequence.new(0.35, 0)
	pe.Transparency = NumberSequence.new(0.2, 1)
	pe.Lifetime = NumberRange.new(0.3, 0.6)
	pe.Rate = if name == "Galaxy" then 40 elseif name == "Rainbow" then 30 else 18
	pe.Speed = NumberRange.new(0.5, 1.5)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Parent = blade
end

local function refresh(player: Player, slot: string)
	clear(player, slot)
	local char = player.Character
	if not char or not char.Parent then
		return
	end
	local star = player:GetAttribute("Gear" .. slot) :: number? or 0
	if star <= 0 then
		return
	end
	local inst = BUILDERS[slot](char, star)
	if inst then
		attached[player] = attached[player] or {}
		attached[player][slot] = inst
	end
	if slot == "Tool" then
		applyAura(player)
	end
end

local function refreshAll(player: Player)
	for slot in BUILDERS do
		refresh(player, slot)
	end
end

local function watch(player: Player)
	attached[player] = {}
	for slot in BUILDERS do
		player:GetAttributeChangedSignal("Gear" .. slot):Connect(function()
			refresh(player, slot)
		end)
	end
	player:GetAttributeChangedSignal("Enhance"):Connect(function()
		applyAura(player)
	end)
	player.CharacterAdded:Connect(function(char)
		-- 림이 다 로드된 뒤 부착
		char:WaitForChild("HumanoidRootPart", 5)
		task.wait(0.2)
		refreshAll(player)
	end)
	if player.Character then
		task.defer(refreshAll, player)
	end
end

function GearVisual:Start()
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(p)
		attached[p] = nil
	end)
end

return GearVisual
