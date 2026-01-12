--[[
	BuildingService.lua
	
	목적: 건물 배치/파괴/수리 관리 (서버 권한)
]]

local BuildingService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SoundService -- ✅ 추가

-- 모듈
local BuildingConfig = require(ServerScriptService.Modules.Config.BuildingConfig)
local GridUtils = require(ReplicatedStorage.Modules.GridUtils)
local WorldDataStructure = require(ServerScriptService.Modules.Data.WorldDataStructure)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local WorldDataStore = require(ServerScriptService.Modules.DataStore.WorldDataStore)

-- RemoteFunction
local RequestBuild
local BuildingUpdated
local RequestSell

-- 월드 데이터
local worldData = nil

-- 건물 폴더
local buildingsFolder = workspace:FindFirstChild("Buildings")
if not buildingsFolder then
	buildingsFolder = Instance.new("Folder")
	buildingsFolder.Name = "Buildings"
	buildingsFolder.Parent = workspace
end


local AUTO_SELL_RATE = 0.5

-- ========================================
-- 초기화
-- ========================================
function BuildingService.init(worldDataRef)
	worldData = worldDataRef

	-- SoundService 로드
	SoundService = require(ServerScriptService.Services.SoundService)

	-- RemoteFunction 연결
	RequestBuild = ReplicatedStorage.RemoteEvents.BuildingRemotes.RequestBuild
	BuildingUpdated = ReplicatedStorage.RemoteEvents.BuildingRemotes.BuildingUpdated
	RequestSell = ReplicatedStorage.RemoteEvents.BuildingRemotes.RequestSell

	RequestBuild.OnServerInvoke = function(player, buildingType, position, rotation)
		local result = BuildingService.tryBuild(player, buildingType, position, rotation)

		-- 성공 시 Dirty Flag
		if result.success then
			WorldDataStore.markDirty()
		end

		return result
	end

	RequestSell.OnServerInvoke = function(player, buildingId)
		local result = BuildingService.trySell(player, buildingId)

		if result.success then
			WorldDataStore.markDirty()
		end

		return result
	end
	print("[BuildingService] 초기화 완료")
end

-- BuildingService.lua 내부 (return 위에 추가)

local AUTO_SELL_RATE = 0.5

-- buildingData에는 type, ownerId, ... 가 있음
-- 업그레이드 들어가면 buildingData.upgradeLevel / investedGold 같은 필드로 확장 가능
local function computeRefund(buildingData)
	local spec = BuildingConfig.getSpec(buildingData.type)
	if not spec then return 0 end

	local invested = spec.price or 0

	-- (향후) 업그레이드 비용까지 포함하려면:
	-- invested += (buildingData.investedGoldFromUpgrades or 0)

	return math.floor(invested * AUTO_SELL_RATE)
end

function BuildingService.sellAndDestroyAllCombatBuildings()
	local worldData = WorldDataStore.get()
	if not worldData then return end

	local buildingsFolder = workspace:FindFirstChild("Buildings")
	if not buildingsFolder then return end

	local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

	local destroyedCount = 0
	local refundedTotal = 0

	for buildingId, buildingData in pairs(worldData.buildings) do
		-- ✅ 파괴 대상: Tower + Trap (벽은 남겨도 되고, 원하면 Wall도 포함 가능)
		if buildingData.type == "Tower" or buildingData.type == "Trap" then
			local refund = computeRefund(buildingData)
			refundedTotal += refund
			destroyedCount += 1

			-- 소유자에게 환급
			local owner = game:GetService("Players"):GetPlayerByUserId(buildingData.ownerId)
			if owner and refund > 0 then
				PlayerDataService.addGold(owner, refund, string.format("%s 자동 판매", buildingData.type))
			end

			-- 월드 데이터 제거
			worldData.buildings[buildingId] = nil

			-- 인스턴스 제거
			local inst = buildingsFolder:FindFirstChild(buildingId)
			if inst then inst:Destroy() end
		end
	end

	WorldDataStore.markDirty()
	print(string.format("[BuildingService] 자동 판매+파괴 완료: %d개, 총 환급=%dG", destroyedCount, refundedTotal))
end

-- 몬스터 체력 보이기
function BuildingService.updateBuildingBillboard(buildingId, buildingData)
	local buildingsFolder = workspace:FindFirstChild("Buildings")
	if not buildingsFolder then return end

	local part = buildingsFolder:FindFirstChild(buildingId)
	if not part then return end

	local billboard = part:FindFirstChild("BuildingInfo")
	if not billboard then return end

	local textLabel = billboard:FindFirstChildWhichIsA("TextLabel")
	if not textLabel then return end

	local spec = BuildingConfig.getSpec(buildingData.type)
	if not spec then return end

	local hp = tonumber(buildingData.hp) or spec.maxHp
	local maxHp = tonumber(buildingData.maxHp) or spec.maxHp

	textLabel.Text = string.format(
		"%s %s\nBy: %s\nHP: %d/%d",
		spec.icon,
		spec.displayName,
		buildingData.ownerName or "?",
		hp,
		maxHp
	)
end

-- ========================================
-- 건물 피해 처리 (몬스터 공격용)
-- ========================================
-- 몬스터가 건물 때릴 때 사용
function BuildingService.damageBuilding(buildingId, damage)
	if not worldData or not worldData.buildings then
		return false, "worldData 없음"
	end

	local buildingData = worldData.buildings[buildingId]
	if not buildingData then
		return false, "buildingData 없음"
	end

	damage = math.max(0, tonumber(damage) or 0)
	if damage <= 0 then
		return false, "damage 0"
	end

	local maxHp = tonumber(buildingData.maxHp) or BuildingConfig.getSpec(buildingData.type).maxHp or 1
	local hp = tonumber(buildingData.hp) or maxHp

	hp -= damage
	buildingData.hp = math.clamp(hp, 0, maxHp)

	-- ✅ Billboard 즉시 반영(서버 인스턴스라 클라에 그대로 복제됨)
	BuildingService.updateBuildingBillboard(buildingId, buildingData)

	-- (선택) 클라에서도 따로 쓰고 싶으면 이벤트도 같이
	if BuildingUpdated then
		BuildingUpdated:FireAllClients({
			action = "BuildingHpChanged",
			buildingId = buildingId,
			hp = buildingData.hp,
			maxHp = maxHp,
		})
	end

	-- 파괴 처리
	if buildingData.hp <= 0 then
		BuildingService.destroyBuilding(buildingId, buildingData)
		return true, "Destroyed"
	end

	WorldDataStore.markDirty()
	return true, "Damaged"
end

-- ========================================
-- 건물 파괴 (월드/인스턴스/클라 알림)
-- ========================================
function BuildingService.destroyBuilding(buildingId, buildingData)
	-- Instance 제거
	local buildingsFolder = workspace:FindFirstChild("Buildings")
	if buildingsFolder then
		local part = buildingsFolder:FindFirstChild(buildingId)
		if part then part:Destroy() end
	end

	-- 월드 데이터에서 제거
	if worldData and worldData.buildings then
		worldData.buildings[buildingId] = nil
	end

	-- 클라 알림
	if BuildingUpdated then
		BuildingUpdated:FireAllClients({
			action = "BuildingDestroyed",
			buildingId = buildingId,
			buildingType = buildingData and buildingData.type or "Unknown",
			ownerId = buildingData and buildingData.ownerId or 0,
			ownerName = buildingData and buildingData.ownerName or "",
		})
	end

	WorldDataStore.markDirty()
	print(string.format("[BuildingService] 건물 파괴: %s", buildingId))
end


-- ========================================
-- 건물 판매 시도
-- ========================================
function BuildingService.trySell(player, buildingId)
	if type(buildingId) ~= "string" or buildingId == "" then
		return { success = false, message = "잘못된 buildingId" }
	end

	local buildingData = worldData.buildings[buildingId]
	if not buildingData then
		return { success = false, message = "존재하지 않는 건물입니다" }
	end

	-- (선택) 내 건물만 판매 가능
	if buildingData.ownerId ~= player.UserId then
		return { success = false, message = "내 건물만 판매할 수 있습니다" }
	end

	local spec = BuildingConfig.getSpec(buildingData.type)
	if not spec then
		return { success = false, message = "건물 스펙을 찾을 수 없습니다" }
	end

	local refund = math.floor((spec.price or 0) * 0.5)

	-- 월드 데이터에서 제거
	worldData.buildings[buildingId] = nil

	-- 실제 Part 제거 (클라에 자동 복제됨)
	local part = buildingsFolder:FindFirstChild(buildingId)
	if part then
		part:Destroy()
	end

	-- 환불
	if refund > 0 then
		PlayerDataService.addGold(player, refund, "건물 판매")
	end

	-- 클라에 알림(선택)
	if BuildingUpdated then
		BuildingUpdated:FireAllClients({
			action = "BuildingSold",
			buildingId = buildingId,
			refund = refund,
			ownerId = player.UserId,
		})
	end

	return {
		success = true,
		message = string.format("판매 완료 (+%dG)", refund),
		refund = refund,
	}
end



-- ========================================
-- 건물 배치 시도
-- ========================================
function BuildingService.tryBuild(player, buildingType, position, rotation)
	-- 1. 기본 검증
	if not BuildingConfig.isValidType(buildingType) then
		return {
			success = false,
			message = "유효하지 않은 건물 타입"
		}
	end

	-- 2. 그리드 스냅
	--local snappedPosition = GridUtils.snapToGrid(position)
	local snappedXZ = GridUtils.snapToGrid(Vector3.new(position.X, 0, position.Z))
	local snappedPosition = Vector3.new(snappedXZ.X, position.Y, snappedXZ.Z)
	local snappedRotation = GridUtils.snapRotation(rotation)

	-- 3. 골드 확인
	local spec = BuildingConfig.getSpec(buildingType)
	local price = spec.price

	if not PlayerDataService.hasGold(player, price) then
		return {
			success = false,
			message = string.format("골드가 부족합니다 (필요: %d, 보유: %d)", 
				price, PlayerDataService.getGold(player))
		}
	end

	-- 4. 배치 가능 여부 확인
	local canPlace, reason = BuildingService.canPlaceAt(snappedPosition, spec.size)
	if not canPlace then
		return {
			success = false,
			message = reason or "이곳에는 건물을 배치할 수 없습니다"
		}
	end

	-- 5. 골드 차감
	if not PlayerDataService.removeGold(player, price) then
		return {
			success = false,
			message = "골드 차감 실패"
		}
	end

	-- 6. 건물 생성
	local buildingId = BuildingService.generateBuildingId()
	local building = BuildingService.createBuilding(
		buildingId,
		buildingType,
		player.UserId,
		player.Name,
		snappedPosition,
		snappedRotation,
		price -- 실제 지불 금액
	)

	if not building then
		-- 실패 시 골드 환불
		PlayerDataService.addGold(player, price)
		return {
			success = false,
			message = "건물 생성 실패"
		}
	end

	-- ✅ 건설 사운드
	if SoundService then
		SoundService.playSFX("Build", snappedPosition)
	end

	-- 7. 월드 데이터 업데이트
	local buildingData = WorldDataStructure.createBuilding(
		buildingId,
		buildingType,
		player.UserId,
		player.Name,
		snappedPosition,
		snappedRotation
	)

	buildingData.hp = spec.maxHp
	buildingData.maxHp = spec.maxHp

	worldData.buildings[buildingId] = buildingData
	
	-- 월드 데이터 업데이트 이후 바로 Billboard 갱신
	BuildingService.updateBuildingBillboard(buildingId, buildingData)


	-- 8. 통계 업데이트
	PlayerDataService.updateStats(player, "buildingsPlaced", 1)

	-- 9. 클라이언트에 알림
	BuildingUpdated:FireAllClients({
		action = "BuildingPlaced",
		buildingId = buildingId,
		buildingType = buildingType,
		position = snappedPosition,
		rotation = snappedRotation,
		ownerId = player.UserId,
		ownerName = player.Name,
	})

	print(string.format(
		"[BuildingService] %s가 %s 건물 배치 (골드 -%d)",
		player.Name,
		buildingType,
		price
		))

	return {
		success = true,
		message = "건물 배치 완료",
		buildingId = buildingId,
		position = snappedPosition,
		rotation = snappedRotation,
	}
end

-- ========================================
-- 배치 가능 여부 확인 (개선됨)
-- ========================================
function BuildingService.canPlaceAt(position, size)
	-- 1. 크리스탈 금지 구역 확인 (반경 15 studs로 축소)
	local crystalPosition = Vector3.new(0, 0, 0)
	local distanceToCrystal = (Vector3.new(position.X, 0, position.Z) - Vector3.new(crystalPosition.X, 0, crystalPosition.Z)).Magnitude

	if distanceToCrystal < 5 then -- 30 → 15로 축소
		return false, "크리스탈에 너무 가깝습니다"
	end

	-- 2. 스폰 포인트 금지 구역 확인
	local spawnPoints = workspace:FindFirstChild("MonsterSpawnPoints")
	if spawnPoints then
		for _, spawnPoint in ipairs(spawnPoints:GetChildren()) do
			if spawnPoint:IsA("BasePart") then
				local distance = (Vector3.new(position.X, 0, position.Z) - Vector3.new(spawnPoint.Position.X, 0, spawnPoint.Position.Z)).Magnitude
				if distance < 5 then
					return false, "스폰 포인트에 너무 가깝습니다"
				end
			end
		end
	end

	-- 3. 다른 건물과 겹침 확인 (개선됨)
	local overlapCheck = BuildingService.checkBuildingOverlap(position, size)
	if not overlapCheck then
		return false, "다른 건물과 겹칩니다"
	end

	-- 4. 맵 경계 확인
	local mapSize = 100 -- 맵 크기의 절반 (200x200 맵 기준)
	if math.abs(position.X) > mapSize or math.abs(position.Z) > mapSize then
		return false, "맵 경계를 벗어났습니다"
	end

	return true, "배치 가능"
end

-- ========================================
-- 건물 겹침 확인 (개선된 3D AABB 충돌 감지)
-- ========================================
function BuildingService.checkBuildingOverlap(position, size)
	-- 3D AABB (Axis-Aligned Bounding Box) 충돌 감지
	-- 새 건물의 바운딩 박스
	local newMin = position - (size / 2)
	local newMax = position + (size / 2)

	-- 모든 기존 건물과 AABB 충돌 확인
	for buildingId, buildingData in pairs(worldData.buildings) do
		local existingPos = Vector3.new(
			buildingData.position.x,
			buildingData.position.y,
			buildingData.position.z
		)

		-- 기존 건물의 크기 가져오기
		local BuildingConfig = require(ServerScriptService.Modules.Config.BuildingConfig)
		local existingSpec = BuildingConfig.getSpec(buildingData.type)
		if not existingSpec then continue end

		local existingSize = existingSpec.size

		-- 기존 건물의 바운딩 박스
		local existingMin = existingPos - (existingSize / 2)
		local existingMax = existingPos + (existingSize / 2)

		-- AABB 충돌 검사 (3D)
		local overlapX = newMax.X > existingMin.X and newMin.X < existingMax.X
		local overlapY = newMax.Y > existingMin.Y and newMin.Y < existingMax.Y
		local overlapZ = newMax.Z > existingMin.Z and newMin.Z < existingMax.Z

		-- 3개 축 모두 겹치면 충돌
		if overlapX and overlapY and overlapZ then
			return false
		end
	end

	return true
end

-- ========================================
-- 건물 ID 생성
-- ========================================
function BuildingService.generateBuildingId()
	return "bld_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
end

-- ========================================
-- 건물 Instance 생성
-- ========================================
function BuildingService.createBuilding(buildingId, buildingType, ownerId, ownerName, position, rotation, paidPrice)
	local spec = BuildingConfig.getSpec(buildingType)
	if not spec then
		warn("[BuildingService] 유효하지 않은 건물 타입:", buildingType)
		return nil
	end

	-- 건물 Part 생성
	local buildingPart = Instance.new("Part")
	buildingPart.Name = buildingId
	buildingPart.Size = spec.size
	buildingPart.Position = position
	buildingPart.Orientation = Vector3.new(0, rotation, 0)
	buildingPart.Anchored = true
	buildingPart.CanCollide = true

	-- 건물 타입별 색상
	if buildingType == "Wall" then
		buildingPart.BrickColor = BrickColor.new("Medium stone grey")
	elseif buildingType == "Tower" then
		buildingPart.BrickColor = BrickColor.new("Brick yellow")
	elseif buildingType == "Trap" then
		buildingPart.BrickColor = BrickColor.new("Really black")
	end

	-- 표지판 생성 (BillboardGui)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BuildingInfo"
	billboard.Size = UDim2.new(0, 100, 0, 50)
	billboard.StudsOffset = Vector3.new(0, spec.size.Y / 2 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = buildingPart

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 0.5
	textLabel.BackgroundColor3 = Color3.new(0, 0, 0)
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Text = string.format(
		"%s %s\nBy: %s\nHP: %d/%d",
		spec.icon,
		spec.displayName,
		ownerName,
		spec.maxHp,
		spec.maxHp
	)
	textLabel.Parent = billboard
	buildingPart:SetAttribute("BuildingType", buildingType)
	buildingPart:SetAttribute("OwnerId", ownerId)
	
	buildingPart:SetAttribute("BuildPrice", (spec.price or 0)) -- 실제 지불가
	buildingPart:SetAttribute("DisplayName", spec.displayName or buildingType)
	buildingPart:SetAttribute("Icon", spec.icon or "🏗️")

	buildingPart.Parent = buildingsFolder

	print(string.format("[BuildingService] 건물 생성: %s at %s", buildingId, tostring(position)))

	return buildingPart
end

return BuildingService