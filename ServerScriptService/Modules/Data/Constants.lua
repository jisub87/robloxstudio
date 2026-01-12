--[[
	Constants.lua
	
	목적: 게임 전체 상수 정의
]]

local Constants = {}

-- ========================================
-- 게임 설정
-- ========================================
Constants.GAME = {
	GRID_SIZE = 4, -- studs (그리드 스냅)
	MAP_SIZE = 200, -- studs (200x200)
	SAVE_INTERVAL = 90, -- 초 (90초마다 자동 저장)
}

-- ========================================
-- 크리스탈 상태
-- ========================================
Constants.CRYSTAL_STATES = {
	HEALTHY = {
		name = "Healthy",
		minHpPercent = 80,
		color = Color3.fromRGB(100, 200, 255), -- 밝은 파란색
	},
	WORRIED = {
		name = "Worried",
		minHpPercent = 50,
		color = Color3.fromRGB(255, 255, 100), -- 노란색
	},
	DANGER = {
		name = "Danger",
		minHpPercent = 20,
		color = Color3.fromRGB(255, 150, 50), -- 주황색
	},
	CRITICAL = {
		name = "Critical",
		minHpPercent = 0,
		color = Color3.fromRGB(255, 50, 50), -- 빨간색
	},
}

-- ========================================
-- Era (시대)
-- ========================================
Constants.ERAS = {
	STONE = {
		id = "Stone",
		name = "Stone Age",
		levelRange = {1, 9},
		maxHp = 1000,
	},
	IRON = {
		id = "Iron",
		name = "Iron Age",
		levelRange = {10, 19},
		maxHp = 3500,
	},
	GOLD = {
		id = "Gold",
		name = "Gold Age",
		levelRange = {20, 29},
		maxHp = 6000,
	},
	CRYSTAL = {
		id = "Crystal",
		name = "Crystal Age",
		levelRange = {30, 999},
		maxHp = 10000,
	},
}

-- ========================================
-- 클래스 배율
-- ========================================
Constants.CLASS_MULTIPLIERS = {
	Builder = {
		buildSpeed = 1.5,
		repairAmount = 1.2,
	},
	Fighter = {
		attackPower = 2.0,
		goldBonus = 1.2,
	},
	Repairer = {
		repairAmount = 2.0,
		repairSpeed = 1.5,
	},
}

-- ========================================
-- 건물 배치 제한
-- ========================================
Constants.BUILDING_RESTRICTIONS = {
	CRYSTAL_EXCLUSION_RADIUS = 30, -- studs
	SPAWN_EXCLUSION_RADIUS = 10, -- studs
	MAX_TOWER_PER_VISITOR = 1, -- 타인 월드에 타워 1개만
}

-- ========================================
-- 재건 파티
-- ========================================
Constants.REBUILD_PARTY = {
	DURATION = 120, -- 초 (2분)
	BUILD_SPEED_MULTIPLIER = 2.0,
	REPAIR_SPEED_MULTIPLIER = 2.0,
	GOLD_MULTIPLIER = 1.5,
	SUCCESS_CONDITIONS = {
		CRYSTAL_HP_PERCENT = 80, -- 크리스탈 80% 이상
		BUILDINGS_BUILT = 10, -- 건물 10개 이상
		WAVES_CLEARED = 1, -- Wave 1개 클리어
	},
	REWARDS = {
		GOLD = 200,
		LEGEND_TOKENS = 1,
		CRYSTAL_EXP = 100,
	},
}

-- ========================================
-- 타워 수수료
-- ========================================
Constants.TOWER_COMMISSION = {
	RATE = 0.1, -- 10%
}

-- ========================================
-- 건물 에이징
-- ========================================
Constants.BUILDING_AGING = {
	SKILLED = {
		days = 7,
		hpBonus = 0.10, -- +10%
		damageBonus = 0.05, -- +5%
		commissionBonus = 0.0,
	},
	VETERAN = {
		days = 30,
		hpBonus = 0.20, -- +20%
		damageBonus = 0.10, -- +10%
		commissionBonus = 0.05, -- +5%
	},
	LEGEND = {
		days = 60,
		hpBonus = 0.30, -- +30%
		damageBonus = 0.20, -- +20%
		commissionBonus = 0.20, -- +20%
	},
}

return Constants