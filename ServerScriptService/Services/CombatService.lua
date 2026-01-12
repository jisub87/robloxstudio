--[[
	CombatService.lua
	
	목적: 전투 관리 (타워 자동 공격)
	책임:
	  - 타워 자동 공격
	  - 몬스터 탐지
	  - 피해 계산
	  - 골드 보상 지급
	  - 타워 수수료
]]

local CombatService = {}
local SoundService -- ✅ 추가

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")


-- 모듈
local BuildingConfig = require(ServerScriptService.Modules.Config.BuildingConfig)
local MonsterService = require(ServerScriptService.Services.MonsterService)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local WorldDataStore = require(ServerScriptService.Modules.DataStore.WorldDataStore)
local Constants = require(ServerScriptService.Modules.Data.Constants)



-- 타워 공격 타이머
local towerAttackTimers = {}

-- ========================================
-- 리모트
-- ========================================
local SystemLogAdded -- RemoteEvent
local function getSystemLogRemote()
	if SystemLogAdded then return SystemLogAdded end

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local sys = remotes:FindFirstChild("SystemRemotes")
	if not sys then
		sys = Instance.new("Folder")
		sys.Name = "SystemRemotes"
		sys.Parent = remotes
	end

	local ev = sys:FindFirstChild("SystemLogAdded")
	if not ev then
		ev = Instance.new("RemoteEvent")
		ev.Name = "SystemLogAdded"
		ev.Parent = sys
	end

	SystemLogAdded = ev
	return SystemLogAdded
end

local function logToPlayer(player, text)
	local ev = getSystemLogRemote()
	if ev and player then
		ev:FireClient(player, { text = text })
	end
end
-- ========================================
-- 초기화
-- ========================================
function CombatService.init()
	-- SoundService 로드
	SoundService = require(ServerScriptService.Services.SoundService)

	-- 타워 자동 공격 루프 시작
	CombatService.startTowerAttackLoop()

	print("[CombatService] 초기화 완료")
end

-- ========================================
-- 타워 자동 공격 루프
-- ========================================
function CombatService.startTowerAttackLoop()
	RunService.Heartbeat:Connect(function()
		local worldData = WorldDataStore.get()
		if not worldData then return end

		-- 모든 타워 확인
		for buildingId, buildingData in pairs(worldData.buildings) do
			if buildingData.type == "Tower" then
				CombatService.updateTowerAttack(buildingId, buildingData)
			end
		end
	end)
end

-- ========================================
-- 타워 공격 업데이트
-- ========================================
function CombatService.updateTowerAttack(buildingId, buildingData)
	-- 타워 Instance 찾기
	local buildingsFolder = workspace:FindFirstChild("Buildings")
	if not buildingsFolder then return end

	local towerPart = buildingsFolder:FindFirstChild(buildingId)
	if not towerPart then return end

	-- 공격 타이머 확인
	local lastAttackTime = towerAttackTimers[buildingId] or 0
	local currentTime = tick()

	local spec = BuildingConfig.getSpec("Tower")
	local attackInterval = 1 / spec.attackSpeed -- 1초당 1회 = 1초 간격

	if currentTime - lastAttackTime < attackInterval then
		return -- 아직 쿨다운
	end

	-- 가장 가까운 몬스터 찾기
	local target = CombatService.findNearestMonster(towerPart.Position, spec.attackRange)

	if target then
		-- 공격!
		CombatService.towerAttack(buildingId, buildingData, towerPart, target)
		towerAttackTimers[buildingId] = currentTime
	end
end

-- ========================================
-- 가장 가까운 몬스터 찾기
-- ========================================
function CombatService.findNearestMonster(towerPosition, attackRange)
	local monstersFolder = workspace:FindFirstChild("Monsters")
	if not monstersFolder then return nil end

	local nearestMonster = nil
	local nearestDistance = attackRange

	for _, monsterModel in ipairs(monstersFolder:GetChildren()) do
		if monsterModel:IsA("Model") and monsterModel.PrimaryPart then
			local distance = (monsterModel.PrimaryPart.Position - towerPosition).Magnitude

			if distance <= attackRange and distance < nearestDistance then
				nearestMonster = monsterModel
				nearestDistance = distance
			end
		end
	end

	return nearestMonster
end

-- ========================================
-- 타워 공격
-- ========================================
function CombatService.towerAttack(buildingId, buildingData, towerPart, targetMonster)
	local spec = BuildingConfig.getSpec("Tower")
	local damage = spec.attackPower

	-- 몬스터 ID
	local monsterId = targetMonster.Name

	-- ✅ 타워 공격 사운드
	if SoundService then
		SoundService.playSFX("TowerAttack", towerPart.Position)
	end
	
	-- 발사체 생성
	CombatService.createProjectile(towerPart.Position, targetMonster.PrimaryPart.Position, damage)
	-- ✅ MonsterService가 스케일된 goldReward/level을 반환하도록 변경했음
	local killed, monsterType, goldReward, monsterLevel = MonsterService.damageMonster(monsterId, damage)

	if killed then
		CombatService.onMonsterKilledByTower(buildingId, buildingData, monsterType, goldReward, monsterLevel)

		-- ✅ 처치 통계는 killed일 때만 1회
		buildingData.stats.monstersDefeated = (buildingData.stats.monstersDefeated or 0) + 1
		WorldDataStore.markDirty()
	end

end

-- ========================================
-- 발사체 생성
-- ========================================
function CombatService.createProjectile(startPos, endPos)
	-- 발사체 Part
	local projectile = Instance.new("Part")
	projectile.Name = "Projectile"
	projectile.Size = Vector3.new(0.5, 0.5, 0.5)
	projectile.Position = startPos
	projectile.Anchored = false
	projectile.CanCollide = false
	
	-- ✅ Touched 이벤트가 안 뜨는 문제 방지
	projectile.CanTouch = true
	projectile.CanQuery = false
	
	projectile.Shape = Enum.PartType.Ball
	projectile.Material = Enum.Material.Neon
	projectile.Color = Color3.fromRGB(255, 255, 100) -- 노란색
	projectile.Parent = workspace

	-- ✅ 서버가 물리/충돌을 확실히 잡도록 (네트워크 소유권)
	pcall(function()
		projectile:SetNetworkOwner(nil)
	end)
	
	-- 발사
	local direction = (endPos - startPos)
	if direction.Magnitude < 0.1 then direction = Vector3.new(0,0,-1) end
	direction = direction.Unit

	local speed = 80
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
	bodyVelocity.Velocity = direction * speed
	bodyVelocity.Parent = projectile

	-- ✅ 맞으면 데미지 1회
	local hitOnce = false
	projectile.Touched:Connect(function(hit)
		if hitOnce then return end
		if not hit or not hit.Parent then return end

		-- 몬스터 Model 찾기
		local model = hit:FindFirstAncestorOfClass("Model")
		if not model then return end
		if model.Parent ~= workspace:FindFirstChild("Monsters") then return end

		-- ✅ monsterId = model.Name (spawnMonster에서 monsterId로 Name을 쓰는 구조)
		local monsterId = model.Name

		hitOnce = true
		local killed, monsterType, goldReward, monsterLevel = MonsterService.damageMonster(monsterId, damage)

		-- 맞으면 삭제
		if projectile and projectile.Parent then
			projectile:Destroy()
		end
	end)
	
	-- 자동 삭제(빗나감 대비)
	task.delay(2, function()
		if projectile and projectile.Parent then
			projectile:Destroy()
		end
	end)

	return projectile
end

-- ========================================
-- 타워가 몬스터 처치 시
-- ========================================
function CombatService.onMonsterKilledByTower(buildingId, buildingData, monsterType, goldReward, monsterLevel)
	goldReward = tonumber(goldReward) or 0
	monsterLevel = tonumber(monsterLevel) or 1

	-- 0이면 스폰/스케일 쪽이 문제라 경고
	if goldReward <= 0 then
		warn("[CombatService] goldReward가 0입니다:",
			"monsterType=", monsterType,
			"monsterLevel=", monsterLevel
		)
	end

	-- 타워 소유자
	local ownerId = buildingData.ownerId
	local owner = Players:GetPlayerByUserId(ownerId)

	-- 월드 소유자
	local worldData = WorldDataStore.get()
	if not worldData then return end

	local worldOwnerId = worldData.ownerId
	local worldOwner = Players:GetPlayerByUserId(worldOwnerId)

	-- 수수료
	local commissionRate = Constants.TOWER_COMMISSION.RATE
	local commission = math.floor(goldReward * commissionRate)
	local worldOwnerGold = goldReward - commission

	-- 표시용 문자열 (원하면 icon/displayName으로 더 예쁘게 가능)
	local label = string.format("👾 %s Lv.%d 처치", monsterType, monsterLevel)

	if ownerId == worldOwnerId then
		-- 내 월드: 100%
		if owner then
			PlayerDataService.addGold(owner, goldReward, label .. " 보상")

			-- ✅ SystemLog에 '실제 받은 금액' 그대로 출력
			logToPlayer(owner, string.format("%s  +%dG", label, goldReward))
		end
	else
		-- 타인 월드: 10/90
		if owner then
			PlayerDataService.addGold(owner, commission, label .. " 수수료")
			logToPlayer(owner, string.format("%s  +%dG (수수료)", label, commission))
		end

		if worldOwner then
			PlayerDataService.addGold(worldOwner, worldOwnerGold, label .. " 월드 보상")
			logToPlayer(worldOwner, string.format("%s  +%dG (월드)", label, worldOwnerGold))
		end
	end
end



return CombatService