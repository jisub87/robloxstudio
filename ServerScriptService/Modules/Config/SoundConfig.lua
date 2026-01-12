--[[
	SoundConfig.lua
	
	목적: 사운드 ID 및 설정 관리
]]

local SoundConfig = {}

-- ========================================
-- BGM 설정
-- ========================================
SoundConfig.BGM = {
	PeaceTime = {
		soundId = "rbxassetid://1837849285", -- Peaceful
		volume = 0.3,
		looped = true,
		name = "Peace Time",
	},
	WaveTime = {
		soundId = "rbxassetid://1845756489", -- Battle
		volume = 0.4,
		looped = true,
		name = "Wave Time",
	},
	BossTime = {
		soundId = "rbxassetid://1841647093", -- Boss Battle
		volume = 0.5,
		looped = true,
		name = "Boss Time",
	},
	RebuildParty = {
		soundId = "rbxassetid://1838673350", -- Party
		volume = 0.4,
		looped = true,
		name = "Rebuild Party",
	},
	Victory = {
		soundId = "rbxassetid://1837849285", -- Victory Fanfare
		volume = 0.5,
		looped = false,
		name = "Victory",
	},
}

-- ========================================
-- SFX 설정
-- ========================================
SoundConfig.SFX = {
	-- 건물
	Build = {
		soundId = "rbxassetid://3417831369", -- Hammer
		volume = 0.5,
		name = "Build",
	},
	Repair = {
		soundId = "rbxassetid://2976773885", -- Repair
		volume = 0.4,
		name = "Repair",
	},
	Destroy = {
		soundId = "rbxassetid://5801257793", -- Explosion
		volume = 0.6,
		name = "Destroy",
	},

	-- 전투
	TowerAttack = {
		soundId = "rbxassetid://78547428374480", -- Magic Shot
		volume = 0.3,
		name = "Tower Attack",
	},
	MonsterHit = {
		soundId = "rbxassetid://8595980577", -- Hit
		volume = 0.4,
		name = "Monster Hit",
	},
	MonsterDeath = {
		soundId = "rbxassetid://17000725105", -- Death
		volume = 0.5,
		name = "Monster Death",
	},
	Explosion = {
		soundId = "rbxassetid://8447388510", -- Explosion
		volume = 0.6,
		name = "Explosion",
	},

	-- 크리스탈
	CrystalDamage = {
		soundId = "rbxassetid://7140152893", -- Glass Break
		volume = 0.5,
		name = "Crystal Damage",
	},
	CrystalLevelUp = {
		soundId = "rbxassetid://3120909354", -- Level Up
		volume = 0.6,
		name = "Crystal Level Up",
	},
	CrystalDestroy = {
		soundId = "rbxassetid://6737582037", -- Big Glass Break
		volume = 0.7,
		name = "Crystal Destroy",
	},
	CrystalRevive = {
		soundId = "rbxassetid://86811255527245", -- Revive
		volume = 0.6,
		name = "Crystal Revive",
	},

	-- UI
	ButtonClick = {
		soundId = "rbxassetid://6895079853", -- UI Click
		volume = 0.3,
		name = "Button Click",
	},
	GoldGet = {
		soundId = "rbxassetid://607665037", -- Coin
		volume = 0.4,
		name = "Gold Get",
	},
	Notification = {
		soundId = "rbxassetid://8486683243", -- Notification
		volume = 0.4,
		name = "Notification",
	},
	WaveStart = {
		soundId = "rbxassetid://6209050003", -- Wave Start
		volume = 0.6,
		name = "Wave Start",
	},
	WaveComplete = {
		soundId = "rbxassetid://4612383790", -- Complete
		volume = 0.5,
		name = "Wave Complete",
	},
}

-- ========================================
-- BGM 가져오기
-- ========================================
function SoundConfig.getBGM(bgmName)
	return SoundConfig.BGM[bgmName]
end

-- ========================================
-- SFX 가져오기
-- ========================================
function SoundConfig.getSFX(sfxName)
	return SoundConfig.SFX[sfxName]
end

return SoundConfig