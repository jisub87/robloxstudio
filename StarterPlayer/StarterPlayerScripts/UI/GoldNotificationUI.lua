--[[
	GoldNotificationUI.lua
	
	목적: 골드 획득 알림 표시
]]

local GoldNotificationUI = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 알림 큐
local notificationQueue = {}
local isShowingNotification = false

-- ========================================
-- 초기화
-- ========================================
function GoldNotificationUI.init()
	print("[GoldNotificationUI] 초기화 완료")
end

-- ========================================
-- 골드 알림 표시
-- ========================================
function GoldNotificationUI.show(amount, reason)
	-- 큐에 추가
	table.insert(notificationQueue, {
		amount = amount,
		reason = reason,
	})

	-- 현재 표시 중이 아니면 즉시 표시
	if not isShowingNotification then
		GoldNotificationUI.processQueue()
	end
end

-- ========================================
-- 큐 처리
-- ========================================
function GoldNotificationUI.processQueue()
	if #notificationQueue == 0 then
		isShowingNotification = false
		return
	end

	isShowingNotification = true

	-- 첫 번째 알림 가져오기
	local notification = table.remove(notificationQueue, 1)

	-- UI 생성
	local screenGui = playerGui:FindFirstChild("PlayerHUD")
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "PlayerHUD"
		screenGui.ResetOnSpawn = false
		screenGui.Parent = playerGui
	end

	-- 알림 Frame
	local notifFrame = Instance.new("Frame")
	notifFrame.Name = "GoldNotification"
	notifFrame.Size = UDim2.new(0, 300, 0, 80)
	notifFrame.Position = UDim2.new(0.5, -150, 0.3, 0)
	notifFrame.BackgroundColor3 = Color3.fromRGB(255, 215, 0) -- 골드 색상
	notifFrame.BorderSizePixel = 0
	notifFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	notifFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15)
	corner.Parent = notifFrame

	-- 금액 텍스트
	local amountText = Instance.new("TextLabel")
	amountText.Size = UDim2.new(1, 0, 0, 35)
	amountText.Position = UDim2.new(0, 0, 0, 10)
	amountText.BackgroundTransparency = 1
	amountText.Text = string.format("+%d 골드", notification.amount)
	amountText.TextColor3 = Color3.new(1, 1, 1)
	amountText.TextScaled = true
	amountText.Font = Enum.Font.GothamBold
	amountText.Parent = notifFrame

	-- 그림자 효과
	local shadow = Instance.new("TextLabel")
	shadow.Size = amountText.Size
	shadow.Position = amountText.Position + UDim2.new(0, 2, 0, 2)
	shadow.BackgroundTransparency = 1
	shadow.Text = amountText.Text
	shadow.TextColor3 = Color3.new(0, 0, 0)
	shadow.TextScaled = true
	shadow.Font = Enum.Font.GothamBold
	shadow.TextTransparency = 0.5
	shadow.ZIndex = amountText.ZIndex - 1
	shadow.Parent = notifFrame

	-- 사유 텍스트
	local reasonText = Instance.new("TextLabel")
	reasonText.Size = UDim2.new(1, -20, 0, 25)
	reasonText.Position = UDim2.new(0, 10, 0, 50)
	reasonText.BackgroundTransparency = 1
	reasonText.Text = notification.reason
	reasonText.TextColor3 = Color3.new(1, 1, 1)
	reasonText.TextScaled = true
	reasonText.Font = Enum.Font.Gotham
	reasonText.Parent = notifFrame

	-- 애니메이션: 등장
	notifFrame.Position = UDim2.new(0.5, -150, 0.2, 0)
	notifFrame.Size = UDim2.new(0, 0, 0, 0)

	local tweenIn = TweenService:Create(notifFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 300, 0, 80),
		Position = UDim2.new(0.5, -150, 0.3, 0),
	})

	tweenIn:Play()

	-- 2초 후 사라짐
	task.wait(2.5)

	local tweenOut = TweenService:Create(notifFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0.5, -150, 0.2, 0),
	})

	tweenOut:Play()
	tweenOut.Completed:Connect(function()
		notifFrame:Destroy()

		-- 다음 알림 처리
		task.wait(0.2)
		GoldNotificationUI.processQueue()
	end)
end

return GoldNotificationUI