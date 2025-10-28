local _, ns = ...
local E = ns.E

-- ============================================================================
-- CUSTOM TOOLTIP (Narcissus layout - EXACT reproduction)
-- ============================================================================

E.CustomTooltip = {}
local CustomTooltip = E.CustomTooltip

-- Create the custom tooltip frame
local tooltip
local activeTicker
local hideTimer
local ownerSlot

-- Helper functions to extract tooltip data (Narcissus method)
local C_TooltipInfo = C_TooltipInfo
local GetInfoByInventoryItem = C_TooltipInfo.GetInventoryItem

local function GetLineText(lines, index)
	if lines[index] and lines[index].leftText then
		return lines[index].leftText
	end
end

local function GetLineColor(lines, index)
	if lines[index] and lines[index].leftColor then
		return lines[index].leftColor
	end
end

local function CreateTooltip()
	if tooltip then return tooltip end

	-- Parent to NihuiParent for stable positioning hierarchy
	tooltip = CreateFrame("Frame", "NihuiOptimizerTooltip", E.NihuiParent, "BackdropTemplate")

	-- Dimensions (like Narcissus)
	local FRAME_WIDTH = 320
	local PADDING = 24  -- Like Narcissus
	local textWidth = FRAME_WIDTH - (2 * PADDING)  -- 272

	tooltip.frameWidth = FRAME_WIDTH
	tooltip.padding = PADDING
	tooltip.textWidth = textWidth

	tooltip:SetWidth(FRAME_WIDTH)
	tooltip:SetHeight(100)
	tooltip:SetFrameStrata("TOOLTIP")
	tooltip:SetFrameLevel(300)
	tooltip:EnableMouse(true)
	tooltip:Hide()

	-- Simple backdrop
	tooltip:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		tile = false,
		edgeSize = 1,
	})
	tooltip:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
	tooltip:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

	-- ====================
	-- HEADER (like Narcissus)
	-- ====================

	-- Item icon (TOP RIGHT like Narcissus!)
	tooltip.icon = tooltip:CreateTexture(nil, "ARTWORK")
	tooltip.icon:SetSize(48, 48)
	tooltip.icon:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT", -PADDING, -PADDING)
	tooltip.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	-- Item name (TOP LEFT)
	tooltip.name = tooltip:CreateFontString(nil, "OVERLAY")
	tooltip.name:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	tooltip.name:SetPoint("TOPLEFT", tooltip, "TOPLEFT", PADDING, -PADDING)
	tooltip.name:SetWidth(textWidth - 60)  -- Leave space for icon
	tooltip.name:SetJustifyH("LEFT")
	tooltip.name:SetTextColor(1, 1, 1, 1)

	-- Item level (under name)
	tooltip.ilvl = tooltip:CreateFontString(nil, "OVERLAY")
	tooltip.ilvl:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")  -- Big like Narcissus
	tooltip.ilvl:SetPoint("TOPLEFT", tooltip.name, "BOTTOMLEFT", 0, -2)
	tooltip.ilvl:SetTextColor(1, 1, 0, 1)

	-- Item context (next to ilvl, like "Éveillé Héroïque")
	tooltip.context = tooltip:CreateFontString(nil, "OVERLAY")
	tooltip.context:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
	tooltip.context:SetPoint("LEFT", tooltip.ilvl, "RIGHT", 8, -2)
	tooltip.context:SetTextColor(0, 1, 0, 1)  -- Green like Narcissus

	-- Item type/slot (under ilvl)
	tooltip.itemType = tooltip:CreateFontString(nil, "OVERLAY")
	tooltip.itemType:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
	tooltip.itemType:SetPoint("TOPLEFT", tooltip.ilvl, "BOTTOMLEFT", 0, -2)
	tooltip.itemType:SetTextColor(0.8, 0.8, 0.8, 1)

	-- ====================
	-- CONTENT AREA (stats + effects)
	-- ====================

	-- Content text (all stats and effects in ONE fontstring for simplicity)
	tooltip.contentText = tooltip:CreateFontString(nil, "OVERLAY")
	tooltip.contentText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")  -- Réduit à 9 pour plus de contenu
	tooltip.contentText:SetPoint("TOPLEFT", tooltip.itemType, "BOTTOMLEFT", 0, -12)
	tooltip.contentText:SetWidth(textWidth)
	tooltip.contentText:SetJustifyH("LEFT")
	tooltip.contentText:SetWordWrap(true)
	tooltip.contentText:SetNonSpaceWrap(true)
	tooltip.contentText:SetMaxLines(0)
	tooltip.contentText:SetSpacing(1)  -- Espacement réduit à 1 pour plus de densité

	-- ====================
	-- MOUSE INTERACTION
	-- ====================

	tooltip:SetScript("OnEnter", function(self)
		if hideTimer then
			hideTimer:Cancel()
			hideTimer = nil
		end
	end)

	tooltip:SetScript("OnLeave", function(self)
		if ownerSlot and MouseIsOver(ownerSlot) then
			return
		end

		if hideTimer then
			hideTimer:Cancel()
		end
		hideTimer = C_Timer.NewTimer(0.1, function()
			CustomTooltip:Hide()
		end)
	end)

	return tooltip
end

-- Calculate intelligent vertical position
local function GetVerticalPosition(slot, elementHeight)
	local slotX, slotY = slot:GetCenter()
	local screenHeight = UIParent:GetHeight()
	local slotHeight = slot:GetHeight()

	-- Calculate space available below and above the slot
	-- Note: y coordinate goes from 0 (bottom) to screenHeight (top)
	local spaceBelow = slotY - (slotHeight / 2)  -- Space from slot bottom to screen bottom
	local spaceAbove = screenHeight - (slotY + slotHeight / 2)  -- Space from slot top to screen top

	-- If tooltip is taller than space below, try opening upward
	if elementHeight > spaceBelow and spaceAbove > spaceBelow then
		return "up"
	else
		return "down"
	end
end

-- ============================================================================
-- STAT TO PERCENTAGE CONVERSION
-- ============================================================================

-- Mapping of French stat names to WoW rating constants
local STAT_TO_CONSTANT = {
	["Coup critique"] = CR_CRIT_MELEE,
	["Score de crit"] = CR_CRIT_MELEE,
	["Crit"] = CR_CRIT_MELEE,
	["Hâte"] = CR_HASTE_MELEE,
	["Maîtrise"] = CR_MASTERY,
	["Polyvalence"] = CR_VERSATILITY_DAMAGE_DONE,
	["Vitesse"] = CR_SPEED,
	["Ponction"] = CR_LIFESTEAL,
	["Évitement"] = CR_AVOIDANCE,
}

-- Extract stat value and name from a stat line
-- Example: "+392 Score de crit." -> 392, "Score de crit"
local function ExtractStatInfo(text)
	-- Match pattern: "+123 Stat Name" or "123 Stat Name"
	local value, statName = text:match("^%+?(%d+)%s+([^%.]+)")
	if value and statName then
		return tonumber(value), statName
	end
	return nil, nil
end

-- Calculate percentage from rating value
local function GetStatPercentage(statValue, statName)
	if not statValue or not statName then return nil end

	-- Find matching constant
	local constant = STAT_TO_CONSTANT[statName]
	if not constant then
		-- Try partial match (e.g., "Score de crit." matches "Score de crit")
		for name, const in pairs(STAT_TO_CONSTANT) do
			if statName:find(name, 1, true) then
				constant = const
				break
			end
		end
	end

	if not constant then return nil end

	-- Get current player's rating and percentage for this stat
	local currentRating = GetCombatRating(constant)
	local currentPercentage = GetCombatRatingBonus(constant)

	if not currentRating or currentRating == 0 then return nil end
	if not currentPercentage then return nil end

	-- Calculate ratio: percentage per rating point
	local ratioPerPoint = currentPercentage / currentRating

	-- Calculate percentage for the item's stat value
	local percentage = statValue * ratioPerPoint
	return percentage
end

-- ============================================================================
-- TOOLTIP DATA PARSING
-- ============================================================================

-- Parse tooltip data using C_TooltipInfo (Narcissus method)
local function ParseTooltipData(slotID)
	local tooltipData = GetInfoByInventoryItem("player", slotID)
	if not tooltipData or not tooltipData.lines then
		return nil, nil
	end

	local lines = tooltipData.lines
	local numLines = #lines
	local contentLines = {}
	local itemContext = nil

	-- Extract context/upgrade info (Narcissus method)
	-- Line 2: Check for context (e.g., "Heroic", special item category)
	if numLines >= 2 then
		local line2Text = GetLineText(lines, 2)
		-- Line 2 that doesn't end with a digit is context
		if line2Text and not line2Text:match("%d$") then
			itemContext = line2Text
		end
	end

	-- Lines 3-5: Check for upgradeString (e.g., "Éveillé Héroïque 4/8")
	-- This takes priority over simple context
	for i = 3, math.min(5, numLines) do
		local text = GetLineText(lines, i)
		if text and text:match("%d+/%d+") then
			-- Found upgrade string with "X/Y" pattern
			itemContext = text
			break
		end
	end

	-- Second pass: Get content (stats, effects, set bonuses)
	-- Start from line 3 to skip name/type/binds
	local skipNextLine = false  -- Flag to skip transmog item name

	for i = 3, numLines do
		local text = GetLineText(lines, i)
		local color = GetLineColor(lines, i)

		if text and text ~= "" and color then
			local r, g, b = color.r, color.g, color.b

			-- Check if this line is a transmog header (we'll skip the next line)
			local isTransmogHeader = text:match("^Transmogrification") or
			                         text:match("^Transmog") or
			                         text:match("^Apparence") or
			                         text:match("^Cosmetic") or
			                         text:match("^Cosmétique")

			-- Skip metadata and transmog lines (expanded list)
			local isMetadata = text:match("^Lié") or
			                   text:match("^Unique") or
			                   text:match("^Requires") or
			                   text:match("^Niveau requis") or
			                   text:match("^Durability") or
			                   text:match("^Durabilité") or
			                   text:match("^Classes:") or
			                   text:match("^Classes :") or
			                   text:match("^Races:") or
			                   text:match("^Races :") or
			                   text:match("Sell Price:") or
			                   text:match("Prix de vente :") or
			                   isTransmogHeader or
			                   skipNextLine or  -- Skip this line if previous was transmog header
			                   text:match("^Item Level") or
			                   text:match("^Niveau d'objet") or
			                   text:match("^Niveau d'amélioration") or  -- Don't show upgrade level in content (shown in context)
			                   text:match("^Upgrade Level") or
			                   text:match("^%<") or  -- Skip lines starting with < (like <Shift Right Click to Socket>)
			                   (itemContext and text == itemContext)  -- Skip context text if already extracted

			-- Set flag for next iteration if this was a transmog header
			if isTransmogHeader then
				skipNextLine = true
			else
				skipNextLine = false
			end

			if not isMetadata then
				-- Format with original colors from tooltip
				local colorCode
				local finalText = text

				-- Green (effects, set bonuses, equipped set pieces, STATS)
				if g > 0.9 and r < 0.1 and b < 0.1 then
					colorCode = "|cff00ff00"  -- Pure green

					-- Try to extract stat value and add percentage
					local statValue, statName = ExtractStatInfo(text)
					if statValue and statName then
						local percentage = GetStatPercentage(statValue, statName)
						if percentage then
							-- Add percentage in slightly dimmed green
							finalText = text .. " |cff88ff88(" .. string.format("%.2f%%", percentage) .. ")|r"
						end
					end

				-- Yellow (set name with counter)
				elseif r > 0.9 and g > 0.7 and b < 0.2 then
					colorCode = "|cffffff00"  -- Yellow
				-- Gray (unequipped set pieces)
				elseif r > 0.4 and r < 0.6 and math.abs(r - g) < 0.05 and math.abs(g - b) < 0.05 then
					colorCode = "|cff808080"  -- Gray
				-- White/default (stats)
				else
					colorCode = "|cffffffff"
				end

				table.insert(contentLines, colorCode .. finalText .. "|r")
			end
		end
	end

	return table.concat(contentLines, "\n"), itemContext
end

-- Show tooltip for equipped item slot
function CustomTooltip:ShowForSlot(slot)
	local tt = CreateTooltip()
	ownerSlot = slot

	if slot.hasItem then
		-- Get item info
		local itemLocation = ItemLocation:CreateFromEquipmentSlot(slot.slotID)
		local itemLink = C_Item.GetItemLink(itemLocation)
		local itemName = C_Item.GetItemName(itemLocation)
		local itemIcon = C_Item.GetItemIcon(itemLocation)
		local itemLevel = C_Item.GetCurrentItemLevel(itemLocation)
		local quality = C_Item.GetItemQuality(itemLocation)

		-- Set header info
		tt.icon:SetTexture(itemIcon)
		tt.name:SetText(itemName or slot.slotName)
		tt.ilvl:SetText(itemLevel or "")

		-- Set quality color
		if quality then
			local r, g, b = C_Item.GetItemQualityColor(quality)
			tt.name:SetTextColor(r, g, b, 1)
		end

		-- Set item type/slot (like "Shoulder · Tissu")
		tt.itemType:SetText(slot.slotName)

		-- Parse and display content (stats + effects)
		local content, itemContext = ParseTooltipData(slot.slotID)
		tt.contentText:SetText(content or "")

		-- Set context (like "Éveillé Héroïque")
		if itemContext then
			tt.context:SetText(itemContext)
			tt.context:Show()
		else
			tt.context:SetText("")
			tt.context:Hide()
		end

		-- Calculate height
		local headerHeight = 24 + 24 + 10 + 12  -- padding + name + ilvl + type + spacing
		local contentHeight = tt.contentText:GetStringHeight()
		local totalHeight = headerHeight + contentHeight + tt.padding * 2

		tt:SetHeight(totalHeight)
	else
		-- Empty slot
		tt.icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
		tt.name:SetText(slot.slotName)
		tt.name:SetTextColor(1, 1, 1, 1)
		tt.ilvl:SetText("")
		tt.context:SetText("")
		tt.context:Hide()
		tt.itemType:SetText("Empty slot")
		tt.contentText:SetText("")
		tt:SetHeight(120)
	end

	-- Position tooltip
	local verticalPos = GetVerticalPosition(slot, tt:GetHeight())

	tt:ClearAllPoints()
	if slot.side == "left" then
		if verticalPos == "up" then
			tt:SetPoint("BOTTOMLEFT", slot, "TOPRIGHT", 8, 0)
		else
			tt:SetPoint("TOPLEFT", slot, "TOPRIGHT", 8, 0)
		end
	else
		if verticalPos == "up" then
			tt:SetPoint("BOTTOMRIGHT", slot, "TOPLEFT", -8, 0)
		else
			tt:SetPoint("TOPRIGHT", slot, "TOPLEFT", -8, 0)
		end
	end

	-- Cancel animations/timers
	if activeTicker then
		activeTicker:Cancel()
		activeTicker = nil
	end
	if hideTimer then
		hideTimer:Cancel()
		hideTimer = nil
	end

	-- Fade in
	tt:SetAlpha(0)
	tt:Show()
	if E.Animations then
		E.Animations:FadeIn(tt, 0.15)
	else
		tt:SetAlpha(1)
	end
end

-- Cancel hide timer
function CustomTooltip:CancelHide()
	if hideTimer then
		hideTimer:Cancel()
		hideTimer = nil
	end
end

-- Schedule hide with delay
function CustomTooltip:ScheduleHide()
	if tooltip and MouseIsOver(tooltip) then
		return
	end

	if hideTimer then
		hideTimer:Cancel()
	end
	hideTimer = C_Timer.NewTimer(0.1, function()
		CustomTooltip:Hide()
	end)
end

-- Hide tooltip
function CustomTooltip:Hide()
	if activeTicker then
		activeTicker:Cancel()
		activeTicker = nil
	end
	if hideTimer then
		hideTimer:Cancel()
		hideTimer = nil
	end

	ownerSlot = nil

	if tooltip and tooltip:IsShown() then
		if E.Animations then
			local elapsed = 0
			local duration = 0.1
			local startAlpha = tooltip:GetAlpha()

			activeTicker = C_Timer.NewTicker(0.01, function()
				elapsed = elapsed + 0.01
				local progress = math.min(elapsed / duration, 1)
				local alpha = startAlpha * (1 - progress)

				tooltip:SetAlpha(alpha)

				if progress >= 1 then
					if activeTicker then
						activeTicker:Cancel()
						activeTicker = nil
					end
					tooltip:Hide()
					tooltip:SetAlpha(1)
				end
			end)
		else
			tooltip:Hide()
		end
	end
end
