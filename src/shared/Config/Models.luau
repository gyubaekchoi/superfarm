--!strict
-- 시각 템플릿 매핑. ReplicatedStorage/Assets 의 Model 이름. 없으면 코드가 회색 프리미티브로 대체한다.
-- 템플릿은 Studio 에서 Creator Store 무료 모델을 정규화(스크립트 제거·스케일·바닥 피벗)해 만들었다. 재생성: tools/studio_build_assets.luau
local Models = {
	Crops = {
		Wheat = { template = "Crop_Wheat", jitter = 0.25 },
		Rice = { template = "Crop_Rice", jitter = 0.25 },
		Corn = { template = "Crop_Corn", jitter = 0.2 },
		Potato = { template = "Crop_Potato", jitter = 0.2 },
		Apple = { template = "Fruit_Apple", jitter = 0 },
		Orange = { template = "Fruit_Orange", jitter = 0 },
	},
	Trees = { Apple = "Tree_Apple", Orange = "Tree_Orange" },
	Stands = { Z1 = "Stand_Stall", Z2 = "Stand_Truck", Z3 = "Stand_Stall" },
	Plaza = { Gacha = "Plaza_Gift", Enhance = "Plaza_Anvil", Shop = "Plaza_Shop" },
	Worker = "Worker_Robot",
	Decor = {
		Rocks = { "Decor_Rock_L", "Decor_Rock_M", "Decor_Rock_S" },
		Trees = { "Decor_Tree_A", "Decor_Tree_B" },
		Fence = "Decor_Fence",
		Windmill = "Decor_Windmill",
	},
	-- 구역 테마 (바닥·밭 색)
	ZoneTheme = {
		Z1 = { floor = { 124, 196, 92 }, tile = { 120, 84, 50 } },
		Z2 = { floor = { 176, 190, 88 }, tile = { 150, 105, 55 } },
		Z3 = { floor = { 104, 184, 110 }, tile = { 96, 150, 70 } },
		Z4 = { floor = { 150, 150, 160 }, tile = { 110, 110, 120 } },
	},
	Ground = { 176, 214, 108 }, -- 월드 바닥 (연두)
	PlazaFloor = { 236, 222, 190 },
	Path = { 238, 204, 140 },
}

return Models
