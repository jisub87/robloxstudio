--[[
	CombatController.lua
	
	목적: 전투 이펙트 클라이언트 관리
	책임:
	  - 몬스터 스폰 이펙트
	  - 몬스터 처치 이펙트
	  - 골드 획득 알림
]]

local CombatController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- RemoteEvents
local MonsterSpawned
local MonsterKilled

-- ========================================
-- 초기화
-- ========================================
function CombatController.init()
	print("[CombatController] 초기화 시작")

	-- RemoteEvents 연결
	MonsterSpawned = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("CombatRemotes"):WaitForChild("MonsterSpawned")
	MonsterKilled = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("CombatRemotes"):WaitForChild("MonsterKilled")

	-- 이벤트 리스너
	MonsterSpawned.OnClientEvent:Connect(function(data)
		CombatController.onMonsterSpawned(data)
	end)

	MonsterKilled.OnClientEvent:Connect(function(data)
		CombatController.onMonsterKilled(data)
	end)

	print("[CombatController] 초기화 완료")
end

-- ========================================
-- 몬스터 스폰 이벤트
-- ========================================
function CombatController.onMonsterSpawned(data)
	--print(string.format("[CombatController] 몬스터 스폰: %s (%s)", data.monsterId, data.monsterType))

	-- TODO: 스폰 이펙트 (파티클, 사운드)
end

-- ========================================
-- 몬스터 처치 이벤트
-- ========================================
function CombatController.onMonsterKilled(data)
	--print(string.format("[CombatController] 몬스터 처치: %s (골드: %d)", data.monsterType, data.goldReward))

	-- TODO: 처치 이펙트 (폭발, 사운드)
	-- TODO: 골드 획득 알림 (+5G 등)
end

return CombatController