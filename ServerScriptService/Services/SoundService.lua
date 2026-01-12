--[[
	SoundService.lua
	
	목적: 사운드 관리 (서버)
	책임:
	  - BGM 전환
	  - SFX 재생 (클라이언트 호출)
]]

local SoundService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- 모듈
local SoundConfig = require(ServerScriptService.Modules.Config.SoundConfig)

-- RemoteEvents
local PlayBGM
local PlaySFX
local StopBGM

-- 현재 BGM
local currentBGM = nil

-- ========================================
-- 초기화
-- ========================================
function SoundService.init()
	-- RemoteEvents 생성
	local soundRemotes = ReplicatedStorage.RemoteEvents:FindFirstChild("SoundRemotes")
	if not soundRemotes then
		soundRemotes = Instance.new("Folder")
		soundRemotes.Name = "SoundRemotes"
		soundRemotes.Parent = ReplicatedStorage.RemoteEvents
	end

	PlayBGM = soundRemotes:FindFirstChild("PlayBGM")
	if not PlayBGM then
		PlayBGM = Instance.new("RemoteEvent")
		PlayBGM.Name = "PlayBGM"
		PlayBGM.Parent = soundRemotes
	end

	PlaySFX = soundRemotes:FindFirstChild("PlaySFX")
	if not PlaySFX then
		PlaySFX = Instance.new("RemoteEvent")
		PlaySFX.Name = "PlaySFX"
		PlaySFX.Parent = soundRemotes
	end

	StopBGM = soundRemotes:FindFirstChild("StopBGM")
	if not StopBGM then
		StopBGM = Instance.new("RemoteEvent")
		StopBGM.Name = "StopBGM"
		StopBGM.Parent = soundRemotes
	end

	print("[SoundService] 초기화 완료")
end

-- ========================================
-- BGM 재생 (모든 클라이언트)
-- ========================================
function SoundService.playBGM(bgmName)
	local bgmConfig = SoundConfig.getBGM(bgmName)
	if not bgmConfig then
		warn("[SoundService] BGM 없음:", bgmName)
		return
	end

	currentBGM = bgmName

	PlayBGM:FireAllClients(bgmConfig)

	print(string.format("[SoundService] BGM 재생: %s", bgmName))
end

-- ========================================
-- BGM 정지
-- ========================================
function SoundService.stopBGM()
	StopBGM:FireAllClients()
	currentBGM = nil

	print("[SoundService] BGM 정지")
end

-- ========================================
-- SFX 재생 (모든 클라이언트)
-- ========================================
function SoundService.playSFX(sfxName, position)
	local sfxConfig = SoundConfig.getSFX(sfxName)
	if not sfxConfig then
		warn("[SoundService] SFX 없음:", sfxName)
		return
	end

	PlaySFX:FireAllClients({
		soundId = sfxConfig.soundId,
		volume = sfxConfig.volume,
		position = position,
	})

	-- print(string.format("[SoundService] SFX 재생: %s", sfxName))
end

-- ========================================
-- 현재 BGM 가져오기
-- ========================================
function SoundService.getCurrentBGM()
	return currentBGM
end

return SoundService