--[[
	BuildingController.lua
	
	목적: 건물 배치 입력 처리 (클라이언트)
]]

local BuildingController = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local playerGui = player:WaitForChild("PlayerGui")

-- 모듈
local GridUtils = require(ReplicatedStorage.Modules.GridUtils)
local BuildMenuUI = require(script.Parent.Parent.UI.BuildMenuUI)

-- RemoteFunction
local RequestBuild
local RequestSell

-- 상태
local isPlacingMode = false
local selectedBuildingType = nil
local ghostPreview = nil
local currentRotation = 0

-- 취소 안내 UI
local cancelHintFrame = nil
-- 판매 상태
local sellFrame = nil
local selectedBuildingIdForSell = nil

-- BuildingConfig
local BuildingConfig = {
	Wall = { size = Vector3.new(4, 4, 4), color = Color3.fromRGB(150, 150, 150) },
	Tower = { size = Vector3.new(3, 6, 3), color = Color3.fromRGB(200, 150, 100) },
	Trap = { size = Vector3.new(4, 1, 4), color = Color3.fromRGB(50, 50, 50) },
}

-- ========================================
-- 초기화
-- ========================================
function BuildingController.init()
	print("[BuildingController] 초기화 시작")

	RequestBuild = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("BuildingRemotes"):WaitForChild("RequestBuild")
	RequestSell = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("BuildingRemotes"):WaitForChild("RequestSell")
	-- UI 생성
	BuildMenuUI.create()
	BuildingController.createCancelHintUI()
	-- UI 생성(선택)
	BuildingController.createSellUI()
	
	-- 입력 이벤트
	UserInputService.InputBegan:Connect(BuildingController.onInputBegan)

	-- 건물 선택 이벤트
	local BuildingSelectedEvent = ReplicatedStorage:FindFirstChild("BuildingSelectedEvent")
	if not BuildingSelectedEvent then
		BuildingSelectedEvent = Instance.new("BindableEvent")
		BuildingSelectedEvent.Name = "BuildingSelectedEvent"
		BuildingSelectedEvent.Parent = ReplicatedStorage
	end

	BuildingSelectedEvent.Event:Connect(function(buildingType)
		BuildingController.startPlacingMode(buildingType)
	end)

	-- 렌더 루프 (프리뷰 업데이트)
	RunService.RenderStepped:Connect(BuildingController.updatePreview)

	print("[BuildingController] 초기화 완료")
end

-- ========================================
-- 판매 상태 UI 생성
-- ========================================
function BuildingController.createSellUI()
	local screenGui = playerGui:FindFirstChild("PlayerHUD") or playerGui:FindFirstChild("BuildMenuGui")
	if not screenGui then return end

	sellFrame = Instance.new("Frame")
	sellFrame.Name = "SellUI"
	sellFrame.Size = UDim2.new(0, 260, 0, 110)
	sellFrame.Position = UDim2.new(0.5, -130, 0.75, 0)
	sellFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	sellFrame.BorderSizePixel = 0
	sellFrame.Visible = false
	sellFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = sellFrame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 35)
	title.Position = UDim2.new(0, 10, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "건물 선택됨"
	title.TextColor3 = Color3.new(1,1,1)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = sellFrame

	local sellButton = Instance.new("TextButton")
	sellButton.Name = "SellButton"
	sellButton.Size = UDim2.new(0.9, 0, 0, 35)
	sellButton.Position = UDim2.new(0.05, 0, 0, 55)
	sellButton.BackgroundColor3 = Color3.fromRGB(200, 120, 40)
	sellButton.Text = "💸 판매"
	sellButton.TextColor3 = Color3.new(1,1,1)
	sellButton.TextScaled = true
	sellButton.Font = Enum.Font.GothamBold
	sellButton.Parent = sellFrame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = sellButton

	sellButton.MouseButton1Click:Connect(function()
		BuildingController.trySellSelectedBuilding()
	end)
end

function BuildingController.showSellUI(buildingPart)
	if not sellFrame then
		BuildingController.createSellUI()
	end
	if not sellFrame then return end

	local buildingId = buildingPart.Name
	local ownerId = buildingPart:GetAttribute("OwnerId")
	local buildingType = buildingPart:GetAttribute("BuildingType")

	-- 내 건물만 판매 UI 표시 (원하면 이 조건 제거 가능)
	if ownerId ~= player.UserId then
		return
	end

	selectedBuildingIdForSell = buildingId

	-- 표시 텍스트 업데이트 (50% 환불 표시용)
	local icon = tostring(buildingPart:GetAttribute("Icon") or "🏗️")
	local displayName = tostring(buildingPart:GetAttribute("DisplayName") or buildingPart.Name)
	local price = tonumber(buildingPart:GetAttribute("BuildPrice")) or 0
	local refund = math.floor(price * 0.5)

	local title = sellFrame:FindFirstChild("Title")
	if title then
		title.Text = string.format("%s %s", icon, displayName)
	end

	local sellButton = sellFrame:FindFirstChild("SellButton")
	if sellButton then
		sellButton.Text = string.format("💸 판매 (+%dG)  |  건설:%dG", refund, price)
	end

	sellFrame.Visible = true
end

function BuildingController.hideSellUI()
	selectedBuildingIdForSell = nil
	if sellFrame then
		sellFrame.Visible = false
	end
end

function BuildingController.trySellSelectedBuilding()
	if not selectedBuildingIdForSell then return end

	local result = RequestSell:InvokeServer(selectedBuildingIdForSell)
	if result and result.success then
		print("[BuildingController] 판매 성공:", result.message)
		BuildingController.hideSellUI()
	else
		warn("[BuildingController] 판매 실패:", result and result.message)
	end
end

-- ========================================
-- 취소 안내 UI 생성
-- ========================================
function BuildingController.createCancelHintUI()
	local screenGui = playerGui:FindFirstChild("PlayerHUD")
	if not screenGui then
		screenGui = playerGui:FindFirstChild("BuildMenuGui")
	end
	if not screenGui then return end

	-- 취소 안내 Frame
	cancelHintFrame = Instance.new("Frame")
	cancelHintFrame.Name = "CancelHint"
	cancelHintFrame.Size = UDim2.new(0, 300, 0, 80)
	cancelHintFrame.Position = UDim2.new(0.5, -150, 0.8, 0)
	cancelHintFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	cancelHintFrame.BorderSizePixel = 0
	cancelHintFrame.Visible = false
	cancelHintFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = cancelHintFrame

	-- 안내 텍스트
	local hintText = Instance.new("TextLabel")
	hintText.Size = UDim2.new(1, -20, 0, 30)
	hintText.Position = UDim2.new(0, 10, 0, 10)
	hintText.BackgroundTransparency = 1
	hintText.Text = "🖱️ 좌클릭: 배치 | 우클릭: 회전"
	hintText.TextColor3 = Color3.new(1, 1, 1)
	hintText.TextScaled = true
	hintText.Font = Enum.Font.Gotham
	hintText.Parent = cancelHintFrame

	-- 취소 버튼
	local cancelButton = Instance.new("TextButton")
	cancelButton.Name = "CancelButton"
	cancelButton.Size = UDim2.new(0.9, 0, 0, 30)
	cancelButton.Position = UDim2.new(0.05, 0, 0, 45)
	cancelButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	cancelButton.Text = "❌ 취소 (ESC)"
	cancelButton.TextColor3 = Color3.new(1, 1, 1)
	cancelButton.TextScaled = true
	cancelButton.Font = Enum.Font.GothamBold
	cancelButton.Parent = cancelHintFrame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 8)
	buttonCorner.Parent = cancelButton

	-- 버튼 클릭 이벤트
	cancelButton.MouseButton1Click:Connect(function()
		BuildingController.cancelPlacingMode()
	end)

	print("[BuildingController] 취소 안내 UI 생성 완료")
end

-- ========================================
-- 입력 처리
-- ========================================
function BuildingController.onInputBegan(input, gameProcessed)
	if gameProcessed then return end

	-- B키: 건물 메뉴 토글
	if input.KeyCode == Enum.KeyCode.B then
		-- Ghost 모드 중이면 먼저 취소
		if isPlacingMode then
			BuildingController.cancelPlacingMode()
		else
			BuildMenuUI.toggle()
		end
	end

	-- 배치 모드일 때
	if isPlacingMode then
		-- 좌클릭: 건물 배치
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			BuildingController.tryPlaceBuilding()
		end

		-- 우클릭: 회전
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			currentRotation = (currentRotation + 90) % 360
			print("[BuildingController] 회전:", currentRotation)
		end

		-- ESC: 배치 모드 취소
		if input.KeyCode == Enum.KeyCode.Escape then
			BuildingController.cancelPlacingMode()
		end
	end
	
	-- 배치 모드가 아닐 때: 건물 클릭 시 판매 UI
	if not isPlacingMode then
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local target = mouse.Target
			if target and target.Parent and target.Parent.Name == "Buildings" then
				BuildingController.showSellUI(target)
			else
				BuildingController.hideSellUI()
			end
		end

		if input.KeyCode == Enum.KeyCode.Escape then
			BuildingController.hideSellUI()
		end
	end
end

-- ========================================
-- 배치 모드 시작
-- ========================================
function BuildingController.startPlacingMode(buildingType)
	print("[BuildingController] 배치 모드 시작:", buildingType)

	isPlacingMode = true
	selectedBuildingType = buildingType
	currentRotation = 0

	-- 프리뷰 생성
	BuildingController.createGhostPreview()

	-- 취소 안내 UI 표시
	if cancelHintFrame then
		cancelHintFrame.Visible = true
	end
end

-- ========================================
-- 배치 모드 취소
-- ========================================
function BuildingController.cancelPlacingMode()
	print("[BuildingController] 배치 모드 취소")

	isPlacingMode = false
	selectedBuildingType = nil

	-- 프리뷰 삭제
	if ghostPreview then
		ghostPreview:Destroy()
		ghostPreview = nil
	end

	-- 취소 안내 UI 숨기기
	if cancelHintFrame then
		cancelHintFrame.Visible = false
	end
end

-- ========================================
-- Ghost 프리뷰 생성
-- ========================================
function BuildingController.createGhostPreview()
	if ghostPreview then
		ghostPreview:Destroy()
	end

	local spec = BuildingConfig[selectedBuildingType]
	if not spec then
		warn("[BuildingController] 유효하지 않은 건물 타입:", selectedBuildingType)
		return
	end

	ghostPreview = Instance.new("Part")
	ghostPreview.Name = "GhostPreview"
	ghostPreview.Size = spec.size
	ghostPreview.Anchored = true
	ghostPreview.CanCollide = false
	ghostPreview.Transparency = 0.5
	ghostPreview.Color = spec.color
	ghostPreview.Material = Enum.Material.Neon
	ghostPreview.Parent = workspace

	print("[BuildingController] Ghost 프리뷰 생성:", selectedBuildingType)
end

-- ========================================
-- 프리뷰 업데이트 (매 프레임)
-- ========================================
--function BuildingController.updatePreview()
--	if not isPlacingMode or not ghostPreview then
--		return
--	end

--	local mapFolder = workspace:FindFirstChild("Map") -- 너 프로젝트 맵 폴더 이름에 맞춰
--	if not mapFolder then return end
	
--	-- 마우스 위치 → 3D 좌표
--	local mouseRay = mouse.UnitRay
--	local raycastParams = RaycastParams.new()
--	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
--	raycastParams.FilterDescendantsInstances = {ghostPreview, player.Character}
	

--	local rayResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000, raycastParams)

--	if rayResult then
--		local hitPosition = rayResult.Position

--		-- 그리드 스냅
--		local snappedPosition = GridUtils.snapToGrid(hitPosition)

--		-- Y 좌표 보정
--		snappedPosition = snappedPosition + Vector3.new(0, ghostPreview.Size.Y / 2, 0)

--		ghostPreview.Position = snappedPosition
--		ghostPreview.Orientation = Vector3.new(0, currentRotation, 0)

--		-- 색상 (배치 가능 = 초록, 불가 = 빨강)
--		ghostPreview.Color = Color3.fromRGB(100, 255, 100)
--	end
--end
function BuildingController.updatePreview()
	if not isPlacingMode or not ghostPreview then
		return
	end

	-- 마우스 위치 → 3D 좌표
	local mouseRay = mouse.UnitRay
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

	-- ✅ Buildings 위에도 설치해야 하니 Buildings는 제외하지 않는다
	-- ✅ 대신 고스트/캐릭터만 제외
	raycastParams.FilterDescendantsInstances = { ghostPreview, player.Character }
	raycastParams.IgnoreWater = true

	local rayResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000, raycastParams)
	if not rayResult then return end

	local hitPosition = rayResult.Position

	-- ✅ X/Z만 그리드 스냅 (Y는 스냅하지 않음!)
	local snappedXZ = GridUtils.snapToGrid(Vector3.new(hitPosition.X, 0, hitPosition.Z))

	-- ✅ Y는 "맞은 표면"에 딱 붙게 계산
	-- hitPosition.Y는 표면 좌표이므로 + (고스트 높이/2)면 바닥이 표면에 정확히 붙음
	local y = hitPosition.Y + (ghostPreview.Size.Y / 2)

	-- ✅ 미세한 떠있음 방지 (부동소수점 오차 보정)
	y = math.floor(y * 1000 + 0.5) / 1000

	local snappedPosition = Vector3.new(snappedXZ.X, y, snappedXZ.Z)

	ghostPreview.Position = snappedPosition
	ghostPreview.Orientation = Vector3.new(0, currentRotation, 0)

	-- 색상 (배치 가능 = 초록, 불가 = 빨강) -> 지금은 항상 초록
	ghostPreview.Color = Color3.fromRGB(100, 255, 100)
end


-- ========================================
-- 건물 배치 시도
-- ========================================
function BuildingController.tryPlaceBuilding()
	if not ghostPreview then return end

	local position = ghostPreview.Position
	local rotation = currentRotation

	print(string.format("[BuildingController] 서버 요청: %s, Pos: %s, Rot: %d",
		selectedBuildingType, tostring(position), rotation))

	-- 서버로 배치 요청
	local result = RequestBuild:InvokeServer(selectedBuildingType, position, rotation)

	if result.success then
		print("[BuildingController] 배치 성공:", result.message)
		-- 배치 모드 유지 (연속 배치)
	else
		warn("[BuildingController] 배치 실패:", result.message)
	end
end

return BuildingController