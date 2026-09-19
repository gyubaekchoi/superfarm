# 아트 에셋 목록 (v0.2 · 유행 로우폴리 스타일)

방향: Grow a Garden·Steal a Brainrot 계열의 **밝고 채도 높은 로우폴리**. 둥글고 두툼한 형태, 파스텔+비비드, 두꺼운 외곽선 UI(Fredoka One), 맑은 하늘·블룸.

## 3D 템플릿 (`ReplicatedStorage/Assets`, 플레이스 파일에 저장)
코드는 `Config/Models.luau` 이름으로 템플릿을 찾아 `Templates.spawn()` 으로 복제하고, 없으면 회색 프리미티브로 대체한다.
재생성: Studio 커맨드바에서 `tools/studio_build_assets.luau` 실행 (InsertService). 실행 후 반드시 플레이스 저장.

| 템플릿 | 출처 (Creator Store, 무료) | 처리 |
|---|---|---|
| Tree_Apple / Tree_Orange | 18935851411 Low Poly Apple Tree | 사과 메시 제거, 0.42배, 캐노피/트렁크 이름 지정, 오렌지는 캐노피 색 변경 |
| Fruit_Apple / Fruit_Orange | 위 나무의 사과 메시 1개 | 0.7배, 오렌지 색 |
| Crop_Wheat / Crop_Rice | 절차 생성 | 줄기 5 + 이삭 |
| Crop_Corn | 14157917435 Corn-Moving | AlignPosition 등 제약 제거, 0.28배 |
| Crop_Potato | 7092525084 potato plant | 0.85배 |
| Stand_Stall | 124928699810262 Low Poly Market Stall | 스크립트·오디오 제거, 0.36배 |
| Stand_Truck | 9149456007 Low Poly Truck | 0.36배 |
| Plaza_Gift | 130249388617847 Present Box | 8배, 코드에서 핑크/금색 채색 |
| Plaza_Anvil | 111454380542291 Anvil | 1.4배 |
| Plaza_Shop | 134047234421874 Merchant Tent | 스크립트 제거, 0.55배 |
| Decor_Rock_L/M/S, Decor_Tree_A/B | 9682467046 Low Poly Nature Pack | 크기별 선별 |
| Decor_Windmill | 18828754732 Low Poly Windmill | 0.35배 |
| Worker_Robot | 절차 생성 | 둥근 몸통·안테나·네온 배 |
| Sky | 528506487 Cartoon Skybox | Lighting.Sky (ID 는 Config/Assets.luau) |

울타리는 템플릿 대신 코드에서 흰 말뚝 울타리를 생성한다(플롯당 약 214파트). 미해금 구역은 아예 생성하지 않으며 허브 가장자리 게이트 🔒만 보인다 (지도 v2).

## 조명·후처리 (`WorldService`)
ClockTime 13.5, Brightness 2.6, Atmosphere(0.16), Bloom(0.55/28/1.4), ColorCorrection(채도 +0.22, 대비 +0.08), SunRays(0.07). 바닥은 Grass 재질 연두, 플롯 중앙 허브는 크림색 동심원 포장 + 가로등 6.

## UI 아이콘 (`assets/icons/*.png`, 256px)
`tools/gen_icons.py` 로 생성한 플랫 아이콘 36종(두꺼운 남보라 외곽선). 업로드된 28종의 ID 는 `Config/Assets.luau` 에 기록.
**미업로드 8종**(Wheat, Rice, Corn, Potato, Apple, Orange, Close, Percent)은 계정 업로드 제한("User is moderated")으로 대기 중 → 이모지로 대체 표시. 제한 해제 후 `upload_image` 로 재업로드해 ID 를 채운다.

## 사운드
`Config/Assets.luau` SFX 18종(Creator Store 무료, ProSoundEffects/APM 우선) + BGM `1839452664` (APM Lovely Day). 편집 모드 프리로드에서 전부 로드 확인.
Play 중 HTTP 403 이 나면 Studio 로그인 세션 문제(DataStore·그룹 조회도 함께 403). Studio 재로그인 후 확인.
