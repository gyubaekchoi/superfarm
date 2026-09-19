--!strict
-- 플레이어별 최종 스탯 캐시 + WalkSpeed 적용. 스탯 관련 데이터 패치 시 자동 갱신.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Stats = require(Shared.Stats)
local Types = require(Shared.Types)
local Signal = require(Packages.Signal)
local DataService = require(script.Parent.DataService)

local StatsService = {}
StatsService.Priority = 85
StatsService.Changed = Signal.new() -- (player, computed)

local cache: { [Player]: Types.Computed } = {}
local PREFIXES = { "gear", "enhance", "pads", "passes" }

local function affects(path: string): boolean
	for _, prefix in PREFIXES do
		if path == prefix or path:sub(1, #prefix + 1) == prefix .. "." then
			return true
		end
	end
	return false
end

local function applyWalkSpeed(player: Player, c: Types.Computed)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = c.speed
	end
end

function StatsService:Refresh(player: Player): Types.Computed?
	local d = DataService:Get(player)
	if not d then
		return nil
	end
	local c = Stats.fromData(d)
	cache[player] = c
	applyWalkSpeed(player, c)
	player:SetAttribute("GearTool", d.gear.Tool and d.gear.Tool.star or 0)
	player:SetAttribute("GearShoes", d.gear.Shoes and d.gear.Shoes.star or 0)
	player:SetAttribute("GearBag", d.gear.Bag and d.gear.Bag.star or 0)
	player:SetAttribute("Enhance", d.enhance)
	StatsService.Changed:Fire(player, c)
	return c
end

function StatsService:Get(player: Player): Types.Computed?
	return cache[player]
end

function StatsService:Start()
	DataService.Loaded:Connect(function(player)
		self:Refresh(player)
	end)
	DataService.Patched:Connect(function(player, patches)
		for _, p in patches do
			if affects(p.path) then
				self:Refresh(player)
				return
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			local c = cache[player]
			if c then
				task.defer(applyWalkSpeed, player, c)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
	end)
end

return StatsService
