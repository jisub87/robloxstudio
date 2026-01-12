--[[
	CrystalService.lua
	
	목적: 월드 크리스탈 관리 (서버 권한)
	책임:
	  - 크리스탈 HP 관리
	  - 상태 계산 (Healthy/Worried/Danger/Critical)
	  - 레벨업 처리
	  - 크리스탈 Instance 생성/업데이트
	  - 클라이언트 동기화
]]

local CrystalService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local workspace = game:GetService("Workspace")

-- 모듈
local Constants = require(ServerScriptService.Modules.Data.Constants)
local WorldDataStore = require(ServerScriptService.Modules.DataStore.WorldDataStore)
local SoundService -- ✅ 추가
local CrystalThemeConfig = require(ServerScriptService.Modules.Config.CrystalThemeConfig)
local BuildingService = require(ServerScriptService.Services.BuildingService)
local WaveService =nil

-- RemoteEvents
local RequestCrystalState
local CrystalUpdated

-- 크리스탈 Instance
local crystalModel = nil
local crystalPart = nil

local isShuttingDown = false


local function getWaveService()
	if WaveService then return WaveService end
	WaveService = require(game:GetService("ServerScriptService").Services.WaveService)
	return WaveService
end

-- ========================================
-- 셧다운 함수
-- ========================================
function CrystalService.shutdown()
	isShuttingDown = true
end

-- ========================================
-- 초기화
-- ========================================
function CrystalService.init()
	-- RemoteEvents 연결
	RequestCrystalState = ReplicatedStorage.RemoteEvents.CrystalRemotes.RequestCrystalState
	CrystalUpdated = ReplicatedStorage.RemoteEvents.CrystalRemotes.CrystalUpdated

	-- SoundService 로드
	SoundService = require(ServerScriptService.Services.SoundService)


	-- RemoteFunction 콜백
	RequestCrystalState.OnServerInvoke = function(player)
		return CrystalService.getCrystalStateDto()
	end

	-- 크리스탈 생성
	CrystalService.createCrystal()

	print("[CrystalService] 초기화 완료")
end

-- ========================================
-- 크리스탈 Instance 생성
-- ========================================
function CrystalService.createCrystal()
	local worldData = WorldDataStore.get()
	if not worldData then
		warn("[CrystalService] 월드 데이터 없음")
		return
	end

	-- CrystalZone 폴더 찾기/생성
	local crystalZone = workspace:FindFirstChild("CrystalZone")
	if not crystalZone then
		crystalZone = Instance.new("Folder")
		crystalZone.Name = "CrystalZone"
		crystalZone.Parent = workspace
	end

	-- 기존 크리스탈 삭제
	local existingCrystal = crystalZone:FindFirstChild("WorldCrystal")
	if existingCrystal then
		existingCrystal:Destroy()
	end

	-- 크리스탈 Model 생성
	crystalModel = Instance.new("Model")
	crystalModel.Name = "WorldCrystal"
	crystalModel.Parent = crystalZone

	-- 크리스탈 Part (육각기둥 형태)
	crystalPart = Instance.new("Part")
	crystalPart.Name = "CrystalCore"
	crystalPart.Size = Vector3.new(6, 20, 6) -- 레벨에 따라 증가
	crystalPart.Position = Vector3.new(0, 10, 0) -- 중앙, Y=10
	crystalPart.Anchored = true
	crystalPart.CanCollide = false
	crystalPart.Material = Enum.Material.Neon
	crystalPart.Transparency = 0.3
	crystalPart.Shape = Enum.PartType.Ball -- 임시 (나중에 Mesh로 교체)
	crystalPart.Parent = crystalModel

	-- 초기 색상 설정
	CrystalService.updateCrystalAppearance()

	-- 회전 애니메이션 (간단한 버전)
	task.spawn(function()
		while not isShuttingDown and crystalPart and crystalPart.Parent do
			crystalPart.Orientation = crystalPart.Orientation + Vector3.new(0, 1, 0)
			task.wait(0.05)
		end
	end)

	print("[CrystalService] 크리스탈 생성 완료")
end

-- ========================================
-- 크리스탈 외형 업데이트
-- ========================================
function CrystalService.updateCrystalAppearance()
	if not crystalPart then return end

	local worldData = WorldDataStore.get()
	if not worldData then return end

	local crystal = worldData.crystal
	
	-- ✅ 테마/변형 적용
	local themeInfo = CrystalThemeConfig.getThemeForLevel(crystal.level)
	
	local state = CrystalService.calculateState(crystal.hp, crystal.maxHp)

	-- 상태별 색상
	local stateTint = {
		Healthy = Color3.fromRGB(255,255,255),
		Worried = Color3.fromRGB(255,240,160),
		Danger = Color3.fromRGB(255,200,140),
		Critical = Color3.fromRGB(255,140,140),
	}
	
	--local stateColors = {
	--	Healthy = Color3.fromRGB(100, 200, 255), -- 밝은 파란색
	--	Worried = Color3.fromRGB(255, 255, 100), -- 노란색
	--	Danger = Color3.fromRGB(255, 150, 50),   -- 주황색
	--	Critical = Color3.fromRGB(255, 50, 50),  -- 빨간색
	--}

	--crystalPart.Color = stateColors[state] or stateColors.Healthy
	-- 레벨에 따른 크기 증가 (1.0 ~ 1.5배)
	--local sizeMultiplier = 1.0 + (crystal.level - 1) * 0.02 -- 레벨당 2% 증가
	--sizeMultiplier = math.min(sizeMultiplier, 1.5) -- 최대 1.5배
	--crystalPart.Size = Vector3.new(6, 20, 6) * sizeMultiplier
	--crystalPart.Position = Vector3.new(0, 10 * sizeMultiplier, 0)

	crystalPart.Material = themeInfo.material
	crystalPart.Color = (themeInfo.color):Lerp(stateTint[state] or Color3.new(1,1,1), 0.25)

	-- ✅ 크기 반영
	local baseSize = Vector3.new(6, 20, 6)
	crystalPart.Size = baseSize * themeInfo.sizeMultiplier
	crystalPart.Position = Vector3.new(0, (baseSize.Y/2) * themeInfo.sizeMultiplier, 0)


	-- (선택) crystalModel에 테마명 표시 속성 넣어두면 UI에도 쓰기 쉬움
	crystalPart:SetAttribute("ThemeId", themeInfo.themeId)
	crystalPart:SetAttribute("ThemeName", themeInfo.themeName)
	crystalPart:SetAttribute("Variant", themeInfo.variant)

	--print(string.format("[CrystalService] 외형 업데이트: 상태=%s, 크기=%.2f배", state, sizeMultiplier))
end

-- ========================================
-- 상태 계산
-- ========================================
function CrystalService.calculateState(hp, maxHp)
	local hpPercent = (hp / maxHp) * 100

	if hpPercent >= 80 then
		return "Healthy"
	elseif hpPercent >= 50 then
		return "Worried"
	elseif hpPercent >= 20 then
		return "Danger"
	else
		return "Critical"
	end
end

-- ========================================
-- CrystalStateDto 생성
-- ========================================
function CrystalService.getCrystalStateDto()
	local worldData = WorldDataStore.get()
	if not worldData then return nil end

	local crystal = worldData.crystal
	local state = CrystalService.calculateState(crystal.hp, crystal.maxHp)

	return {
		level = crystal.level,
		exp = crystal.exp,
		hp = crystal.hp,
		maxHp = crystal.maxHp,
		state = state,
		eraId = crystal.eraId,
	}
end

-- CrystalService.lua에 추가/수정

-- 상태 변수 추가
local isDestroyed = false
local rebuildPartyActive = false

-- ========================================
-- HP 변경 (피해 or 회복)
-- ========================================
function CrystalService.changeHp(amount)
	local worldData = WorldDataStore.get()
	if not worldData then return false end

	local crystal = worldData.crystal
	local oldHp = crystal.hp
	local oldState = CrystalService.calculateState(crystal.hp, crystal.maxHp)

	-- HP 변경
	crystal.hp = math.max(0, math.min(crystal.hp + amount, crystal.maxHp))

	local newState = CrystalService.calculateState(crystal.hp, crystal.maxHp)

	-- 상태 변경 체크
	if oldState ~= newState then
		crystal.state = newState
		--print(string.format("[CrystalService] 상태 변경: %s → %s", oldState, newState))
	end

	-- ✅ 피해 받을 때 사운드
	if amount < 0 and SoundService then
		SoundService.playSFX("CrystalDamage", Vector3.new(0, 0, 0))
	end

	-- 외형 업데이트
	CrystalService.updateCrystalAppearance()

	-- 클라이언트 동기화
	CrystalService.syncToAllClients()

	-- WorldDataStore Dirty Flag
	WorldDataStore.markDirty()

	--print(string.format("[CrystalService] HP 변경: %d → %d (%+d)", oldHp, crystal.hp, amount))

	-- ✅ HP가 0이 되었는지 확인
	if crystal.hp <= 0 and not isDestroyed then
		CrystalService.onCrystalDestroyed()
	end

	return true
end

-- ========================================
-- 크리스탈 파괴
-- ========================================
function CrystalService.onCrystalDestroyed()
	isDestroyed = true

	print("[CrystalService] 💔 크리스탈 파괴!")

	-- ✅ 타워/함정 자동 판매+파괴
	pcall(function()
		BuildingService.sellAndDestroyAllCombatBuildings()
	end)

	-- ✅ 웨이브 중단 + 5분 뒤 같은 웨이브 재시작
	local WaveService = getWaveService()
	pcall(function()
		WaveService.onCrystalDestroyed()
	end)
	
	-- ✅ 파괴 사운드
	if SoundService then
		SoundService.playSFX("CrystalDestroy", Vector3.new(0, 0, 0))
		SoundService.stopBGM() -- BGM 정지
	end
	
	-- 클라이언트에 파괴 알림
	local CrystalDestroyed = ReplicatedStorage.RemoteEvents.CrystalRemotes:FindFirstChild("CrystalDestroyed")
	if not CrystalDestroyed then
		CrystalDestroyed = Instance.new("RemoteEvent")
		CrystalDestroyed.Name = "CrystalDestroyed"
		CrystalDestroyed.Parent = ReplicatedStorage.RemoteEvents.CrystalRemotes
	end

	CrystalDestroyed:FireAllClients()

	-- 파괴 연출 (서버)
	CrystalService.playCrystalDestroyEffect()

	-- 10초 후 자동 부활
	task.delay(10, function()
		if isShuttingDown then return end
		CrystalService.reviveCrystal()
	end)
end

-- ========================================
-- 크리스탈 파괴 연출 (서버)
-- ========================================
function CrystalService.playCrystalDestroyEffect()
	if isShuttingDown then return end
	if not crystalPart then return end

	-- 크리스탈 반짝임 효과
	for i = 1, 5 do
		if isShuttingDown or not crystalPart or not crystalPart.Parent then return end
		crystalPart.Transparency = 0.8
		task.wait(0.1)

		if isShuttingDown or not crystalPart or not crystalPart.Parent then return end
		crystalPart.Transparency = 0.3
		task.wait(0.1)
	end

	-- 폭발 파티클 (간단한 버전)
	local explosion = Instance.new("Part")
	explosion.Name = "Explosion"
	explosion.Size = Vector3.new(1, 1, 1)
	explosion.Position = crystalPart.Position
	explosion.Anchored = true
	explosion.CanCollide = false
	explosion.Transparency = 1
	explosion.Parent = workspace

	local particleEmitter = Instance.new("ParticleEmitter")
	particleEmitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	particleEmitter.Rate = 100
	particleEmitter.Lifetime = NumberRange.new(1, 2)
	particleEmitter.Speed = NumberRange.new(10, 20)
	particleEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 100, 100))
	particleEmitter.Size = NumberSequence.new(5, 10)
	particleEmitter.Parent = explosion

	task.delay(2, function()
		if isShuttingDown then return end
		particleEmitter.Enabled = false
		task.wait(3)
		explosion:Destroy()
	end)

	print("[CrystalService] 파괴 연출 재생")
end

-- ========================================
-- 크리스탈 부활
-- ========================================
function CrystalService.reviveCrystal()
	local worldData = WorldDataStore.get()
	if not worldData then return end

	local crystal = worldData.crystal

	-- HP 50% 회복
	crystal.hp = math.floor(crystal.maxHp * 0.5)

	isDestroyed = false

	print(string.format("[CrystalService] ✨ 크리스탈 부활! (HP: %d/%d)", crystal.hp, crystal.maxHp))

	-- ✅ 부활 사운드
	if SoundService then
		SoundService.playSFX("CrystalRevive", Vector3.new(0, 0, 0))
	end
	
	-- 외형 업데이트
	CrystalService.updateCrystalAppearance()

	-- 클라이언트 동기화
	CrystalService.syncToAllClients()

	-- 클라이언트에 부활 알림
	local CrystalRevived = ReplicatedStorage.RemoteEvents.CrystalRemotes:FindFirstChild("CrystalRevived")
	if not CrystalRevived then
		CrystalRevived = Instance.new("RemoteEvent")
		CrystalRevived.Name = "CrystalRevived"
		CrystalRevived.Parent = ReplicatedStorage.RemoteEvents.CrystalRemotes
	end

	CrystalRevived:FireAllClients()

	-- 재건 파티 시작
	CrystalService.startRebuildParty()

	-- WorldDataStore Dirty Flag
	WorldDataStore.markDirty()
end

-- ========================================
-- 재건 파티 시작
-- ========================================
function CrystalService.startRebuildParty()
	rebuildPartyActive = true

	print("[CrystalService] 🎉 재건 파티 시작! (2분)")

	-- ✅ 재건 파티 BGM
	if SoundService then
		SoundService.playBGM("RebuildParty")
	end
	
	-- 클라이언트에 재건 파티 알림
	local RebuildPartyStarted = ReplicatedStorage.RemoteEvents.CrystalRemotes:FindFirstChild("RebuildPartyStarted")
	if not RebuildPartyStarted then
		RebuildPartyStarted = Instance.new("RemoteEvent")
		RebuildPartyStarted.Name = "RebuildPartyStarted"
		RebuildPartyStarted.Parent = ReplicatedStorage.RemoteEvents.CrystalRemotes
	end

	RebuildPartyStarted:FireAllClients({
		duration = 120, -- 2분
		buildSpeedMultiplier = 2.0,
		repairSpeedMultiplier = 2.0,
		goldMultiplier = 1.5,
	})

	-- 2분 후 종료
	task.delay(120, function()
		if isShuttingDown then return end
		CrystalService.endRebuildParty()
	end)
end

-- ========================================
-- 재건 파티 종료
-- ========================================
function CrystalService.endRebuildParty()
	rebuildPartyActive = false

	print("[CrystalService] 재건 파티 종료")

	-- 성공 여부 확인
	local success = CrystalService.checkRebuildPartySuccess()

	-- 클라이언트에 종료 알림
	local RebuildPartyEnded = ReplicatedStorage.RemoteEvents.CrystalRemotes:FindFirstChild("RebuildPartyEnded")
	if not RebuildPartyEnded then
		RebuildPartyEnded = Instance.new("RemoteEvent")
		RebuildPartyEnded.Name = "RebuildPartyEnded"
		RebuildPartyEnded.Parent = ReplicatedStorage.RemoteEvents.CrystalRemotes
	end

	RebuildPartyEnded:FireAllClients({
		success = success,
	})

	-- 성공 시 보상
	if success then
		CrystalService.giveRebuildPartyRewards()
	end
end

-- ========================================
-- 재건 파티 성공 여부 확인
-- ========================================
function CrystalService.checkRebuildPartySuccess()
	local worldData = WorldDataStore.get()
	if not worldData then return false end

	local crystal = worldData.crystal
	local hpPercent = (crystal.hp / crystal.maxHp) * 100

	-- 성공 조건: HP 80% 이상
	if hpPercent >= 80 then
		print("[CrystalService] ✅ 재건 파티 성공! (HP 80% 이상)")
		return true
	end

	-- TODO: 추가 조건
	-- - 건물 10개 이상 건설
	-- - Wave 1개 클리어

	print("[CrystalService] ❌ 재건 파티 실패 (HP 부족)")
	return false
end

-- ========================================
-- 재건 파티 성공 보상
-- ========================================
function CrystalService.giveRebuildPartyRewards()
	local Players = game:GetService("Players")
	local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

	for _, player in ipairs(Players:GetPlayers()) do
		-- 골드 +200
		PlayerDataService.addGold(player, 200, "🎉 재건 파티 성공!")

		-- 전설 토큰 +1
		local playerData = require(ServerScriptService.Modules.DataStore.PlayerDataStore).get(player)
		if playerData then
			playerData.legendTokens = playerData.legendTokens + 1

			-- 칭호 추가
			if not table.find(playerData.titles, "불굴의 수호자") then
				table.insert(playerData.titles, "불굴의 수호자")
			end

			PlayerDataService.syncToClient(player)
		end
	end

	-- 크리스탈 경험치 +100
	CrystalService.addExp(100)

	print("[CrystalService] 재건 파티 보상 지급 완료")
end

-- ========================================
-- 재건 파티 활성 여부
-- ========================================
function CrystalService.isRebuildPartyActive()
	return rebuildPartyActive
end


-- ========================================
-- 경험치 추가
-- ========================================
function CrystalService.addExp(amount)
	local worldData = WorldDataStore.get()
	if not worldData then return false end

	local crystal = worldData.crystal
	crystal.exp = crystal.exp + amount

	-- 레벨업 확인
	local requiredExp = crystal.level * 100
	if crystal.exp >= requiredExp then
		CrystalService.levelUp()
	end

	-- 클라이언트 동기화
	CrystalService.syncToAllClients()

	-- WorldDataStore Dirty Flag
	WorldDataStore.markDirty()

	return true
end

-- ========================================
-- 레벨업
-- ========================================
function CrystalService.levelUp()
	local worldData = WorldDataStore.get()
	if not worldData then return end

	local crystal = worldData.crystal
	local oldLevel = crystal.level

	-- 레벨업
	crystal.level = crystal.level + 1
	crystal.exp = 0

	-- MaxHP 증가 (Era 확인)
	CrystalService.updateMaxHp()

	-- HP 회복 (50%)
	crystal.hp = math.min(crystal.hp + crystal.maxHp * 0.5, crystal.maxHp)

	-- ✅ 레벨업 사운드
	if SoundService then
		SoundService.playSFX("CrystalLevelUp", Vector3.new(0, 0, 0))
	end

	-- 외형 업데이트
	CrystalService.updateCrystalAppearance()

	-- 클라이언트 동기화
	CrystalService.syncToAllClients()

	-- WorldDataStore Dirty Flag
	WorldDataStore.markDirty()

	print(string.format("[CrystalService] 레벨업: %d → %d (HP: %d/%d)",
		oldLevel, crystal.level, crystal.hp, crystal.maxHp))
end

-- ========================================
-- MaxHP 업데이트 (Era 확인)
-- ========================================
function CrystalService.updateMaxHp()
	local worldData = WorldDataStore.get()
	if not worldData then return end

	local crystal = worldData.crystal
	local level = crystal.level

	-- Era 확인
	for _, era in pairs(Constants.ERAS) do
		if level >= era.levelRange[1] and level <= era.levelRange[2] then
			crystal.eraId = era.id
			crystal.maxHp = era.maxHp
			print(string.format("[CrystalService] Era 변경: %s (MaxHP: %d)", era.name, era.maxHp))
			break
		end
	end
end

-- ========================================
-- 클라이언트 동기화
-- ========================================
function CrystalService.syncToAllClients()
	if isShuttingDown then return end
	local dto = CrystalService.getCrystalStateDto()
	if dto then
		CrystalUpdated:FireAllClients(dto)
	end
end

return CrystalService