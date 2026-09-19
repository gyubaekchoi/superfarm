-- Roblox 스타일 require(script.Parent.X) 를 Lune에서 흉내내는 로더.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local cache = {}

local function makeProxy(path: string)
	return setmetatable({ __path = path }, {
		__index = function(_, key)
			if key == "Parent" then
				return makeProxy(path:match("^(.*)/[^/]+$") or "")
			end
			return makeProxy(path .. "/" .. key)
		end,
	})
end

local function resolveFile(path: string): string
	for _, cand in { path .. ".luau", path .. "/init.luau", path .. ".lua" } do
		if fs.isFile(cand) then
			return cand
		end
	end
	error("module not found: " .. path)
end

local function rbxRequire(target)
	local path = if type(target) == "table" then target.__path else target
	if cache[path] ~= nil then
		return cache[path]
	end
	local file = resolveFile(path)
	local src = fs.readFile(file)
	local fn = luau.load(src, {
		debugName = file,
		environment = { script = makeProxy(path), require = rbxRequire },
	})
	local result = fn()
	cache[path] = result
	return result
end

return { require = rbxRequire }
