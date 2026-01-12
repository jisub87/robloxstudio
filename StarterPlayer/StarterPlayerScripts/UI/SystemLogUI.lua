-- SystemLogUI.lua
local SystemLogUI = {}

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local screenGui
local panel
local scroll
local isOpen = false

local MAX_LINES = 80
local entries = {}

function SystemLogUI.create()
	if screenGui then return end

	screenGui = playerGui:FindFirstChild("PlayerHUD")
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "PlayerHUD"
		screenGui.ResetOnSpawn = false
		screenGui.Parent = playerGui
	end

	panel = Instance.new("Frame")
	panel.Name = "SystemLogPanel"
	panel.Size = UDim2.new(0, 380, 0, 260)
	panel.Position = UDim2.new(1, -400, 1, -290) -- 우하단 근처
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 32)
	title.Position = UDim2.new(0, 10, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "📜 시스템 로그"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = panel

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "Close"
	closeBtn.Size = UDim2.new(0, 32, 0, 32)
	closeBtn.Position = UDim2.new(1, -40, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = panel

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		SystemLogUI.setOpen(false)
	end)

	scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.Size = UDim2.new(1, -20, 1, -50)
	scroll.Position = UDim2.new(0, 10, 0, 42)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = scroll
	
	local function bindRemote()
		local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
		local sys = remotes:FindFirstChild("SystemRemotes")
		if not sys then
			sys = Instance.new("Folder")
			sys.Name = "SystemRemotes"
			sys.Parent = remotes
		end

		local ev = sys:FindFirstChild("SystemLogAdded")
		if not ev then
			-- 서버가 만들 예정이지만, 안전하게 클라에서도 생성 시도(없으면 그냥 생김)
			ev = Instance.new("RemoteEvent")
			ev.Name = "SystemLogAdded"
			ev.Parent = sys
		end

		ev.OnClientEvent:Connect(function(payload)
			-- payload: { text = "..." }
			if payload and payload.text then
				SystemLogUI.addLine(payload.text)
			end
		end)
	end

	bindRemote()
end

function SystemLogUI.setOpen(open)
	isOpen = open
	if panel then
		panel.Visible = isOpen
	end
end

function SystemLogUI.toggle()
	SystemLogUI.setOpen(not isOpen)
end

local function rebuild()
	if not scroll then return end
	scroll:ClearAllChildren()

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = scroll

	local y = 0
	for i, e in ipairs(entries) do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 22)
		label.BackgroundTransparency = 1
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.Font = Enum.Font.Gotham
		label.Text = e
		label.LayoutOrder = i
		label.Parent = scroll

		y += 22 + 4
	end

	scroll.CanvasSize = UDim2.new(0, 0, 0, math.max(y, 0))
	scroll.CanvasPosition = Vector2.new(0, math.max(y - 240, 0)) -- 맨 아래로
end

function SystemLogUI.addLine(text)
	if not screenGui then
		SystemLogUI.create()
	end

	table.insert(entries, text)
	if #entries > MAX_LINES then
		table.remove(entries, 1)
	end

	rebuild()
end

return SystemLogUI
