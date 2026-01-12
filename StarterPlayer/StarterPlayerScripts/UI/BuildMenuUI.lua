--[[
	BuildMenuUI.lua
	
	목적: 건물 메뉴 UI 생성
]]

local BuildMenuUI = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BuildingConfig = {
	BUILDINGS = {
		Wall = { icon = "🏰", displayName = "방어벽", price = 10 },
		Tower = { icon = "🗼", displayName = "타워", price = 15 },
		Trap = { icon = "⚡", displayName = "함정", price = 20 },
	}
}

local buildMenuFrame = nil
local isMenuOpen = false

-- ========================================
-- UI 생성
-- ========================================
function BuildMenuUI.create()
	-- ScreenGui 생성
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BuildMenuGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- Frame (건물 메뉴)
	buildMenuFrame = Instance.new("Frame")
	buildMenuFrame.Name = "BuildMenu"
	buildMenuFrame.Size = UDim2.new(0, 300, 0, 200)
	buildMenuFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
	buildMenuFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	buildMenuFrame.BorderSizePixel = 2
	buildMenuFrame.Visible = false
	buildMenuFrame.Parent = screenGui

	-- UICorner (둥근 모서리)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = buildMenuFrame

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "건물 선택 (ESC로 닫기)"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = buildMenuFrame

	-- 건물 버튼들
	local yOffset = 50
	for buildingType, spec in pairs(BuildingConfig.BUILDINGS) do
		local button = Instance.new("TextButton")
		button.Name = buildingType .. "Button"
		button.Size = UDim2.new(0.9, 0, 0, 40)
		button.Position = UDim2.new(0.05, 0, 0, yOffset)
		button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		button.Text = string.format("%s %s (%dG)", spec.icon, spec.displayName, spec.price)
		button.TextColor3 = Color3.new(1, 1, 1)
		button.TextScaled = true
		button.Font = Enum.Font.Gotham
		button.Parent = buildMenuFrame

		-- 버튼 클릭 이벤트
		button.MouseButton1Click:Connect(function()
			BuildMenuUI.onBuildingSelected(buildingType)
		end)

		yOffset = yOffset + 50
	end

	print("[BuildMenuUI] UI 생성 완료")
end

-- ========================================
-- 메뉴 토글
-- ========================================
function BuildMenuUI.toggle()
	if not buildMenuFrame then
		BuildMenuUI.create()
	end

	isMenuOpen = not isMenuOpen
	buildMenuFrame.Visible = isMenuOpen

	print("[BuildMenuUI] 메뉴 토글:", isMenuOpen)
end

-- ========================================
-- 메뉴 닫기
-- ========================================
function BuildMenuUI.close()
	if buildMenuFrame then
		isMenuOpen = false
		buildMenuFrame.Visible = false
	end
end

-- ========================================
-- 건물 선택 시
-- ========================================
function BuildMenuUI.onBuildingSelected(buildingType)
	print("[BuildMenuUI] 건물 선택:", buildingType)

	-- 메뉴 닫기
	BuildMenuUI.close()

	-- BuildingController에 알림
	local BuildingSelectedEvent = ReplicatedStorage:FindFirstChild("BuildingSelectedEvent")
	if not BuildingSelectedEvent then
		BuildingSelectedEvent = Instance.new("BindableEvent")
		BuildingSelectedEvent.Name = "BuildingSelectedEvent"
		BuildingSelectedEvent.Parent = ReplicatedStorage
	end

	BuildingSelectedEvent:Fire(buildingType)
end

return BuildMenuUI