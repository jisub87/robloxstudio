-- WaveConfig.lua

local WaveConfig = {}

-- ========================================
-- 타임라인
-- ========================================
WaveConfig.TIMELINE = {
	PEACE_DURATION = 10, -- 5분
	WAVE_REST_DURATION = 20, -- 20초
	REWARD_DURATION = 180, -- 3분
}

-- ========================================
-- Wave 데이터
-- ========================================
local waves = {
	-- Wave 1
	{
		waveNumber = 1,
		duration = 60, -- 1분
		monsters = {
			{type = "Slime", count = 10},
		},
		goldReward = 50,
		expReward = 10,
		crystalHeal = 50,
	},

	-- Wave 2
	{
		waveNumber = 2,
		duration = 60,
		monsters = {
			{type = "Slime", count = 15},
			{type = "Goblin", count = 3},
		},
		goldReward = 100,
		expReward = 20,
		crystalHeal = 50,
	},

	-- Wave 3
	{
		waveNumber = 3,
		duration = 90,
		monsters = {
			{type = "Goblin", count = 10},
			{type = "Orc", count = 2},
		},
		goldReward = 120,
		expReward = 20,
		crystalHeal = 50,
	},

	-- Wave 4
	{
		waveNumber = 4,
		duration = 90,
		monsters = {
			{type = "Orc", count = 15},
			{type = "Goblin", count = 10},
		},
		goldReward = 180,
		expReward = 20,
		crystalHeal = 50,
	},

	-- Wave 5 (Boss)
	{
		waveNumber = 5,
		duration = 120, -- 2분
		monsters = {
			{type = "Boss", count = 1},
			{type = "Orc", count = 5},
		},
		goldReward = 300,
		expReward = 50,
		crystalHeal = 100,
		legendToken = 1, -- 전설 토큰
	},
}

-- ========================================
-- Wave 가져오기
-- ========================================
function WaveConfig.getWave(waveNumber)
	for _, wave in ipairs(waves) do
		if wave.waveNumber == waveNumber then
			return wave
		end
	end
	return nil -- ✅ 명시적으로 nil 반환
end

-- ========================================
-- 전체 Wave 개수
-- ========================================
function WaveConfig.getTotalWaves()
	return #waves -- ✅ waves 배열 길이 반환 (5)
end

return WaveConfig