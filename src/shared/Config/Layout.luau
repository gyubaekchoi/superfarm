--!strict
-- 월드 배치. 구역별 좌표는 구역 원점(Origin) 기준. Layout.pos(zone, key) 로 플롯 로컬 좌표를 얻는다. DevSpec §12.
export type V3 = { number }

local Layout = {
	PlotCount = 6,
	PlotRingRadius = 180,
	PlotSize = 200,
	PlotCenterLocal = { 40, 0, 50 },
	GroundY = 0.1,
	FieldTileHeight = 0.2,
	CropSpacing = 4,
	TreeSpacing = 8,
	CropBaseSize = { 1.2, 1.6, 1.2 },
	FruitSize = 1.0,
	FruitRing = 2.2, -- 나무 기준 열매 배치 반경
	FruitHeight = 5.2,
	PadSize = { 5, 0.4, 5 },
	FogSize = { 78, 24, 90 },

	-- 구역 공통 상대 배치. 구역별로 덮어쓸 수 있음
	Common = {
		Field1 = { 0, 0, 0 },
		Field2 = { 0, 0, 30 },
		SellStand = { -16, 0, 14 },
		SellStandSize = { 4, 4, 6 },
		Pads = { Move = { -16, 0, -6 }, Harvest = { -16, 0, -10 }, Cap = { -16, 0, -14 } },
		ExpandPad = { 12, 0, -16 },
		Crop2Pad = { 0, 0, 30 },
		WorkerPad = { -16, 0, 20 },
	},

	Zone = {
		Z1 = { Origin = { 0, 0, 0 }, Spawn = { -12, 0, 0 } },
		Z2 = {
			Origin = { 75, 0, 0 },
			SellStandSize = { 8, 5, 4 }, -- 🚚 트럭
			Pads = { Move = { -16, 0, -6 }, Harvest = { -16, 0, -10 }, Cap = { -16, 0, -14 }, Grow = { -16, 0, -18 } },
		},
		Z3 = {
			Origin = { 0, 0, 85 },
			Field2 = { 0, 0, 36 },
			Crop2Pad = { 0, 0, 36 },
		},
		Z4 = { Origin = { 75, 0, 85 } },
	},

	-- 게이트: 플롯 로컬 좌표. axis = 통과 방향
	Gates = {
		Z2 = { pos = { 38, 0, 0 }, axis = "x" },
		Z3 = { pos = { 0, 0, 58 }, axis = "z" },
		Z4 = { pos = { 75, 0, 58 }, axis = "z" },
	},

	Plaza = {
		Radius = 30,
		GachaBox = { 0, 0, -14 },
		EnhanceStation = { -14, 0, 8 },
		ShopKiosk = { 14, 0, 8 },
		OpenRadius = 4, -- 오브젝트 근접 시 화면 자동 오픈
	},
	CoinScatter = { minDist = 3, maxDist = 6, halfWidth = 3 },
	DepositInterval = 0.08,
	CoinFlushInterval = 0.4,
	RespawnDelay = 3,

	Worker = { Speed = 8, Interval = 0.5, Cap = 10, ArriveDist = 2.5, HarvestRadius = 4.5, SpawnOffset = { -8, 0, 8 } },
}

local function add(a: V3, b: V3): V3
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end

-- 구역 상대 키 조회 (구역 덮어쓰기 → 공통)
function Layout.zoneValue(zone: string, key: string): any
	local z = (Layout.Zone :: any)[zone]
	if z and z[key] ~= nil then
		return z[key]
	end
	return (Layout.Common :: any)[key]
end

-- 플롯 로컬 좌표
function Layout.pos(zone: string, key: string): V3
	local origin = (Layout.Zone :: any)[zone].Origin
	return add(origin, Layout.zoneValue(zone, key))
end

function Layout.padPos(zone: string, padKey: string): V3?
	local pads = Layout.zoneValue(zone, "Pads")
	local rel = pads and pads[padKey]
	if not rel then
		return nil
	end
	return add((Layout.Zone :: any)[zone].Origin, rel)
end

return Layout
