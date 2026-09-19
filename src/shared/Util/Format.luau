--!strict
-- 숫자 표기. 999 → "999", 1000 → "1K", 1250 → "1.25K", 3400000 → "3.4M"
local Format = {}

local UNITS = { { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }

function Format.short(n: number): string
	n = math.floor(n)
	if n < 1000 then
		return tostring(n)
	end
	for _, u in UNITS do
		local div, suffix = u[1], u[2]
		if n >= div then
			local v = n / div
			local s
			if v >= 100 then
				s = string.format("%d", math.floor(v))
			elseif v >= 10 then
				s = string.format("%.1f", math.floor(v * 10) / 10)
			else
				s = string.format("%.2f", math.floor(v * 100) / 100)
			end
			s = s:gsub("%.?0+$", "")
			return s .. suffix
		end
	end
	return tostring(n)
end

return Format
