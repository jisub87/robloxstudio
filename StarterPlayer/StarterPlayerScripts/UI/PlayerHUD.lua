--[[
	PlayerHUD.lua
	
	목적: 플레이어 HUD UI 생성 (골드, 레벨, 클래스)
]]

local PlayerHUD = {}

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local BuildMenuUI = require(script.Parent.BuildMenuUI) 


-- UI 요소
local screenGui = nil
local goldLabel = nil
local tokenLabel = nil
local classLabel = nil

-- ========================================
-- UI 생성
-- ========================================
function PlayerHUD.create()
	-- ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PlayerHUD"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- TopBar Frame
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 50)
	topBar.Position = UDim2.new(0, 0, 0, 0)
	topBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	topBar.BorderSizePixel = 0
	topBar.Parent = screenGui

	-- 골드 표시
	local goldFrame = Instance.new("Frame")
	goldFrame.Name = "GoldFrame"
	goldFrame.Size = UDim2.new(0, 150, 0, 40)
	goldFrame.Position = UDim2.new(0, 10, 0, 5)
	goldFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	goldFrame.Parent = topBar

	local goldCorner = Instance.new("UICorner")
	goldCorner.CornerRadius = UDim.new(0, 8)
	goldCorner.Parent = goldFrame

	goldLabel = Instance.new("TextLabel")
	goldLabel.Name = "GoldLabel"
	goldLabel.Size = UDim2.new(1, 0, 1, 0)
	goldLabel.BackgroundTransparency = 1
	goldLabel.Text = "💰 골드: 0"
	goldLabel.TextColor3 = Color3.new(1, 1, 1)
	goldLabel.TextScaled = true
	goldLabel.Font = Enum.Font.GothamBold
	goldLabel.Parent = goldFrame

	-- 전설 토큰 표시
	local tokenFrame = Instance.new("Frame")
	tokenFrame.Name = "TokenFrame"
	tokenFrame.Size = UDim2.new(0, 150, 0, 40)
	tokenFrame.Position = UDim2.new(0, 170, 0, 5)
	tokenFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	tokenFrame.Parent = topBar

	local tokenCorner = Instance.new("UICorner")
	tokenCorner.CornerRadius = UDim.new(0, 8)
	tokenCorner.Parent = tokenFrame

	tokenLabel = Instance.new("TextLabel")
	tokenLabel.Name = "TokenLabel"
	tokenLabel.Size = UDim2.new(1, 0, 1, 0)
	tokenLabel.BackgroundTransparency = 1
	tokenLabel.Text = "⭐ 토큰: 0"
	tokenLabel.TextColor3 = Color3.new(1, 1, 1)
	tokenLabel.TextScaled = true
	tokenLabel.Font = Enum.Font.GothamBold
	tokenLabel.Parent = tokenFrame

	-- 클래스 표시
	local classFrame = Instance.new("Frame")
	classFrame.Name = "ClassFrame"
	classFrame.Size = UDim2.new(0, 150, 0, 40)
	classFrame.Position = UDim2.new(1, -160, 0, 5)
	classFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	classFrame.Parent = topBar

	local classCorner = Instance.new("UICorner")
	classCorner.CornerRadius = UDim.new(0, 8)
	classCorner.Parent = classFrame

	classLabel = Instance.new("TextLabel")
	classLabel.Name = "ClassLabel"
	classLabel.Size = UDim2.new(1, 0, 1, 0)
	classLabel.BackgroundTransparency = 1
	classLabel.Text = "🧱 Builder"
	classLabel.TextColor3 = Color3.new(1, 1, 1)
	classLabel.TextScaled = true
	classLabel.Font = Enum.Font.GothamBold
	classLabel.Parent = classFrame

	-- 빌드 버튼 (B)
	local buildButton = Instance.new("TextButton")
	buildButton.Name = "BuildButton"
	buildButton.Size = UDim2.new(0, 120, 0, 40)
	buildButton.Position = UDim2.new(0, 330, 0, 5) -- 토큰 오른쪽에 배치
	buildButton.BackgroundColor3 = Color3.fromRGB(70, 90, 160)
	buildButton.Text = "🏗️ 빌드 (B)"
	buildButton.TextColor3 = Color3.new(1, 1, 1)
	buildButton.TextScaled = true
	buildButton.Font = Enum.Font.GothamBold
	buildButton.Parent = topBar

	local buildCorner = Instance.new("UICorner")
	buildCorner.CornerRadius = UDim.new(0, 8)
	buildCorner.Parent = buildButton

	buildButton.MouseButton1Click:Connect(function()
		BuildMenuUI.toggle()
	end)

	local SystemLogUI = require(script.Parent.SystemLogUI)

	-- create() 안, topBar에:
	local logButton = Instance.new("TextButton")
	logButton.Name = "LogButton"
	logButton.Size = UDim2.new(0, 110, 0, 40)
	logButton.Position = UDim2.new(0, 460, 0, 5)
	logButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	logButton.Text = "📜 로그"
	logButton.TextColor3 = Color3.new(1,1,1)
	logButton.TextScaled = true
	logButton.Font = Enum.Font.GothamBold
	logButton.Parent = topBar

	local logCorner = Instance.new("UICorner")
	logCorner.CornerRadius = UDim.new(0, 8)
	logCorner.Parent = logButton

	logButton.MouseButton1Click:Connect(function()
		SystemLogUI.toggle()
	end)


	print("[PlayerHUD] UI 생성 완료")
end

-- ========================================
-- 데이터 업데이트
-- ========================================
function PlayerHUD.update(playerData)
	if not playerData then
		warn("[PlayerHUD] playerData가 nil입니다")
		return
	end

	-- 골드 업데이트
	if goldLabel then
		goldLabel.Text = string.format("💰 골드: %d", playerData.gold or 0)
	end

	-- 토큰 업데이트
	if tokenLabel then
		tokenLabel.Text = string.format("⭐ 토큰: %d", playerData.legendTokens or 0)
	end

	-- 클래스 업데이트
	if classLabel then
		local classIcons = {
			Builder = "🧱",
			Fighter = "⚔️",
			Repairer = "🔧"
		}

		local icon = classIcons[playerData.currentClass] or "❓"
		classLabel.Text = string.format("%s %s", icon, playerData.currentClass or "Unknown")
	end

	print(string.format("[PlayerHUD] UI 업데이트: 골드=%d, 토큰=%d, 클래스=%s",
		playerData.gold or 0,
		playerData.legendTokens or 0,
		playerData.currentClass or "Unknown"))
end

return PlayerHUD