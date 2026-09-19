--!strict
-- 문자열 조회. L("pad.Move") / L("pad.Crop2", cropName)
-- 한국어 로케일이면 ko, 그 외는 en (Roblox 자동 번역이 en 을 각 언어로 옮긴다).
local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Strings = require(ReplicatedStorage:WaitForChild("Shared").Config.Strings)

local table_ = Strings[Strings.Fallback]
local ok, locale = pcall(function()
	return LocalizationService.RobloxLocaleId
end)
if ok and typeof(locale) == "string" then
	local short = locale:sub(1, 2):lower()
	if Strings[short] then
		table_ = Strings[short]
	end
end

local function L(key: string, ...): string
	local s = table_[key] or Strings[Strings.Fallback][key] or key
	if select("#", ...) > 0 then
		local fine, formatted = pcall(string.format, s, ...)
		if fine then
			return formatted
		end
	end
	return s
end

return L
