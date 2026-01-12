--[[
	DataStoreManager.lua
	
	목적: DataStore 래퍼 (재시도 로직, 에러 처리)
	책임:
	  - UpdateAsync 재시도 (3회 + 백오프)
	  - 에러 로깅
	  - DataStore 접근 추상화
]]

local DataStoreManager = {}

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

-- Studio 모드 확인
local isStudio = RunService:IsStudio()


-- ========================================
-- DataStore 가져오기
-- ========================================
local studioApiChecked = false
local studioApiAvailable = true
function DataStoreManager.getDataStore(dataStoreName)
	-- ✅ Studio 모드에서 API 서비스 체크
	if isStudio and not studioApiChecked then
		studioApiChecked = true
		local success = pcall(function()
			return DataStoreService:GetDataStore("_test")
		end)
		if not success then
			studioApiAvailable = false
			warn("[DataStoreManager] Studio에서 DataStore API 비활성화...")
		end
	end

	if isStudio and not studioApiAvailable then
		return nil
	end

	local success, result = pcall(function()
		return DataStoreService:GetDataStore(dataStoreName)
	end)

	if success and result then
		print(string.format("[DataStoreManager] DataStore 로드: %s", dataStoreName))
		return result
	else
		-- ✅ result는 에러 메시지 (문자열) 또는 nil
		local errorMsg = tostring(result or "알 수 없는 에러")
		warn(string.format("[DataStoreManager] DataStore 로드 실패: %s", dataStoreName))
		warn(string.format("  에러: %s", errorMsg))
		return nil
	end
end

-- ========================================
-- UpdateAsync (재시도 로직)
-- ========================================
function DataStoreManager.updateAsync(dataStoreName, key, transformFunction)
	local dataStore = DataStoreManager.getDataStore(dataStoreName)

	-- ✅ DataStore가 없으면 nil 반환
	if not dataStore then
		warn(string.format("[DataStoreManager] DataStore 없음: %s - 저장 건너뜀", dataStoreName))
		return nil
	end

	local maxRetries = 3
	local attempt = 0

	while attempt < maxRetries do
		attempt = attempt + 1

		local success, result = pcall(function()
			return dataStore:UpdateAsync(key, transformFunction)
		end)

		if success then
			print(string.format("[DataStoreManager] UpdateAsync 성공: %s", key))
			return result
		else
			-- ✅ result는 에러 메시지
			local errorMsg = tostring(result or "알 수 없는 에러")
			warn(string.format("[DataStoreManager] UpdateAsync 실패: %s (시도: %d/%d)", 
				key, attempt, maxRetries))
			warn(string.format("  에러: %s", errorMsg))

			-- 백오프: 2초, 4초, 8초
			if attempt < maxRetries then
				local backoffTime = 2 ^ attempt
				task.wait(backoffTime)
			end
		end
	end

	warn(string.format("[DataStoreManager] UpdateAsync 최종 실패: %s (모든 재시도 소진)", key))
	return nil
end

-- ========================================
-- GetAsync (재시도 로직)
-- ========================================
function DataStoreManager.getAsync(dataStoreName, key)
	local dataStore = DataStoreManager.getDataStore(dataStoreName)

	-- ✅ DataStore가 없으면 nil 반환
	if not dataStore then
		warn(string.format("[DataStoreManager] DataStore 없음: %s - 로드 건너뜀", dataStoreName))
		return nil
	end

	local maxRetries = 3
	local attempt = 0

	while attempt < maxRetries do
		attempt = attempt + 1

		local success, result = pcall(function()
			return dataStore:GetAsync(key)
		end)

		if success then
			if result then
				print(string.format("[DataStoreManager] GetAsync 성공: %s", key))
			else
				print(string.format("[DataStoreManager] GetAsync: %s (데이터 없음)", key))
			end
			return result
		else
			-- ✅ result는 에러 메시지
			local errorMsg = tostring(result or "알 수 없는 에러")
			warn(string.format("[DataStoreManager] GetAsync 실패: %s (시도: %d/%d)", 
				key, attempt, maxRetries))
			warn(string.format("  에러: %s", errorMsg))

			if attempt < maxRetries then
				local backoffTime = 2 ^ attempt
				task.wait(backoffTime)
			end
		end
	end

	warn(string.format("[DataStoreManager] GetAsync 최종 실패: %s (모든 재시도 소진)", key))
	return nil
end

-- ========================================
-- SetAsync with Retry Logic
-- ========================================
function DataStoreManager.setAsync(dataStore, key, value, maxRetries)
	maxRetries = maxRetries or 3
	local attempt = 0

	while attempt < maxRetries do
		attempt = attempt + 1

		local success, result = pcall(function()
			return dataStore:SetAsync(key, value)
		end)

		if success then
			print(string.format("[DataStoreManager] SetAsync 성공: %s (시도: %d)", key, attempt))
			return true
		else
			warn(string.format("[DataStoreManager] SetAsync 실패: %s (시도: %d/%d)", key, attempt, maxRetries))
			warn("  에러:", result)

			if attempt < maxRetries then
				local backoffTime = 2 ^ attempt
				print(string.format("  %d초 후 재시도...", backoffTime))
				wait(backoffTime)
			end
		end
	end

	warn(string.format("[DataStoreManager] SetAsync 최종 실패: %s (시도: %d회)", key, maxRetries))
	return false
end

return DataStoreManager