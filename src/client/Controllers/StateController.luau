--!strict
-- 서버 데이터 스냅샷 캐시. DataSync(전체) / DataPatch(부분)를 받아 보관하고 Changed 시그널을 낸다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Types = require(Shared.Types)
local Remotes = require(Shared.Remotes)
local Stats = require(Shared.Stats)
local Signal = require(Packages.Signal)

type PlayerData = Types.PlayerData
type DataPatch = Types.DataPatch

local StateController = {}
StateController.Priority = 100
StateController.Loaded = Signal.new() -- (data)
StateController.Changed = Signal.new() -- (path, value)
StateController.StatsChanged = Signal.new() -- (computed)

local data: PlayerData? = nil
local computed: Types.Computed? = nil

local STAT_PREFIXES = { "gear", "enhance", "pads", "passes" }

local function recompute()
	if not data then
		return
	end
	computed = Stats.fromData(data)
	StateController.StatsChanged:Fire(computed)
end

local function affectsStats(path: string): boolean
	for _, prefix in STAT_PREFIXES do
		if path == prefix or path:sub(1, #prefix + 1) == prefix .. "." then
			return true
		end
	end
	return false
end

local function resolve(root: any, path: string): (any, string)
	local parts = string.split(path, ".")
	local node = root
	for i = 1, #parts - 1 do
		local nxt = node[parts[i]]
		if type(nxt) ~= "table" then
			nxt = {}
			node[parts[i]] = nxt
		end
		node = nxt
	end
	return node, parts[#parts]
end

function StateController:Get(): PlayerData?
	return data
end

function StateController:GetStats(): Types.Computed?
	return computed
end

function StateController:Start()
	if game:GetService("RunService"):IsStudio() then
		-- Players.LocalPlayer.PlayerScripts.Debug:Invoke("get" | "stats")
		local bf = Instance.new("BindableFunction")
		bf.Name = "Debug"
		bf.OnInvoke = function(action: string)
			if action == "get" then
				return data
			elseif action == "stats" then
				return computed
			end
			return nil
		end
		bf.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")
	end
	Remotes.get("DataSync").OnClientEvent:Connect(function(d: PlayerData)
		data = d
		recompute()
		print(
			("[StateController] synced · lv%d · coins %d · power %d"):format(
				d.level,
				d.coins,
				computed and computed.power or -1
			)
		)
		StateController.Loaded:Fire(d)
	end)
	Remotes.get("DataPatch").OnClientEvent:Connect(function(patches: { DataPatch })
		if not data then
			return
		end
		local statsDirty = false
		for _, p in patches do
			local node, key = resolve(data, p.path)
			node[key] = p.value
			StateController.Changed:Fire(p.path, p.value)
			if affectsStats(p.path) then
				statsDirty = true
			end
		end
		if statsDirty then
			recompute()
		end
	end)
end

return StateController
