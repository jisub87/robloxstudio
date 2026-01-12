-- ServerScriptService/Services/WaveService.lua
local WaveService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local WaveGenerator = require(ServerScriptService.Modules.Systems.WaveGenerator)
local MonsterService = require(ServerScriptService.Services.MonsterService)
local CrystalService = require(ServerScriptService.Services.CrystalService)

local WaveStateChanged = ReplicatedStorage.RemoteEvents.WaveRemotes.WaveStateChanged
local WaveCompleted = ReplicatedStorage.RemoteEvents.WaveRemotes.WaveCompleted

local SoundService

-- 상태
local currentState = "Peace"
local currentWaveNumber = 0
local waveTimer = 0

-- ✅ 중복 실행/보상 중복 방지 토큰
local runToken = 0
local waveActiveToken = 0

-- 실패 후 재시작 대기(5분)
local RESTART_DELAY = 300

-- 스폰 포인트
local spawnPoints = {}

function WaveService.init()
	WaveService.loadSpawnPoints()
	SoundService = require(ServerScriptService.Services.SoundService)
	WaveService.startPeace()
	print("[WaveService] 초기화 완료")
end

function WaveService.loadSpawnPoints()
	local spawnFolder = workspace:FindFirstChild("MonsterSpawnPoints")
	if not spawnFolder then
		warn("[WaveService] MonsterSpawnPoints 폴더 없음")
		return
	end
	spawnPoints = {}
	for _, spawn in ipairs(spawnFolder:GetChildren()) do
		if spawn:IsA("BasePart") then
			table.insert(spawnPoints, spawn.Position)
		end
	end
end

local function broadcastState(state, duration, waveNumber)
	WaveStateChanged:FireAllClients({
		state = state,
		duration = duration,
		waveNumber = waveNumber or 0,
		totalWaves = 0, -- 무한이므로 UI에서 "∞" 처리 추천
	})
end

function WaveService.startPeace()
	runToken += 1
	local token = runToken

	currentState = "Peace"
	waveTimer = 10 -- 네가 지금 10으로 해둔 값 유지(원하면 300으로)
	broadcastState("Peace", waveTimer, currentWaveNumber)

	if SoundService then
		SoundService.playBGM("PeaceTime")
	end

	task.spawn(function()
		while token == runToken and waveTimer > 0 do
			task.wait(1)
			waveTimer -= 1
			broadcastState("Peace", waveTimer, currentWaveNumber)
		end
		if token ~= runToken then return end
		WaveService.startWave(math.max(1, currentWaveNumber + 1))
	end)
end

function WaveService.startWave(waveNumber)
	runToken += 1
	waveActiveToken += 1
	local token = runToken
	local waveToken = waveActiveToken

	currentState = "Wave"
	currentWaveNumber = waveNumber

	-- 크리스탈 레벨 가져오기
	local crystalLevel = 1
	local worldData = require(ServerScriptService.Modules.DataStore.WorldDataStore).get()
	if worldData and worldData.crystal then
		crystalLevel = worldData.crystal.level or 1
	end

	local waveData = WaveGenerator.generate(waveNumber, crystalLevel)
	local spawnDuration = waveData.spawnDuration

	-- UI는 "스폰 남은 시간"을 보여주는 게 자연스럽다
	waveTimer = spawnDuration
	broadcastState("Wave", waveTimer, currentWaveNumber)

	if SoundService then
		if waveData.isBossWave then
			SoundService.playBGM("BossTime")
		else
			SoundService.playBGM("WaveTime")
		end
		SoundService.playSFX("WaveStart")
	end

	-- ✅ 1) 스폰 루프
	task.spawn(function()
		local spawned = 0
		local spawnEndTime = tick() + spawnDuration

		while token == runToken and waveToken == waveActiveToken and tick() < spawnEndTime do
			task.wait(0.5)

			if #spawnPoints == 0 then continue end
			if spawned >= waveData.count then break end

			local spawnPos = spawnPoints[math.random(1, #spawnPoints)]
			local offset = Vector3.new(math.random(-5,5), 0, math.random(-5,5))
			local mType = waveData.pickMonsterType()

			MonsterService.spawnMonster(mType, spawnPos + offset, currentWaveNumber, crystalLevel)
			spawned += 1
		end
	end)

	-- ✅ 2) 타이머(스폰 남은 시간)
	task.spawn(function()
		while token == runToken and waveTimer > 0 do
			task.wait(1)
			waveTimer -= 1
			broadcastState("Wave", waveTimer, currentWaveNumber)
		end
	end)

	-- ✅ 3) 혼합 클리어(B): 스폰 끝난 뒤, 남은 몬스터 전멸하면 1회 클리어
	task.spawn(function()
		-- 스폰이 끝날 때까지 대기
		task.wait(spawnDuration)
		if token ~= runToken or waveToken ~= waveActiveToken then return end

		-- 남은 몬스터 전멸 대기
		while token == runToken and waveToken == waveActiveToken do
			task.wait(1)
			if MonsterService.getActiveMonsterCount() <= 0 then
				break
			end
		end
		if token ~= runToken or waveToken ~= waveActiveToken then return end

		WaveService.onWaveComplete(waveData)
	end)
end

function WaveService.onWaveComplete(waveData)
	-- ✅ 보상 중복 방지: waveActiveToken을 한번 올려서, 남아있던 루프들이 종료되게 함
	waveActiveToken += 1

	print(string.format("[WaveService] Wave %d 완료", currentWaveNumber))
	if SoundService then
		SoundService.playSFX("WaveComplete")
	end

	-- 클리어 보상(모든 플레이어)
	local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerDataService.addGold(player, waveData.clearGold, string.format("Wave %d 클리어", currentWaveNumber))
		PlayerDataService.updateStats(player, "wavesCleared", 1)
	end

	WaveCompleted:FireAllClients({
		waveNumber = currentWaveNumber,
		goldReward = waveData.clearGold,
		expReward = 0,
	})

	-- 다음 웨이브로
	currentState = "Peace"
	task.wait(20) -- rest
	WaveService.startPeace()
end

-- ✅ 크리스탈 파괴 시 Wave 중단 + 5분 후 같은 웨이브 재시작
function WaveService.onCrystalDestroyed()
	print("[WaveService] 크리스탈 파괴로 웨이브 중단. 5분 후 재시작:", currentWaveNumber)

	-- 모든 루프 중단
	runToken += 1
	waveActiveToken += 1

	currentState = "Peace"
	MonsterService.clearAllMonsters()

	broadcastState("Reward", RESTART_DELAY, currentWaveNumber)

	task.delay(RESTART_DELAY, function()
		-- 같은 웨이브로 재시작
		WaveService.startWave(math.max(1, currentWaveNumber))
	end)
end

return WaveService
