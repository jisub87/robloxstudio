local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")

local function getOrCreateFolder(parent, folderName)
	local folder = parent:FindFirstChild(folderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = parent
	end
	return folder
end

local function createRemoteEvent(parent, eventName)
	if parent:FindFirstChild(eventName) then return end
	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = eventName
	remoteEvent.Parent = parent
	print("✅ RemoteEvent 생성:", eventName)
end

local function createRemoteFunction(parent, functionName)
	if parent:FindFirstChild(functionName) then return end
	local remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = functionName
	remoteFunction.Parent = parent
	print("✅ RemoteFunction 생성:", functionName)
end

local playerFolder = getOrCreateFolder(remoteEventsFolder, "PlayerRemotes")
createRemoteFunction(playerFolder, "RequestPlayerData")
createRemoteEvent(playerFolder, "PlayerDataUpdated")
print("[SetupRemotes] PlayerRemotes 완료")