--[[
	GridUtils.lua
	
	목적: 그리드 스냅 계산 (서버/클라이언트 공유)
]]

local GridUtils = {}

local GRID_SIZE = 4 -- studs

-- 위치를 그리드에 스냅
function GridUtils.snapToGrid(position)
	return Vector3.new(
		math.floor(position.X / GRID_SIZE + 0.5) * GRID_SIZE,
		math.floor(position.Y / GRID_SIZE + 0.5) * GRID_SIZE,
		math.floor(position.Z / GRID_SIZE + 0.5) * GRID_SIZE
	)
end

-- 회전을 90도 단위로 스냅
function GridUtils.snapRotation(rotation)
	local normalized = rotation % 360
	return math.floor(normalized / 90 + 0.5) * 90
end

return GridUtils