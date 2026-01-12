--[[
	WaveController.lua
	
	목적: Wave 데이터 클라이언트 관리
]]

local WaveController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- 모듈
local WaveHUD = require(script.Parent.Parent.UI.WaveHUD)

-- RemoteEvents
local WaveStateChanged
local WaveCompleted

-- 로컬 상태
local currentWaveData = {
	state = "Peace",
	waveNumber = 0,
	totalWaves = 5,
	duration = 300,
}

local startTime = 0

-- ========================================
-- 초기화
-- ========================================
function WaveController.init()
	print("[WaveController] 초기화 시작")

	-- RemoteEvents 연결
	WaveStateChanged = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("WaveRemotes"):WaitForChild("WaveStateChanged")
	WaveCompleted = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("WaveRemotes"):WaitForChild("WaveCompleted")

	-- UI 생성
	WaveHUD.create()

	-- 이벤트 리스너
	WaveStateChanged.OnClientEvent:Connect(function(waveData)
		WaveController.onWaveStateChanged(waveData)
	end)

	WaveCompleted.OnClientEvent:Connect(function(rewardData)
		WaveController.onWaveCompleted(rewardData)
	end)

	-- 타이머 업데이트 (매 초)
	RunService.Heartbeat:Connect(function()
		WaveController.updateTimer()
	end)

	print("[WaveController] 초기화 완료")
end

-- ========================================
-- Wave 상태 변경
-- ========================================
function WaveController.onWaveStateChanged(waveData)
	print(string.format("[WaveController] 상태 변경: %s, Wave %d", waveData.state, waveData.waveNumber or 0))

	currentWaveData = waveData
	startTime = tick()

	-- UI 업데이트
	WaveHUD.update(waveData)
end

-- ========================================
-- Wave 완료
-- ========================================
function WaveController.onWaveCompleted(rewardData)
	print(string.format("[WaveController] Wave %d 완료! 보상: %dG", 
		rewardData.waveNumber, rewardData.goldReward))

	-- TODO: 보상 알림 UI
end

-- ========================================
-- 타이머 업데이트
-- ========================================
function WaveController.updateTimer()
	if not currentWaveData then return end

	local elapsed = tick() - startTime
	local remaining = math.max(0, currentWaveData.duration - math.floor(elapsed))

	-- 남은 시간 업데이트
	if remaining ~= currentWaveData.duration then
		local updatedData = {
			state = currentWaveData.state,
			waveNumber = currentWaveData.waveNumber,
			totalWaves = currentWaveData.totalWaves,
			duration = remaining,
		}

		WaveHUD.update(updatedData)
	end
end

return WaveController