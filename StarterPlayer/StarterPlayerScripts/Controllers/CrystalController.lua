--[[
	CrystalController.lua
	
	목적: 크리스탈 데이터 클라이언트 관리
]]

local CrystalController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 모듈
local CrystalHUD = require(script.Parent.Parent.UI.CrystalHUD)
local CrystalDestroyUI = require(script.Parent.Parent.UI.CrystalDestroyUI)

-- RemoteEvents
local RequestCrystalState
local CrystalUpdated
local CrystalDestroyed
local CrystalRevived
local RebuildPartyStarted
local RebuildPartyEnded

-- 로컬 데이터 캐시
local localCrystalData = nil

-- ========================================
-- 초기화
-- ========================================
function CrystalController.init()
	print("[CrystalController] 초기화 시작")

	-- RemoteEvents 연결
	local crystalRemotes = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("CrystalRemotes")

	RequestCrystalState = crystalRemotes:WaitForChild("RequestCrystalState")
	CrystalUpdated = crystalRemotes:WaitForChild("CrystalUpdated")

	-- 추가 RemoteEvents (없으면 대기)
	CrystalDestroyed = crystalRemotes:FindFirstChild("CrystalDestroyed")
	if CrystalDestroyed then
		CrystalDestroyed.OnClientEvent:Connect(function()
			CrystalController.onCrystalDestroyed()
		end)
	end

	CrystalRevived = crystalRemotes:FindFirstChild("CrystalRevived")
	if CrystalRevived then
		CrystalRevived.OnClientEvent:Connect(function()
			CrystalController.onCrystalRevived()
		end)
	end

	RebuildPartyStarted = crystalRemotes:FindFirstChild("RebuildPartyStarted")
	if RebuildPartyStarted then
		RebuildPartyStarted.OnClientEvent:Connect(function(data)
			CrystalController.onRebuildPartyStarted(data)
		end)
	end

	RebuildPartyEnded = crystalRemotes:FindFirstChild("RebuildPartyEnded")
	if RebuildPartyEnded then
		RebuildPartyEnded.OnClientEvent:Connect(function(data)
			CrystalController.onRebuildPartyEnded(data)
		end)
	end

	-- UI 생성
	CrystalHUD.create()
	CrystalDestroyUI.init()

	-- 서버로부터 초기 데이터 요청
	CrystalController.requestInitialData()

	-- 데이터 업데이트 리스너
	CrystalUpdated.OnClientEvent:Connect(function(crystalData)
		CrystalController.onDataUpdated(crystalData)
	end)

	print("[CrystalController] 초기화 완료")
end

-- ========================================
-- 초기 데이터 요청
-- ========================================
function CrystalController.requestInitialData()
	print("[CrystalController] 서버에 초기 데이터 요청")

	local success, crystalData = pcall(function()
		return RequestCrystalState:InvokeServer()
	end)

	if success and crystalData then
		print("[CrystalController] 초기 데이터 수신")
		CrystalController.onDataUpdated(crystalData)
	else
		warn("[CrystalController] 초기 데이터 요청 실패")
	end
end

-- ========================================
-- 데이터 업데이트 처리
-- ========================================
function CrystalController.onDataUpdated(crystalData)
	if not crystalData then
		warn("[CrystalController] 수신한 crystalData가 nil입니다")
		return
	end

	-- 로컬 캐시 업데이트
	localCrystalData = crystalData

	-- UI 업데이트
	CrystalHUD.update(crystalData)

	--print(string.format("[CrystalController] 데이터 업데이트: Lv=%d, HP=%d/%d, 상태=%s", crystalData.level, crystalData.hp, crystalData.maxHp, crystalData.state))
end

-- ========================================
-- 크리스탈 파괴
-- ========================================
function CrystalController.onCrystalDestroyed()
	print("[CrystalController] 💔 크리스탈 파괴!")

	CrystalDestroyUI.showDestroyed()
end

-- ========================================
-- 크리스탈 부활
-- ========================================
function CrystalController.onCrystalRevived()
	print("[CrystalController] ✨ 크리스탈 부활!")

	CrystalDestroyUI.showRevived()
end

-- ========================================
-- 재건 파티 시작
-- ========================================
function CrystalController.onRebuildPartyStarted(data)
	print("[CrystalController] 🎉 재건 파티 시작!")

	CrystalDestroyUI.showRebuildParty(data)
end

-- ========================================
-- 재건 파티 종료
-- ========================================
function CrystalController.onRebuildPartyEnded(data)
	print("[CrystalController] 재건 파티 종료:", data.success)

	CrystalDestroyUI.showRebuildPartyEnd(data.success)
end

-- ========================================
-- 로컬 데이터 가져오기
-- ========================================
function CrystalController.getLocalData()
	return localCrystalData
end

return CrystalController