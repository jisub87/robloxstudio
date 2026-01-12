--[[
	PlayerDataStructure.lua
	
	목적: 플레이어 데이터 구조 정의
]]

local PlayerDataStructure = {}

-- ========================================
-- 기본 데이터 생성
-- ========================================
function PlayerDataStructure.createDefault(userId, displayName)
	return {
		version = 1,
		userId = userId,
		displayName = displayName,

		-- 기본 정보
		gold = 50,
		legendTokens = 0,
		currentClass = "Builder",

		-- 로그인 정보
		lastLogin = "", -- "2025-01-11" 형식
		consecutiveDays = 0, -- 연속 출석 일수
		totalLoginDays = 0, -- 총 출석 일수

		-- 플레이 시간
		totalPlayTime = 0, -- 총 플레이 시간 (초)
		lastPlayTimeReward = 0, -- 마지막 플레이 시간 보상 시각

		-- 통계
		stats = {
			buildingsPlaced = 0,
			monstersKilled = 0,
			repairsTotal = 0,
			wavesCleared = 0,
			rebuildPartiesWon = 0,
			totalGoldEarned = 0, -- ✅ 추가: 총 획득 골드
		},

		-- 클래스별 통계
		classStats = {
			Builder = {
				buildingsPlaced = 0,
				repairsTotal = 0,
				playTime = 0,
			},
			Fighter = {
				monstersKilled = 0,
				damageDealt = 0,
				playTime = 0,
			},
			Repairer = {
				repairsTotal = 0,
				hpRestored = 0,
				playTime = 0,
			},
		},

		-- 칭호
		titles = {},

		-- 메타데이터
		createdAt = os.time(),
		lastSaved = os.time(),
	}
end

-- ========================================
-- 데이터 검증
-- ========================================
function PlayerDataStructure.validate(data)
	if not data then
		warn("[PlayerDataStructure] 데이터가 nil입니다")
		return false
	end

	-- 필수 필드 확인
	local requiredFields = {"version", "userId", "gold", "stats"}
	for _, field in ipairs(requiredFields) do
		if data[field] == nil then
			warn("[PlayerDataStructure] 필수 필드 누락:", field)
			return false
		end
	end

	return true
end

-- ========================================
-- 데이터 마이그레이션
-- ========================================
function PlayerDataStructure.migrate(data)
	if not data then return nil end

	-- 버전 1 (최신)
	if data.version == 1 then
		-- 새 필드 추가 (하위 호환)
		if not data.lastLogin then
			data.lastLogin = ""
		end
		if not data.consecutiveDays then
			data.consecutiveDays = 0
		end
		if not data.totalLoginDays then
			data.totalLoginDays = 0
		end
		if not data.totalPlayTime then
			data.totalPlayTime = 0
		end
		if not data.lastPlayTimeReward then
			data.lastPlayTimeReward = 0
		end
		if not data.stats.totalGoldEarned then
			data.stats.totalGoldEarned = 0
		end

		return data
	end

	-- 버전 0 (구버전)
	if not data.version then
		data.version = 1
		data.lastLogin = ""
		data.consecutiveDays = 0
		data.totalLoginDays = 0
		data.totalPlayTime = 0
		data.lastPlayTimeReward = 0

		if data.stats then
			data.stats.totalGoldEarned = 0
		end
	end

	return data
end

return PlayerDataStructure