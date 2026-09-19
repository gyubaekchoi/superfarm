-- lune run tests/run
local fs = require("@lune/fs")
local process = require("@lune/process")
local H = require("./_harness")

for _, name in fs.readDir("tests") do
	if name:match("%.spec%.luau$") then
		require("./" .. name:gsub("%.luau$", ""))
	end
end

local failed = H.summary()
process.exit(failed == 0 and 0 or 1)
