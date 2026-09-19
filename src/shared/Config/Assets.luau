--!strict
-- 아이콘·사운드·색. 에셋 업로드 후 ID 교체. 클라이언트에서만 Color3 변환.
local Assets = {
	Icons = {
		Coin = "rbxassetid://113652099343896",
		Stone = "rbxassetid://129760192304191",
		Ticket = "rbxassetid://80198124345211",
		Star = "rbxassetid://115105485828956",
		Shoe = "rbxassetid://74689784085604",
		Sickle = "rbxassetid://119060982202222",
		Bag = "rbxassetid://123501246838746",
		Bolt = "rbxassetid://133827064938151",
		Lock = "rbxassetid://115764603288470",
		Unlock = "rbxassetid://105506856626133",
		Shop = "rbxassetid://86869265497291",
		Gift = "rbxassetid://76642593586087",
		Anvil = "rbxassetid://92860538839998",
		Robot = "rbxassetid://103397325195989",
		Truck = "rbxassetid://127416685532405",
		Stall = "rbxassetid://97064471734518",
		Drop = "rbxassetid://115256280444262",
		NoEntry = "rbxassetid://78083250045432",
		Arrow = "rbxassetid://108193310684678",
		Hand = "rbxassetid://73071467667126",
		Construction = "rbxassetid://89900057550923",
		ShoeGold = "rbxassetid://74713610123367",
		SickleGold = "rbxassetid://76798886727787",
		BagGold = "rbxassetid://103716345292233",
		CoinGold = "rbxassetid://121576971806202",
		RobotGold = "rbxassetid://106582247731236",
		Field = "rbxassetid://112875588303311",
		Check = "rbxassetid://133964918667815",
		Close = "rbxassetid://0",
		Percent = "rbxassetid://0",
	},
	-- 아이콘 PNG가 없을 때 쓰는 이모지 대체 (TextLabel). 최종 빌드에서는 전부 ImageLabel로 교체된다.
	EmojiFallback = {
		Coin = "💰",
		Stone = "💎",
		Ticket = "🎫",
		Star = "⭐",
		Shoe = "👟",
		Sickle = "🌾",
		Bag = "🎒",
		Bolt = "⚡",
		Lock = "🔒",
		Unlock = "🔓",
		Shop = "🛒",
		Gift = "🎁",
		Anvil = "⚒️",
		Robot = "🤖",
		Truck = "🚚",
		Stall = "🏪",
		Drop = "💧",
		NoEntry = "🚫",
		Arrow = "➡️",
		Hand = "👆",
		Construction = "🚧",
		Field = "🟫",
		Check = "✅",
		ShoeGold = "👟",
		SickleGold = "🌾",
		BagGold = "🎒",
		CoinGold = "💰",
		RobotGold = "🤖",
	},
	SFX = {
		-- Creator Store 무료 오디오 (ProSoundEffects/APM 우선). 라이선스·톤 검수 후 교체 가능
		Harvest = "rbxassetid://140323850218372", -- Pop Sound Effect
		Coin = "rbxassetid://135483737426662", -- Coin Collect
		StackFull = "rbxassetid://106879573498735", -- Pop_Up_Sound (낮은 피치로 재생)
		Deposit = "rbxassetid://137081214744553", -- whoosh
		PadDrain = "rbxassetid://133570405319995", -- Coin Clinking
		PadComplete = "rbxassetid://9126073001", -- Synth Sparkle Bell Ding (ProSoundEffects)
		LevelUp = "rbxassetid://112485797063762", -- UI - Level Up
		DrumRoll = "rbxassetid://4718483268", -- Drum Roll
		GachaRare = "rbxassetid://117011707307950", -- Glitter Sparkle Magic
		GachaLegend = "rbxassetid://1841488866", -- Big and Bang Sting b (APM)
		StarPing = "rbxassetid://9126073318", -- Synth Sparkle Ding (ProSoundEffects)
		Equip = "rbxassetid://138890894929151", -- Whoosh2
		HammerSlow = "rbxassetid://9125672726", -- Sledge Hammer Metal Impact (ProSoundEffects)
		HammerFast = "rbxassetid://3417831369", -- Hammer hit
		Crit = "rbxassetid://138190748214493", -- gold magic
		Boom = "rbxassetid://138533090376585", -- Explosion Blast Impact Boom
		RollTick = "rbxassetid://100836780668038", -- ClickSound
		Tada = "rbxassetid://4757565956", -- TaDa
	},
	Sky = {
		Bk = "rbxassetid://528480826",
		Dn = "rbxassetid://528481890",
		Ft = "rbxassetid://528481964",
		Lf = "rbxassetid://528482047",
		Rt = "rbxassetid://528482365",
		Up = "rbxassetid://528484371",
	},
	BGM = "rbxassetid://1839452664", -- APM Lovely Day (33s loop)
	RarityColors = { "#AAAAAA", "#5AC85A", "#468CFF", "#FFC828" },
	AuraColors = { White = "#FFFFFF", BlueFlame = "#4AA8FF", Gold = "#FFC828", Rainbow = "RAINBOW", Galaxy = "#8A4DFF" },
}

return Assets
