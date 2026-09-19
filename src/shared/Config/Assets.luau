--!strict
-- 아이콘·사운드·색. 에셋 업로드 후 ID 교체. 클라이언트에서만 Color3 변환.
local Assets = {
	Icons = {
		Coin = "rbxassetid://0",
		Stone = "rbxassetid://0",
		Ticket = "rbxassetid://0",
		Star = "rbxassetid://0",
		Shoe = "rbxassetid://0",
		Sickle = "rbxassetid://0",
		Bag = "rbxassetid://0",
		Bolt = "rbxassetid://0",
		Lock = "rbxassetid://0",
		Unlock = "rbxassetid://0",
		Shop = "rbxassetid://0",
		Gift = "rbxassetid://0",
		Anvil = "rbxassetid://0",
		Robot = "rbxassetid://0",
		Truck = "rbxassetid://0",
		Stall = "rbxassetid://0",
		Drop = "rbxassetid://0",
		NoEntry = "rbxassetid://0",
		Arrow = "rbxassetid://0",
		Hand = "rbxassetid://0",
		Construction = "rbxassetid://0",
		ShoeGold = "rbxassetid://0",
		SickleGold = "rbxassetid://0",
		BagGold = "rbxassetid://0",
		CoinGold = "rbxassetid://0",
		RobotGold = "rbxassetid://0",
		Field = "rbxassetid://0",
		Check = "rbxassetid://0",
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
	RarityColors = { "#AAAAAA", "#5AC85A", "#468CFF", "#FFC828" },
	AuraColors = { White = "#FFFFFF", BlueFlame = "#4AA8FF", Gold = "#FFC828", Rainbow = "RAINBOW", Galaxy = "#8A4DFF" },
}

return Assets
