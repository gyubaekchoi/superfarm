--!strict
-- 코인 액면 분해. 내림차순 그리디, 최대 개수 초과분은 가장 큰 조각에 합산.
local CoinSplit = {}

function CoinSplit.split(value: number, denoms: { number }, maxPieces: number): { number }
	value = math.floor(value)
	local pieces: { number } = {}
	if value <= 0 then
		return pieces
	end
	local remaining = value
	for i = #denoms, 1, -1 do
		local d = denoms[i]
		while remaining >= d and #pieces < maxPieces do
			table.insert(pieces, d)
			remaining -= d
		end
	end
	if remaining > 0 then
		if #pieces > 0 then
			pieces[1] += remaining
		else
			table.insert(pieces, remaining)
		end
	end
	return pieces
end

-- 액면 등급 (1..#denoms). value 이상인 가장 큰 액면의 인덱스
function CoinSplit.tier(value: number, denoms: { number }): number
	local tier = 1
	for i, d in denoms do
		if value >= d then
			tier = i
		end
	end
	return tier
end

return CoinSplit
