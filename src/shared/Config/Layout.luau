--!strict
-- 월드 배치 v2: 플롯 중앙 관리 허브 + 사방(북·동·남·서) 구역. 구역 좌표는 "허브가 -Z 쪽"인 구역 프레임에 적고 yaw 로 회전한다.
export type V3 = { number }

local Layout = {
	PlotCount = 6,
	PlotSize = 180,
	GridCols = 3,
	GridSpacing = 200,
	GroundY = 0.2, -- 오브젝트가 놓이는 기준면 (= 플롯 바닥 윗면, Y.Plot 과 같아야 한다)
	-- Y 레이어. 같은 높이의 면이 겹치면 z-fighting(카메라가 움직일 때 바닥이 깜박임)이 생긴다.
	-- 바닥·판·데칼류는 반드시 아래 값만 사용하고, 새 레이어가 필요하면 여기에 추가한다.
	Y = {
		World = 0.0, -- 월드 바닥 윗면
		Path = 0.08, -- 플롯 사이 통로
		Plot = 0.2, -- 플롯 바닥 윗면 (= GroundY)
		HubRing = { 0.3, 0.36, 0.42 }, -- 허브 동심원 3겹
		Zone = 0.32, -- 구역 바닥 윗면
		Tile = 0.6, -- 밭 타일 윗면 (작물이 이 위에 선다)
		Ring = 0.75, -- 수확 반경 링
		Dash = 0.9, -- 가이드 화살표 대시
	},
	FieldTileHeight = 0.2,
	CropSpacing = 4,
	TreeSpacing = 8,
	CropBaseSize = { 1.2, 1.6, 1.2 },
	FruitSize = 1.0,
	FruitRing = 2.2,
	FruitHeight = 5.2,
	PadSize = { 5, 0.4, 5 },

	-- 작은 마을 = 관리 허브 (플롯 로컬, 중앙 원점). 스폰 → 마을 → 밭 순서로 이어진다.
	-- 이동·수확·가방·성장 패드는 전 구역 공통이므로 구역이 아니라 마을에 둔다.
	Hub = {
		Radius = 26,
		Spawn = { 0, 0, 5 }, -- 마을 한복판, 북쪽 밭을 바라본다
		Gacha = { -11, 0, -11 },
		Enhance = { 11, 0, -11 },
		Shop = { 11, 0, 11 },
		Pads = { Move = { -16, 0, 3 }, Harvest = { -14, 0, 9 }, Cap = { -10, 0, 14 }, Grow = { -3, 0, 17 } },
		-- 집 {x, y, z, yaw, 지붕색 인덱스}
		Houses = {
			{ -19, 0, -19, 0.8, 1 },
			{ 19, 0, -19, 2.4, 2 },
			{ 19, 0, 19, 3.9, 3 },
		},
		Props = { { -20, 0, -4 }, { 20, 0, 0 }, { 4, 0, 20 } }, -- 통·상자 장식
		Lamps = 6,
		OpenRadius = 4,
	},

	-- 구역 프레임: 허브가 -Z, 구역이 +Z 로 뻗는다. 원점은 허브 중심에서 ZoneDistance 만큼 바깥
	ZoneDistance = 30,
	Common = {
		Gate = { 0, 0, -7 }, -- 마을 가장자리 (중심에서 23)
		Field1 = { 0, 0, 6 }, -- 중심에서 36
		Field2 = { 0, 0, 38 },
		SellStand = { -16, 0, 2 }, -- 1번 밭에서 16 studs
		SellStandSize = { 4, 4, 6 },
		ExpandPad = { 16, 0, 2 },
		Crop2Pad = { 0, 0, 38 },
		WorkerPad = { 16, 0, 12 },
		FloorSize = { 50, 0.2, 60 },
		FloorCenter = { 0, 0, 24 },
		Decor = { { 22, 0, 44 }, { -22, 0, 44 }, { -22, 0, 20 } },
	},
	Zone = {
		Z1 = { yaw = math.pi }, -- 북
		Z2 = { yaw = math.pi / 2, SellStandSize = { 8, 5, 4 }, Windmill = { -22, 0, 40 } }, -- 동
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

-- 마을 공용 스탯 패드 위치 (플롯 로컬)
function Layout.hubPadPos(padKey: string): V3?
	return Layout.Hub.Pads[padKey]
end

-- 플롯 i 의 월드 중심 (3×2 격자)
function Layout.plotCenter(index: number): V3
	local col = (index - 1) % Layout.GridCols
	local row = math.floor((index - 1) / Layout.GridCols)
	local rows = math.ceil(Layout.PlotCount / Layout.GridCols)
	return { (col - (Layout.GridCols - 1) / 2) * Layout.GridSpacing, 0, (row - (rows - 1) / 2) * Layout.GridSpacing }
end

return Layout
