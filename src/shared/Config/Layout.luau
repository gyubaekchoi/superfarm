--!strict
-- 월드 배치 v2: 플롯 중앙 관리 허브 + 사방(북·동·남·서) 구역. 구역 좌표는 "허브가 -Z 쪽"인 구역 프레임에 적고 yaw 로 회전한다.
export type V3 = { number }

local Layout = {
	PlotCount = 6,
	PlotSize = 200,
	GridCols = 3,
	GridSpacing = 230,
	GroundY = 0.1,
	FieldTileHeight = 0.2,
	CropSpacing = 4,
	TreeSpacing = 8,
	CropBaseSize = { 1.2, 1.6, 1.2 },
	FruitSize = 1.0,
	FruitRing = 2.2,
	FruitHeight = 5.2,
	PadSize = { 5, 0.4, 5 },

	-- 관리 허브 (플롯 로컬, 중앙 원점)
	Hub = {
		Radius = 24,
		Spawn = { 0, 0, -6 }, -- 북쪽(Z1) 을 바라보고 스폰
		Gacha = { -14, 0, 4 },
		Enhance = { 14, 0, 4 },
		Shop = { 0, 0, 15 },
		OpenRadius = 4,
		Lamps = 6,
	},

	-- 구역 프레임: 허브가 -Z, 구역이 +Z 로 뻗는다. 원점은 허브 중심에서 ZoneDistance 만큼 바깥
	ZoneDistance = 34,
	Common = {
		Gate = { 0, 0, -14 }, -- 허브 가장자리 (중심에서 20)
		Field1 = { 0, 0, 12 },
		Field2 = { 0, 0, 44 },
		SellStand = { -18, 0, 6 },
		SellStandSize = { 4, 4, 6 },
		Pads = { Move = { -18, 0, 16 }, Harvest = { -18, 0, 20 }, Cap = { -18, 0, 24 } },
		ExpandPad = { 18, 0, 6 },
		Crop2Pad = { 0, 0, 44 },
		WorkerPad = { 18, 0, 14 },
		FloorSize = { 60, 0.2, 70 },
		FloorCenter = { 0, 0, 26 },
		Decor = { { 24, 0, 54 }, { -24, 0, 54 }, { 26, 0, 30 } }, -- 구역 안쪽 장식 위치
	},
	Zone = {
		Z1 = { yaw = math.pi }, -- 북
		Z2 = {
			yaw = math.pi / 2,
			SellStandSize = { 8, 5, 4 },
			Pads = { Move = { -18, 0, 16 }, Harvest = { -18, 0, 20 }, Cap = { -18, 0, 24 }, Grow = { -18, 0, 28 } },
			Windmill = { -26, 0, 48 },
		}, -- 동
		Z3 = { yaw = 0 }, -- 남
		Z4 = { yaw = -math.pi / 2 }, -- 서 (티저)
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

-- 구역 yaw 로 벡터 회전 (Roblox CFrame.Angles(0, yaw, 0) 과 동일)
function Layout.rot(zone: string, v: V3): V3
	local yaw = (Layout.Zone :: any)[zone].yaw
	local c, s = math.cos(yaw), math.sin(yaw)
	return { v[1] * c + v[3] * s, v[2], -v[1] * s + v[3] * c }
end

-- 구역 원점 (플롯 로컬)
function Layout.origin(zone: string): V3
	return Layout.rot(zone, { 0, 0, Layout.ZoneDistance })
end

-- 구역이 뻗는 방향 단위 벡터 (플롯 로컬)
function Layout.dir(zone: string): V3
	return Layout.rot(zone, { 0, 0, 1 })
end

function Layout.yaw(zone: string): number
	return (Layout.Zone :: any)[zone].yaw
end

-- 구역 상대 키 조회 (구역 덮어쓰기 → 공통)
function Layout.zoneValue(zone: string, key: string): any
	local z = (Layout.Zone :: any)[zone]
	if z and z[key] ~= nil then
		return z[key]
	end
	return (Layout.Common :: any)[key]
end

-- 구역 프레임 상대 좌표 → 플롯 로컬
function Layout.rel(zone: string, v: V3): V3
	return add(Layout.origin(zone), Layout.rot(zone, v))
end

function Layout.pos(zone: string, key: string): V3
	return Layout.rel(zone, Layout.zoneValue(zone, key))
end

function Layout.padPos(zone: string, padKey: string): V3?
	local pads = Layout.zoneValue(zone, "Pads")
	local r = pads and pads[padKey]
	if not r then
		return nil
	end
	return Layout.rel(zone, r)
end

-- 플롯 i 의 월드 중심 (3×2 격자)
function Layout.plotCenter(index: number): V3
	local col = (index - 1) % Layout.GridCols
	local row = math.floor((index - 1) / Layout.GridCols)
	local rows = math.ceil(Layout.PlotCount / Layout.GridCols)
	return { (col - (Layout.GridCols - 1) / 2) * Layout.GridSpacing, 0, (row - (rows - 1) / 2) * Layout.GridSpacing }
end

return Layout
