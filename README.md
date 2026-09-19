# SUPER FARM

Roblox 아이들 아케이드 농장 타이쿤. 기획: `docs/GDD_v0.1.md`, 개발 명세: `docs/DevSpec_v0.1.md`.

## 셋업
```bash
rokit install          # rojo, wally, lune, stylua, selene (rokit.toml 고정 버전)
wally install          # Packages/
rojo serve             # Studio의 Rojo 플러그인에서 Connect (localhost:34872)
```

## 일상 명령
```bash
lune run tests/run             # 단위 테스트 (Stats·Enhance·Gacha·PadLogic·Format·Util)
lune run tools/sim 60 1        # 60분 경제 시뮬레이터 (분, seed, [cheapRatio])
lune run tools/check_no_text   # 클라 UI 텍스트 금지 린트 (숫자·아이콘·기호만 허용)
stylua src tests && selene src # 포맷 + 린트
```

## 구조
- `src/shared`  → ReplicatedStorage/Shared (Config, Types, Stats, PadLogic, GachaLogic, EnhanceLogic, Remotes, Util)
- `src/server`  → ServerScriptService/Server (Services/*, Vendor/ProfileService)
- `src/client`  → StarterPlayerScripts/Client (Controllers/*, Controllers/UI/*)
- `tools/`      → Lune 스크립트 (경제 시뮬레이터, 텍스트 린트)
- `tests/`      → Lune 단위 테스트 (`_shim.luau` 이 Roblox식 require 를 흉내냄)

## Studio 디버그 (Play 중 커맨드바)
```lua
-- 서버
local D = game.ServerStorage.Debug
D:Invoke("get")                          -- PlayerData
D:Invoke("set", nil, "coins", 5000)      -- 필드 설정 (경로: "pads.Move.level" 등)
D:Invoke("add", nil, "stones", 30)
D:Invoke("gacha", nil, "Ticket")         -- 뽑기 ("Stones" 도 가능)
D:Invoke("enhance", nil)                 -- 폭발 강화
D:Invoke("grant", nil, "Stones50")       -- 상품 효과 지급 (영수증 없이)
D:Invoke("daily", nil)                   -- 일일 상자 시도
-- 클라
game.Players.LocalPlayer.PlayerScripts.Debug:Invoke("get")   -- / "stats"
```

## 출시 전 체크리스트
1. Roblox 크리에이터 대시보드에서 게임패스 5종·개발자 상품 6종을 만들고 `src/shared/Config/Products.luau` 의 `id` 를 채운다. id 가 0 인 카드는 상점에 🚧 로 표시되고 결제되지 않는다.
2. 아이콘 PNG(256×256, 플랫, 2px 외곽선) 32종을 업로드해 `Config/Assets.luau` 의 `Icons` 를 채운다. 비어 있으면 이모지로 대체 표시된다.
3. `Config/Assets.luau` 의 사운드 18종은 Creator Store 무료 오디오로 채워져 있다. 톤·라이선스 검수 후 교체.
4. Game Settings → Security → "Enable Studio Access to API Services" 를 켜면 Studio 에서도 실제 DataStore 에 저장된다. 테스트 데이터 초기화:
   `game:GetService("DataStoreService"):GetDataStore("PlayerData_v1"):RemoveAsync("Player_" .. game.Players:GetPlayers()[1].UserId)`
5. 모바일(저사양) 프로파일링: MicroProfiler 로 클라 프레임·메모리 확인, `Workspace.StreamingEnabled` 는 켜져 있음.
6. 10인 무설명 60분 플레이테스트 (DevSpec §16-3) → 경제 수치는 `tools/sim.luau` 로 재검증 후 Config 조정.
