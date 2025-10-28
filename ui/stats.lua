local _, ns = ...
local E = ns.E

-- Create a stat row
local function CreateStatRow(parent, label, yOffset)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(280, 20)
	row:SetPoint("TOP", parent, "TOP", 0, yOffset)

	local labelText = row:CreateFontString(nil, "OVERLAY")
	labelText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	labelText:SetPoint("LEFT", row, "LEFT", 10, 0)
	labelText:SetTextColor(0.8, 0.8, 0.8, 1)
	labelText:SetText(label)
	row.label = labelText

	local valueText = row:CreateFontString(nil, "OVERLAY")
	valueText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	valueText:SetPoint("RIGHT", row, "RIGHT", -10, 0)
	valueText:SetTextColor(1, 1, 1, 1)
	row.value = valueText

	return row
end

-- Update character stats
local function UpdateStats(panel)
	if not panel or not panel.stats then return end

	-- Average item level
	local avgEquipped, avgTotal = GetAverageItemLevel()
	panel.stats.ilvl.value:SetText(string.format("%.1f", avgEquipped))

	-- Primary stat (depends on class/spec)
	local spec = GetSpecialization()
	local primaryStat
	if spec then
		local role = GetSpecializationRole(spec)
		if role == "TANK" then
			primaryStat = UnitStat("player", LE_UNIT_STAT_STAMINA)
		elseif role == "HEALER" then
			primaryStat = UnitStat("player", LE_UNIT_STAT_INTELLECT)
		else
			-- DPS - could be Str, Agi, or Int
			local _, class = UnitClass("player")
			if class == "WARRIOR" or class == "PALADIN" or class == "DEATHKNIGHT" then
				primaryStat = UnitStat("player", LE_UNIT_STAT_STRENGTH)
			elseif class == "HUNTER" or class == "ROGUE" or class == "SHAMAN" or class == "MONK" or class == "DRUID" or class == "DEMONHUNTER" then
				primaryStat = UnitStat("player", LE_UNIT_STAT_AGILITY)
			else
				primaryStat = UnitStat("player", LE_UNIT_STAT_INTELLECT)
			end
		end
	else
		-- No spec, show Stamina
		primaryStat = UnitStat("player", LE_UNIT_STAT_STAMINA)
	end
	panel.stats.primary.value:SetText(primaryStat)

	-- Stamina
	local stamina = UnitStat("player", LE_UNIT_STAT_STAMINA)
	panel.stats.stamina.value:SetText(stamina)

	-- Critical Strike
	local critChance = GetCritChance()
	panel.stats.crit.value:SetText(string.format("%.2f%%", critChance))

	-- Haste
	local hastePercent = UnitSpellHaste("player")
	panel.stats.haste.value:SetText(string.format("%.2f%%", hastePercent))

	-- Mastery
	local masteryPercent = GetMasteryEffect()
	panel.stats.mastery.value:SetText(string.format("%.2f%%", masteryPercent))

	-- Versatility
	local versatilityPercent = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)
	panel.stats.versatility.value:SetText(string.format("%.2f%%", versatilityPercent))

	-- Speed (movement)
	local _, runSpeed, flightSpeed, swimSpeed = GetUnitSpeed("player")
	local baseSpeed = 7 -- Base speed
	local speedPercent = ((runSpeed / baseSpeed) - 1) * 100
	panel.stats.speed.value:SetText(string.format("%.0f%%", speedPercent))

	-- Leech
	local leechPercent = GetLifesteal()
	panel.stats.leech.value:SetText(string.format("%.2f%%", leechPercent))

	-- Avoidance
	local avoidancePercent = GetAvoidance()
	panel.stats.avoidance.value:SetText(string.format("%.2f%%", avoidancePercent))
end

function E:CreateStatsPanel(parent)
	local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	panel:SetAllPoints(parent)

	-- Create glass backdrop
	E:CreateGlassBackdrop(panel, 0.9, true)

	-- Title
	local title = panel:CreateFontString(nil, "OVERLAY")
	title:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
	title:SetPoint("TOP", panel, "TOP", 0, -15)
	title:SetTextColor(0, 1, 0, 1)
	title:SetText("Character Stats")
	panel.title = title

	-- Create stat rows
	panel.stats = {}
	local yOffset = -45
	local rowHeight = -30

	-- Item Level
	panel.stats.ilvl = CreateStatRow(panel, "Item Level", yOffset)
	yOffset = yOffset + rowHeight

	-- Primary Stat
	panel.stats.primary = CreateStatRow(panel, "Primary Stat", yOffset)
	yOffset = yOffset + rowHeight

	-- Stamina
	panel.stats.stamina = CreateStatRow(panel, "Stamina", yOffset)
	yOffset = yOffset + rowHeight

	-- Separator
	yOffset = yOffset + rowHeight / 2

	-- Secondary Stats
	panel.stats.crit = CreateStatRow(panel, "Critical Strike", yOffset)
	yOffset = yOffset + rowHeight

	panel.stats.haste = CreateStatRow(panel, "Haste", yOffset)
	yOffset = yOffset + rowHeight

	panel.stats.mastery = CreateStatRow(panel, "Mastery", yOffset)
	yOffset = yOffset + rowHeight

	panel.stats.versatility = CreateStatRow(panel, "Versatility", yOffset)
	yOffset = yOffset + rowHeight

	-- Separator
	yOffset = yOffset + rowHeight / 2

	-- Tertiary Stats
	panel.stats.speed = CreateStatRow(panel, "Speed", yOffset)
	yOffset = yOffset + rowHeight

	panel.stats.leech = CreateStatRow(panel, "Leech", yOffset)
	yOffset = yOffset + rowHeight

	panel.stats.avoidance = CreateStatRow(panel, "Avoidance", yOffset)

	-- Initial update
	UpdateStats(panel)

	-- Store panel reference
	parent.statsPanel = panel

	-- Update on events
	panel:RegisterUnitEvent("UNIT_STATS", "player")
	panel:RegisterUnitEvent("UNIT_SPELL_HASTE", "player")
	panel:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

	panel:SetScript("OnEvent", function(self)
		UpdateStats(self)
	end)

	return panel
end
