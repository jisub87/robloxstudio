--[[
	PlayerDataService.lua
	
	목적: 플레이어 데이터 관리
]]

local PlayerDataService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

-- 모듈
local PlayerDataStore = require(ServerScriptService.Modules.DataStore.PlayerDataStore)
local PlayerDataStructure = require(ServerScriptService.Modules.Data.PlayerDataStructure)

-- RemoteEvents
local RequestPlayerData
local PlayerDataUpdated
local GoldNotification -- ✅ 새로운 RemoteEvent

local SystemLogEvent -- 시스템 로그
-- ========================================
-- 초기화
-- ========================================
function PlayerDataService.init()
	-- RemoteEvents 연결
	RequestPlayerData = ReplicatedStorage.RemoteEvents.PlayerRemotes.RequestPlayerData
	PlayerDataUpdated = ReplicatedStorage.RemoteEvents.PlayerRemotes.PlayerDataUpdated
	GoldNotification = ReplicatedStorage.RemoteEvents.PlayerRemotes.GoldNotification
	SystemLogEvent = ReplicatedStorage.RemoteEvents.PlayerRemotes.SystemLogEvent


	-- RemoteFunction 콜백
	RequestPlayerData.OnServerInvoke = function(player)
		return PlayerDataService.getPlayerDataDto(player)
	end

	-- 플레이어 이벤트
	Players.PlayerAdded:Connect(PlayerDataService.onPlayerAdded)
	Players.PlayerRemoving:Connect(PlayerDataService.onPlayerRemoving)

	-- 플레이 시간 추적
	PlayerDataService.startPlayTimeTracking()

	print("[PlayerDataService] 초기화 완료")
end

-- ========================================
-- 플레이어 접속
-- ========================================
function PlayerDataService.onPlayerAdded(player)
	print(string.format("[PlayerDataService] 플레이어 접속: %s", player.Name))

	-- 데이터 로드
	local playerData = PlayerDataStore.load(player)

	-- 일일 로그인 보너스 체크
	PlayerDataService.checkDailyBonus(player, playerData)

	-- 클라이언트로 초기 데이터 전송
	task.wait(1)

	local dto = PlayerDataService.getPlayerDataDto(player)
	PlayerDataUpdated:FireClient(player, dto)

	print(string.format("[PlayerDataService] 초기 데이터 전송: %s (골드: %d)", player.Name, dto.gold))
end

-- ========================================
-- 플레이어 퇴장
-- ========================================
function PlayerDataService.onPlayerRemoving(player)
	print(string.format("[PlayerDataService] 플레이어 퇴장: %s", player.Name))

	-- 플레이 시간 기록
	local playerData = PlayerDataStore.get(player)
	if playerData then
		local sessionStartTime = playerData._sessionStartTime or tick()
		local sessionTime = tick() - sessionStartTime
		playerData.totalPlayTime = (playerData.totalPlayTime or 0) + sessionTime
		print(string.format("[PlayerDataService] 세션 시간: %s (%.1f분)", player.Name, sessionTime / 60))
	else
		warn(string.format("[PlayerDataService] 플레이어 데이터 없음: %s", player.Name))
	end

	-- 데이터 저장
	PlayerDataStore.save(player)

	-- 캐시 제거
	PlayerDataStore.unload(player)
end

-- ========================================
-- 로그 보내기
-- ========================================
function PlayerDataService.pushSystemLog(player, text, logType)
	if SystemLogEvent then
		SystemLogEvent:FireClient(player, {
			text = text,
			type = logType or "Info",
			timestamp = os.time(),
		})
	end
end


-- ========================================
-- 일일 로그인 보너스
-- ========================================
function PlayerDataService.checkDailyBonus(player, playerData)
	local today = os.date("%Y-%m-%d")
	local lastLogin = playerData.lastLogin or ""

	if lastLogin == today then
		-- 이미 오늘 보너스 받음
		print(string.format("[PlayerDataService] 오늘 이미 로그인함: %s", player.Name))
		return
	end

	-- 연속 출석 계산
	local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
	if lastLogin == yesterday then
		-- 연속 출석
		playerData.consecutiveDays = (playerData.consecutiveDays or 0) + 1
	else
		-- 연속 출석 끊김
		playerData.consecutiveDays = 1
	end

	playerData.totalLoginDays = (playerData.totalLoginDays or 0) + 1
	playerData.lastLogin = today

	-- 기본 일일 보너스
	local bonus = 10

	-- 연속 출석 보너스
	if playerData.consecutiveDays >= 30 then
		bonus = bonus + 50 -- 30일 연속: +50G
		print(string.format("[PlayerDataService] 30일 연속 출석 보너스!: %s", player.Name))
	elseif playerData.consecutiveDays >= 7 then
		bonus = bonus + 20 -- 7일 연속: +20G
		print(string.format("[PlayerDataService] 7일 연속 출석 보너스!: %s", player.Name))
	end

	-- 주말 보너스 (토요일=7, 일요일=1)
	local dayOfWeek = tonumber(os.date("%w"))
	if dayOfWeek == 0 or dayOfWeek == 6 then
		bonus = bonus * 2 -- 주말 2배
		print(string.format("[PlayerDataService] 주말 보너스 2배!: %s", player.Name))
	end

	-- 골드 지급
	playerData.gold = playerData.gold + bonus
	playerData.stats.totalGoldEarned = (playerData.stats.totalGoldEarned or 0) + bonus

	print(string.format("[PlayerDataService] 일일 보너스: %s (+%dG, 연속 %d일)", 
		player.Name, bonus, playerData.consecutiveDays))

	-- 세션 시작 시간 기록
	playerData._sessionStartTime = tick()

	-- 클라이언트 알림
	task.wait(2)
	PlayerDataService.notifyGold(player, bonus, string.format("일일 보너스 (연속 %d일)", playerData.consecutiveDays))

	-- 동기화
	PlayerDataService.syncToClient(player)
end

-- ========================================
-- 몬스터 누적 처치 기록
-- ========================================
function PlayerDataService.recordMonsterKill(player, monsterType, goldEarned)
	local playerData = PlayerDataStore.get(player)
	if not playerData then return end

	playerData.stats = playerData.stats or {}
	playerData.stats.monsterBreakdown = playerData.stats.monsterBreakdown or {}

	local entry = playerData.stats.monsterBreakdown[monsterType]
	if not entry then
		entry = { kills = 0, gold = 0 }
		playerData.stats.monsterBreakdown[monsterType] = entry
	end

	entry.kills += 1
	entry.gold += (goldEarned or 0)

	-- 선택: 총합도 같이 올리고 싶으면
	playerData.stats.monstersKilled = (playerData.stats.monstersKilled or 0) + 1
end


-- ========================================
-- 플레이 시간 추적
-- ========================================
function PlayerDataService.startPlayTimeTracking()
	task.spawn(function()
		while true do
			task.wait(60) -- 1분마다 체크

			for _, player in ipairs(Players:GetPlayers()) do
				local playerData = PlayerDataStore.get(player)
				if not playerData then continue end

				local sessionStart = playerData._sessionStartTime or tick()
				local currentPlayTime = tick() - sessionStart

				-- 5분마다 보너스
				local lastReward = playerData.lastPlayTimeReward or 0
				if currentPlayTime - lastReward >= 300 then -- 5분 = 300초
					local bonus = 20
					playerData.gold = playerData.gold + bonus
					playerData.stats.totalGoldEarned = (playerData.stats.totalGoldEarned or 0) + bonus
					playerData.lastPlayTimeReward = currentPlayTime

					print(string.format("[PlayerDataService] 플레이 시간 보너스: %s (+%dG)", player.Name, bonus))

					PlayerDataService.notifyGold(player, bonus, "플레이 시간 보너스 (5분)")
					PlayerDataService.syncToClient(player)
				end
			end
		end
	end)
end

-- ========================================
-- 골드 추가
-- ========================================
function PlayerDataService.addGold(player, amount, reason)
	amount = tonumber(amount) or 0
	if amount <= 0 then
		-- 0G는 로그/팝업 모두 생략
		return true
	end
	
	local playerData = PlayerDataStore.get(player)
	if not playerData then
		warn("[PlayerDataService] 플레이어 데이터 없음:", player.Name)
		return false
	end

	playerData.gold = playerData.gold + amount
	playerData.stats.totalGoldEarned = (playerData.stats.totalGoldEarned or 0) + amount

	-- ✅ 시스템 로그
	PlayerDataService.pushSystemLog(
		player,
		string.format("🪙 +%dG (%s)", amount, reason or "획득"),
		"Gold"
	)

	-- 클라이언트 알림
	if reason then
		PlayerDataService.notifyGold(player, amount, reason)
	end

	-- 동기화
	PlayerDataService.syncToClient(player)

	return true
end

-- ========================================
-- 골드 차감
-- ========================================
function PlayerDataService.removeGold(player, amount)
	local playerData = PlayerDataStore.get(player)
	if not playerData then
		warn("[PlayerDataService] 플레이어 데이터 없음:", player.Name)
		return false
	end

	if playerData.gold < amount then
		warn(string.format("[PlayerDataService] 골드 부족: %s (필요: %d, 보유: %d)",
			player.Name, amount, playerData.gold))
		return false
	end

	playerData.gold = playerData.gold - amount

	PlayerDataService.pushSystemLog(player, string.format("🪙 -%dG", amount), "Gold")

	-- 동기화
	PlayerDataService.syncToClient(player)

	return true
end

-- ========================================
-- 골드 확인
-- ========================================
function PlayerDataService.hasGold(player, amount)
	local playerData = PlayerDataStore.get(player)
	if not playerData then return false end

	return playerData.gold >= amount
end

function PlayerDataService.getGold(player)
	local playerData = PlayerDataStore.get(player)
	if not playerData then return 0 end

	return playerData.gold
end

-- ========================================
-- 골드 알림 (클라이언트)
-- ========================================
function PlayerDataService.notifyGold(player, amount, reason)
	if GoldNotification then
		GoldNotification:FireClient(player, {
			amount = amount,
			reason = reason or "",
		})
	end
end

-- ========================================
-- 통계 업데이트
-- ========================================
function PlayerDataService.updateStats(player, statName, value)
	local playerData = PlayerDataStore.get(player)
	if not playerData then return false end

	if playerData.stats[statName] then
		playerData.stats[statName] = playerData.stats[statName] + value

		-- 마일스톤 체크
		PlayerDataService.checkMilestones(player, statName, playerData.stats[statName])
	end

	return true
end

-- ========================================
-- 마일스톤 체크 (보너스)
-- ========================================
function PlayerDataService.checkMilestones(player, statName, currentValue)
	local milestones = {
		buildingsPlaced = {
			{count = 10, reward = 50, title = "건설의 시작"},
			{count = 50, reward = 100, title = "숙련된 건설가"},
			{count = 100, reward = 200, title = "건축 마스터"},
		},
		monstersKilled = {
			{count = 50, reward = 50, title = "몬스터 사냥꾼"},
			{count = 200, reward = 100, title = "전투의 달인"},
			{count = 500, reward = 200, title = "전설의 전사"},
		},
		wavesCleared = {
			{count = 5, reward = 50, title = "파도를 넘어"},
			{count = 20, reward = 100, title = "웨이브 마스터"},
			{count = 50, reward = 200, title = "불굴의 수호자"},
		},
	}

	local statMilestones = milestones[statName]
	if not statMilestones then return end

	for _, milestone in ipairs(statMilestones) do
		if currentValue == milestone.count then
			-- 마일스톤 달성!
			local playerData = PlayerDataStore.get(player)
			if not playerData then return end

			playerData.gold = playerData.gold + milestone.reward
			playerData.stats.totalGoldEarned = (playerData.stats.totalGoldEarned or 0) + milestone.reward

			-- 칭호 추가
			table.insert(playerData.titles, milestone.title)

			print(string.format("[PlayerDataService] 마일스톤 달성: %s - %s (%d/%d) +%dG",
				player.Name, statName, currentValue, milestone.count, milestone.reward))

			PlayerDataService.notifyGold(player, milestone.reward, 
				string.format("🏆 업적 달성: %s", milestone.title))

			PlayerDataService.syncToClient(player)
		end
	end
end

-- ========================================
-- 클래스 변경
-- ========================================
function PlayerDataService.changeClass(player, newClass)
	local playerData = PlayerDataStore.get(player)
	if not playerData then return false end

	local validClasses = {"Builder", "Fighter", "Repairer"}
	if not table.find(validClasses, newClass) then
		warn("[PlayerDataService] 유효하지 않은 클래스:", newClass)
		return false
	end

	playerData.currentClass = newClass

	print(string.format("[PlayerDataService] 클래스 변경: %s → %s", player.Name, newClass))

	-- 동기화
	PlayerDataService.syncToClient(player)

	return true
end

-- ========================================
-- 클라이언트 동기화
-- ========================================
function PlayerDataService.syncToClient(player)
	local dto = PlayerDataService.getPlayerDataDto(player)
	if dto then
		PlayerDataUpdated:FireClient(player, dto)
	end
end

-- ========================================
-- PlayerDataDto 생성
-- ========================================
function PlayerDataService.getPlayerDataDto(player)
	local playerData = PlayerDataStore.get(player)
	if not playerData then
		warn("[PlayerDataService] 플레이어 데이터 없음:", player.Name)
		return nil
	end

	return {
		gold = playerData.gold,
		legendTokens = playerData.legendTokens,
		currentClass = playerData.currentClass,
		stats = playerData.stats,
		titles = playerData.titles,
		consecutiveDays = playerData.consecutiveDays or 0,
		totalLoginDays = playerData.totalLoginDays or 0,

		monsterBreakdown = (playerData.stats and playerData.stats.monsterBreakdown) or {},
	}
end

return PlayerDataService