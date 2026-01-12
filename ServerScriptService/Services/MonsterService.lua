--[[
	MonsterService.lua
	
	목적: 몬스터 생성 및 AI 관리
	책임:
	  - 몬스터 스폰
	  - 경로 찾기 (PathfindingService)
	  - 크리스탈 공격
	  - 몬스터 처치
]]

local MonsterService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

-- 모듈
local MonsterConfig = require(ServerScriptService.Modules.Config.MonsterConfig)
local CrystalService = nil
local BuildingService = require(ServerScriptService.Services.BuildingService)
local WorldDataStore = require(ServerScriptService.Modules.DataStore.WorldDataStore)
local MonsterScaler = require(ServerScriptService.Modules.Systems.MonsterScaler)

local SoundService -- ✅ 추가

-- RemoteEvents
local MonsterSpawned = ReplicatedStorage.RemoteEvents.CombatRemotes.MonsterSpawned
local MonsterKilled = ReplicatedStorage.RemoteEvents.CombatRemotes.MonsterKilled

-- 몬스터 폴더
local monstersFolder = workspace:FindFirstChild("Monsters")
if not monstersFolder then
	monstersFolder = Instance.new("Folder")
	monstersFolder.Name = "Monsters"
	monstersFolder.Parent = workspace
end

-- 활성 몬스터 추적
local activeMonsters = {}


-- ✅ 트랩 밟기 디바운스 (몬스터-트랩 쌍)
local trapDebounce = {}

local function trapKey(monsterId, buildingId)
	return monsterId .. "::" .. buildingId
end

local function getCrystalService()
	if CrystalService then return CrystalService end
	CrystalService = require(game:GetService("ServerScriptService").Services.CrystalService)
	return CrystalService
end

-- ========================================
-- 초기화
-- ========================================
function MonsterService.init()
	-- SoundService 로드
	SoundService = require(ServerScriptService.Services.SoundService)

	print("[MonsterService] 초기화 완료")
end

-- 몬스터가 트랩 밟는 처리
local function tryTriggerTrap(monsterId, trapId)
	local worldData = require(ServerScriptService.Modules.DataStore.WorldDataStore).get()
	if not worldData or not worldData.buildings then return end

	local trapData = worldData.buildings[trapId]
	if not trapData or trapData.type ~= "Trap" then return end

	local k = trapKey(monsterId, trapId)
	if trapDebounce[k] then return end
	trapDebounce[k] = true

	-- trap HP만큼 피해 (요구사항)
	local trapHp = tonumber(trapData.hp) or 0
	if trapHp <= 0 then
		trapDebounce[k] = nil
		return
	end

	-- 몬스터 현재 HP
	local m = activeMonsters[monsterId]
	if not m or not m.isAlive then
		trapDebounce[k] = nil
		return
	end

	local monsterHp = tonumber(m.currentHp) or 0
	local dmg = math.min(trapHp, monsterHp)

	-- 몬스터 피해
	MonsterService.damageMonster(monsterId, dmg)

	-- 트랩도 동일하게 HP 감소 → 보통 0이라 파괴됨
	local BuildingService = require(ServerScriptService.Services.BuildingService)
	BuildingService.damageBuilding(trapId, dmg)

	-- 0.2초 후 디바운스 해제 (겹침 연속 호출 방지)
	task.delay(0.2, function()
		trapDebounce[k] = nil
	end)
end

-- ========================================
-- 몬스터 스폰
-- ========================================
function MonsterService.spawnMonster(monsterType, spawnPosition, waveNumber, crystalLevel)
	local baseSpec = MonsterConfig.getSpec(monsterType)
	if not baseSpec then
		warn("[MonsterService] 유효하지 않은 몬스터 타입:", monsterType)
		return nil
	end

	local monsterLevel = MonsterScaler.computeMonsterLevel(crystalLevel, waveNumber)

	local spec = MonsterConfig.getSpec(monsterType)
	if not spec then
		warn("[MonsterService] 유효하지 않은 몬스터 타입:", monsterType)
		return nil
	end

	-- spec 정규화 (nil 방지)
	spec.hp = tonumber(spec.hp) or 1
	spec.speed = tonumber(spec.speed) or 10
	spec.attackPower = tonumber(spec.attackPower) or 1
	spec.goldReward = tonumber(spec.goldReward) or 0
	spec.expReward = tonumber(spec.expReward) or 0
	spec.level = tonumber(spec.level) or 1 -- ✅ 추가
	print("[MonsterService] debug spec:",
		"monsterType=", monsterType,
		"hp=", spec and spec.hp,
		"speed=", spec and spec.speed,
		"atk=", spec and spec.attackPower,
		"gold=", spec and spec.goldReward,
		"level=", spec and spec.level
	)

	-- 몬스터 ID 생성
	local monsterId = "monster_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))

	-- 몬스터 Model 생성
	local monsterModel = Instance.new("Model")
	monsterModel.Name = monsterId
	monsterModel.Parent = monstersFolder

	-- 몬스터 Part (Body)
	local monsterPart = Instance.new("Part")
	monsterPart.Name = "Body"
	monsterPart.Size = spec.size
	monsterPart.Position = spawnPosition + Vector3.new(0, spec.size.Y / 2, 0)
	monsterPart.Anchored = false
	monsterPart.CanTouch = true
	monsterPart.CanCollide = true

	-- 몬스터 타입별 색상
	if monsterType == "Slime" then
		monsterPart.Color = Color3.fromRGB(100, 255, 100) -- 초록
		monsterPart.Material = Enum.Material.SmoothPlastic
		monsterPart.Shape = Enum.PartType.Ball
	elseif monsterType == "Goblin" then
		monsterPart.Color = Color3.fromRGB(150, 100, 50) -- 갈색
	elseif monsterType == "Orc" then
		monsterPart.Color = Color3.fromRGB(100, 100, 100) -- 회색
	elseif monsterType == "Boss" then
		monsterPart.Color = Color3.fromRGB(50, 50, 50) -- 검은색
		monsterPart.Material = Enum.Material.Neon
	end

	monsterPart.Parent = monsterModel

	-- ✅ HPBar 생성
	local hpBillboard = Instance.new("BillboardGui")
	hpBillboard.Name = "HPBar"
	hpBillboard.Size = UDim2.new(0, 90, 0, 28)
	hpBillboard.StudsOffset = Vector3.new(0, spec.size.Y/2 + 2.5, 0)
	hpBillboard.AlwaysOnTop = true
	hpBillboard.Parent = monsterPart

	local bg = Instance.new("Frame")
	bg.Name = "BG"
	bg.Size = UDim2.new(1, 0, 0, 10)
	bg.Position = UDim2.new(0, 0, 0, 0)
	bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	bg.BorderSizePixel = 0
	bg.Parent = hpBillboard

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 6)
	bgCorner.Parent = bg

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
	fill.BorderSizePixel = 0
	fill.Parent = bg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	local hpText = Instance.new("TextLabel")
	hpText.Name = "HPText"
	hpText.Size = UDim2.new(1, 0, 0, 16)
	hpText.Position = UDim2.new(0, 0, 0, 12)
	hpText.BackgroundTransparency = 1
	hpText.TextColor3 = Color3.new(1, 1, 1)
	hpText.TextScaled = true
	hpText.Font = Enum.Font.GothamBold
	hpText.Text = string.format("%d / %d", spec.hp, spec.hp)
	hpText.Parent = hpBillboard

	-- spawnMonster 안에서 monsterPart.Parent = monsterModel 이후 추가:
	monsterPart.Touched:Connect(function(hit)
		-- hit이 Buildings 안의 파트인지 확인
		local buildingsFolder = workspace:FindFirstChild("Buildings")
		if not buildingsFolder then return end

		if hit and hit:IsDescendantOf(buildingsFolder) then
			local trapId = hit.Name
			-- 월드데이터에서 Trap인지 확인은 tryTriggerTrap에서 함
			tryTriggerTrap(monsterId, trapId)
		end
	end)

	-- Humanoid 생성
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = spec.hp
	humanoid.Health = spec.hp
	humanoid.WalkSpeed = spec.speed
	humanoid.Parent = monsterModel

	-- PrimaryPart 설정
	monsterModel.PrimaryPart = monsterPart

	monsterModel:SetAttribute("MonsterType", monsterType)
	monsterModel:SetAttribute("MonsterLevel", spec.level)
	monsterModel:SetAttribute("GoldReward", spec.goldReward)

	-- 이름에 레벨 표시(선택)
	monsterModel.Name = string.format("monster_%d_%d_%d", os.time(), math.random(1000,9999), spec.level)

	-- BodyVelocity (경로 이동용)
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(0, 0, 0)
	bodyVelocity.Velocity = Vector3.new(0, 0, 0)
	bodyVelocity.Parent = monsterPart

	-- 몬스터 데이터
	local monsterData = {
		id = monsterId,
		type = monsterType,
		model = monsterModel,
		humanoid = humanoid,
		spec = spec,
		currentHp = spec.hp,
		maxHp = spec.hp,
		targetPosition = Vector3.new(0, 0, 0), -- 크리스탈 위치
		isAlive = true,
	}

	activeMonsters[monsterId] = monsterData

	-- AI 시작
	MonsterService.startAI(monsterData)

	-- 클라이언트 알림
	MonsterSpawned:FireAllClients({
		monsterId = monsterId,
		monsterType = monsterType,
		position = spawnPosition,
	})

	--print(string.format("[MonsterService] 몬스터 스폰: %s (%s)", monsterId, monsterType))

	return monsterData
end

-- ========================================
-- AI 시작
-- ========================================
function MonsterService.startAI(monsterData)
	task.spawn(function()
		while monsterData.isAlive and monsterData.model.Parent do
			-- 크리스탈 위치로 이동
			local crystalPosition = Vector3.new(0, 0, 0)
			local currentPosition = monsterData.model.PrimaryPart.Position

			-- 거리 확인
			local distance = (crystalPosition - currentPosition).Magnitude

			if distance <= 5 then
				MonsterService.attackCrystal(monsterData)
				task.wait(1)
			else
				local dir = (crystalPosition - currentPosition)
				if dir.Magnitude < 0.001 then
					task.wait(0.1)
					return
				end
				dir = dir.Unit

				-- ✅ 전방 건물 체크
				local buildingsFolder = workspace:FindFirstChild("Buildings")
				local hitBuildingId = nil

				if buildingsFolder then
					local rp = RaycastParams.new()
					rp.FilterType = Enum.RaycastFilterType.Whitelist
					rp.FilterDescendantsInstances = { buildingsFolder }
					rp.IgnoreWater = true

					-- 감지 거리(몬스터 크기/속도에 따라 조절)
					local checkDist = 6
					local hit = workspace:Raycast(currentPosition, dir * checkDist, rp)

					if hit and hit.Instance and hit.Instance:IsA("BasePart") then
						hitBuildingId = hit.Instance.Name
					end
				end

				if hitBuildingId then
					-- ✅ 건물 공격 모드: 이동 멈춤 + 공격
					local bodyVelocity = monsterData.model.PrimaryPart:FindFirstChildOfClass("BodyVelocity")
					if bodyVelocity then
						bodyVelocity.MaxForce = Vector3.new(0, 0, 0)
						bodyVelocity.Velocity = Vector3.new(0, 0, 0)
					end

					-- 공격
					local dmg = monsterData.spec.attackPower or 5
					BuildingService.damageBuilding(hitBuildingId, dmg)

					task.wait(1) -- 공격 쿨다운
				else
					-- ✅ 막는 건물 없으면 이동
					local velocity = dir * monsterData.spec.speed
					local bodyVelocity = monsterData.model.PrimaryPart:FindFirstChildOfClass("BodyVelocity")
					if bodyVelocity then
						bodyVelocity.MaxForce = Vector3.new(4000, 0, 4000)
						bodyVelocity.Velocity = Vector3.new(velocity.X, 0, velocity.Z)
					end

					task.wait(0.1)
				end
			end
		end
	end)
end

-- ========================================
-- 크리스탈 공격
-- ========================================
function MonsterService.attackCrystal(monsterData)
	if not monsterData.isAlive then return end

	local damage = monsterData.spec.attackPower

	--print(string.format("[MonsterService] %s가 크리스탈 공격 (피해: %d)", monsterData.id, damage))

	-- CrystalService에 피해 전달
	local CrystalService = getCrystalService()
	CrystalService.changeHp(-damage)
end

-- ========================================
-- 몬스터 피해
-- ========================================
-- damageMonster 함수에서 몬스터 타입 반환

function MonsterService.damageMonster(monsterId, damage)
	local monsterData = activeMonsters[monsterId]
	if not monsterData or not monsterData.isAlive then
		return false, nil
	end

	damage = math.max(0, tonumber(damage) or 0)
	if damage <= 0 then
		-- damage가 0이면 여기서부터 아무 변화 없음
		return false, monsterData.type, 0, monsterData.level or 1
	end

	-- ✅ currentHp가 nil인 케이스 방지 (스케일링/리팩터링 하다 자주 생김)
	local maxHp = tonumber(monsterData.maxHp)
		or tonumber(monsterData.spec and monsterData.spec.hp)
		or tonumber(monsterData.humanoid and monsterData.humanoid.MaxHealth)
		or 1

	local curHp = tonumber(monsterData.currentHp)
		or tonumber(monsterData.humanoid and monsterData.humanoid.Health)
		or maxHp

	curHp = curHp - damage
	curHp = math.clamp(curHp, 0, maxHp)

	monsterData.currentHp = curHp

	-- ✅ Humanoid랑 동기화 (클라에서 HP를 보거나 내부 로직이 Humanoid를 볼 수도 있음)
	if monsterData.humanoid then
		monsterData.humanoid.MaxHealth = maxHp
		monsterData.humanoid.Health = curHp
	end

	-- ✅ HPBar/UI 업데이트 (네가 추가한 코드가 있다면 유지)
	local primary = monsterData.model and monsterData.model.PrimaryPart
	if primary then
		local hpBar = primary:FindFirstChild("HPBar")
		if hpBar then
			local bg = hpBar:FindFirstChild("BG")
			local fill = bg and bg:FindFirstChild("Fill")
			local hpText = hpBar:FindFirstChild("HPText")

			local ratio = math.clamp(curHp / maxHp, 0, 1)
			if fill then
				fill.Size = UDim2.new(ratio, 0, 1, 0)
			end
			if hpText then
				hpText.Text = string.format("%d / %d", math.floor(curHp + 0.5), math.floor(maxHp + 0.5))
			end
		end
	end

	-- ✅ 처치 확인
	if curHp <= 0 then
		MonsterService.killMonster(monsterId)
		return true, monsterData.type, monsterData.goldReward or (monsterData.spec and monsterData.spec.goldReward) or 0, monsterData.level or 1
	end

	return false, monsterData.type, monsterData.goldReward or (monsterData.spec and monsterData.spec.goldReward) or 0, monsterData.level or 1
end


-- getMonsterType 함수 추가
function MonsterService.getMonsterType(monsterId)
	local monsterData = activeMonsters[monsterId]
	if monsterData then
		return monsterData.type
	end
	return nil
end

-- ========================================
-- 몬스터 처치
-- ========================================
function MonsterService.killMonster(monsterId)
	local monsterData = activeMonsters[monsterId]
	if not monsterData then return end

	monsterData.isAlive = false

	--print(string.format("[MonsterService] 몬스터 처치: %s", monsterId))

	-- ✅ 처치 사운드
	if SoundService and monsterData.model.PrimaryPart then
		SoundService.playSFX("MonsterDeath", monsterData.model.PrimaryPart.Position)
	end
	
	local reward =
		tonumber(monsterData.spec.goldReward)
		or tonumber(monsterData.spec.rewardGold)
		or tonumber(monsterData.spec.gold)
		or 0
	
	-- 클라이언트 알림
	MonsterKilled:FireAllClients({
		monsterId = monsterId,
		monsterType = monsterData.type,
		monsterLevel = monsterData.spec.level or 1,
		goldReward = monsterData.spec.goldReward,
	})

	-- Model 삭제
	if monsterData.model then
		monsterData.model:Destroy()
	end

	-- 활성 목록에서 제거
	activeMonsters[monsterId] = nil

	-- TODO: 골드/Exp 보상 지급 (PlayerDataService)
end

-- ========================================
-- 활성 몬스터 개수
-- ========================================
function MonsterService.getActiveMonsterCount()
	local count = 0
	for _ in pairs(activeMonsters) do
		count = count + 1
	end
	return count
end

-- ========================================
-- 모든 몬스터 제거
-- ========================================
function MonsterService.clearAllMonsters()
	for monsterId, monsterData in pairs(activeMonsters) do
		if monsterData.model then
			monsterData.model:Destroy()
		end
	end

	activeMonsters = {}
	print("[MonsterService] 모든 몬스터 제거")
end

return MonsterService