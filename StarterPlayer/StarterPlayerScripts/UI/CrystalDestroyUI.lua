--[[
	CrystalDestroyUI.lua
	
	목적: 크리스탈 파괴/부활 UI 표시
]]

local CrystalDestroyUI = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local destroyFrame = nil
local countdownText = nil

-- ========================================
-- 초기화
-- ========================================
function CrystalDestroyUI.init()
	print("[CrystalDestroyUI] 초기화 완료")
end

-- ========================================
-- 파괴 화면 표시
-- ========================================
function CrystalDestroyUI.showDestroyed()
	print("[CrystalDestroyUI] 크리스탈 파괴 화면 표시")

	-- ScreenGui
	local screenGui = playerGui:FindFirstChild("PlayerHUD")
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "PlayerHUD"
		screenGui.ResetOnSpawn = false
		screenGui.Parent = playerGui
	end

	-- 전체 화면 어두운 오버레이
	destroyFrame = Instance.new("Frame")
	destroyFrame.Name = "CrystalDestroyOverlay"
	destroyFrame.Size = UDim2.new(1, 0, 1, 0)
	destroyFrame.Position = UDim2.new(0, 0, 0, 0)
	destroyFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	destroyFrame.BackgroundTransparency = 1
	destroyFrame.ZIndex = 100
	destroyFrame.Parent = screenGui

	-- 페이드 인 애니메이션
	local fadeIn = TweenService:Create(destroyFrame, TweenInfo.new(2, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 0.3,
	})
	fadeIn:Play()

	-- 메인 텍스트
	local mainText = Instance.new("TextLabel")
	mainText.Size = UDim2.new(0.8, 0, 0, 100)
	mainText.Position = UDim2.new(0.1, 0, 0.35, 0)
	mainText.BackgroundTransparency = 1
	mainText.Text = "💔 크리스탈이 파괴되었습니다..."
	mainText.TextColor3 = Color3.fromRGB(255, 100, 100)
	mainText.TextScaled = true
	mainText.Font = Enum.Font.GothamBold
	mainText.TextTransparency = 1
	mainText.Parent = destroyFrame

	-- 텍스트 페이드 인
	local textFadeIn = TweenService:Create(mainText, TweenInfo.new(1, Enum.EasingStyle.Quad), {
		TextTransparency = 0,
	})
	textFadeIn:Play()

	-- 카운트다운 텍스트
	task.wait(2)

	countdownText = Instance.new("TextLabel")
	countdownText.Size = UDim2.new(0.8, 0, 0, 80)
	countdownText.Position = UDim2.new(0.1, 0, 0.5, 0)
	countdownText.BackgroundTransparency = 1
	countdownText.Text = "10초 후 재건 파티 시작..."
	countdownText.TextColor3 = Color3.fromRGB(255, 255, 100)
	countdownText.TextScaled = true
	countdownText.Font = Enum.Font.Gotham
	countdownText.Parent = destroyFrame

	-- 카운트다운
	CrystalDestroyUI.startCountdown(10)
end

-- ========================================
-- 카운트다운
-- ========================================
function CrystalDestroyUI.startCountdown(seconds)
	task.spawn(function()
		for i = seconds, 1, -1 do
			if countdownText then
				countdownText.Text = string.format("%d초 후 재건 파티 시작...", i)
			end
			task.wait(1)
		end
	end)
end

-- ========================================
-- 부활 화면
-- ========================================
function CrystalDestroyUI.showRevived()
	print("[CrystalDestroyUI] 크리스탈 부활 화면 표시")

	if destroyFrame then
		-- 부활 텍스트
		local reviveText = Instance.new("TextLabel")
		reviveText.Size = UDim2.new(0.8, 0, 0, 100)
		reviveText.Position = UDim2.new(0.1, 0, 0.35, 0)
		reviveText.BackgroundTransparency = 1
		reviveText.Text = "✨ 크리스탈이 부활했습니다!"
		reviveText.TextColor3 = Color3.fromRGB(100, 255, 100)
		reviveText.TextScaled = true
		reviveText.Font = Enum.Font.GothamBold
		reviveText.Parent = destroyFrame

		task.wait(2)

		-- 페이드 아웃
		local fadeOut = TweenService:Create(destroyFrame, TweenInfo.new(1, Enum.EasingStyle.Quad), {
			BackgroundTransparency = 1,
		})
		fadeOut:Play()

		fadeOut.Completed:Connect(function()
			if destroyFrame then
				destroyFrame:Destroy()
				destroyFrame = nil
			end
		end)
	end
end

-- ========================================
-- 재건 파티 시작 UI
-- ========================================
function CrystalDestroyUI.showRebuildParty(data)
	print("[CrystalDestroyUI] 재건 파티 UI 표시")

	local screenGui = playerGui:FindFirstChild("PlayerHUD")
	if not screenGui then return end

	-- 재건 파티 배너
	local partyFrame = Instance.new("Frame")
	partyFrame.Name = "RebuildPartyBanner"
	partyFrame.Size = UDim2.new(0, 400, 0, 100)
	partyFrame.Position = UDim2.new(0.5, -200, 0, -120)
	partyFrame.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	partyFrame.BorderSizePixel = 0
	partyFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15)
	corner.Parent = partyFrame

	-- 배너 텍스트
	local bannerText = Instance.new("TextLabel")
	bannerText.Size = UDim2.new(1, -20, 0, 40)
	bannerText.Position = UDim2.new(0, 10, 0, 10)
	bannerText.BackgroundTransparency = 1
	bannerText.Text = "🎉 재건 파티 시작!"
	bannerText.TextColor3 = Color3.new(1, 1, 1)
	bannerText.TextScaled = true
	bannerText.Font = Enum.Font.GothamBold
	bannerText.Parent = partyFrame

	-- 버프 설명
	local buffText = Instance.new("TextLabel")
	buffText.Size = UDim2.new(1, -20, 0, 45)
	buffText.Position = UDim2.new(0, 10, 0, 50)
	buffText.BackgroundTransparency = 1
	buffText.Text = string.format(
		"건설 속도 x%.1f | 수리 속도 x%.1f | 골드 x%.1f",
		data.buildSpeedMultiplier,
		data.repairSpeedMultiplier,
		data.goldMultiplier
	)
	buffText.TextColor3 = Color3.new(1, 1, 1)
	buffText.TextScaled = true
	buffText.Font = Enum.Font.Gotham
	buffText.Parent = partyFrame

	-- 슬라이드 다운 애니메이션
	local slideDown = TweenService:Create(partyFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -200, 0, 10),
	})
	slideDown:Play()

	-- 타이머 추가
	local timerText = Instance.new("TextLabel")
	timerText.Size = UDim2.new(0, 80, 0, 30)
	timerText.Position = UDim2.new(1, -90, 0, 10)
	timerText.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	timerText.TextColor3 = Color3.new(1, 1, 1)
	timerText.TextScaled = true
	timerText.Font = Enum.Font.GothamBold
	timerText.Text = "2:00"
	timerText.Parent = partyFrame

	local timerCorner = Instance.new("UICorner")
	timerCorner.CornerRadius = UDim.new(0, 8)
	timerCorner.Parent = timerText

	-- 카운트다운
	local startTime = tick()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = tick() - startTime
		local remaining = math.max(0, data.duration - elapsed)

		local minutes = math.floor(remaining / 60)
		local seconds = math.floor(remaining % 60)
		timerText.Text = string.format("%d:%02d", minutes, seconds)

		if remaining <= 0 then
			connection:Disconnect()
		end
	end)

	-- 2분 후 슬라이드 업
	task.delay(data.duration, function()
		local slideUp = TweenService:Create(partyFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, -200, 0, -120),
		})
		slideUp:Play()

		slideUp.Completed:Connect(function()
			partyFrame:Destroy()
		end)
	end)
end

-- ========================================
-- 재건 파티 종료 UI
-- ========================================
function CrystalDestroyUI.showRebuildPartyEnd(success)
	print("[CrystalDestroyUI] 재건 파티 종료:", success)

	local screenGui = playerGui:FindFirstChild("PlayerHUD")
	if not screenGui then return end

	local resultFrame = Instance.new("Frame")
	resultFrame.Size = UDim2.new(0, 400, 0, 150)
	resultFrame.Position = UDim2.new(0.5, -200, 0.5, -75)
	resultFrame.BackgroundColor3 = success and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
	resultFrame.BorderSizePixel = 0
	resultFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15)
	corner.Parent = resultFrame

	local resultText = Instance.new("TextLabel")
	resultText.Size = UDim2.new(1, -20, 0, 60)
	resultText.Position = UDim2.new(0, 10, 0, 20)
	resultText.BackgroundTransparency = 1
	resultText.Text = success and "✅ 재건 파티 성공!" or "❌ 재건 파티 실패"
	resultText.TextColor3 = Color3.new(1, 1, 1)
	resultText.TextScaled = true
	resultText.Font = Enum.Font.GothamBold
	resultText.Parent = resultFrame

	if success then
		local rewardText = Instance.new("TextLabel")
		rewardText.Size = UDim2.new(1, -20, 0, 60)
		rewardText.Position = UDim2.new(0, 10, 0, 80)
		rewardText.BackgroundTransparency = 1
		rewardText.Text = "보상: 골드 +200, 토큰 +1"
		rewardText.TextColor3 = Color3.new(1, 1, 1)
		rewardText.TextScaled = true
		rewardText.Font = Enum.Font.Gotham
		rewardText.Parent = resultFrame
	end

	task.delay(3, function()
		resultFrame:Destroy()
	end)
end

return CrystalDestroyUI