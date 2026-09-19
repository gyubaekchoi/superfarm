--!strict
-- HEX / {r,g,b} → Color3 (클라이언트 전용; Roblox 타입 사용)
local Colors = {}

function Colors.hex(h: string): Color3
	local s = h:gsub("#", "")
	local r = tonumber(s:sub(1, 2), 16) or 255
	local g = tonumber(s:sub(3, 4), 16) or 255
	local b = tonumber(s:sub(5, 6), 16) or 255
	return Color3.fromRGB(r, g, b)
end

function Colors.rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

return Colors
