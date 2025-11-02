local _, ns = ...
local E = ns.E

-- ========================================
-- STATS PANEL CONFIG (Minimal Modern Style)
-- ========================================
local CONFIG = {
	-- Gradient settings (transparent left → black right)
	gradient = {
		enabled = true,
		startAlpha = 0.0,   -- Fully transparent on left
		endAlpha = 0.85,    -- Dark on right (85% opacity)
		startOffset = 0.3,  -- Start gradient at 30% from left
	},

	-- Font settings
	fonts = {
		statLabel = {font = "Fonts\\FRIZQT__.TTF", size = 13, flags = ""},
		statValue = {font = "Fonts\\FRIZQT__.TTF", size = 13, flags = "OUTLINE"},
		sectionTitle = {font = "Fonts\\FRIZQT__.TTF", size = 11, flags = ""},
	},

	-- Colors
	colors = {
		statLabel = {0.7, 0.7, 0.7, 1},
		statValue = {1, 1, 1, 1},
		sectionTitle = {0, 1, 0, 0.6},  -- Nihui green, subtle
	},

	-- Spacing
	spacing = {
		topMargin = 20,
		rowHeight = 24,
		sectionGap = 12,  -- Extra gap between sections
		leftPadding = 20,
		rightPadding = 20,
	},
}

-- Create a stat row (minimal style - no background)
local function CreateStatRow(parent, label, yOffset, tooltipInfo)
	local row = CreateFrame("Frame", nil, parent)
	-- Use anchors instead of fixed width for responsiveness
	row:SetHeight(CONFIG.spacing.rowHeight)
	row:SetPoint("LEFT", parent, "LEFT", CONFIG.spacing.leftPadding, 0)
	row:SetPoint("RIGHT", parent, "RIGHT", -CONFIG.spacing.rightPadding, 0)
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
	labelText:SetFont(CONFIG.fonts.statLabel.font, CONFIG.fonts.statLabel.size, CONFIG.fonts.statLabel.flags)
	labelText:SetPoint("LEFT", row, "LEFT", 0, 0)
	labelText:SetTextColor(unpack(CONFIG.colors.statLabel))
	labelText:SetText(label)
	row.label = labelText

	local valueText = row:CreateFontString(nil, "OVERLAY")
	valueText:SetFont(CONFIG.fonts.statValue.font, CONFIG.fonts.statValue.size, CONFIG.fonts.statValue.flags)
	valueText:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	valueText:SetTextColor(unpack(CONFIG.colors.statValue))
	row.value = valueText

	return row
end

-- Create a section separator (subtle line)
local function CreateSectionTitle(parent, yOffset, title)
	local section = CreateFrame("Frame", nil, parent)
	section:SetHeight(16)
	section:SetPoint("LEFT", parent, "LEFT", CONFIG.spacing.leftPadding, 0)
	section:SetPoint("RIGHT", parent, "RIGHT", -CONFIG.spacing.rightPadding, 0)
	section:SetPoint("TOP", parent, "TOP", 0, yOffset)

	-- Subtle line
	local line = section:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(unpack(CONFIG.colors.sectionTitle))
	line:SetHeight(1)
	line:SetPoint("LEFT", section, "LEFT", 0, 0)
	line:SetPoint("RIGHT", section, "RIGHT", 0, 0)

	-- Optional: section title text (if you want labels like "Secondary Stats")
	if title then
		local text = section:CreateFontString(nil, "OVERLAY")
		text:SetFont(CONFIG.fonts.sectionTitle.font, CONFIG.fonts.sectionTitle.size, CONFIG.fonts.sectionTitle.flags)
		text:SetPoint("LEFT", section, "LEFT", 0, -8)
		text:SetTextColor(unpack(CONFIG.colors.sectionTitle))
		text:SetText(title)
		text:SetAlpha(0.6)
	end

	return section
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
	local panel = CreateFrame("Frame", nil, parent)
	-- Match parent width, but height will be set dynamically
	panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

	print("[StatsPanel] Creating stats panel, parent:", parent:GetName() or "anonymous")

	-- Create gradient background (transparent → black)
	if CONFIG.gradient.enabled then
		local gradient = panel:CreateTexture(nil, "BACKGROUND")
		gradient:SetAllPoints(panel)

		-- Create gradient effect (horizontal: transparent left → dark right)
		-- Note: SetGradient uses RGB + alpha separately in some WoW versions
		gradient:SetGradient("HORIZONTAL",
			{r = 0, g = 0, b = 0, a = CONFIG.gradient.startAlpha},  -- Left: transparent
			{r = 0, g = 0, b = 0, a = CONFIG.gradient.endAlpha}     -- Right: dark
		)

		print(string.format("[StatsPanel] Gradient created: startAlpha=%.2f, endAlpha=%.2f",
			CONFIG.gradient.startAlpha, CONFIG.gradient.endAlpha))
	end

	-- Calculate content height dynamically
	local yOffset = -CONFIG.spacing.topMargin
	local rowHeight = CONFIG.spacing.rowHeight

	-- Create stat rows
	panel.stats = {}

	-- PRIMARY STATS (no section title, just stats)
	panel.stats.ilvl = CreateStatRow(panel, "Item Level", yOffset)
	yOffset = yOffset - rowHeight

	panel.stats.primary = CreateStatRow(panel, "Primary Stat", yOffset)
	yOffset = yOffset - rowHeight

	panel.stats.stamina = CreateStatRow(panel, "Endurance", yOffset, {
		title = "Endurance",
		description = "Augmente les points de vie maximum de votre personnage. Chaque point d'endurance augmente vos PV d'environ 20."
	})
	yOffset = yOffset - rowHeight

	-- Section separator
	yOffset = yOffset - CONFIG.spacing.sectionGap
	CreateSectionTitle(panel, yOffset, nil)  -- No title, just a line
	yOffset = yOffset - 16

	-- SECONDARY STATS
	panel.stats.crit = CreateStatRow(panel, "Coup critique", yOffset, {
		title = "Coup critique",
		description = "Augmente les chances que vos attaques et sorts infligent des dégâts critiques (200% des dégâts normaux). Également utile pour le Heal."
	})
	yOffset = yOffset - rowHeight

	panel.stats.haste = CreateStatRow(panel, "Hâte", yOffset, {
		title = "Hâte",
		description = "Réduit le temps de recharge de vos sorts et augmente la vitesse d'attaque. Réduit également le temps de recharge global (GCD)."
	})
	yOffset = yOffset - rowHeight

	panel.stats.mastery = CreateStatRow(panel, "Maîtrise", yOffset, {
		title = "Maîtrise",
		description = "Bonus unique à votre spécialisation. L'effet varie selon votre classe et spé. Consultez votre livre de sorts pour les détails."
	})
	yOffset = yOffset - rowHeight

	panel.stats.versatility = CreateStatRow(panel, "Polyvalence", yOffset, {
		title = "Polyvalence",
		description = "Augmente tous les dégâts et soins infligés. Réduit également les dégâts subis. Stat équilibrée et toujours utile."
	})
	yOffset = yOffset - rowHeight

	-- Section separator
	yOffset = yOffset - CONFIG.spacing.sectionGap
	CreateSectionTitle(panel, yOffset, nil)
	yOffset = yOffset - 16

	-- TERTIARY STATS
	panel.stats.speed = CreateStatRow(panel, "Vitesse", yOffset, {
		title = "Vitesse",
		description = "Augmente votre vitesse de déplacement. N'affecte pas la vitesse de combat."
	})
	yOffset = yOffset - rowHeight

	panel.stats.leech = CreateStatRow(panel, "Ponction", yOffset, {
		title = "Ponction",
		description = "Restaure des points de vie en pourcentage des dégâts et soins effectués. Excellent pour la survie en solo."
	})
	yOffset = yOffset - rowHeight

	panel.stats.avoidance = CreateStatRow(panel, "Évitement", yOffset, {
		title = "Évitement",
		description = "Réduit les dégâts de zone (AoE) subis. Utile dans les donjons et raids avec beaucoup de dégâts de zone."
	})
	yOffset = yOffset - rowHeight

	-- Set panel height to fit content exactly
	local contentHeight = math.abs(yOffset) + CONFIG.spacing.topMargin
	panel:SetHeight(contentHeight)

	-- CRITICAL: Set parent (statsFrame) height to match content
	-- Without this, statsFrame has height=0 and nothing is visible!
	parent:SetHeight(contentHeight)

	-- Make sure panel is shown (needed for animation)
	panel:Show()

	print(string.format("[StatsPanel] Panel created: width=%.0f, height=%.0f, alpha=%.2f, shown=%s",
		panel:GetWidth(), contentHeight, panel:GetAlpha(), tostring(panel:IsShown())))
	print(string.format("[StatsPanel] Parent frame: width=%.0f, height=%.0f",
		parent:GetWidth(), parent:GetHeight()))

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
