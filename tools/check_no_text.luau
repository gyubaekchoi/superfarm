-- UI 글자 규칙 검사. lune run tools/check_no_text
-- 규칙: 클라이언트 코드에서 .Text 에 알파벳/한글이 든 문자열 리터럴을 직접 넣지 않는다.
--       모든 문장은 Config/Strings.luau 에 두고 L("key") 로 가져온다 (Roblox 자동 번역 대상).
--       숫자·기호(▲ ✕ % 등)와 빈 문자열은 허용한다.
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

local function hasWord(lit: string): boolean
	if lit:match("[A-Za-z]") then
		return true
	end
	-- 한글 음절 UTF-8: EA B0 80 ~ ED 9E A3
	for i = 1, #lit - 2 do
		local b1 = lit:byte(i)
		if b1 and b1 >= 0xEA and b1 <= 0xED then
			return true
		end
	end
	return false
end

local files = {}
walk("src/client", files)
local hits = {}
for _, f in files do
	local line = 0
	for l in (fs.readFile(f) .. "\n"):gmatch("(.-)\n") do
		line += 1
		for lit in l:gmatch('%.Text%s*=%s*"([^"]*)"') do
			if hasWord(lit) then
				table.insert(hits, ("%s:%d  %q"):format(f, line, lit))
			end
		end
	end
end

-- Strings 테이블은 ko/en 키가 짝을 이뤄야 한다
local src = fs.readFile("src/shared/Config/Strings.luau")
local function keysIn(section: string): { [string]: boolean }
	local body = src:match("\n\t" .. section .. " = {(.-)\n\t},")
	local keys = {}
	for k in (body or ""):gmatch('%["([%w%.]+)"%]') do
		keys[k] = true
	end
	return keys
end
local ko, en = keysIn("ko"), keysIn("en")
for k in ko do
	if not en[k] then
		table.insert(hits, ("Strings: en 에 %q 없음"):format(k))
	end
end
for k in en do
	if not ko[k] then
		table.insert(hits, ("Strings: ko 에 %q 없음"):format(k))
	end
end

if #hits == 0 then
	local n = 0
	for _ in ko do
		n += 1
	end
	print(("text lint OK (%d files, %d strings x2 locales)"):format(#files, n))
	process.exit(0)
end
print(("text lint: %d violations"):format(#hits))
for _, h in hits do
	print("  " .. h)
end
process.exit(1)
