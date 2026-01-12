-- ServerScriptService/Modules/Config/CrystalThemeConfig.lua
local CrystalThemeConfig = {}

-- 50레벨 단위 테마 (원하면 나중에 마음껏 늘리기)
CrystalThemeConfig.THEMES = {
	[1] = { id="Forest",  name="초록숲",  baseColor=Color3.fromRGB(90, 220, 140),  material=Enum.Material.Neon },
	[2] = { id="Volcano", name="화산",    baseColor=Color3.fromRGB(255, 120, 60),  material=Enum.Material.Neon },
	[3] = { id="Frost",   name="빙결",    baseColor=Color3.fromRGB(120, 200, 255), material=Enum.Material.Neon },
	[4] = { id="Cosmos",  name="우주",    baseColor=Color3.fromRGB(180, 120, 255), material=Enum.Material.Neon },
	[5] = { id="Aether",  name="에테르",  baseColor=Color3.fromRGB(255, 230, 120), material=Enum.Material.Neon },
}

local function clamp(x, a, b)
	return math.max(a, math.min(b, x))
end

local function lerpColor(a, b, t)
	t = clamp(t, 0, 1)
	return Color3.new(
		a.R + (b.R - a.R) * t,
		a.G + (b.G - a.G) * t,
		a.B + (b.B - a.B) * t
	)
end

-- level -> themeIndex(50단위), variantIndex(5단위)
function CrystalThemeConfig.getThemeForLevel(level)
	level = math.max(1, level or 1)
	local themeIndex = math.floor((level - 1) / 50) + 1
	local theme = CrystalThemeConfig.THEMES[themeIndex] or CrystalThemeConfig.THEMES[#CrystalThemeConfig.THEMES]

	-- 5레벨 단위 변형: 0~9
	local variant = math.floor((level - 1) / 5) % 10
	local t = variant / 9 -- 0~1

	-- 변형에 따라 밝아지거나 색이 살짝 이동하는 느낌
	local brighter = Color3.new(1,1,1)
	local color = lerpColor(theme.baseColor, brighter, 0.25 * t)

	-- 크기: 5레벨마다 +2% (최대 1.8배 제한)
	local sizeMul = 1.0 + 0.02 * math.floor((level - 1) / 5)
	sizeMul = math.min(sizeMul, 1.8)

	return {
		themeIndex = themeIndex,
		themeId = theme.id,
		themeName = theme.name,
		variant = variant,
		color = color,
		material = theme.material,
		sizeMultiplier = sizeMul,
	}
end

return CrystalThemeConfig
