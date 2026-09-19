--!strict
-- Studio 전용. 커맨드바/MCP에서 실행 중인 서비스에 접근하기 위한 BindableFunction.
-- ServerStorage.Debug:Invoke(action, ...) 로 호출.
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local DebugService = {}
DebugService.Priority = -100

local actions: { [string]: (...any) -> any } = {}

function DebugService:Register(name: string, fn: (...any) -> any)
	actions[name] = fn
end

function DebugService:Init()
	if not RunService:IsStudio() then
		return
	end
	local DataService = require(script.Parent.DataService)

	local function resolvePlayer(who: any): Player
		if typeof(who) == "Instance" then
			return who :: Player
		end
		if type(who) == "string" then
			return assert(Players:FindFirstChild(who), "no player " .. who) :: Player
		end
		return assert(Players:GetPlayers()[1], "no players")
	end

	self:Register("get", function(who)
		return DataService:Get(resolvePlayer(who))
	end)
	self:Register("add", function(who, path: string, delta: number)
		return DataService:Add(resolvePlayer(who), path, delta)
	end)
	self:Register("set", function(who, path: string, value: any)
		DataService:Set(resolvePlayer(who), path, value)
		return true
	end)
	self:Register("patch", function(who, patches)
		DataService:Patch(resolvePlayer(who), patches)
		return true
	end)

	self:Register("gacha", function(who, currency: string?)
		local GachaService = require(script.Parent.GachaService)
		return GachaService:Pull(resolvePlayer(who), currency or "Ticket")
	end)

	self:Register("enhance", function(who)
		local EnhanceService = require(script.Parent.EnhanceService)
		return EnhanceService:Burst(resolvePlayer(who))
	end)

	self:Register("grant", function(who, key: string)
		local ShopService = require(script.Parent.ShopService)
		return ShopService:Grant(resolvePlayer(who), key)
	end)
	self:Register("daily", function(who)
		local DailyService = require(script.Parent.DailyService)
		return DailyService:TryClaim(resolvePlayer(who))
	end)
	self:Register("suspicious", function(who)
		local AntiCheatService = require(script.Parent.AntiCheatService)
		return AntiCheatService:IsSuspicious(resolvePlayer(who))
	end)

	local bf = Instance.new("BindableFunction")
	bf.Name = "Debug"
	bf.OnInvoke = function(action: string, ...)
		local fn = assert(actions[action], "unknown debug action: " .. tostring(action))
		return fn(...)
	end
	bf.Parent = ServerStorage
end

return DebugService
