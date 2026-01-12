--[[
	WaveHUD.lua
	
	목적: Wave HUD UI 생성
]]

local WaveHUD = {}

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI 요소
local waveFrame = nil
local waveText = nil
local timerText = nil
local stateText = nil

-- ========================================
-- UI 생성
-- ========================================
function WaveHUD.create()
	local screenGui = playerGui:FindFirstChild("PlayerHUD")
	if not screenGui then
		warn("[WaveHUD] PlayerHUD가 없습니다")
		return
	end

	-- WaveHUD Frame
	waveFrame = Instance.new("Frame")
	waveFrame.Name = "WaveHUD"
	waveFrame.Size = UDim2.new(0, 250, 0, 80)
	waveFrame.Position = UDim2.new(1, -260, 0, 10) -- 우측 상단
	waveFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	waveFrame.BorderSizePixel = 0
	waveFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = waveFrame

	-- 상태 텍스트 (Peace/Wave/Reward)
	stateText = Instance.new("TextLabel")
	stateText.Name = "StateText"
	stateText.Size = UDim2.new(1, -20, 0, 25)
	stateText.Position = UDim2.new(0, 10, 0, 10)
	stateText.BackgroundTransparency = 1
	stateText.Text = "⏸️ Peace Time"
	stateText.TextColor3 = Color3.new(1, 1, 1)
	stateText.TextScaled = true
	stateText.Font = Enum.Font.GothamBold
	stateText.TextXAlignment = Enum.TextXAlignment.Left
	stateText.Parent = waveFrame

	-- Wave 번호
	waveText = Instance.new("TextLabel")
	waveText.Name = "WaveText"
	waveText.Size = UDim2.new(1, -20, 0, 20)
	waveText.Position = UDim2.new(0, 10, 0, 35)
	waveText.BackgroundTransparency = 1
	waveText.Text = "Wave 0 / 5"
	waveText.TextColor3 = Color3.fromRGB(200, 200, 200)
	waveText.TextScaled = true
	waveText.Font = Enum.Font.Gotham
	waveText.TextXAlignment = Enum.TextXAlignment.Left
	waveText.Parent = waveFrame

	-- 타이머
	timerText = Instance.new("TextLabel")
	timerText.Name = "TimerText"
	timerText.Size = UDim2.new(1, -20, 0, 20)
	timerText.Position = UDim2.new(0, 10, 0, 55)
	timerText.BackgroundTransparency = 1
	timerText.Text = "⏱️ 5:00"
	timerText.TextColor3 = Color3.fromRGB(150, 150, 150)
	timerText.TextScaled = true
	timerText.Font = Enum.Font.Gotham
	timerText.TextXAlignment = Enum.TextXAlignment.Left
	timerText.Parent = waveFrame

	print("[WaveHUD] UI 생성 완료")
end

-- ========================================
-- 데이터 업데이트
-- ========================================
function WaveHUD.update(waveData)
	if not waveData then return end

	-- 상태 텍스트
	if stateText then
		local stateIcons = {
			Peace = "⏸️",
			Wave = "⚔️",
			Reward = "🎉",
		}

		local icon = stateIcons[waveData.state] or "❓"
		stateText.Text = string.format("%s %s Time", icon, waveData.state)

		-- 상태별 색상
		if waveData.state == "Peace" then
			stateText.TextColor3 = Color3.fromRGB(100, 255, 100)
		elseif waveData.state == "Wave" then
			stateText.TextColor3 = Color3.fromRGB(255, 100, 100)
		elseif waveData.state == "Reward" then
			stateText.TextColor3 = Color3.fromRGB(255, 255, 100)
		end
	end

	-- Wave 번호
	if waveText then
		waveText.Text = string.format("Wave %d / %d", waveData.waveNumber or 0, waveData.totalWaves or 5)
	end

	-- 타이머 (초 → 분:초)
	if timerText then
		local minutes = math.floor(waveData.duration / 60)
		local seconds = waveData.duration % 60
		timerText.Text = string.format("⏱️ %d:%02d", minutes, seconds)
	end

	--print(string.format("[WaveHUD] UI 업데이트: %s, Wave %d, 시간 %d초", waveData.state, waveData.waveNumber or 0, waveData.duration))
end

return WaveHUD