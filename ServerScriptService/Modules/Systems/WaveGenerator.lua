-- ServerScriptService/Modules/Systems/WaveGenerator.lua
local WaveGenerator = {}

local MonsterConfig = require(game:GetService("ServerScriptService").Modules.Config.MonsterConfig)

-- 몬스터 풀을 크리스탈 테마/레벨에 따라 확장할 예정
-- 일단 현재 4종 기반 + 이후 추가하기 쉽게 풀 구조로 구성
local BASE_POOL = { "Slime", "Goblin", "Orc" }
local BOSS_POOL = { "Boss" }

-- 웨이브 길이(스폰 기간)
local function getSpawnDuration(waveNumber)
	-- 초반은 짧게, 후반은 살짝 증가
	return math.min(60 + waveNumber * 2, 120)
end

-- 웨이브 클리어 골드(크리스탈 레벨 반영)
local function getClearGold(waveNumber, crystalLevel)
	-- 추천: 크리스탈 레벨 영향 큼 + 웨이브도 꾸준히 증가
	-- 테마(50단위) 점프도 자연스럽게 섞기
	local themeTier = math.floor((crystalLevel - 1) / 50) -- 0,1,2...
	return math.floor(40 + waveNumber * 8 + crystalLevel * 6 + themeTier * 150)
end

local function pickMonsterType(waveNumber, crystalLevel)
	-- 점점 다양한 몬스터 등장하도록 간단 가중
	-- (추가 몬스터 넣을 때 여기만 바꾸면 됨)
	local roll = math.random()
	if waveNumber % 10 == 0 and roll < 0.35 then
		return "Boss"
	end

	-- 후반일수록 Orc 비중 증가
	local orcWeight = math.clamp(0.1 + waveNumber * 0.01, 0.1, 0.45)
	local goblinWeight = math.clamp(0.35 - waveNumber * 0.005, 0.15, 0.35)
	local slimeWeight = 1 - (orcWeight + goblinWeight)

	local r = math.random()
	if r < slimeWeight then return "Slime" end
	if r < slimeWeight + goblinWeight then return "Goblin" end
	return "Orc"
end

function WaveGenerator.generate(waveNumber, crystalLevel)
	waveNumber = math.max(1, waveNumber or 1)
	crystalLevel = math.max(1, crystalLevel or 1)

	local spawnDuration = getSpawnDuration(waveNumber)
	local clearGold = getClearGold(waveNumber, crystalLevel)

	-- 스폰 수: 크리스탈 레벨과 웨이브가 함께 증가
	local baseCount = 8 + math.floor(waveNumber * 1.4) + math.floor(crystalLevel * 0.8)

	-- 보스 웨이브(10단위)는 몬스터 수 살짝 줄이고 보스 섞기
	local isBossWave = (waveNumber % 10 == 0)
	if isBossWave then
		baseCount = math.floor(baseCount * 0.75)
	end

	return {
		waveNumber = waveNumber,
		spawnDuration = spawnDuration, -- ✅ 스폰 기간(혼합 클리어용)
		clearGold = clearGold,
		isBossWave = isBossWave,
		count = baseCount,
		pickMonsterType = function()
			return pickMonsterType(waveNumber, crystalLevel)
		end
	}
end

return WaveGenerator
