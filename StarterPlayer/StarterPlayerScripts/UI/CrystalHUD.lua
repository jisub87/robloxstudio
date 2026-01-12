--[[
	CrystalHUD.lua
	
	목적: 크리스탈 HUD UI 생성 (HP, 레벨, 상태)
]]

local CrystalHUD = {}

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI 요소
local crystalFrame = nil
local hpBar = nil
local hpText = nil
local levelText = nil
local stateIcon = nil

-- ========================================
-- UI 생성
-- ========================================
function CrystalHUD.create()
	-- PlayerHUD의 ScreenGui 찾기 (이미 존재)
	local screenGui = playerGui:FindFirstChild("PlayerHUD")
	if not screenGui then
		warn("[CrystalHUD] PlayerHUD가 없습니다")
		return
	end

	-- CrystalHUD Frame
	crystalFrame = Instance.new("Frame")
	crystalFrame.Name = "CrystalHUD"
	crystalFrame.Size = UDim2.new(0, 300, 0, 100)
	crystalFrame.Position = UDim2.new(0.5, -150, 0, 60) -- TopBar 아래
	crystalFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	crystalFrame.BorderSizePixel = 0
	crystalFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = crystalFrame

	-- 상태 아이콘
	stateIcon = Instance.new("TextLabel")
	stateIcon.Name = "StateIcon"
	stateIcon.Size = UDim2.new(0, 40, 0, 40)
	stateIcon.Position = UDim2.new(0, 10, 0, 10)
	stateIcon.BackgroundTransparency = 1
	stateIcon.Text = "💎"
	stateIcon.TextScaled = true
	stateIcon.Font = Enum.Font.GothamBold
	stateIcon.Parent = crystalFrame

	-- 레벨 텍스트
	levelText = Instance.new("TextLabel")
	levelText.Name = "LevelText"
	levelText.Size = UDim2.new(0, 100, 0, 30)
	levelText.Position = UDim2.new(0, 60, 0, 10)
	levelText.BackgroundTransparency = 1
	levelText.Text = "Lv 1"
	levelText.TextColor3 = Color3.new(1, 1, 1)
	levelText.TextScaled = true
	levelText.Font = Enum.Font.GothamBold
	levelText.TextXAlignment = Enum.TextXAlignment.Left
	levelText.Parent = crystalFrame

	-- HP 바 배경
	local hpBarBg = Instance.new("Frame")
	hpBarBg.Name = "HPBarBg"
	hpBarBg.Size = UDim2.new(0, 280, 0, 30)
	hpBarBg.Position = UDim2.new(0, 10, 0, 50)
	hpBarBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	hpBarBg.BorderSizePixel = 0
	hpBarBg.Parent = crystalFrame

	local hpBarCorner = Instance.new("UICorner")
	hpBarCorner.CornerRadius = UDim.new(0, 8)
	hpBarCorner.Parent = hpBarBg

	-- HP 바 (진행바)
	hpBar = Instance.new("Frame")
	hpBar.Name = "HPBar"
	hpBar.Size = UDim2.new(1, 0, 1, 0) -- 100%
	hpBar.BackgroundColor3 = Color3.fromRGB(100, 200, 255) -- Healthy 색상
	hpBar.BorderSizePixel = 0
	hpBar.Parent = hpBarBg

	local hpBarInnerCorner = Instance.new("UICorner")
	hpBarInnerCorner.CornerRadius = UDim.new(0, 8)
	hpBarInnerCorner.Parent = hpBar

	-- HP 텍스트
	hpText = Instance.new("TextLabel")
	hpText.Name = "HPText"
	hpText.Size = UDim2.new(1, 0, 1, 0)
	hpText.BackgroundTransparency = 1
	hpText.Text = "1000 / 1000"
	hpText.TextColor3 = Color3.new(1, 1, 1)
	hpText.TextScaled = true
	hpText.Font = Enum.Font.GothamBold
	hpText.ZIndex = 2
	hpText.Parent = hpBarBg

	print("[CrystalHUD] UI 생성 완료")
end

-- ========================================
-- 데이터 업데이트
-- ========================================
function CrystalHUD.update(crystalData)
	if not crystalData then
		warn("[CrystalHUD] crystalData가 nil입니다")
		return
	end

	-- 레벨 업데이트
	if levelText then
		levelText.Text = string.format("Lv %d", crystalData.level or 1)
	end

	-- HP 바 업데이트
	if hpBar and hpText then
		local hpPercent = (crystalData.hp / crystalData.maxHp)
		hpBar.Size = UDim2.new(hpPercent, 0, 1, 0)
		hpText.Text = string.format("%d / %d", crystalData.hp, crystalData.maxHp)

		-- 상태별 색상
		local stateColors = {
			Healthy = Color3.fromRGB(100, 200, 255),
			Worried = Color3.fromRGB(255, 255, 100),
			Danger = Color3.fromRGB(255, 150, 50),
			Critical = Color3.fromRGB(255, 50, 50),
		}

		hpBar.BackgroundColor3 = stateColors[crystalData.state] or stateColors.Healthy
	end

	-- 상태 아이콘 (색상 변경)
	if stateIcon then
		local stateColors = {
			Healthy = Color3.fromRGB(100, 200, 255),
			Worried = Color3.fromRGB(255, 255, 100),
			Danger = Color3.fromRGB(255, 150, 50),
			Critical = Color3.fromRGB(255, 50, 50),
		}

		stateIcon.TextColor3 = stateColors[crystalData.state] or stateColors.Healthy
	end

	--print(string.format("[CrystalHUD] UI 업데이트: Lv=%d, HP=%d/%d, 상태=%s", crystalData.level, crystalData.hp, crystalData.maxHp, crystalData.state))
end

return CrystalHUD