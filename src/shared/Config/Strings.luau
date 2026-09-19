--!strict
-- UI 문자열. 아이콘 옆에 함께 표기해 인지를 높인다.
-- 로케일 정책: 한국어 로케일은 ko 테이블, 그 외는 en 테이블을 그리고 Roblox 자동 번역이 en 을 각 언어로 옮긴다.
--   → 크리에이터 대시보드 → Localization 에서 소스 언어를 English 로 두고 자동 번역을 켤 것.
-- 값에 %s / %d 가 있으면 L(key, ...) 로 포맷한다.
local Strings = {
	Fallback = "en",

	ko = {
		["pad.Move"] = "이동 속도",
		["pad.Harvest"] = "수확 속도",
		["pad.Cap"] = "가방 크기",
		["pad.Grow"] = "성장 촉진",
		["pad.Expand"] = "밭 넓히기",
		["pad.Worker"] = "일꾼 고용",
		["pad.Crop2"] = "%s 심기",
		["pad.Gate"] = "%s 열기",
		["pad.Level"] = "Lv.%d",
		["pad.Max"] = "최대",

		["zone.Z1"] = "밀밭",
		["zone.Z2"] = "옥수수밭",
		["zone.Z3"] = "과수원",
		["zone.Z4"] = "가공소",

		["crop.Wheat"] = "밀",
		["crop.Rice"] = "벼",
		["crop.Corn"] = "옥수수",
		["crop.Potato"] = "감자",
		["crop.Apple"] = "사과",
		["crop.Orange"] = "오렌지",

		["hub.Gacha"] = "뽑기",
		["hub.Enhance"] = "강화",
		["hub.Shop"] = "상점",
		["hub.Sell"] = "판매",

		["hint.Gacha"] = "여기서 장비 뽑기",
		["hint.Enhance"] = "여기서 장비 강화",
		["hint.Shop"] = "여기서 구매",
		["hint.Sell"] = "작물 팔기",
		["hint.Stand"] = "여기로 가져오기",
		["hint.Step"] = "밟고 서 있기",

		["req.Level"] = "레벨 %d 필요",
		["req.Soon"] = "준비 중",

		["btn.Draw"] = "뽑기",
		["btn.Enhance"] = "강화하기",
		["btn.Hold"] = "길게 누르기",
		["btn.Buy"] = "구매",

		["title.Gacha"] = "장비 뽑기",
		["title.Enhance"] = "장비 강화",
		["title.Shop"] = "상점",
		["title.Odds"] = "확률",
		["title.Power"] = "파워",
		["title.Owned"] = "보유 중",
		["goal.Title"] = "지금 할 일",
		["goal.Harvest"] = "작물에 다가가 수확하기",
		["goal.Sell"] = "작물을 판매대로 가져가기",
		["goal.Gacha"] = "상자 열어보기",
		["goal.Enhance"] = "장비 강화하기",
		["goal.Pad"] = "%s 사기",
		["goal.Gate"] = "%s 열기",
		["goal.Save"] = "코인 모으기",
		["goal.Idle"] = "작물이 자라는 중",
		["unlock.New"] = "새로 열렸어요",
	},

	en = {
		["pad.Move"] = "Walk Speed",
		["pad.Harvest"] = "Harvest Speed",
		["pad.Cap"] = "Bag Size",
		["pad.Grow"] = "Growth Boost",
		["pad.Expand"] = "Bigger Farm",
		["pad.Worker"] = "Hire Helper",
		["pad.Crop2"] = "Plant %s",
		["pad.Gate"] = "Open %s",
		["pad.Level"] = "Lv.%d",
		["pad.Max"] = "MAX",

		["zone.Z1"] = "Wheat Field",
		["zone.Z2"] = "Corn Field",
		["zone.Z3"] = "Orchard",
		["zone.Z4"] = "Factory",

		["crop.Wheat"] = "Wheat",
		["crop.Rice"] = "Rice",
		["crop.Corn"] = "Corn",
		["crop.Potato"] = "Potato",
		["crop.Apple"] = "Apple",
		["crop.Orange"] = "Orange",

		["hub.Gacha"] = "Lucky Box",
		["hub.Enhance"] = "Upgrade",
		["hub.Shop"] = "Shop",
		["hub.Sell"] = "Sell",

		["hint.Gacha"] = "Open a box here",
		["hint.Enhance"] = "Upgrade gear here",
		["hint.Shop"] = "Buy here",
		["hint.Sell"] = "Sell your crops",
		["hint.Stand"] = "Bring crops here",
		["hint.Step"] = "Stand on it",

		["req.Level"] = "Level %d needed",
		["req.Soon"] = "Coming soon",

		["btn.Draw"] = "Draw",
		["btn.Enhance"] = "Upgrade",
		["btn.Hold"] = "Hold",
		["btn.Buy"] = "Buy",

		["title.Gacha"] = "Lucky Box",
		["title.Enhance"] = "Upgrade Gear",
		["title.Shop"] = "Shop",
		["title.Odds"] = "Odds",
		["title.Power"] = "Power",
		["title.Owned"] = "Owned",
		["goal.Title"] = "Your next step",
		["goal.Harvest"] = "Walk into crops to harvest",
		["goal.Sell"] = "Take crops to the stand",
		["goal.Gacha"] = "Open the lucky box",
		["goal.Enhance"] = "Upgrade your gear",
		["goal.Pad"] = "Buy %s",
		["goal.Gate"] = "Open %s",
		["goal.Save"] = "Save up coins",
		["goal.Idle"] = "Crops are growing",
		["unlock.New"] = "New!",
	},
}

return Strings
