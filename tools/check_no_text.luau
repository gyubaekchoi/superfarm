-- 클라이언트 UI 코드에서 글자(영문·한글)가 들어간 Text 리터럴을 찾는다. lune run tools/check_no_text
local fs = require("@lune/fs")
local process = require("@lune/process")

local function walk(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local p = dir .. "/" .. name
		if fs.isDir(p) then
			walk(p, out)
		elseif name:match("%.luau$") then
			table.insert(out, p)
		end
	end
end

local files = {}
walk("src/client", files)
local hits = {}
for _, f in files do
	local src = fs.readFile(f)
	local line = 0
	for l in (src .. "\n"):gmatch("(.-)\n") do
		line += 1
		for lit in l:gmatch("%.Text%s*=%s*\"([^\"]*)\"") do
			-- 영문 알파벳 또는 한글 음절이 있으면 위반. 숫자·기호·이모지는 허용
			if lit:match("[A-Za-z]") or lit:match("[\226\128-\237\158\180]") and lit:match("[\234-\237][\128-\191][\128-\191]") then
				table.insert(hits, ("%s:%d  %q"):format(f, line, lit))
			end
		end
	end
end
if #hits == 0 then
	print(("no-text lint OK (%d files)"):format(#files))
	process.exit(0)
end
print(("no-text lint: %d violations"):format(#hits))
for _, h in hits do
	print("  " .. h)
end
process.exit(1)
