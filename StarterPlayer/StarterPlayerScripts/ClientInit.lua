--[[
	ClientInit.lua
	
	목적: 클라이언트 초기화
]]

local BuildingController = require(script.Parent.Controllers.BuildingController)
local PlayerController = require(script.Parent.Controllers.PlayerController)
local CrystalController = require(script.Parent.Controllers.CrystalController)
local WaveController = require(script.Parent.Controllers.WaveController)
local CombatController = require(script.Parent.Controllers.CombatController)
local SoundController = require(script.Parent.Controllers.SoundController) -- ✅ 추가

print("===========================================")
print("[ClientInit] 클라이언트 초기화 시작")
print("===========================================")

-- ✅ 잠시 대기 (서버가 RemoteEvents 생성할 시간)
task.wait(1)

-- Controllers 초기화 (순서 중요!)
SoundController.init() -- ✅ 먼저 초기화
PlayerController.init() 
CrystalController.init()
WaveController.init()
CombatController.init()
BuildingController.init()

print("[ClientInit] 초기화 완료")