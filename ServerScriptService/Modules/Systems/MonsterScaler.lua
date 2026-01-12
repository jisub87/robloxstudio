-- ServerScriptService/Modules/Systems/MonsterScaler.lua
local MonsterScaler = {}

-- "중간" 스케일 기본값
-- 레벨당 HP +8%, 공격 +6%, 보상 +5%
local HP_PER_LV = 0.08
local ATK_PER_LV = 0.06
local GOLD_PER_LV = 0.05

-- 크리스탈 레벨 + 웨이브 번호로 몬스터 레벨 생성
function MonsterScaler.computeMonsterLevel(crystalLevel, waveNumber)
	crystalLevel = math.max(1, tonumber(crystalLevel) or 1)
	waveNumber = math.max(1, tonumber(waveNumber) or 1)

	-- 추천: 크리스탈이 메인, 웨이브가 서브로 성장
	local lv = math.floor(crystalLevel / 2) + math.floor(waveNumber / 3)
	return math.max(1, lv)
end

function MonsterScaler.scaleSpec(baseSpec, monsterLevel)
	monsterLevel = math.max(1, tonumber(monsterLevel) or 1)

	local hpMul = 1 + HP_PER_LV * (monsterLevel - 1)
	local atkMul = 1 + ATK_PER_LV * (monsterLevel - 1)
	local goldMul = 1 + GOLD_PER_LV * (monsterLevel - 1)

	local scaled = table.clone(baseSpec)
	scaled.level = monsterLevel
	scaled.hp = math.floor((baseSpec.hp or 10) * hpMul)
	scaled.attackPower = math.floor((baseSpec.attackPower or 1) * atkMul)
	scaled.goldReward = math.floor((baseSpec.goldReward or 0) * goldMul)
	scaled.expReward = math.floor((baseSpec.expReward or 0) * (1 + 0.03 * (monsterLevel - 1)))

	return scaled
end

return MonsterScaler
