--[[
	WorldDataStore.lua
	
	목적: 월드 데이터 저장/로드
	책임:
	  - 월드 데이터 로드
	  - 월드 데이터 저장 (Dirty Flag)
	  - 자동 저장 (90초 주기)
	  - 건물 복원
]]

local WorldDataStore = {}

local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

-- 모듈
local DataStoreManager = require(script.Parent.DataStoreManager)
local WorldDataStructure = require(ServerScriptService.Modules.Data.WorldDataStructure)
local Constants = require(ServerScriptService.Modules.Data.Constants)

-- DataStore
local WORLD_DATASTORE_NAME = "WorldData_V1"
local worldDataStore = DataStoreService:GetDataStore("WorldData_V1")

-- 현재 월드 데이터
local currentWorldId = nil
local currentWorldData = nil
local isDirty = false -- Dirty Flag
local lastSaveTime = 0

local isSaving = false
local lastAttemptTime = 0 -- 실패 시 너무 자주 재시도 방지용(선택)

-- ========================================
-- 월드 데이터 로드
-- ========================================
function WorldDataStore.load(worldId)
	currentWorldId = worldId
	local key = "World_" .. worldId

	print(string.format("[WorldDataStore] 월드 로드 시작: %s", worldId))

	-- GetAsync로 데이터 로드
	local loadedData = DataStoreManager.getAsync(WORLD_DATASTORE_NAME, key)

	if loadedData then
		-- 데이터 존재 → 마이그레이션
		print("[WorldDataStore] 기존 월드 데이터 발견")
		currentWorldData = WorldDataStructure.migrate(loadedData)

		-- 검증
		local isValid, msg = WorldDataStructure.validate(currentWorldData)
		if not isValid then
			warn("[WorldDataStore] 데이터 검증 실패:", msg)
			warn("[WorldDataStore] 기본 데이터로 대체")
			currentWorldData = WorldDataStructure.createDefault(worldId, 0)
		end
	else
		-- 데이터 없음 → 기본 데이터 생성
		print("[WorldDataStore] 신규 월드 - 기본 데이터 생성")
		currentWorldData = WorldDataStructure.createDefault(worldId, 0)
	end

	isDirty = false
	lastSaveTime = os.time()

	print(string.format("[WorldDataStore] 월드 로드 완료: %s (크리스탈 Lv: %d, 건물: %d개)",
		worldId, currentWorldData.crystal.level, WorldDataStore.getBuildingCount()))

	return currentWorldData
end

-- ========================================
-- 데이터 저장
-- ========================================
function WorldDataStore.save(forceImmediate)
	if not currentWorldData then
		warn("[WorldDataStore] 저장할 월드 데이터 없음")
		return false
	end
	
	-- 저장 중이면 중복 저장 요청 막기
	if isSaving then
		return false
	end
	
	-- forceImmediate가 아니고 Dirty가 아니면 저장 안 함
	if not forceImmediate and not isDirty then
		print("[WorldDataStore] Dirty Flag = false, 저장 건너뜀")
		return true
	end
	
	-- 실패 폭주 방지(선택): 직전 시도 후 10초는 재시도 금지
	if not forceImmediate then
		local now = os.time()
		if now - lastAttemptTime < 10 then
			return false
		end
		lastAttemptTime = now
	end

	isSaving = true
	
	if not currentWorldId then
		warn("[WorldDataStore] currentWorldId가 없어 저장 불가 (load가 먼저 호출되어야 함)")
		return false
	end
	
	-- ✅ DataStore 사용 가능 여부 확인
	if not DataStoreManager.getDataStore(WORLD_DATASTORE_NAME) then
		warn("[WorldDataStore] DataStore 비활성화 - 저장 건너뜀")
		return false
	end

	print(string.format("[WorldDataStore] 월드 데이터 저장 시작: %s", currentWorldId))

	-- lastSaved 업데이트
	currentWorldData.lastSaved = os.time()

	local key = "World_" .. currentWorldId

	local result = DataStoreManager.updateAsync(WORLD_DATASTORE_NAME, key, function(oldData)
		-- 새 데이터로 덮어쓰기
		return currentWorldData
	end)

	if result then
		print("[WorldDataStore] 저장 성공")
		isDirty = false
		lastSaveTime = os.time()
		return true
	else
		warn("[WorldDataStore] 저장 실패")
		return false
	end
end

-- ========================================
-- Dirty Flag 설정
-- ========================================
function WorldDataStore.markDirty()
	isDirty = true
	--print("[WorldDataStore] Dirty Flag = true")
end

-- ========================================
-- 현재 월드 데이터 가져오기
-- ========================================
function WorldDataStore.get()
	return currentWorldData
end

-- ========================================
-- 건물 개수 가져오기
-- ========================================
function WorldDataStore.getBuildingCount()
	if not currentWorldData then return 0 end

	local count = 0
	for _ in pairs(currentWorldData.buildings) do
		count = count + 1
	end
	return count
end

-- ========================================
-- 자동 저장 시작 (90초 주기)
-- ========================================
function WorldDataStore.startAutoSave()
	print("[WorldDataStore] 자동 저장 시작 (90초 주기)")

	task.spawn(function()
		while true do
			task.wait(1)

			local currentTime = os.time()
			local timeSinceLastSave = currentTime - lastSaveTime

			if timeSinceLastSave >= Constants.GAME.SAVE_INTERVAL and isDirty then
				print(string.format("[WorldDataStore] 자동 저장 트리거 (경과: %d초)", timeSinceLastSave))
				WorldDataStore.save(false)
			end
		end
	end)
end

-- ========================================
-- 건물 복원 (월드 로드 후 호출)
-- ========================================
function WorldDataStore.restoreBuildings()
	if not currentWorldData then
		warn("[WorldDataStore] 복원할 월드 데이터 없음")
		return
	end

	local buildingsFolder = workspace:FindFirstChild("Buildings")
	if not buildingsFolder then
		buildingsFolder = Instance.new("Folder")
		buildingsFolder.Name = "Buildings"
		buildingsFolder.Parent = workspace
	end

	-- 기존 건물 삭제
	buildingsFolder:ClearAllChildren()

	print(string.format("[WorldDataStore] 건물 복원 시작: %d개", WorldDataStore.getBuildingCount()))

	-- BuildingService 요구
	local BuildingService = require(ServerScriptService.Services.BuildingService)

	for buildingId, buildingData in pairs(currentWorldData.buildings) do
		local position = Vector3.new(
			buildingData.position.x,
			buildingData.position.y,
			buildingData.position.z
		)

		local building = BuildingService.createBuilding(
			buildingId,
			buildingData.type,
			buildingData.ownerId,
			buildingData.ownerName,
			position,
			buildingData.rotation
		)

		if building then
			print(string.format("  ✅ 건물 복원: %s (%s by %s)", 
				buildingId, buildingData.type, buildingData.ownerName))
		else
			warn(string.format("  ❌ 건물 복원 실패: %s", buildingId))
		end
	end

	print("[WorldDataStore] 건물 복원 완료")
end

return WorldDataStore