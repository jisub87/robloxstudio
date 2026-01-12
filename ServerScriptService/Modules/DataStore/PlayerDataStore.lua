--[[
	PlayerDataStore.lua
	
	목적: 플레이어 데이터 저장/로드
	책임:
	  - 플레이어 데이터 로드 (GetAsync)
	  - 플레이어 데이터 저장 (UpdateAsync)
	  - 기본 데이터 생성
	  - 마이그레이션
]]

local PlayerDataStore = {}

local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

-- 모듈
local DataStoreManager = require(script.Parent.DataStoreManager)
local PlayerDataStructure = require(ServerScriptService.Modules.Data.PlayerDataStructure)

-- DataStore
local PLAYER_DATASTORE_NAME = "PlayerData_V1"
--local playerDataStore = DataStoreService:GetDataStore("PlayerData_V1")

-- 메모리 캐시 (UserId -> PlayerData)
local playerDataCache = {}

-- ========================================
-- 플레이어 데이터 로드
-- ========================================
function PlayerDataStore.load(player)
	local userId = player.UserId
	local displayName = player.DisplayName

	print(string.format("[PlayerDataStore] 데이터 로드 시작: %s (UserId: %d)", displayName, userId))

	local key = "Player_" .. tostring(userId)

	-- DataStore에서 로드
	local loadedData = DataStoreManager.getAsync(PLAYER_DATASTORE_NAME, key)

	local playerData

	if loadedData then
		-- 기존 데이터 있음
		print(string.format("[PlayerDataStore] 기존 데이터 로드: %s", displayName))

		-- 마이그레이션
		playerData = PlayerDataStructure.migrate(loadedData)

		-- 검증
		if not PlayerDataStructure.validate(playerData) then
			warn(string.format("[PlayerDataStore] 데이터 검증 실패: %s - 기본값 사용", displayName))
			playerData = PlayerDataStructure.createDefault(userId, displayName)
		end
	else
		-- ✅ 데이터 없음 또는 DataStore 비활성화
		if DataStoreManager.getDataStore(PLAYER_DATASTORE_NAME) then
			print(string.format("[PlayerDataStore] 신규 플레이어: %s", displayName))
		else
			warn(string.format("[PlayerDataStore] DataStore 비활성화 - 임시 데이터 사용: %s", displayName))
		end

		playerData = PlayerDataStructure.createDefault(userId, displayName)
	end

	-- 캐시에 저장
	playerDataCache[userId] = playerData

	print(string.format("[PlayerDataStore] 데이터 로드 완료: %s (골드: %d)", displayName, playerData.gold))

	return playerData
end

-- ========================================
-- 플레이어 데이터 저장
-- ========================================
function PlayerDataStore.save(player)
	local userId = player.UserId
	local playerData = playerDataCache[userId]

	if not playerData then
		warn(string.format("[PlayerDataStore] 저장할 데이터 없음: %s (UserId: %d)", player.Name, userId))
		return false
	end

	print(string.format("[PlayerDataStore] 데이터 저장 시작: %s (UserId: %d)", player.Name, userId))

	-- ✅ DataStore 사용 가능 여부 확인
	if not DataStoreManager.getDataStore(PLAYER_DATASTORE_NAME) then
		warn(string.format("[PlayerDataStore] DataStore 비활성화 - 저장 건너뜀: %s", player.Name))
		return false
	end

	-- lastSaved 업데이트
	if playerData then
		playerData.lastSaved = os.time()
	end

	local key = "Player_" .. tostring(userId)

	local result = DataStoreManager.updateAsync(PLAYER_DATASTORE_NAME, key, function(oldData)
		-- 새 데이터로 덮어쓰기
		return playerData
	end)

	if result then
		print(string.format("[PlayerDataStore] 저장 성공: %s", player.Name))
		return true
	else
		warn(string.format("[PlayerDataStore] 저장 실패: %s", player.Name))
		return false
	end
end

-- ========================================
-- 캐시에서 플레이어 데이터 가져오기
-- ========================================
function PlayerDataStore.get(player)
	return playerDataCache[player.UserId]
end

-- ========================================
-- 캐시에서 플레이어 데이터 제거
-- ========================================
function PlayerDataStore.unload(player)
	playerDataCache[player.UserId] = nil
	print(string.format("[PlayerDataStore] 캐시에서 제거: %s", player.Name))
end

return PlayerDataStore