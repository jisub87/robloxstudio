--[[
	BuildingConfig.lua
	
	목적: 건물 스펙 정의
	참조: WCD_Building_System.docx - Section 2
]]

local BuildingConfig = {}

BuildingConfig.BUILDINGS = {
	Wall = {
		name = "Wall",
		displayName = "방어벽",
		icon = "🏰",
		price = 10, -- 골드
		maxHp = 100,
		size = Vector3.new(4, 4, 4),
		role = "방어",
		canAttack = false,
	},

	Tower = {
		name = "Tower",
		displayName = "공격 타워",
		icon = "🗼",
		price = 15, -- 골드
		priceInOtherWorld = 0, -- 타인 월드에서는 무료
		maxHp = 80,
		size = Vector3.new(3, 6, 3),
		role = "공격",
		canAttack = true,
		attackPower = 15,
		attackSpeed = 1.0, -- 초당 1회
		attackRange = 30, -- studs
	},

	Trap = {
		name = "Trap",
		displayName = "함정",
		icon = "⚡",
		price = 20, -- 골드
		maxHp = 50,
		size = Vector3.new(4, 1, 4),
		role = "함정",
		canAttack = false,
		explosionDamage = 100,
		explosionRadius = 10, -- studs
		detectionRange = 5, -- studs
		isOneTimeUse = true,
	},
}

-- 건물 타입 유효성 검사
function BuildingConfig.isValidType(buildingType)
	return BuildingConfig.BUILDINGS[buildingType] ~= nil
end

-- 건물 스펙 가져오기
function BuildingConfig.getSpec(buildingType)
	return BuildingConfig.BUILDINGS[buildingType]
end

-- 건물 가격 가져오기 (내 월드 vs 타인 월드)
function BuildingConfig.getPrice(buildingType, isOwnWorld)
	local spec = BuildingConfig.BUILDINGS[buildingType]
	if not spec then
		return 0
	end

	-- 타워는 타인 월드에서 무료
	if buildingType == "Tower" and not isOwnWorld then
		return spec.priceInOtherWorld or 0
	end

	return spec.price
end

return BuildingConfig