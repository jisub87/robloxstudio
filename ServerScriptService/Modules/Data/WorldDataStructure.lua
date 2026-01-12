--[[
	WorldDataStructure.lua
	
	목적: 월드 데이터 구조 정의
	참조: WCD_Data_Structure.docx - Section 3
]]

local WorldDataStructure = {}

-- 기본 월드 데이터 생성
function WorldDataStructure.createDefault(worldId, ownerId)
	return {
		version = 1,
		worldId = worldId,
		ownerId = ownerId,

		-- 크리스탈
		crystal = {
			level = 1,
			exp = 0,
			hp = 1000,
			maxHp = 1000,
			state = "Healthy", -- Healthy/Worried/Danger/Critical
			eraId = "Stone", -- Stone/Iron/Gold/Crystal
		},

		-- 건물 (빈 테이블)
		buildings = {},

		-- 기록
		history = {
			todayLog = {
				date = os.date("%Y-%m-%d"),
				events = {},
				dailyLegend = {
					building = nil,
					player = nil,
				},
			},
			weekSummary = {},
			milestones = {},
		},

		-- 메타데이터
		createdAt = os.time(),
		lastSaved = os.time(),
		lastPlayerExit = nil,
	}
end

-- 건물 데이터 생성
function WorldDataStructure.createBuilding(buildingId, buildingType, ownerId, ownerName, position, rotation)
	return {
		id = buildingId,
		type = buildingType, -- Wall/Tower/Trap
		ownerId = ownerId,
		ownerName = ownerName,
		position = {
			x = position.X,
			y = position.Y,
			z = position.Z,
		},
		rotation = rotation or 0,
		hp = 100, -- 초기값, BuildingConfig에서 재설정
		maxHp = 100,
		createdAt = os.time(),
		agingDays = 0,
		stats = {
			monstersDefeated = 0,
			damageBlocked = 0,
			repairCount = 0,
		},
	}
end

-- 데이터 검증
function WorldDataStructure.validate(data)
	if not data then
		return false, "데이터가 nil입니다"
	end

	if type(data) ~= "table" then
		return false, "데이터가 테이블이 아닙니다"
	end

	-- 필수 필드 확인
	local requiredFields = {
		"version", "worldId", "ownerId", "crystal", "buildings", "history"
	}

	for _, field in ipairs(requiredFields) do
		if data[field] == nil then
			return false, "필수 필드 누락: " .. field
		end
	end

	-- 크리스탈 필드 확인
	local crystalFields = {"level", "exp", "hp", "maxHp", "state", "eraId"}
	for _, field in ipairs(crystalFields) do
		if data.crystal[field] == nil then
			return false, "크리스탈 필드 누락: " .. field
		end
	end

	return true, "검증 성공"
end

-- 데이터 마이그레이션
function WorldDataStructure.migrate(data)
	if data.version == 1 then
		-- 현재 최신 버전
		return data
	end

	-- V0 → V1 마이그레이션
	if not data.version then
		warn("[WorldData] V0 데이터를 V1로 마이그레이션")
		data.version = 1
		data.history = data.history or {
			todayLog = { date = os.date("%Y-%m-%d"), events = {}, dailyLegend = {} },
			weekSummary = {},
			milestones = {},
		}
	end

	return data
end

return WorldDataStructure