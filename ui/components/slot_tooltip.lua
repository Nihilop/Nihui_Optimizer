local _, ns = ...
local E = ns.E

-- ============================================================================
-- SLOT TOOLTIP - Modern sliding tooltip for equipment slots
-- ============================================================================
-- Features:
-- - Single reusable frame (performance)
-- - Smooth slide animations between slots
-- - Intelligent positioning (opens up/down based on available space)
-- - Adaptive height based on content
-- - Content fade transitions
-- - Interactive (can move cursor into tooltip)
-- ============================================================================

E.SlotTooltip = {}
local SlotTooltip = E.SlotTooltip

-- State management
local tooltip = nil
local activeSlot = nil
local currentSide = nil       -- "left" or "right"
local contentTicker = nil     -- For content fade animations
local slideTicker = nil       -- For slide animations
local hideTicker = nil        -- For delayed hide
local isTransitioning = false -- Prevent animation conflicts

-- Animation timings (carefully tuned for smooth UX)
local TIMING = {
	slideSpeed = 0.16,      -- Slide between slots (visible slide)
	contentFadeOut = 0.04,  -- Content disappears (micro fade)
	contentFadeIn = 0.06,   -- Content appears (micro fade)
	hideDelay = 0.2,        -- Delay before auto-hide
	firstShowSlide = 0.12,  -- First appearance slide
}

-- ============================================================================
-- HELPER: Parse tooltip data (same as custom_tooltip.lua for now)
-- ============================================================================

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
local function ExtractStatInfo(text)
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
		for name, const in pairs(STAT_TO_CONSTANT) do
			if statName:find(name, 1, true) then
				constant = const
				break
			end
		end
	end

	if not constant then return nil end

	-- Get current player's rating and percentage
	local currentRating = GetCombatRating(constant)
	local currentPercentage = GetCombatRatingBonus(constant)

	if not currentRating or currentRating == 0 then return nil end
	if not currentPercentage then return nil end

	-- Calculate percentage for item's stat value
	local ratioPerPoint = currentPercentage / currentRating
	local percentage = statValue * ratioPerPoint
	return percentage
end

-- Parse tooltip data with percentage support
local function ParseTooltipContent(slotID)
	local tooltipData = GetInfoByInventoryItem("player", slotID)
	if not tooltipData or not tooltipData.lines then
		return {}
	end

	local lines = tooltipData.lines
	local numLines = #lines
	local contentLines = {}
	local skipNextLine = false

	-- Start from line 3 to skip name/type/binds
	for i = 3, numLines do
		local text = GetLineText(lines, i)
		local color = GetLineColor(lines, i)

		if text and text ~= "" and color then
			local r, g, b = color.r, color.g, color.b

			-- Check transmog header
			local isTransmogHeader = text:match("^Transmogrification") or
			                         text:match("^Transmog") or
			                         text:match("^Apparence")

			-- Skip metadata
			local isMetadata = text:match("^Lié") or
			                   text:match("^Unique") or
			                   text:match("^Requires") or
			                   text:match("^Niveau requis") or
			                   text:match("^Durability") or
			                   text:match("^Durabilité") or
			                   text:match("^Classes:") or
			                   text:match("^Races:") or
			                   text:match("Sell Price:") or
			                   text:match("Prix de vente :") or
			                   isTransmogHeader or
			                   skipNextLine or
			                   text:match("^Item Level") or
			                   text:match("^Niveau d'objet") or
			                   text:match("^%<")

			if isTransmogHeader then
				skipNextLine = true
			else
				skipNextLine = false
			end

			if not isMetadata then
				local colorCode
				local finalText = text

				-- Green (stats with percentages)
				if g > 0.9 and r < 0.1 and b < 0.1 then
					colorCode = "|cff00ff00"
					local statValue, statName = ExtractStatInfo(text)
					if statValue and statName then
						local percentage = GetStatPercentage(statValue, statName)
						if percentage then
							finalText = text .. " |cff88ff88(" .. string.format("%.2f%%", percentage) .. ")|r"
						end
					end
				-- Yellow
				elseif r > 0.9 and g > 0.7 and b < 0.2 then
					colorCode = "|cffffff00"
				-- Gray
				elseif r > 0.4 and r < 0.6 and math.abs(r - g) < 0.05 then
					colorCode = "|cff808080"
				-- White/default
				else
					colorCode = "|cffffffff"
				end

				table.insert(contentLines, colorCode .. finalText .. "|r")
			end
		end
	end

	return contentLines
end

-- ============================================================================
-- CREATE TOOLTIP FRAME (once, reused forever)
-- ============================================================================

local function CreateTooltipFrame()
	if tooltip then return tooltip end

	-- Parent to NihuiParent for stable positioning
	local frame = CreateFrame("Frame", "NihuiOptimizerSlotTooltip", E.NihuiParent, "BackdropTemplate")

	-- Dimensions (similar to custom_tooltip)
	local FRAME_WIDTH = 320
	local PADDING = 24

	frame:SetWidth(FRAME_WIDTH)
	frame:SetHeight(100)  -- Will be adjusted dynamically
	frame:SetFrameStrata("TOOLTIP")
	frame:SetFrameLevel(300)
	frame:EnableMouse(true)  -- CRITICAL: Can hover the tooltip
	frame:SetClipsChildren(true)  -- OVERFLOW: HIDDEN - Clips content that overflows during animations
	frame:Hide()

	-- Backdrop
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		tile = false,
		edgeSize = 1,
	})
	frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
	frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

	-- Header: Item icon (top right)
	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetSize(48, 48)
	frame.icon:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, -PADDING)
	frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	-- Header: Item name (top left)
	frame.name = frame:CreateFontString(nil, "OVERLAY")
	frame.name:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	frame.name:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -PADDING)
	frame.name:SetWidth(FRAME_WIDTH - 60 - (2 * PADDING))
	frame.name:SetJustifyH("LEFT")

	-- Header: Item level (under name)
	frame.ilvl = frame:CreateFontString(nil, "OVERLAY")
	frame.ilvl:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
	frame.ilvl:SetPoint("TOPLEFT", frame.name, "BOTTOMLEFT", 0, -2)
	frame.ilvl:SetTextColor(1, 1, 0, 1)

	-- Header: Item type/slot (under ilvl)
	frame.itemType = frame:CreateFontString(nil, "OVERLAY")
	frame.itemType:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
	frame.itemType:SetPoint("TOPLEFT", frame.ilvl, "BOTTOMLEFT", 0, -2)
	frame.itemType:SetTextColor(0.8, 0.8, 0.8, 1)

	-- Separator line
	frame.separator = frame:CreateTexture(nil, "ARTWORK")
	frame.separator:SetColorTexture(0.3, 0.3, 0.3, 1)
	frame.separator:SetHeight(1)
	frame.separator:SetPoint("TOPLEFT", frame.itemType, "BOTTOMLEFT", -PADDING, -8)
	frame.separator:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, -95)

	-- Content area (stats + effects)
	frame.content = frame:CreateFontString(nil, "OVERLAY")
	frame.content:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
	frame.content:SetPoint("TOPLEFT", frame.separator, "BOTTOMLEFT", PADDING, -8)
	frame.content:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, -105)
	frame.content:SetJustifyH("LEFT")
	frame.content:SetJustifyV("TOP")
	frame.content:SetSpacing(2)
	frame.content:SetNonSpaceWrap(false)
	frame.content:SetWordWrap(true)

	-- Content container (for fade animations)
	frame.contentContainer = CreateFrame("Frame", nil, frame)
	frame.contentContainer:SetAllPoints(frame.content)
	frame.content:SetParent(frame.contentContainer)

	-- OnEnter: Cancel scheduled hide
	frame:SetScript("OnEnter", function(self)
		SlotTooltip:CancelHide()
	end)

	-- OnLeave: Schedule hide
	frame:SetScript("OnLeave", function(self)
		if not MouseIsOver(activeSlot) then
			SlotTooltip:ScheduleHide()
		end
	end)

	tooltip = frame
	return frame
end

-- ============================================================================
-- POSITION CALCULATION
-- ============================================================================

-- Get anchor point for tooltip based on slot side AND vertical space
-- Slots on left → tooltip on right
-- Slots on right → tooltip on left
-- Top of screen → grow downward (TOPLEFT/TOPRIGHT)
-- Bottom of screen → grow upward (BOTTOMLEFT/BOTTOMRIGHT)
local function GetAnchorForSlot(slot)
	local slotX, slotY = slot:GetCenter()
	local screenHeight = WorldFrame:GetHeight()
	local tooltipHeight = tooltip:GetHeight()

	-- Calculate space available
	local spaceBelow = slotY
	local spaceAbove = screenHeight - slotY

	-- Determine vertical anchor (grow up or down)
	local useBottom = (tooltipHeight > spaceBelow and spaceAbove > spaceBelow)

	-- Horizontal anchor based on slot side
	if slot.side == "left" then
		-- Tooltip on RIGHT of slot
		if useBottom then
			return "BOTTOMLEFT", slot, "BOTTOMRIGHT", 5, 0
		else
			return "TOPLEFT", slot, "TOPRIGHT", 5, 0
		end
	else
		-- Tooltip on LEFT of slot
		if useBottom then
			return "BOTTOMRIGHT", slot, "BOTTOMLEFT", -5, 0
		else
			return "TOPRIGHT", slot, "TOPLEFT", -5, 0
		end
	end
end

-- ============================================================================
-- CONTENT UPDATE
-- ============================================================================

function SlotTooltip:UpdateContent(slot)
	local frame = CreateTooltipFrame()
	local PADDING = 24

	-- Check if slot has an item
	if slot.hasItem then
		-- CASE: Slot with item
		local itemLocation = ItemLocation:CreateFromEquipmentSlot(slot.slotID)
		local itemLink = C_Item.GetItemLink(itemLocation)
		local itemName = C_Item.GetItemName(itemLocation)
		local itemIcon = C_Item.GetItemIcon(itemLocation)
		local itemLevel = C_Item.GetCurrentItemLevel(itemLocation)
		local quality = C_Item.GetItemQuality(itemLocation)

		-- Update header
		frame.icon:SetTexture(itemIcon)
		frame.name:SetText(itemName or slot.slotName)
		frame.ilvl:SetText(itemLevel or "")
		frame.itemType:SetText(slot.slotName)

		-- Set quality color
		if quality then
			local r, g, b = C_Item.GetItemQualityColor(quality)
			frame.name:SetTextColor(r, g, b, 1)
		end

		-- Parse and set content
		local contentLines = ParseTooltipContent(slot.slotID)
		frame.content:SetText(table.concat(contentLines, "\n"))

	else
		-- CASE: Empty slot - show slot info
		-- Use generic empty slot icon
		frame.icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")

		-- Slot name as title
		frame.name:SetText(slot.slotName)
		frame.name:SetTextColor(0.7, 0.7, 0.7, 1)  -- Gray for empty

		-- No ilvl for empty slots
		frame.ilvl:SetText("")

		-- Type (same as slot name)
		frame.itemType:SetText("Emplacement d'équipement")

		-- Empty message
		frame.content:SetText("|cff808080Aucun objet équipé|r\n\n|cffffffffCliquez pour parcourir les objets disponibles.|r")
	end

	-- Calculate and set height
	local contentHeight = frame.content:GetStringHeight()
	local totalHeight = PADDING + 48 + 8 + contentHeight + PADDING + 20
	frame:SetHeight(math.max(120, totalHeight))
end

-- ============================================================================
-- ANIMATIONS
-- ============================================================================

-- Cancel all active animations
function SlotTooltip:CancelAnimations()
	if contentTicker then
		contentTicker:Cancel()
		contentTicker = nil
	end
	if slideTicker then
		slideTicker:Cancel()
		slideTicker = nil
	end
	if hideTicker then
		hideTicker:Cancel()
		hideTicker = nil
	end

	-- Reset content container to visible (in case animation was interrupted)
	if tooltip and tooltip.contentContainer then
		tooltip.contentContainer:SetAlpha(1)
	end

	isTransitioning = false
end

-- Fade out content with callback
function SlotTooltip:FadeOutContent(callback)
	local frame = CreateTooltipFrame()

	-- Cancel existing content animation
	if contentTicker then
		contentTicker:Cancel()
	end

	local elapsed = 0
	local duration = TIMING.contentFadeOut
	local startAlpha = frame.contentContainer:GetAlpha()

	contentTicker = C_Timer.NewTicker(0.01, function()
		elapsed = elapsed + 0.01
		local progress = math.min(elapsed / duration, 1)
		local alpha = startAlpha * (1 - progress)

		frame.contentContainer:SetAlpha(alpha)

		if progress >= 1 then
			if contentTicker then
				contentTicker:Cancel()
				contentTicker = nil
			end
			if callback then callback() end
		end
	end)
end

-- Fade in content
function SlotTooltip:FadeInContent()
	local frame = CreateTooltipFrame()

	-- Cancel existing content animation
	if contentTicker then
		contentTicker:Cancel()
	end

	local elapsed = 0
	local duration = TIMING.contentFadeIn

	contentTicker = C_Timer.NewTicker(0.01, function()
		elapsed = elapsed + 0.01
		local progress = math.min(elapsed / duration, 1)
		local alpha = progress

		frame.contentContainer:SetAlpha(alpha)

		if progress >= 1 then
			if contentTicker then
				contentTicker:Cancel()
				contentTicker = nil
			end
		end
	end)
end

-- Slide tooltip to new slot position (VISIBLE slide with HEIGHT animation)
function SlotTooltip:SlideToSlot(newSlot, oldHeight, newHeight, callback)
	local frame = CreateTooltipFrame()

	-- Cancel existing slide
	if slideTicker then
		slideTicker:Cancel()
		slideTicker = nil
	end

	-- Get start position (current)
	local startX, startY = frame:GetCenter()
	if not startX or not startY then
		-- First show, position instantly
		frame:ClearAllPoints()
		local point, relativeTo, relativePoint, xOfs, yOfs = GetAnchorForSlot(newSlot)
		frame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
		if callback then callback() end
		return
	end

	-- Get end position (new slot)
	frame:ClearAllPoints()
	local point, relativeTo, relativePoint, xOfs, yOfs = GetAnchorForSlot(newSlot)
	frame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
	local endX, endY = frame:GetCenter()

	-- Calculate deltas
	local deltaX = endX - startX
	local deltaY = endY - startY
	local deltaHeight = newHeight - oldHeight

	-- Reset to start position and height
	frame:SetHeight(oldHeight)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", E.NihuiParent, "BOTTOMLEFT", startX, startY)

	-- Animate slide + height change simultaneously
	local elapsed = 0
	local duration = TIMING.slideSpeed

	slideTicker = C_Timer.NewTicker(0.01, function()
		elapsed = elapsed + 0.01
		local progress = math.min(elapsed / duration, 1)

		-- Easing (smooth ease out)
		local easedProgress = 1 - (1 - progress) * (1 - progress)  -- EaseOutQuad

		-- Interpolate position
		local currentX = startX + (deltaX * easedProgress)
		local currentY = startY + (deltaY * easedProgress)

		-- Interpolate height (SMOOTH resize!)
		local currentHeight = oldHeight + (deltaHeight * easedProgress)
		frame:SetHeight(currentHeight)

		frame:ClearAllPoints()
		frame:SetPoint("CENTER", E.NihuiParent, "BOTTOMLEFT", currentX, currentY)

		if progress >= 1 then
			if slideTicker then
				slideTicker:Cancel()
				slideTicker = nil
			end

			-- Snap to final anchor point and height
			frame:SetHeight(newHeight)
			frame:ClearAllPoints()
			frame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)

			if callback then callback() end
		end
	end)
end

-- ============================================================================
-- SHOW/HIDE
-- ============================================================================

function SlotTooltip:Show(slot)
	if not slot then return end

	-- Cancel any scheduled hide
	self:CancelHide()

	local frame = CreateTooltipFrame()

	-- CASE 1: First show (no active slot)
	if not activeSlot or not frame:IsShown() then
		-- Update content immediately
		self:UpdateContent(slot)

		-- Position at slot
		frame:ClearAllPoints()
		local point, relativeTo, relativePoint, xOfs, yOfs = GetAnchorForSlot(slot)
		frame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)

		-- Show with fade in
		frame:SetAlpha(0)
		frame:Show()

		if E.Animations then
			E.Animations:FadeIn(frame, TIMING.firstShowSlide)
		else
			frame:SetAlpha(1)
		end

		activeSlot = slot
		currentSide = slot.side

		print(string.format("[SlotTooltip] First show for slot: %s (side: %s)", slot.slotName, slot.side))

	-- CASE 2: Transition to different slot
	elseif activeSlot ~= slot then
		if isTransitioning then
			-- Already transitioning, force complete previous and start fresh
			self:CancelAnimations()
			frame.contentContainer:SetAlpha(1)  -- Reset content visibility
		end

		isTransitioning = true

		print(string.format("[SlotTooltip] Transition from %s to %s", activeSlot.slotName, slot.slotName))

		-- Orchestrate: fade out → update → slide (with height anim) + fade in
		-- 1. Fade out current content (micro fade)
		self:FadeOutContent(function()
			-- 2. Capture old height BEFORE updating content
			local oldHeight = frame:GetHeight()

			-- 3. Update content while invisible (this calculates new height)
			self:UpdateContent(slot)

			-- 4. Capture new height AFTER update
			local newHeight = frame:GetHeight()

			-- 5. Start slide with HEIGHT animation AND fade in simultaneously
			frame.contentContainer:SetAlpha(0)  -- Ensure invisible before fade in

			self:SlideToSlot(slot, oldHeight, newHeight, function()
				-- Slide complete
				isTransitioning = false
			end)

			-- Start fade in immediately (parallel to slide)
			C_Timer.After(0.02, function()  -- Tiny delay to ensure content is set
				self:FadeInContent()
			end)
		end)

		activeSlot = slot
		currentSide = slot.side

	-- CASE 3: Same slot (do nothing)
	else
		print("[SlotTooltip] Same slot, ignoring")
	end
end

function SlotTooltip:ScheduleHide()
	-- Cancel existing hide timer
	if hideTicker then
		hideTicker:Cancel()
	end

	-- Schedule hide
	hideTicker = C_Timer.NewTimer(TIMING.hideDelay, function()
		self:Hide()
		hideTicker = nil
	end)
end

function SlotTooltip:CancelHide()
	if hideTicker then
		hideTicker:Cancel()
		hideTicker = nil
	end
end

function SlotTooltip:Hide()
	if not tooltip or not tooltip:IsShown() then return end

	-- Cancel animations
	self:CancelAnimations()

	-- Manual fade out (no E.Animations:FadeOut)
	local elapsed = 0
	local duration = 0.1
	local startAlpha = tooltip:GetAlpha()

	local fadeTicker
	fadeTicker = C_Timer.NewTicker(0.01, function()
		elapsed = elapsed + 0.01
		local progress = math.min(elapsed / duration, 1)
		local alpha = startAlpha * (1 - progress)

		tooltip:SetAlpha(alpha)

		if progress >= 1 then
			if fadeTicker then
				fadeTicker:Cancel()
			end
			tooltip:Hide()
			tooltip:SetAlpha(1)  -- Reset for next show
			activeSlot = nil
			currentSide = nil
		end
	end)

	print("[SlotTooltip] Hiding")
end
