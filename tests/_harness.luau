-- 초경량 테스트 하네스
local H = {}
local passed, failed = 0, 0
local failures = {}

function H.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  ✓ " .. name)
	else
		failed += 1
		table.insert(failures, name .. "\n      " .. tostring(err))
		print("  ✗ " .. name)
	end
end

function H.eq(actual, expected, msg: string?)
	if actual ~= expected then
		error(("%sexpected %s, got %s"):format(msg and (msg .. ": ") or "", tostring(expected), tostring(actual)), 2)
	end
end

function H.near(actual: number, expected: number, eps: number, msg: string?)
	if math.abs(actual - expected) > eps then
		error(("%sexpected ~%s (±%s), got %s"):format(msg and (msg .. ": ") or "", expected, eps, actual), 2)
	end
end

function H.truthy(v, msg: string?)
	if not v then
		error((msg or "expected truthy") .. ", got " .. tostring(v), 2)
	end
end

function H.summary(): number
	print(("\n%d passed, %d failed"):format(passed, failed))
	for _, f in failures do
		print("  FAIL " .. f)
	end
	return failed
end

return H
