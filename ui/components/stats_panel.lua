local _, ns = ...
local E = ns.E

-- Create a stat row with optional tooltip
local function CreateStatRow(parent, label, yOffset, tooltipInfo)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(280, 20)
	row:SetPoint("TOP", parent, "TOP", 0, yOffset)

	-- Enable mouse for tooltip
	if tooltipInfo then
		row:EnableMouse(true)
		row:SetScript("OnEnter", function(self)
			if E.CursorTooltip then
				E.CursorTooltip:Show(tooltipInfo.title, tooltipInfo.description)
			end
		end)
		row:SetScript("OnLeave", function(self)
			if E.CursorTooltip then
				E.CursorTooltip:Hide()
			end
		end)
	end

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
	local critRating = GetCombatRating(CR_CRIT_MELEE)
	panel.stats.crit.value:SetText(string.format("%.2f%% (%d)", critChance, critRating))

	-- Haste
	local hastePercent = UnitSpellHaste("player")
	local hasteRating = GetCombatRating(CR_HASTE_MELEE)
	panel.stats.haste.value:SetText(string.format("%.2f%% (%d)", hastePercent, hasteRating))

	-- Mastery
	local masteryPercent = GetMasteryEffect()
	local masteryRating = GetCombatRating(CR_MASTERY)
	panel.stats.mastery.value:SetText(string.format("%.2f%% (%d)", masteryPercent, masteryRating))

	-- Versatility
	local versatilityPercent = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)
	local versatilityRating = GetCombatRating(CR_VERSATILITY_DAMAGE_DONE)
	panel.stats.versatility.value:SetText(string.format("%.2f%% (%d)", versatilityPercent, versatilityRating))

	-- Speed (movement)
	local _, runSpeed, flightSpeed, swimSpeed = GetUnitSpeed("player")
	local baseSpeed = 7 -- Base speed
	local speedPercent = ((runSpeed / baseSpeed) - 1) * 100
	local speedRating = GetCombatRating(CR_SPEED)
	panel.stats.speed.value:SetText(string.format("%.0f%% (%d)", speedPercent, speedRating))

	-- Leech
	local leechPercent = GetLifesteal()
	local leechRating = GetCombatRating(CR_LIFESTEAL)
	panel.stats.leech.value:SetText(string.format("%.2f%% (%d)", leechPercent, leechRating))

	-- Avoidance
	local avoidancePercent = GetAvoidance()
	local avoidanceRating = GetCombatRating(CR_AVOIDANCE)
	panel.stats.avoidance.value:SetText(string.format("%.2f%% (%d)", avoidancePercent, avoidanceRating))
end

function E:CreateStatsPanel(parent)
	local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	panel:SetAllPoints(parent)

	-- Create simple backdrop
	E:CreateSimpleBackdrop(panel, 0.9)

	-- Character name
	local charName = panel:CreateFontString(nil, "OVERLAY")
	charName:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
	charName:SetPoint("TOP", panel, "TOP", 0, -10)
	charName:SetTextColor(1, 1, 1, 1)
	charName:SetText(UnitName("player"))
	panel.charName = charName

	-- Level and spec
	local levelSpec = panel:CreateFontString(nil, "OVERLAY")
	levelSpec:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	levelSpec:SetPoint("TOP", charName, "BOTTOM", 0, -4)
	levelSpec:SetTextColor(0.8, 0.8, 0.8, 1)

	local level = UnitLevel("player")
	local specIndex = GetSpecialization()
	local specName = specIndex and select(2, GetSpecializationInfo(specIndex)) or "No Spec"
	levelSpec:SetText(string.format("Level %d %s", level, specName))
	panel.levelSpec = levelSpec

	-- Divider
	local divider = panel:CreateTexture(nil, "ARTWORK")
	divider:SetColorTexture(0.3, 0.3, 0.3, 1)
	divider:SetHeight(1)
	divider:SetPoint("TOPLEFT", levelSpec, "BOTTOMLEFT", -20, -8)
	divider:SetPoint("TOPRIGHT", levelSpec, "BOTTOMRIGHT", 20, -8)

	-- Title
	local title = panel:CreateFontString(nil, "OVERLAY")
	title:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
	title:SetPoint("TOP", divider, "BOTTOM", 0, -10)
	title:SetTextColor(0, 1, 0, 1)
	title:SetText("Stats")
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
	panel.stats.stamina = CreateStatRow(panel, "Endurance", yOffset, {
		title = "Endurance",
		description = "Augmente les points de vie maximum de votre personnage. Chaque point d'endurance augmente vos PV d'environ 20."
	})
	yOffset = yOffset + rowHeight

	-- Separator
	yOffset = yOffset + rowHeight / 2

	-- Secondary Stats
	panel.stats.crit = CreateStatRow(panel, "Coup critique", yOffset, {
		title = "Coup critique",
		description = "Augmente les chances que vos attaques et sorts infligent des dégâts critiques (200% des dégâts normaux). Également utile pour le Heal."
	})
	yOffset = yOffset + rowHeight

	panel.stats.haste = CreateStatRow(panel, "Hâte", yOffset, {
		title = "Hâte",
		description = "Réduit le temps de recharge de vos sorts et augmente la vitesse d'attaque. Réduit également le temps de recharge global (GCD)."
	})
	yOffset = yOffset + rowHeight

	panel.stats.mastery = CreateStatRow(panel, "Maîtrise", yOffset, {
		title = "Maîtrise",
		description = "Bonus unique à votre spécialisation. L'effet varie selon votre classe et spé. Consultez votre livre de sorts pour les détails."
	})
	yOffset = yOffset + rowHeight

	panel.stats.versatility = CreateStatRow(panel, "Polyvalence", yOffset, {
		title = "Polyvalence",
		description = "Augmente tous les dégâts et soins infligés. Réduit également les dégâts subis. Stat équilibrée et toujours utile."
	})
	yOffset = yOffset + rowHeight

	-- Separator
	yOffset = yOffset + rowHeight / 2

	-- Tertiary Stats
	panel.stats.speed = CreateStatRow(panel, "Vitesse", yOffset, {
		title = "Vitesse",
		description = "Augmente votre vitesse de déplacement. N'affecte pas la vitesse de combat."
	})
	yOffset = yOffset + rowHeight

	panel.stats.leech = CreateStatRow(panel, "Ponction", yOffset, {
		title = "Ponction",
		description = "Restaure des points de vie en pourcentage des dégâts et soins effectués. Excellent pour la survie en solo."
	})
	yOffset = yOffset + rowHeight

	panel.stats.avoidance = CreateStatRow(panel, "Évitement", yOffset, {
		title = "Évitement",
		description = "Réduit les dégâts de zone (AoE) subis. Utile dans les donjons et raids avec beaucoup de dégâts de zone."
	})


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
