--[[
	MonsterConfig.lua
	
	목적: 몬스터 스펙 정의
	참조: WCD_Game_Systems.docx - Section 2.2
]]

local MonsterConfig = {}

MonsterConfig.MONSTERS = {
	Slime = {
		name = "Slime",
		displayName = "슬라임",
		level = 1,
		icon = "🟢",
		hp = 50,
		attackPower = 10,
		speed = 10, -- studs/sec (느림)
		goldReward = 5,
		expReward = 1,
		size = Vector3.new(3, 2, 3),
	},

	Goblin = {
		name = "Goblin",
		displayName = "고블린",
		level = 2,
		icon = "👺",
		hp = 80,
		attackPower = 20,
		speed = 16, -- studs/sec (보통)
		goldReward = 10,
		expReward = 2,
		size = Vector3.new(3, 4, 3),
	},

	Orc = {
		name = "Orc",
		displayName = "오크",
		level = 3,
		icon = "👹",
		hp = 150,
		attackPower = 40,
		speed = 20, -- studs/sec (빠름)
		goldReward = 20,
		expReward = 5,
		size = Vector3.new(4, 6, 4),
	},

	Boss = {
		name = "Boss",
		displayName = "보스",
		level = 4,
		icon = "👿",
		hp = 500,
		attackPower = 100,
		speed = 12, -- studs/sec (느림)
		goldReward = 100,
		expReward = 20,
		size = Vector3.new(6, 10, 6),
	},
}

-- 몬스터 타입 유효성 검사
function MonsterConfig.isValidType(monsterType)
	return MonsterConfig.MONSTERS[monsterType] ~= nil
end

-- 몬스터 스펙 가져오기
function MonsterConfig.getSpec(monsterType)
	return MonsterConfig.MONSTERS[monsterType]
end

return MonsterConfig