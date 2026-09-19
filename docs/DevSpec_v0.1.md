# 🌾 SUPER FARM — 개발 기획서 (Dev Spec) v0.1

> 상위 문서: [GDD_v0.1.md](./GDD_v0.1.md)
> 본 문서는 GDD의 기획을 **구현 가능한 수준**으로 분해한다. 수치·자료구조·알고리즘·네트워크·연출 타임라인·검수 기준을 포함한다.
> 모든 수치는 `ReplicatedStorage/Shared/Config/*` 테이블로 외부화하며, 코드에 상수를 박지 않는다.

| 항목 | 내용 |
|---|---|
| 엔진 | Roblox / Luau (strict 모드) |
| 툴체인 | Rojo 7 + Wally, Selene(lint), StyLua(format) |
| 외부 라이브러리 | ProfileService(저장), Promise, Signal(GoodSignal), Janitor, TweenService(내장) |
| 서버 규모 | 6인 / 개인 플롯 6 + 공용 광장 1 |
| 타깃 프레임 | 클라 60fps(PC) / 30fps 이상(모바일 저사양), 서버 tick 10Hz |
| 작성일 | 2026-09-19 |

---

## 0. 우선순위 선언 — 세 가지 핵심 재미

이 문서의 모든 결정은 아래 세 가지를 살리는 방향으로 판정한다. 충돌 시 이 순서로 우선한다.

| # | 핵심 재미 | 구현 원칙 | 상세 장 |
|---|---|---|---|
| 1 | **손 안 대고 수확** | 입력 0. 스폰 후 10초 안에 첫 수확. 수확 반경이 눈에 보인다. 스택은 물리적으로 흔들린다. | §5 |
| 2 | **폭발 강화** | 강화는 절대 +1씩 오르지 않는다. 최소 +3, 평균 +5~8. 3초 안에 파워가 눈에 띄게 뛴다. | §7 |
| 3 | **첫 뽑기의 짜릿함** | 첫 뽑기 ★3 확정 + 도구 슬롯 고정 → 수확 반경이 커지는 것이 바로 보인다. | §6 |

---

## 1. 프로젝트 구조

### 1-1. Rojo 트리

```
super_farm/
├─ default.project.json
├─ wally.toml
├─ docs/
├─ assets/                    ← 아이콘 PNG, 사운드 원본 (업로드 후 Config/Assets.luau 에 ID 기록)
└─ src/
   ├─ shared/                 → ReplicatedStorage/Shared
   │  ├─ Config/
   │  │  ├─ Crops.luau
   │  │  ├─ Zones.luau
   │  │  ├─ Pads.luau
   │  │  ├─ Gacha.luau
   │  │  ├─ Enhance.luau
   │  │  ├─ Economy.luau      ← XP 테이블, 코인 단위, 드롭률
   │  │  ├─ Products.luau     ← 게임패스/개발자 상품 ID
   │  │  └─ Assets.luau       ← 아이콘·사운드·파티클 ID
   │  ├─ Types.luau           ← PlayerData 등 공용 타입
   │  ├─ Stats.luau           ← 최종 스탯 계산 (서버·클라 공용, 순수 함수)
   │  ├─ Remotes.luau         ← Remote 이름 상수 + 페이로드 타입
   │  └─ Util/ (Format.luau, Spring.luau, Rng.luau)
   ├─ server/                 → ServerScriptService/Server
   │  ├─ Bootstrap.server.luau
   │  └─ Services/
   │     ├─ DataService.luau
   │     ├─ PlotService.luau
   │     ├─ CropService.luau
   │     ├─ HarvestService.luau
   │     ├─ SellService.luau
   │     ├─ CoinService.luau
   │     ├─ PadService.luau
   │     ├─ WorkerService.luau
   │     ├─ EconomyService.luau
   │     ├─ GachaService.luau
   │     ├─ EnhanceService.luau
   │     ├─ ShopService.luau
   │     ├─ GuideService.luau     ← 다음 목표 산출(서버) → 화살표
   │     └─ AnalyticsService.luau
   └─ client/                 → StarterPlayer/StarterPlayerScripts/Client
      ├─ Bootstrap.client.luau
      └─ Controllers/
         ├─ StateController.luau  ← 서버 스냅샷 캐시 + Signal
         ├─ CropVisual.luau
         ├─ StackVisual.luau
         ├─ CoinVisual.luau
         ├─ PadVisual.luau
         ├─ RadiusVisual.luau     ← 수확 반경 링
         ├─ GuideArrow.luau
         ├─ GachaFX.luau
         ├─ EnhanceFX.luau
         ├─ LevelUpFX.luau
         ├─ AudioController.luau  ← 피치 사다리
         ├─ CameraController.luau ← 줌·흔들림
         └─ UI/ (HUD, GachaScreen, EnhanceScreen, ShopScreen)
```

### 1-2. 코딩 규약

- 서비스는 `Init()` → `Start()` 2단계. `Init`에서 참조만, `Start`에서 연결.
- 클라이언트는 **연출과 표시만** 담당. 게임 상태를 바꾸는 판정은 전부 서버.
- Remote는 `Remotes.luau`에 이름·타입 정의. 직접 문자열 사용 금지.
- 모든 확률은 `Rng.luau`의 시드 가능한 RNG 사용(테스트 재현용).

---

## 2. 데이터 모델

### 2-1. PlayerData (저장 대상)

```lua
-- Types.luau
export type GearSlot = "Tool" | "Shoes" | "Bag"
export type Gear = { star: number }            -- 1~4. nil = 미장착

export type PlayerData = {
  version: number,                              -- 스키마 버전 (마이그레이션용). 현재 1
  coins: number,
  stones: number,                               -- 💎 강화석
  tickets: number,                              -- 🎫
  xp: number,
  level: number,

  zones: { [string]: boolean },                 -- "Z1"=true, "Z2"=false ...
  gates: { [string]: number },                  -- 게이트 부분 결제액 "Z2"=350
  pads: { [string]: { level: number, paid: number } },   -- "Z1_Move", "Z1_Harvest", "Z1_Cap", "Z2_Grow" ...
  fields: { [string]: { expansion: number, paid: number, crop2: boolean, crop2Paid: number } }, -- "Z1","Z2","Z3"
  workers: { [string]: { count: number, level: number, paid: number } },

  gear: { Tool: Gear?, Shoes: Gear?, Bag: Gear? },
  enhance: number,                              -- 장비 세트 강화 단계 0~30

  gacha: { freeCount: number, paidCount: number, pity: number },
  passes: { [string]: boolean },                -- "SpeedPass"=true
  boosts: { coinX2Until: number },              -- os.time() 기준 만료

  tutorial: number,                             -- 완료한 가이드 단계 (0~)
  daily: { lastChest: number },
  stats: { totalCoins: number, totalHarvest: number, playtimeSec: number, enhanceBursts: number },
}
```

### 2-2. 기본값

```lua
DEFAULT = {
  version=1, coins=0, stones=0, tickets=0, xp=0, level=1,
  zones={Z1=true}, gates={}, pads={}, fields={Z1={expansion=0,paid=0,crop2=false,crop2Paid=0}},
  workers={}, gear={}, enhance=0,
  gacha={freeCount=0,paidCount=0,pity=0}, passes={}, boosts={coinX2Until=0},
  tutorial=0, daily={lastChest=0},
  stats={totalCoins=0,totalHarvest=0,playtimeSec=0,enhanceBursts=0},
}
```

### 2-3. 런타임 상태 (저장 안 함, 서버 메모리)

```lua
type CropState = { idx: number, cropId: string, pos: Vector3, readyAt: number }   -- readyAt <= now → Ready
type PlotRuntime = {
  owner: Player, plotIndex: number, origin: CFrame,
  crops: { [string]: { [number]: CropState } },     -- zoneId → 배열
  grid: { [Vector3]: { CropState } },                -- 4x4 stud 버킷 → 준비 여부 무관 전체
  stack: { { cropId: string } },                     -- 머리 위 스택 (순서 유지)
  harvestCooldown: number,
  coins: { [number]: { id: number, pos: Vector3, value: number } },  -- 바닥 코인
  workers: { WorkerRuntime },
  full: boolean,
}
```

### 2-4. 저장 정책 (DataService)

- ProfileService, 키 `Player_{UserId}`, 세션락 사용.
- 자동 저장 60초, 퇴장 시 `Release()`. `BindToClose`에서 전원 저장 대기(최대 25초).
- 로드 실패 시 플레이어를 **킥**(중복 세션/데이터 손실 방지). 아이콘만 있는 안내 화면 후 재접속 유도.
- 마이그레이션: `version` 비교 후 `Migrations[version](data)` 순차 적용.
- 상점 영수증(`ProcessReceipt`)은 `purchaseIds` 링버퍼(최근 50개)로 중복 처리 방지 → `Enum.ProductPurchaseDecision.PurchaseGranted`.

---

## 3. 스탯 계산 (Stats.luau — 공용 순수 함수)

모든 배율은 **곱연산**. 클라이언트는 표시용으로 같은 함수를 호출한다.

```lua
local BASE_SPEED, BASE_INTERVAL, BASE_CAP, BASE_RADIUS = 16, 0.25, 10, 4.5

function Stats.compute(d: PlayerData, zonePads): Computed
  local enh = 1 + 0.03 * d.enhance                       -- 세트 강화: 단계당 +3% (모든 장비 효과에 곱)
  local tool  = d.gear.Tool  and Gacha.Effect.Tool[d.gear.Tool.star]   or 0   -- 0.10/0.25/0.50/1.00
  local shoes = d.gear.Shoes and Gacha.Effect.Shoes[d.gear.Shoes.star] or 0   -- 0.10/0.20/0.35/0.60
  local bag   = d.gear.Bag   and Gacha.Effect.Bag[d.gear.Bag.star]     or 0   -- 5/15/30/60 (가산)
  local radiusStar = d.gear.Tool and Gacha.Radius[d.gear.Tool.star] or 0      -- +0.5/+1/+2/+3

  local padMove, padHarv, padCap = zonePads.Move, zonePads.Harvest, zonePads.Cap -- 현재 위치 구역 패드 단계

  local speed    = (BASE_SPEED + padMove) * (1 + shoes * enh) * (d.passes.SpeedPass and 1.5 or 1)
  local interval = (BASE_INTERVAL - 0.013 * padHarv) / (1 + tool * enh) / (d.passes.HarvestPass and 2 or 1)
  local cap      = math.floor((BASE_CAP + 4 * padCap + bag * enh) * (d.passes.BagPass and 2 or 1))
  local radius   = BASE_RADIUS + radiusStar

  speed    = math.clamp(speed, 16, 40)        -- 40 초과 시 수확 판정·카메라가 무너짐
  interval = math.max(interval, 0.03)

  local power = math.floor(100 * (speed / BASE_SPEED) + 100 * (BASE_INTERVAL / interval) + 100 * (cap / BASE_CAP) - 200)
  return { speed=speed, interval=interval, cap=cap, radius=radius, power=power }
end
```

**파워 기준값 검증**
- 시작: 16/16=1, 0.25/0.25=1, 10/10=1 → 300−200 = **⚡100** (반경 4.5: 작물 간격 4에서 가운데 줄을 걸으면 양옆 줄까지 닿는 최소값)
- 첫 뽑기 ★3 도구(+50% 수확): interval 0.1667 → 100+150+100−200 = **⚡150** (한 방에 +50)
- 첫 폭발 강화 +5 (enh 1.15): tool 0.5×1.15=0.575 → 100+157+100−200 = ⚡157 + 패드 누적분. 강화 효과가 작아 보이므로 **강화는 3슬롯 전체에 곱해지는 구조**를 채택 (§7-1 참고).

---

## 4. 네트워크 (Remotes.luau)

전송 방식: 연출용 대량 이벤트는 `UnreliableRemoteEvent`, 상태 변경은 `RemoteEvent`. 클라→서버는 초당 5회 레이트리밋, 초과 시 무시 + 로그.

### 4-1. 서버 → 클라이언트

| 이름 | 방식 | 페이로드 | 용도 |
|---|---|---|---|
| `DataSync` | Reliable | `PlayerData` 전체 | 접속 직후 1회, 이후 변경 필드만 `DataPatch` |
| `DataPatch` | Reliable | `{ path: string, value: any }[]` | 코인·💎·🎫·레벨 등 HUD 갱신 |
| `CropReset` | Unreliable | `{ zone, idx, readyAt }[]` | 수확 후 성장 시작(클라가 시간 보간으로 단계 렌더) |
| `HarvestBatch` | Unreliable | `{ plot, items: {zone, idx}[], stackCount }` | 튀는 연출 + 스택 갱신. **같은 서버 전원에게** 전송(구경 가능) |
| `StackFull` | Reliable | `{ plot, full: boolean }` | 🚫 표시 토글 |
| `SellDeposit` | Unreliable | `{ plot, count, coinValue }` | 판매대 투입 연출 |
| `CoinSpawn` | Reliable | `{ plot, coins: {id, pos, value}[] }` | 바닥 코인 생성 |
| `CoinCollect` | Unreliable | `{ plot, ids: number[] }` | 자석 연출·삭제 |
| `StoneDrop` | Reliable | `{ pos, amount }` | 💎 드롭 연출 |
| `PadProgress` | Unreliable | `{ padId, paid, cost }` | 게이지 |
| `PadComplete` | Reliable | `{ padId, newLevel }` | 완료 연출 + 스탯 재계산 |
| `ZoneUnlocked` | Reliable | `{ zone }` | 안개 걷힘 + 카메라 팬 |
| `LevelUp` | Reliable | `{ level, rewards: {tickets, stones} }` | ⭐ 연출 |
| `GachaResult` | Reliable | `{ slot, star, equipped: boolean, stonesGained, isFirst: boolean }` | 뽑기 연출 |
| `EnhanceResult` | Reliable | `{ from, to, steps: {gain, crit}[], stonesSpent, powerFrom, powerTo }` | 폭발 강화 연출 |
| `GuideTarget` | Reliable | `{ kind, worldPos, icon }` | 다음 목표 화살표 |
| `WorkerState` | Unreliable | `{ plot, workerIdx, state, targetPos }` | 일꾼 애니메이션 |

### 4-2. 클라이언트 → 서버

| 이름 | 페이로드 | 서버 검증 |
|---|---|---|
| `RequestGacha` | `{ currency: "Ticket" \| "Stones" }` | 티켓≥1 또는 💎≥50, 정책 체크, 쿨다운 1.5s |
| `RequestEnhance` | `{}` | `canLevels(stones) >= 3`, 쿨다운 4s |
| `RequestPurchase` | `{ productKey: string }` | Products 테이블 존재 → `PromptProductPurchase`/`PromptGamePassPurchase` |
| `ClaimDaily` | `{}` | `os.time() - daily.lastChest >= 72000` |
| `GuideAck` | `{ step }` | 단조 증가만 허용 |

- 수확·판매·패드·코인은 **클라이언트 요청이 없다**. 서버가 캐릭터 위치로만 판정.

---

## 5. 핵심 재미 ① — 손 안 대고 수확

### 5-1. 첫 10초 설계 (온보딩 하드 제약)

| 제약 | 값 | 이유 |
|---|---|---|
| 스폰 위치 → 가장 가까운 밀 | **8 studs** | 두 걸음에 수확 시작 |
| 스폰 시 카메라 | 캐릭터 뒤 위, 밭이 화면 중앙 | 시선 유도 |
| 첫 접속 시 구역1 작물 상태 | **전부 Ready(성장 완료)** | 기다림 0 |
| 바닥 화살표 | 스폰 → 밭 중심 | 글자 없는 튜토리얼 |
| 기본 운반량 | 10 | 밀 3×3=9 → 한 번 훑으면 딱 채워짐 → 🚫 → 판매대 화살표 |
| 판매대 거리 | 밭 가장자리에서 **12 studs** | 왕복 4초 |

→ 예상: 0:03 첫 수확, 0:08 스택 만땅, 0:14 첫 판매·코인 튐, 0:18 첫 코인 획득.

### 5-2. 작물 배치 & 성장 (CropService)

- 구역별 밭은 `expansion` 단계에 따라 3×3 → 4×4 → 5×5 → 5×6 → 5×7 (Zones.luau의 `fieldGrid[expansion]`).
- 작물 간격 4 studs. 두 번째 작물(벼 등)은 별도 밭 블록.
- 서버는 `readyAt`만 가진다. 성장 단계 렌더는 클라이언트가 `workspace:GetServerTimeNow()`로 보간.

```lua
-- Crops.luau
return {
  Wheat  = { zone="Z1", price=1,  growSec=6,  mesh="rbxassetid://…", color=Color3.fromRGB(240,200,80) },
  Rice   = { zone="Z1", price=2,  growSec=8,  … },
  Corn   = { zone="Z2", price=5,  growSec=10, … },
  Potato = { zone="Z2", price=8,  growSec=12, … },
  Apple  = { zone="Z3", price=20, growSec=15, perTree=5, tree=true },
  Orange = { zone="Z3", price=30, growSec=18, perTree=5, tree=true },
}
```

- 성장 시간에 💧 성장속도 패드 배율(`1 - 0.08*lv`, 5단계 → ×0.6) 적용.
- 클라 성장 단계: 진행률 `p = 1 - (readyAt-now)/growSec`
  - `p < 0.4` 🌱 Scale 0.35
  - `p < 1.0` 🌿 Scale 0.35→0.85 선형
  - `p ≥ 1.0` 🌾 Scale 1.0 + **바운스** `y = 0.15*sin(t*4)` + 하이라이트(Emissive 0.3, Ready 색상 살짝 밝게)
- 나무(Z3): Ready 시 열매 5개가 가지에 달림. 수확 시 나무가 좌우로 흔들리고(Rotation ±6° 감쇠 0.6s) 열매가 떨어져 스택으로 날아감.

### 5-3. 수확 판정 (HarvestService, 서버 10Hz)

```lua
-- 공간 그리드
local CELL = 4
local function cellOf(p: Vector3) return Vector3.new(p.X // CELL, 0, p.Z // CELL) end

-- tick (플레이어별)
function HarvestService:_tick(rt: PlotRuntime, dt)
  local char = rt.owner.Character; if not char then return end
  local root = char.PrimaryPart; if not root then return end
  if rt.full then return end

  local st = Stats.compute(data, PadService:levelsAt(rt, root.Position))
  rt.harvestCooldown -= dt
  local budget = 0
  while rt.harvestCooldown <= 0 do budget += 1; rt.harvestCooldown += st.interval end   -- interval 0.05면 tick당 2개
  if budget == 0 then return end

  local now = workspace:GetServerTimeNow()
  local c = cellOf(root.Position)
  local candidates = {}
  for dx = -2, 2 do for dz = -2, 2 do                         -- R 최대 7 → ±2셀
    for _, crop in rt.grid[c + Vector3.new(dx,0,dz)] or {} do
      if crop.readyAt <= now and (crop.pos - root.Position).Magnitude <= st.radius then
        table.insert(candidates, crop)
      end
    end
  end end
  table.sort(candidates, function(a,b) return (a.pos-root.Position).Magnitude < (b.pos-root.Position).Magnitude end)

  local harvested = {}
  for i = 1, math.min(budget, #candidates, st.cap - #rt.stack) do
    local crop = candidates[i]
    table.insert(rt.stack, { cropId = crop.cropId })
    crop.readyAt = now + Crops[crop.cropId].growSec * PadService:growMult(rt, crop.zone)
    table.insert(harvested, { zone = crop.zone, idx = crop.idx })
    if Rng:chance(Economy.stoneDropRate) then EconomyService:addStones(rt.owner, 1, crop.pos) end  -- 3%
  end
  if #harvested > 0 then
    Remotes.HarvestBatch:FireAllClients({ plot = rt.plotIndex, items = harvested, stackCount = #rt.stack })
    Remotes.CropReset:FireAllClients(…)
    data.stats.totalHarvest += #harvested
  end
  if #rt.stack >= st.cap then rt.full = true; Remotes.StackFull:FireAllClients({ plot = rt.plotIndex, full = true }) end
end
```

- **가까운 것부터** 수확 → 캐릭터가 지나가는 궤적을 따라 "우수수" 쓸리는 느낌.
- 반경 R은 도구 ★에 따라 4.5 → 7.5 studs. 이 차이가 핵심 재미 ③의 시각 증거가 된다.

### 5-4. 수확 반경 링 (RadiusVisual, 클라)

- 캐릭터 발밑에 반투명 원형 Decal(또는 `CylinderHandleAdornment`) 반지름 = `st.radius`.
- 색: 도구 등급색. 미장착 시 흰색 알파 0.15.
- 반경이 커질 때(뽑기·패드) **0.4초 동안 링이 펄스**(Scale 1.3→1.0) + 링 색 플래시.
- 밭 위에서 Ready 작물이 링 안에 들어오면 작물 하이라이트가 한 톤 더 밝아짐(수확 예고).

### 5-5. 스택 비주얼 (StackVisual, 클라) — "우수수" 감각의 핵심

**구성**: 캐릭터 `Head` 위 `Attachment`에 스택 루트 Part(Massless, CanCollide false, Weld). 각 작물 아이템은 Part 1개 (MeshPart 재사용, 크기 1.2×0.5×1.2). 최대 표시 **30개**, 초과 시 `×N` 숫자 빌보드만 증가(성능).

**날아오기 (작물 → 스택)**
```
t = 0     : 작물 위치에서 아이템 Part 생성, 작물은 Scale 1.0→0.35로 0.12s 스쿼시(가로 1.2배 후 축소)
t = 0~0.25: 베지어 포물선 (시작, 중간점 +3 studs 위, 스택 top) — 회전 720°
t = 0.25  : 스택 top에 안착, 스택 전체가 아래로 0.15 stud 눌렸다가 스프링 복귀 (질량감)
```
동시에 도착하는 아이템은 **0.03s씩 시차** → 연속 "톡톡톡".

**흔들림 (스프링)**
```lua
-- Spring.luau: 감쇠 스프링 (stiffness 120, damping 10)
-- 매 프레임: 캐릭터 수평 속도 v(로컬 좌표)
targetTilt = Vector2.new(-v.Z, v.X) * 0.012        -- 이동 반대 방향으로 기울어짐
tilt = spring:update(dt, targetTilt)
for i, item in stack do
  item.CFrame = root.CFrame * CFrame.new(0, 0.5*i, 0) * CFrame.Angles(tilt.X * i/#stack, 0, tilt.Y * i/#stack)
end
```
→ 위쪽 아이템이 더 크게 휘어 "위태롭게 쌓인" 피자레디 감성. 급정지 시 반대로 출렁.

**만땅 🚫**
- 스택 최상단 위 BillboardGui 🚫(64px), 0.6s 주기 펄스.
- 스택 좌우 진동 ±3° 1회, 짧은 "붑" 사운드(1회만).
- `GuideTarget`이 판매대로 전환 → 바닥 화살표.

### 5-6. 사운드 피치 사다리 (AudioController)

```lua
combo, lastAt = 0, 0
function onHarvest(n)
  for i = 1, n do
    if tick() - lastAt > 0.6 then combo = 0 end
    combo = math.min(combo + 1, 20)
    play(Assets.SFX.Harvest, { pitch = 1.0 + 0.05 * combo, volume = 0.5 })   -- 1.0 → 2.0
    lastAt = tick()
  end
end
```
- 코인 획득도 동일 구조(별도 콤보, 피치 0.9 → 1.8).
- 동시 재생 상한 8개(SoundGroup), 넘으면 가장 오래된 것 생략.

### 5-7. 판매 & 코인 (SellService, CoinService)

**투입**
- 판매대 Part 중심 5 studs 이내 → 0.08s마다 스택 top 1개 제거, 가치 누적.
- `SellDeposit` 연출: 아이템이 스택에서 판매대 구멍으로 빨려 들어감(0.2s), 판매대가 살짝 부풀었다 복귀.
- 코인 가치 = `Σ price × zoneSellMult(Z2 트럭 1.2) × (coinX2 부스트 or 패스 ? 2 : 1)`.

**코인 생성 (물리 오브젝트)**
- 액면 단위 `{1, 5, 25, 100, 500, 2500}`으로 그리디 분해, 1회 투입당 **최대 8개** 오브젝트(초과분은 가장 큰 코인에 합산).
- 플롯당 바닥 코인 상한 **30개**. 초과 시 가장 가치 낮은 두 개를 합쳐 하나로(위치는 중간점).
- 스폰: 판매대 앞 반경 3~6 studs 랜덤, 위로 튀는 초기 속도(Server가 위치만 결정, 클라가 포물선 연출 0.5s 후 안착, 회전 애니메이션).
- 코인 크기는 액면에 따라 5단계(1: 0.8 stud → 2500: 2.2 stud, 금색 → 보라색).

**획득**
- 서버 tick: 캐릭터 6 studs 이내 코인 → `coins += value`, `CoinCollect` 전송.
- 클라: `CoinCollect` 수신 즉시 자석 연출(코인이 캐릭터 가슴으로 0.2s 흡수, 스케일 0) + 피치 사다리 + HUD 💰 롤링(0.3s).
- **선반영 없음**: 서버 판정 후 연출이라도 6 studs 자석 반경 덕분에 지연 체감이 없다.

### 5-8. 검수 기준 (핵심 재미 ①)

- [ ] 새 계정 스폰 후 **10초 이내** 첫 수확 이벤트가 Analytics에 기록된다.
- [ ] 이동 중 수확 시 아이템이 **가까운 순서**로 튀며 스택이 이동 반대 방향으로 기울어진다.
- [ ] 스택 30개 초과 시에도 클라 프레임 저하 없음(모바일 30fps 유지).
- [ ] 만땅 시 🚫 표시 + 판매대 화살표가 1초 이내 나타난다.
- [ ] 수확 반경 링이 도구 등급에 따라 4.5/5/5.5/6.5/7.5 studs로 정확히 그려진다.
- [ ] 판매 후 코인이 바닥에 흩뿌려지고 밟으면 자석처럼 빨려 온다. 코인 30개 상한 동작.

---

## 6. 핵심 재미 ③ — 첫 뽑기의 짜릿함

(②보다 먼저 경험하므로 먼저 기술)

### 6-1. Gacha.luau

```lua
return {
  Weights = { [1]=55, [2]=30, [3]=12, [4]=3 },        -- 합 100
  Pity = 10,                                           -- 10회 내 ★3 보장
  Effect = {
    Tool  = { 0.10, 0.25, 0.50, 1.00 },                -- 수확속도 배율 가산
    Shoes = { 0.10, 0.20, 0.35, 0.60 },
    Bag   = { 5, 15, 30, 60 },
  },
  Radius = { 0.5, 1.0, 2.0, 3.0 },                     -- 도구 ★별 수확 반경 추가
  Dismantle = { 1, 3, 10, 30 },                        -- 분해 시 💎
  StoneCost = 50,                                      -- 💎로 뽑기
  FreeRig = {                                          -- 무료 티켓 n회차 리깅
    [1] = { minStar = 3, forceSlot = "Tool" },         -- 첫 뽑기: ★3 이상 + 도구 고정
    [3] = { minStar = 2 },
  },
  Colors = { Color3.fromRGB(170,170,170), Color3.fromRGB(90,200,90), Color3.fromRGB(70,140,255), Color3.fromRGB(255,200,40) },
}
```

### 6-2. 알고리즘 (GachaService)

```lua
function GachaService:pull(player, currency)
  local d = Data[player]
  -- 1) 지불
  if currency == "Ticket" then
    if d.tickets < 1 then return end; d.tickets -= 1
  else
    if d.stones < Gacha.StoneCost then return end; d.stones -= Gacha.StoneCost
  end
  local isFree = (currency == "Ticket")
  local n = isFree and (d.gacha.freeCount + 1) or (d.gacha.paidCount + 1)

  -- 2) 등급
  local star = Rng:weighted(Gacha.Weights)
  if isFree and Gacha.FreeRig[n] then star = math.max(star, Gacha.FreeRig[n].minStar) end
  if d.gacha.pity >= Gacha.Pity - 1 then star = math.max(star, 3) end
  d.gacha.pity = (star >= 3) and 0 or (d.gacha.pity + 1)

  -- 3) 슬롯
  local slot = (isFree and Gacha.FreeRig[n] and Gacha.FreeRig[n].forceSlot) or Rng:pick({"Tool","Shoes","Bag"})

  -- 4) 장착 판정: 더 높은 ★만 교체. 같거나 낮으면 분해
  local cur = d.gear[slot]
  local equipped, gained = false, 0
  if not cur or star > cur.star then
    if cur then gained = Gacha.Dismantle[cur.star] end          -- 기존 장비 분해
    d.gear[slot] = { star = star }; equipped = true
  else
    gained = Gacha.Dismantle[star]
  end
  d.stones += gained
  if isFree then d.gacha.freeCount = n else d.gacha.paidCount = n end

  Remotes.GachaResult:FireClient(player, { slot=slot, star=star, equipped=equipped, stonesGained=gained, isFirst=(isFree and n==1) })
  Analytics:log(player, "Gacha", { n=n, free=isFree, star=star, slot=slot, equipped=equipped })
end
```

- **강화 단계는 세트 단위**이므로 장비 교체 시 강화가 소실되지 않는다(사용자 불만 방지).
- 정책: `PolicyService:GetPolicyInfoForPlayerAsync(player).ArePaidRandomItemsRestricted == true`이면 상점의 🎫 Robux 상품 버튼을 숨긴다. 💎 뽑기와 무료 티켓은 유지.

### 6-3. 첫 뽑기 유도 시나리오

| 시각 | 서버 | 클라 |
|---|---|---|
| Lv2 도달 (XP 100, 약 3분) | `LevelUp{tickets=1}` | ⭐ 폭발, 🎫 아이콘이 HUD로 날아가 `1` 표시 |
| 즉시 | `GuideTarget{kind="Gacha"}` | 광장 🎁 상자 위 🎫 아이콘 바운스 + 바닥 화살표. HUD 좌하 🎁 버튼 펄스 |
| 상자 4 studs 접근 | — | 🎫 또는 💎50 이상 보유 시 뽑기 화면 자동 오픈(이동 정지, 반경 밖으로 나가면 재무장). 화면: 상자 + [🎫 N] [💎 50] 버튼 + 확률 표 |
| 🎫 버튼 탭 | `RequestGacha{Ticket}` → ★3 Tool 확정 | §6-4 연출 |

- 뽑기 화면 오픈 중 캐릭터는 `WalkSpeed 0`(클라이언트 로컬). 1차 구현은 2D 패널(상자 아이콘·빛기둥·별 4개)이며 3D 뷰포트·카메라 고정은 폴리시 단계에서 검토.
- 이후에도 상자 근접(4 studs)으로 열리고, HUD 🎁 버튼(좌하 PC / 좌상 모바일, 🎫 배지·펄스)으로 어디서든 열 수 있다.
- 장착은 서버가 플레이어 어트리뷰트(GearTool/GearShoes/GearBag = ★)로 알리고 클라이언트 `GearVisual`이 모든 플레이어 캐릭터에 부착한다. 도구: 손잡이+등급색 날(★3+ Neon·트레일), 신발: 발 덧씌움, 가방: 등 뒤 상자. 크기 1.0/1.15/1.3/1.5.
- 판정 로직은 `Shared/GachaLogic.luau` 순수 함수로 분리되어 서버와 Lune 테스트가 공유한다 (`tests/Gacha.spec.luau`: 리깅 1,000회, 천장 10만 회, 분포 10만 회).

### 6-4. 뽑기 연출 타임라인 (GachaFX, 총 3.6s / ★3+ 4.4s)

| t(s) | 연출 | 사운드 |
|---|---|---|
| 0.00 | HUD 페이드아웃, 카메라 상자 정면(FOV 70→55 트윈 0.3s) | 드럼롤 시작 |
| 0.00–0.90 | 상자 진동: 진폭 0.05→0.4 stud, 주기 점점 짧아짐(0.12→0.05s) | 드럼롤 피치 상승 |
| 0.90 | 상자 뚜껑 살짝 열리며 **흰색** 빛 새어나옴 | — |
| 1.20 | 빛기둥 색이 등급색으로 **전환**(★1 회색은 그대로 흰→회 페이드) | 등급 사운드 (★3 "샤앙", ★4 "쿠웅") |
| 1.20 ★3+ | 화면 흰색 플래시 0.1s, **슬로모 구간 0.5s**(모든 트윈 시간 ×2), 컨페티 파티클 200개 | — |
| 1.50 (★3+ 2.00) | 뚜껑 팝, 장비 아이콘 3D 모델이 2 stud 위로 솟아 720° 회전, ★ 개수만큼 별이 순차 점등(0.1s 간격) | 별 점등 "띵" ×n |
| 2.40 (★3+ 2.90) | 장비가 캐릭터 슬롯으로 날아가 장착. 캐릭터 외형 즉시 교체(도구가 손에, 크기 등급별 1.0/1.15/1.3/1.5배, 등급색 트레일) | 장착 "촥" |
| 2.60 (★3+ 3.10) | **⚡ 파워 롤링** `100 → 150` (0.8s, 이징 OutQuint), 숫자 색 등급색, 스케일 1.4→1.0 | 롤링 틱음 |
| 2.60 | **수확 반경 링 펄스**: 4.5 → 6.5 studs로 커지며 링이 0.5s간 밝게 점멸 | — |
| 3.40 (★3+ 4.20) | 카메라 복귀, HUD 페이드인. 분해였다면 💎 `+N`이 HUD로 날아감 | — |
| 3.60 | `GuideTarget` → 가장 가까운 Ready 밭. **바로 달려가 차이를 느끼게** | — |

- 1.2s 이후 화면 탭으로 스킵 가능(즉시 결과 상태로 점프). 첫 뽑기는 스킵 불가.
- 첫 뽑기(`isFirst`)는 장착 직후 캐릭터 주변에 **3초간 금빛 오라** + 화면 하단에 🪓 아이콘 ↔ 🌾 아이콘 사이에 큰 `+50%` 숫자 배지 2초 표시(글자 없이 숫자·아이콘만).

### 6-5. 검수 기준 (핵심 재미 ③)

- [ ] 새 계정의 무료 1회차는 100% ★3 이상 Tool. 1,000회 시뮬레이션 테스트 통과.
- [ ] 3회차 무료는 100% ★2 이상. 10회 연속 ★3 미획득 케이스는 발생하지 않음(시뮬레이션 100,000회).
- [ ] 유료(💎/Robux) 뽑기는 리깅이 적용되지 않으며 실측 분포가 표기 확률 ±1%p 이내(100,000회).
- [ ] 뽑기 직후 수확 반경 링이 실제로 커지고, 같은 밭을 훑을 때 수확 개수/속도 차이가 체감된다(내부 플레이테스트 5인 중 5인 "차이 느껴짐").
- [ ] `ArePaidRandomItemsRestricted` 플레이어에게 Robux 🎫 버튼이 숨겨진다.

---

## 7. 핵심 재미 ② — 폭발 강화

### 7-1. 설계 결정: 장비 세트 단일 강화 단계

GDD의 "장비별 강화"를 **세트 단일 단계(0~30)**로 변경한다.

| 이유 | 설명 |
|---|---|
| 파워 점프가 크다 | 세 스탯에 동시에 곱해지므로 한 번의 폭발이 ⚡를 크게 움직인다 |
| 아이콘 UI에 맞다 | 버튼 하나(⚒️). 슬롯 선택 UI가 필요 없다 |
| 장비 교체와 충돌 없음 | 뽑기로 더 좋은 장비를 얻어도 강화가 유지된다 |
| 💎 사용 결정이 없다 | 어디에 쓸지 고민 없이 "모이면 터뜨린다"에 집중 |

효과: 단계당 **+3%** → 모든 장비 효과(도구·신발·가방)에 곱. +30 = ×1.9.

### 7-2. Enhance.luau

```lua
return {
  MaxLevel = 30,
  PerLevel = 0.03,
  MinBurst = 3,                 -- 이 단계 이상 올릴 수 없으면 강화대 비활성
  CritChance = 0.15,
  CritGain = 2,
  Cost = function(lv) return 2 + lv end,   -- 0→1: 2, 1→2: 3 …  (0→+5 = 20, 0→+10 = 65, 0→+30 = 495)
  Aura = { [5]="White", [10]="BlueFlame", [15]="Gold", [20]="Rainbow", [30]="Galaxy" },
  StepTimeMax = 0.20, StepTimeMin = 0.08, TotalTimeCap = 3.2,
}
```

### 7-3. 활성화 판정 (서버·클라 공용)

```lua
function Enhance.previewLevels(stones, lv): (levels: number, cost: number)
  local n, spent = 0, 0
  while lv + n < Enhance.MaxLevel and stones - spent >= Enhance.Cost(lv + n) do
    spent += Enhance.Cost(lv + n); n += 1
  end
  return n, spent
end
-- 활성: previewLevels(d.stones, d.enhance) >= MinBurst
```

- 클라 HUD의 💎 숫자 옆에 **⚒️ 미니 아이콘**이 활성 시 나타나 펄스. 강화대 자체도 빛나기 시작(PointLight + 파티클).
- `GuideService`는 활성 상태면 화살표를 강화대로 돌린다(우선순위 §10).
- 비활성일 때 강화대에 가면 버튼이 회색이고 아래에 `💎 12 / 20` 형태로 필요량 숫자만 표기.

### 7-4. 폭발 알고리즘 (EnhanceService)

```lua
function EnhanceService:burst(player)
  local d = Data[player]
  local levels = Enhance.previewLevels(d.stones, d.enhance)
  if levels < Enhance.MinBurst then return end

  local steps, from, spent = {}, d.enhance, 0
  while d.enhance < Enhance.MaxLevel and d.stones >= Enhance.Cost(d.enhance) do
    d.stones -= Enhance.Cost(d.enhance); spent += Enhance.Cost(d.enhance)
    local crit = Rng:chance(Enhance.CritChance)
    local gain = crit and Enhance.CritGain or 1
    gain = math.min(gain, Enhance.MaxLevel - d.enhance)
    d.enhance += gain
    table.insert(steps, { gain = gain, crit = crit })
  end
  local powerFrom = Stats.compute(dPrev …).power
  local powerTo   = Stats.compute(d …).power
  d.stats.enhanceBursts += 1
  Remotes.EnhanceResult:FireClient(player, { from=from, to=d.enhance, steps=steps, stonesSpent=spent, powerFrom=powerFrom, powerTo=powerTo })
  Analytics:log(player, "Enhance", { from=from, to=d.enhance, steps=#steps, crits=countCrits(steps) })
end
```

- 크리티컬은 💎를 추가로 소모하지 않고 단계만 2배 → "공짜 한 단계"의 기쁨.
- 남는 💎(다음 단계 비용 미달)는 그대로 보유 → 다음 폭발의 씨앗.

### 7-5. 💎 공급 곡선 (1시간 목표 ≈ 200)

| 출처 | 수량 | 근거 |
|---|---|---|
| 레벨업 (Lv3~10) | 10+10+20+30+30+40 = 140 | Economy.luau `LevelRewards` |
| 수확 드롭 3% | 약 1,800회 수확 × 3% ≈ 54 | 1시간 수확량 추정 |
| 뽑기 분해 | 5~15 | 티켓 8장 중 중복분 |
| 일일/타이머 상자 | 10 + 5~15 ×2 | 첫 세션 |

**예상 폭발 이벤트 (누적 💎 → 단계)**

| 시각 | 누적 💎 획득 | 폭발 | 단계 | 파워 예시 |
|---|---|---|---|---|
| ~20분 (Lv4) | ~30 | 1회 | 0 → **+6** (크릿 1회 가정) | ⚡178 → 205 |
| ~32분 (Lv6) | ~70 | 2회 | 6 → **+10** | |
| ~42분 (Lv7~8) | ~130 | 3회 | 10 → **+15** (금빛 오라) | |
| ~55분 (Lv9~10) | ~200 | 4회 | 15 → **+19** | |

→ MinBurst 3 규칙 때문에 어떤 폭발도 +3 미만이 없고, 초반은 비용이 싸서 +6~8이 터진다.

### 7-6. 강화대 UX (아이콘 전용)

```
 ┌────────────────────────────────┐
 │        ⚒️  +6                   │   ← 현재 세트 단계
 │   🪓 ★★★   👟 ★    🎒 ★★        │   ← 장착 장비 (효과 숫자 없음, 아이콘+별만)
 │                                │
 │        [ 💎 47 ]                │   ← 보유
 │                                │
 │      ╭──────────────╮          │
 │      │  ⚒️  ▲ +7     │  ← 활성: 노란 펄스, 예상 상승 단계 표시
 │      ╰──────────────╯          │   비활성: 회색 + `💎 12 / 20`
 │            ⚡ 205                │
 └────────────────────────────────┘
```

- 버튼은 **0.3초 홀드**로 발동(버튼 하단 게이지가 채워짐). 홀드 중 💎 아이콘들이 버튼 주위로 모이기 시작 → 기대감. 도중에 손을 떼면 게이지가 되감긴다.
- 홀드 완료 → `RequestEnhance` → 연출. 연출 중에는 닫기 불가. 서버 응답이 2초 안에 없으면 버튼이 다시 활성화된다.
- 강화대 근접(4 studs)으로 화면이 열린다(Lv4 미만은 열리지 않고 강화대 위 🔒 ⭐4 빌보드). HUD 💎 옆 ⚒️ 미니 배지와 강화대 위 ⚒️는 폭발 가능할 때만 표시·펄스.
- 구현 메모: 판정은 `Shared/EnhanceLogic.luau` 순수 함수(서버·Lune 공유). 크리티컬로 건너뛴 단계의 다음 비용은 **높아진 단계 기준**이므로 같은 💎로 총 단계 수는 같거나 적어질 수 있다(테스트 `tests/Enhance2.spec.luau`). HUD ⚡ 롤링은 연출 P3까지 보류(`HUDController:HoldPower`)해 화면 숫자와 동시에 굴러간다. 오라는 플레이어 어트리뷰트 `Enhance`를 읽어 `GearVisual`이 도구 날 파티클로 항상 표시하고, 폭발 직후 3초 전신 오라는 로컬 연출.

### 7-7. 폭발 연출 타임라인 (EnhanceFX)

`n = #steps`, `stepTime = clamp(TotalTimeCap / n, StepTimeMin, StepTimeMax)`

| 구간 | 연출 | 사운드 |
|---|---|---|
| **P0 흡수** 0.0–0.5s | 💎 파티클 `min(stonesSpent, 40)`개가 HUD 💎 위치에서 화면 중앙 강화대 장비로 소용돌이(나선 궤적)로 빨려 들어감. HUD 💎 숫자는 롤다운 | "슈우웅" 상승음 |
| **P1 타격** 0.5s ~ 0.5+n×stepTime | 각 step마다: 망치가 내려침(0.6×stepTime 낙하, 0.4 복귀) → 장비 Scale 1.0→1.25→1.0 펀치 → 상단 ⚒️ 숫자 `+6 → +7` 갱신(위로 튀는 숫자 팝업 `+1`) → 불꽃 스파크 20개 | 타격음 피치 `0.8 + 0.06×i` (최대 1.7) |
| P1 크리티컬 step | 팝업이 **금색 `+2`** 1.6배 크기, 카메라 흔들림 진폭 0.35 stud 0.25s, 화면 가장자리 금색 비네트 플래시, 스파크 60개 | 별도 "챙!" 고음 + 저음 킥 |
| P1 오라 임계 통과 | +5/+10/+15/+20/+30 통과 순간 장비 주변 오라 파티클 교체(White→BlueFlame→Gold→Rainbow→Galaxy), 0.15s 화면 플래시(해당 색) | 오라 "우웅" |
| **P2 폭발** P1 종료 +0.0–0.4s | 마지막 타격 후 장비에서 링 웨이브(반경 0→8 stud), 카메라 줌인 FOV 55→48 (0.15s) → 복귀(0.25s), 캐릭터 발밑 충격파 데칼 | 저음 "쿠웅" + 심벌 |
| **P3 파워 롤링** +0.4–1.4s | **⚡ 숫자 롤링** `powerFrom → powerTo` (1.0s, OutExpo). 숫자 스케일 1.6→1.0, 색 흰→금. 롤링 중 초당 12회 틱음. 완료 시 `▲ +27` 서브 숫자 0.6s 표시 | 틱음 + 완료 "따란" |
| **P4 여운** +1.4–4.4s | 캐릭터 몸 전체에 현재 오라 색 3초 지속. 장비 3개 아이콘이 차례로 반짝 | — |
| P4 | `GuideTarget` → 가장 가까운 Ready 밭. 강화대는 **항상 밭에서 15 studs 이내**에 배치해 5초 안에 체감 | — |

- n이 15 이상이면 stepTime이 0.08s까지 줄어 **"드르르륵"** 연타감. n 3~5는 0.2s로 한 방 한 방 묵직하게. 두 리듬이 모두 즐겁도록 사운드 두 세트 준비(느린 망치 / 빠른 망치).
- 모바일 햅틱: 크리티컬 `HapticService` Medium, P2 Heavy.

### 7-8. 검수 기준 (핵심 재미 ②)

- [ ] 어떤 상태에서도 강화대 활성 시 최소 +3 상승. `previewLevels` 단위 테스트(경계: 💎 8→비활성, 9→+3).
- [ ] 크리티컬은 💎 추가 소모 없이 +2. 100,000 step 시뮬레이션에서 크릿률 15% ±0.5%p.
- [ ] 연출 총 길이가 n에 무관하게 **P0~P3 4.6초 이내**.
- [ ] 연출 후 ⚡ HUD 값 == `Stats.compute` 서버 값(불일치 0건).
- [ ] 첫 세션 20분 내 첫 폭발 도달률 90% 이상(내부 테스트 10인).
- [ ] 폭발 직후 밭에서 수확 속도 차이 체감(테스터 설문 4/5 이상).

---

## 8. 경제·진행 시스템 상세

### 8-1. Economy.luau

```lua
return {
  XPPerCoin = 1,
  LevelXP = { [2]=150, [3]=1000, [4]=4000, [5]=8000, [6]=14000, [7]=28000, [8]=42000, [9]=65000, [10]=100000 }, -- 누적. 시뮬레이터(tools/sim.luau) 60분 누적 코인 곡선에서 역산
  LevelRewards = {
    [2]={tickets=1}, [3]={stones=10}, [4]={tickets=1, stones=10}, [5]={stones=20},
    [6]={tickets=2}, [7]={stones=30}, [8]={tickets=2, stones=30}, [9]={stones=40}, [10]={tickets=3},
  },
  LevelUnlocks = { [2]="Gacha", [3]="GateZ2", [4]="Enhance", [6]="GateZ3", [10]="GateZ4Teaser" },
  StoneDropRate = 0.01, -- 3%면 60분 수확 1.3만 회 × 3% ≈ 400개로 폭발 9회 이상 → 1%로 조정 (시뮬 6회)
  CoinDenoms = { 1, 5, 25, 100, 500, 2500 },
  MaxGroundCoins = 30,
  DailyChest = { stones=10, ticketChance=0.3 }, TimerChest = { everySec=1200, stonesMin=5, stonesMax=15 },
}
```

### 8-2. Zones.luau (요약)

```lua
return {
  Z1 = { gateCost=0,     minLevel=1,  crops={"Wheat","Rice"},   crop2Cost=150,   sellMult=1.0,
         fieldGrid={ {3,3},{4,4},{5,5},{5,6},{5,7} }, expansionCost={20,45,100,200},
         workerCost={400}, workerMax=1, hasGrowPad=false, origin=CFrame.new(0,0,0) },
  Z2 = { gateCost=800,   minLevel=3,  crops={"Corn","Potato"},  crop2Cost=2000,  sellMult=1.2,
         fieldGrid=…, expansionCost={300,600,1200,2000}, workerCost={3000}, workerMax=1, hasGrowPad=true, growPadBase=800, origin={75,0,0} },
  Z3 = { gateCost=8000,  minLevel=6,  crops={"Apple","Orange"}, crop2Cost=15000, sellMult=1.0,
         treeGrid={ {2,2},{2,3},{3,3},{3,4} }, expansionCost={3000,5000,8000,12000}, workerCost={10000,20000}, workerMax=2, origin={0,0,85} },
  Z4 = { gateCost=60000, minLevel=10, teaser=true, origin={75,0,85} },
}
```

### 8-3. Pads.luau

```lua
return {
  Move    = { base=30, mult=1.45, max=15, icon="Shoe" },
  Harvest = { base=40, mult=1.45, max=15, icon="Sickle" },
  Cap     = { base=25, mult=1.45, max=15, icon="Bag" },
  Grow    = { base=800, mult=1.8, max=5, icon="Drop" },     -- Z2에서 해금, 전 구역 성장에 적용
  cost = function(def, lv) return math.floor(def.base * def.mult ^ (lv - 1)) end,
  DrainPerSec = function(cost) return math.max(5, cost / 1.5) end,   -- 총비용 기준 선형: 어떤 패드도 서 있으면 1.5초 내 완료 (잔액 비례로 하면 지수 감소해 끝이 안 남)
}
```

- 패드는 **구역별 독립**(Z1_Move, Z2_Move…)이 아니라 **스탯 3종은 계정 공용**, 단 구역마다 패드 오브젝트가 있어 어디서든 올릴 수 있다(동일 단계 공유). Grow 패드는 Z2 이후 존재.
- `levelsAt()`는 따라서 위치 무관하게 공용 단계를 돌려준다(Stats 인터페이스 유지).

### 8-4. 패드 흐름 (PadService)

```
플레이어가 패드 Part 상단 3 studs 이내 & 0.3s 이상 정지(속도 < 2)
  → 매 tick: drain = min(coins, remaining, ceil(DrainPerSec(cost) * dt)); coins -= drain; paid += drain
  → PadProgress (게이지 = paid/cost, 코인 파티클 캐릭터→패드 스트림)
  → paid >= cost: level += 1; paid = 0; PadComplete
       · 스탯 패드: 링 펄스(Move: 발밑 속도 라인 / Harvest: 반경 링 / Cap: 스택 최대치 숫자 점프)
       · 밭 확장: 새 작물 칸이 땅에서 솟아오름(0.5s), 첫 상태 Ready
       · 일꾼: 로봇이 패드에서 조립되는 연출 1.2s
       · 게이트: 문이 열리고 안개 걷힘, 카메라 2s 팬 → 복귀
```

- 코인이 0이 되면 스트림이 멈추고 패드 위 💰 아이콘이 회색 → 부분 결제 유지.

### 8-5. 일꾼 (WorkerService)

```
상태기계: Idle → GoField → Harvest → GoSell → Deposit → Idle
속도 8 studs/s, 수확 간격 0.5s, 용량 10, 수확 반경 4.5 (Layout.Worker)
Harvest: 반경 내 Ready 작물을 0.5s마다 1개. 없으면 가득 차기 전까지 다음 Ready 작물로 GoField,
         가득 찼거나 구역에 Ready가 없을 때만 GoSell. 판매 시 코인은 소유자에게 직접 가산(바닥 코인 없음)
이동: 서버는 구간(leg: from, to, t0, dur)만 갖고 WorkerState로 전송. 클라이언트가 시간 보간으로 모델을 움직인다
      (Humanoid·물리 없음, 앵커드 파트 3개). 늦게 접속한 클라는 다음 leg 부터 동기화
일꾼 속도 업그레이드(3단계)는 2차 스코프
```
- 일꾼 결과는 소유자 코인으로 직접 가산되며 코인 오브젝트는 생성하지 않는다(바닥 코인 상한 보호). 대신 일꾼 머리 위 `+N💰` 텍스트 팝업.

### 8-6. 1시간 자원 시뮬레이션 (목표 검증용)

Config 로드 → 헤드리스 시뮬레이터(`tools/sim.luau`, Lune 실행)로 "이상적 플레이어" 60분 궤적을 계산해 다음을 검증:

| 지표 | 목표 |
|---|---|
| Z2 해금 | 13~17분 |
| Z3 해금 | 32~38분 |
| Lv10 | 55~62분 |
| 폭발 강화 횟수 | 4~6회 |
| 60분 누적 코인 | 120K~180K |

수치 튠은 시뮬레이터 통과 후 실플레이로 보정.

**1차 튠 결과 (2026-09-19, seed 1·2)**: Z2 해금 16~19분, Z3 해금 37~39분, Lv10 53~55분, 폭발 강화 6~7회, 60분 누적 코인 128K~146K.
조정 내용: Z2 게이트 1,500→800, Z3 12,000→8,000, Z4 80,000→60,000, XP 테이블 재산정, 💎 드롭 3%→1%.
시뮬레이터 가정: 플레이어는 가장 비싼 열린 구역에서만 수확, 가이드 우선순위대로 소비하며 게이트 목표 중에는 게이트 잔액의 20% 이하 패드만 구매.
실행: `lune run tools/sim [분] [seed] [cheapRatio]`

---

## 9. 상점 (ShopService, Products.luau)

```lua
return {
  Passes = {
    SpeedPass   = { id=0, effect="speed",   mult=1.5, icon="ShoeGold", price=149 },
    HarvestPass = { id=0, effect="harvest", mult=2,   icon="SickleGold", price=199 },
    BagPass     = { id=0, effect="cap",     mult=2,   icon="BagGold", price=149 },
    CoinPass    = { id=0, effect="coin",    mult=2,   icon="CoinGold", price=299 },
    WorkerPass  = { id=0, effect="worker",  mult=2,   icon="RobotGold", price=249 },
  },
  Products = {
    Stones50   = { id=0, grant={stones=50},   price=49 },
    Stones300  = { id=0, grant={stones=300},  price=199 },
    Ticket1    = { id=0, grant={tickets=1},   price=39,  randomItem=true },
    Ticket10   = { id=0, grant={tickets=10},  price=299, randomItem=true },
    BoostX2    = { id=0, grant={coinX2Sec=900}, price=29 },
    GrowAll    = { id=0, grant={growAll=true}, price=19 },
    SkipGate   = { id=0, dynamic=true },       -- 게이트 잔액에 비례, Robux 가격은 사전 정의된 3티어 중 선택
  },
}
```

- 패스 소유는 접속 시 `UserOwnsGamePassAsync`로 동기화 + `PromptGamePassPurchaseFinished`. `id = 0`(미등록)인 패스·상품은 상점 카드에 🚧 오버레이로 표시되고 프롬프트를 열지 않는다 → ID 없이도 게임이 돌아간다.
- 영수증: `ProcessReceipt`에서 `PlayerData.purchases`(최근 50개 PurchaseId)로 중복 지급을 막고, 데이터 로드 전이면 `NotProcessedYet`. 효과 적용은 `ShopService:Grant(player, key)` 하나로 모아 디버그(`Debug:Invoke("grant")`)와 공유.
- 지급 연출은 `Reward` 리모트 → 클라 `LevelUpFX`가 아이콘을 HUD로 날린다 (일일 상자도 동일 경로).
- 패스 구매 즉시: 해당 장비 외형에 금색 트림 + 파워 롤링 연출(뽑기와 동일 FX 재사용).
- `randomItem=true` 상품은 정책 제한 플레이어에게 노출 금지.
- 상점 화면: 아이콘 + Robux 로고 + 숫자만. 카드 6개, 좌우 스크롤.

---

## 10. 가이드 시스템 (GuideService) — 글자 없는 튜토리얼

서버가 1초마다 "다음 목표"를 우선순위로 산출해 `GuideTarget` 전송. 클라는 바닥 화살표 빔 + 목표 위 아이콘 바운스로 표현.

| 우선순위 | 조건 | 목표 | 아이콘 |
|---|---|---|---|
| 1 | 스택 만땅 | 현재 구역 판매대 | 🏪 |
| 2 | `tickets > 0` | 광장 🎁 | 🎫 |
| 3 | 강화 활성(`previewLevels ≥ 3`) | 광장 ⚒️ | 💎 |
| 4 | 레벨 조건을 만족한 다음 게이트가 있으면 **잔액이 부족해도 게이트가 목표** (저축 유도). 결제 가능하면 🔓, 아니면 화살표는 밭·보조 마커 🔒는 게이트 | 게이트 | 🔓 / 🔒 |
| 4′ | 저축 중이라도 게이트 잔액의 20% 이하인 싼 패드는 계속 안내 (`GuideService.CheapPadRatio`) | 해당 패드 | 해당 아이콘 |
| 5 | 게이트 목표가 없을 때: 결제 가능한 가장 싼 패드/확장/일꾼 | 해당 패드 | 해당 아이콘 |
| 6 | 그 외 | 가장 가까운 Ready 작물 밀집 지점 | 🌾 |

- 튜토리얼 단계(`tutorial`)는 0~6까지 최초 이벤트에 맞춰 증가하고, 각 단계 최초 1회는 **유령 손가락**(반투명 손 아이콘이 목표 위에서 탭 애니메이션) 추가. 6 이후 손가락은 사라지고 화살표만 남는다.
- 화살표는 플레이어가 목표 6 studs 이내면 숨김.

---

## 11. UI 명세 (아이콘 전용)

### 11-1. HUD

| 요소 | 위치 | 구성 | 갱신 |
|---|---|---|---|
| ⭐ 레벨 | 좌상 | ⭐ 아이콘 + 레벨 숫자 + XP 바(240×14px) | `DataPatch` |
| ⚡ 파워 | 중앙 상단 | ⚡ + 숫자(굵게 40px) | 스탯 변화 시 롤링 |
| 💰 코인 | 우상 | 💰 + `Format.short(n)` (1.2K / 3.4M) | 롤링 0.3s |
| 💎 강화석 | 우상 💰 아래 | 💎 + 숫자, 활성 시 ⚒️ 미니 배지 펄스 | |
| 🎁 뽑기 | 좌하(PC) / 좌상 아래(모바일) | 🎁 + 티켓 수 배지 | 티켓>0 펄스 |
| 🛒 상점 | 우하 | 🛒 | 세일/부스트 중 타이머 링 |
| 스택 카운트 | 캐릭터 머리 위 | `7/10`, 만땅 시 🚫 | `HarvestBatch` |
| 말풍선 | 상호작용 오브젝트 위 | 아이콘 + 이름 + 비용/요구/안내 + 게이지 | 상태 변경 시 |

- 폰트: 숫자 전용 둥근 산세리프(Roblox `GothamBold` 대체). 숫자 외 문자열 사용 금지 — lint 룰로 `TextLabel.Text`에 한글/영문 포함 시 빌드 경고(스크립트 `tools/check_no_text.luau`).
- 안전영역: 모바일 노치 대응 `ScreenGui.IgnoreGuiInset=false`, 하단 조이스틱 영역(좌하 200×200) 회피.

### 11-2. 등급 색 (Assets.luau)

| ★ | 이름 | HEX | 사용처 |
|---|---|---|---|
| 1 | Common | `#AAAAAA` | 빛기둥, 링, 테두리 |
| 2 | Uncommon | `#5AC85A` | |
| 3 | Rare | `#468CFF` | |
| 4 | Legendary | `#FFC828` | |

오라 색: White `#FFFFFF`, BlueFlame `#4AA8FF`, Gold `#FFC828`, Rainbow(HSV 회전), Galaxy(보라 `#8A4DFF` + 별 파티클).

### 11-3. 아이콘 에셋 목록

256×256 PNG, 플랫, 2px 어두운 외곽선, 단일 시각 언어. 파일명 = Config 키.

`Coin, Stone, Ticket, Star, Shoe, Sickle, Bag, Bolt, Lock, Unlock, Shop, Gift, Anvil, Robot, Truck, Stall, Drop, NoEntry, Arrow, Hand, Construction, ShoeGold, SickleGold, BagGold, CoinGold, RobotGold, Wheat, Rice, Corn, Potato, Apple, Orange`

### 11-4. 화면 (모달)

- **뽑기**: 상자 3D 뷰포트, 하단 `[🎫 N]` `[💎 50]` 두 버튼, 우측 확률 `★ 55  ★★ 30  ★★★ 12  ★★★★ 3` (숫자만, % 아이콘). 닫기 `✕`.
- **강화**: §7-6.
- **상점**: §9.
- 모든 모달은 열릴 때 `WalkSpeed 0`, 닫힐 때 복구. ESC/뒤로 지원.

---

## 12. 레벨 디자인 (월드 배치) — v3: 작은 마을 중앙 + 사방 해금

원칙: ① 관리 영역(작은 마을)은 플롯 **중앙**, ② 구역은 마을에서 **북·동·남·서로 하나씩 해금**, ③ **해금 전 구역·기능은 아예 보이지 않음**, ④ 동선을 짧게.

```
               [Z1 북: 밀·벼]
                     │ 게이트
  [Z4 서 🚧] ─ 게이트 ─ (작은 마을) ─ 게이트 ─ [Z2 동: 옥수수·감자]
                     │ 게이트
               [Z3 남: 과수원]
```

- 플롯 180×180, 3×2 격자(간격 200), 월드 바닥은 격자 + 200. 플롯 둘레는 흰 말뚝 울타리.
- **작은 마을**(반지름 26): 흙빛 광장 3겹 + 집 3채(박공 지붕) + 가로등 6 + 통·상자. 밝은 크림 광장을 흙빛으로 낮춰 초록 밭과 대비를 준다.
  - 스폰 (0,0,5), 북쪽 밭을 바라본다.
  - 🎁 뽑기 (-11,0,-11) · ⚒️ 강화 (11,0,-11) · 🛒 상점 (11,0,11)
  - **공용 스탯 패드는 마을에** 둔다 (전 구역 공통이므로): 👟 (-16,0,3) · 🌾 (-14,0,9) · 🎒 (-10,0,14) · 💧 (-3,0,17)
  - 구역 게이트 4개는 마을 가장자리(중심에서 23).
- 구역 프레임: 마을이 -Z, 구역이 +Z. 구역별 yaw(북 180° · 동 90° · 남 0° · 서 -90°)로 회전. 원점은 중심에서 30.
  - 밭1 (0,0,6) → 중심에서 36, 밭2 (0,0,38), 판매대 (-16,0,2)는 밭1에서 16 studs, 확장 (16,0,2), 일꾼 (16,0,12), 구역 바닥 50×60.
- **동선**: 마을 중심 → 밭1 36 studs(약 2초), 밭 ↔ 판매대 16 studs. 이전 v2 대비 각각 10·6 studs 단축.

### 12-2. 기능 해금 순서 (`Shared/Unlocks.luau`)

처음부터 버튼을 늘어놓지 않고 하나씩 드러낸다. 조건을 만족하기 전에는 월드에서 **보이지 않고 결제도 되지 않는다**(서버 `PadService` 도 같은 규칙으로 막는다).

| 순서 | 대상 | 조건 |
|---|---|---|
| 1 | 🏪 판매대 | 첫 수확 (tutorial ≥ 1) |
| 2 | 👟 이동 속도 | 첫 판매 (tutorial ≥ 2) |
| 3 | 🌾 수확 속도 | 👟 1단계 |
| 4 | 🎒 가방 크기 | 🌾 1단계 |
| 5 | 🟫 밭 넓히기 | 🎒 1단계 |
| 6 | 🎁 뽑기 | Lv2 |
| 7 | 🍚 벼 심기 | 밭 확장 1단계 |
| 8 | 🤖 일꾼 고용 | 벼 해금 |
| 9 | 🔒 2구역 게이트 | Lv3 |
| 10 | ⚒️ 강화대 | Lv4 |
| 11 | 🛒 상점 | Lv5 |
| 12 | 💧 성장 촉진 | 2구역 해금 |
| 13~ | 3·4구역 게이트 | 직전 구역 해금 |

2·3구역의 패드는 구역 게이트 자체가 관문이므로 해금과 동시에 전부 보인다.
새로 열리면 말풍선이 튀어오르고 소리가 난다.

### 12-1. Y 레이어 (바닥 깜박임 방지)

같은 높이의 면이 겹치면 카메라가 움직일 때 z-fighting 으로 바닥이 깜박인다. 바닥·판·데칼류는 `Layout.Y` 값만 사용한다.

| 레이어 | Y (윗면) | 대상 |
|---|---|---|
| World | 0.00 | 월드 바닥 |
| Path | 0.08 | 플롯 사이 통로 |
| Plot | 0.20 | 플롯 바닥 (= `Layout.GroundY`, 오브젝트 기준면) |
| HubRing | 0.30 / 0.36 / 0.42 | 마을 광장 3겹 |
| Zone | 0.32 | 구역 바닥 |
| Tile | 0.60 | 밭 타일 (작물이 이 위에 선다) |
| Ring | 0.75 | 수확 반경 링 |
| Dash | 0.90 | 가이드 화살표 대시 |

원인 1: 월드 바닥과 플롯 바닥의 윗면이 둘 다 0.1 로 완전히 겹쳐 있었다.
원인 2: **Roblox 기본 Baseplate 의 윗면이 정확히 Y=0** 이라 월드 바닥과 또 겹쳤다 → `WorldService` 가 Baseplate 와 SpawnLocation 을 제거한다.
레이어 간격은 최소 0.08 studs 를 유지한다.

## 13. 성능 예산

| 항목 | 예산 |
|---|---|
| 서버 tick | 10Hz. 플레이어 1인 tick ≤ 0.3ms (그리드 25셀 × 평균 4작물) |
| 작물 Part | 플롯당 ≤ 200 (5×7×2 + 나무 12×5). 전 서버 ≤ 1,200 |
| 스택 Part | 캐릭터당 ≤ 30 |
| 바닥 코인 | 플롯당 ≤ 30 |
| 파티클 | 화면 동시 이미터 ≤ 12, 강화 P1 스파크는 이미터 1개 `Emit(n)` |
| Remote | 플레이어당 ≤ 20 msg/s (HarvestBatch·CropReset 배칭) |
| 메모리 | 클라 < 800MB (모바일 저사양) — StreamingEnabled, 타 플롯 작물 LOD(30 studs 밖은 성장 애니메이션 정지) |
| 사운드 동시 재생 | 8 |

- 작물은 단일 MeshPart 템플릿 `:Clone()`, 색·크기만 변경. 텍스처 1장(아틀라스).
- 타 플레이어 플롯의 `HarvestBatch` 연출은 100 studs 밖이면 무시.

---

## 14. 보안 / 안티치트

- 클라는 상태 변경 요청을 3종(`RequestGacha`, `RequestEnhance`, `RequestPurchase`)만 보낸다. 나머지는 위치 기반 서버 판정.
- 텔레포트/스피드핵 대응(`AntiCheatService`): 10Hz tick 마다 수평 이동 거리가 `(speed × 1.4 + 6) × dt` 를 넘으면 0.5초간 의심 상태 → 수확·코인 획득 무효(킥 없음, 3회 누적마다 warn). 스폰·리스폰 후 3초 유예, 서버가 의도적으로 순간이동시킬 때는 `AntiCheatService:Grace(player)`.
- 패드 드레인은 서버 코인 잔액에서만 차감.
- 영수증 중복 처리 방지(§2-4). `PromptProductPurchase`는 서버에서만 호출.
- Remote 페이로드 타입 검증(`t` 라이브러리), 실패 시 무시.

---

## 15. 분석 이벤트 (AnalyticsService)

`AnalyticsService:LogCustomEvent` 래퍼(`Services/AnalyticsService.luau`, customFields 최대 3개, Studio 에서는 콘솔 출력). 이벤트명·필드:

| 이벤트 | 필드 | 퍼널 |
|---|---|---|
| `Session_Start` | isNew | |
| `First_Harvest` | secSinceSpawn | ① |
| `First_Sell` | secSinceSpawn | ① |
| `Level_Up` | level, sec | |
| `Gacha` | n, free, star, slot, equipped | ③ |
| `Enhance` | from, to, steps, crits, sec | ② |
| `Pad_Complete` | padId, level, sec | |
| `Zone_Unlock` | zone, sec | |
| `Purchase` | productKey, robux | |
| `Session_End` | playtimeSec, level, power, coins | |

핵심 대시보드: 스폰→첫 수확 중위값(목표 <10s), Lv2 도달률·시각, 첫 뽑기 후 5분 잔존율, 첫 폭발 도달 시각, Z2/Z3 해금률.

---

## 16. 테스트 계획

### 16-1. 단위 테스트 (Lune + TestEZ)

- `Stats.compute` 경계값(속도 cap 40, interval min 0.03, 파워 기준 100/150).
- `Enhance.previewLevels` 경계(8→0, 9→3, 20→5, 495→30).
- `GachaService` 시뮬레이션: 리깅·천장·확률 분포(§6-5).
- `Format.short` (999 → 999, 1000 → 1K, 1,250,000 → 1.25M).
- `CoinService` 액면 분해·상한 병합.

### 16-2. 통합 (Studio 플레이 테스트, 2인 서버)

- 두 플레이어가 서로 플롯을 침범해도 수확·코인 획득이 소유자에게만 발생.
- 접속 종료 → 재접속 시 스택은 사라지고(저장 안 함) 코인·단계·장비 유지.
- 서버 셧다운 중 저장 손실 0건(`BindToClose`).

### 16-3. 플레이테스트 프로토콜 (핵심 재미 검증)

- 대상: 내부 10인(게이머 5 / 비게이머 5), 무설명 60분.
- 관찰 항목: 첫 수확까지 시간, 처음 멈춰 서서 "무엇을 해야 하나" 고민한 시각과 횟수, 첫 뽑기 시 표정/발화, 첫 폭발 강화 시 반응.
- 설문(아이콘 5점 척도 ☹️~😍): 수확 재미 / 뽑기 재미 / 강화 재미 / 다음에 또 하고 싶은가.
- 통과선: 세 핵심 재미 평균 4.0 이상, 글자 없이 진행 막힘 0건(막히면 가이드 우선순위 수정).

---

## 17. 작업 분해 (WBS, 4주 · 1인 개발 기준 시간)

### Week 1 — 코어 루프 (핵심 재미 ①)

| 작업 | 시간 |
|---|---|
| Rojo/Wally 셋업, 서비스 골격, Remotes, Types | 6 |
| DataService(ProfileService) + 기본값·마이그레이션 | 6 |
| PlotService: 6플롯 생성·할당·스폰 | 6 |
| CropService: 배치·readyAt·CropReset, 클라 성장 보간 | 8 |
| HarvestService: 그리드·tick·cap·StackFull | 8 |
| StackVisual: 포물선·스프링·🚫 | 10 |
| RadiusVisual | 3 |
| SellService/CoinService: 투입·액면·스폰·자석 | 10 |
| AudioController 피치 사다리 | 3 |
| **소계** | **60** |

### Week 2 — 진행·경제

| 작업 | 시간 |
|---|---|
| EconomyService: XP·레벨·보상·LevelUpFX | 6 |
| PadService: 드레인·게이지·3패드·확장·Grow | 10 |
| 게이트·안개·카메라 팬, Z2/Z3 레이아웃, 나무 수확 | 10 |
| WorkerService 상태기계 + 모델 | 8 |
| GuideService + GuideArrow + 유령 손가락 | 8 |
| HUD(아이콘) + Format | 6 |
| 시뮬레이터 `tools/sim.luau` + 1차 튠 | 8 |
| **소계** | **56** |

### Week 3 — 핵심 재미 ②③

| 작업 | 시간 |
|---|---|
| GachaService(리깅·천장·분해·정책) + 단위 테스트 | 8 |
| GachaScreen + GachaFX 타임라인 + 장비 외형 교체 | 14 |
| EnhanceService + previewLevels + 테스트 | 5 |
| EnhanceScreen(홀드) + EnhanceFX(P0~P4) + 오라 5종 | 16 |
| 파워 롤링 컴포넌트(공용), 카메라 줌·쉐이크 | 5 |
| 💎 드롭 연출, 타이머/일일 상자 | 6 |
| **소계** | **54** |

### Week 4 — 상점·폴리시·검증

| 작업 | 시간 |
|---|---|
| ShopService(패스·상품·영수증·정책) + ShopScreen | 10 |
| AnalyticsService 이벤트 | 4 |
| 아이콘 32종 제작/업로드(미완: 이모지 대체 중), 사운드 18종(Creator Store 무료 오디오로 채움) | 12 |
| 안티치트(속도 검증), 레이트리밋 | 4 |
| 성능 프로파일링(모바일), StreamingEnabled 튠 | 6 |
| 플레이테스트 10인 + 튠 2회전 | 12 |
| `check_no_text` 린트, 버그픽스 버퍼 | 8 |
| **소계** | **56** |

**총계 약 226시간.** 2인이면 주당 30시간 페어로 4주 가능.

---

## 17-1. 구현 현황 (2026-09-19)

| 단계 | 상태 | 비고 |
|---|---|---|
| 0 셋업 / 1 뼈대 | ✅ | Rokit·Rojo·Wally·Lune, DataService(ProfileService v2 스키마), Stats, Remotes |
| 2 핵심 재미 ① | ✅ | 반경 4.5, 스택 스프링, 코인 자석 |
| 3 경제 루프 | ✅ | 패드 선형 드레인, 레벨업, 가이드(저축 유도), HUD |
| 4 확장 | ✅ | Z2·Z3·게이트·안개·과수원·일꾼, 시뮬레이터 튠 |
| 5 핵심 재미 ③ | ✅ | GachaLogic 테스트, 2D 뽑기 화면, GearVisual |
| 6 핵심 재미 ② | ✅ | EnhanceLogic 테스트, 홀드 버튼, P0~P4 연출, 오라 |
| 7 상점·마무리 | ◐ | ShopService·정책·영수증·분석·안티치트·일일 상자·사운드 완료. **미완**: 상품 ID 등록(대시보드), 아이콘 PNG, 모바일 프로파일링, 10인 플레이테스트 |
| 2차 스코프 | — | 타이머 상자, 일꾼 속도 업그레이드, 3D 뽑기 뷰포트·카메라 고정, Rewarded Video, 오프라인 수익, 환생 |

## 18. 미결 사항

| # | 항목 | 현재 초안 | 결정 필요 시점 |
|---|---|---|---|
| 1 | 게임 명칭·아이콘 로고 | 🌾⚡ | Week 4 스토어 등록 전 |
| 2 | 리깅 3회차 이후 추가 보정(5회차 ★2 보장 등) | 없음 | Week 3 플레이테스트 후 |
| 3 | 강화 상한 30 도달 후 처리 | 버튼 비활성 + 🚧 | 2차 스코프(환생) |
| 4 | Rewarded Video(13+) 도입 | 미도입 | 출시 후 |
| 5 | 오프라인 일꾼 수익 | 미도입 | 2차 |
| 6 | 서버 인원 6 vs 8 | 6 | 성능 측정 후 |
