local _, ns = ...
local E = ns.E

-- ============================================================================
-- CURSOR TOOLTIP
-- Tooltip qui apparaît à la position de la souris
-- Utile pour afficher des infos supplémentaires au survol
-- ============================================================================

E.CursorTooltip = {}
local CursorTooltip = E.CursorTooltip

-- Create the cursor tooltip frame
local tooltip
local activeTicker  -- Store active animation ticker to cancel it if needed

local function CreateTooltip()
	if tooltip then return tooltip end

	-- Parent to NihuiParent for stable positioning hierarchy
	tooltip = CreateFrame("Frame", "NihuiOptimizerCursorTooltip", E.NihuiParent, "BackdropTemplate")
	tooltip:SetWidth(250)
	tooltip:SetHeight(60)  -- Will be adjusted dynamically
	tooltip:SetFrameStrata("TOOLTIP")
	tooltip:SetFrameLevel(500)  -- Higher than custom tooltip
	tooltip:Hide()

	-- Simple backdrop
	tooltip:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		tile = false,
		edgeSize = 1,
	})
	tooltip:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
	tooltip:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

	-- Title text
	tooltip.title = tooltip:CreateFontString(nil, "OVERLAY")
	tooltip.title:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
	tooltip.title:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 10, -8)
	tooltip.title:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT", -10, -8)
	tooltip.title:SetJustifyH("LEFT")
	tooltip.title:SetTextColor(1, 0.82, 0, 1)  -- Gold color
	tooltip.title:SetWordWrap(false)

	-- Description text (multiline)
	tooltip.description = tooltip:CreateFontString(nil, "OVERLAY")
	tooltip.description:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
	tooltip.description:SetPoint("TOPLEFT", tooltip.title, "BOTTOMLEFT", 0, -6)
	tooltip.description:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT", -10, -30)
	tooltip.description:SetJustifyH("LEFT")
	tooltip.description:SetTextColor(1, 1, 1, 1)
	tooltip.description:SetWordWrap(true)

	return tooltip
end

-- Show cursor tooltip at mouse position
-- @param title: Title text (yellow/gold)
-- @param description: Description text (white, multiline)
function CursorTooltip:Show(title, description)
	local tt = CreateTooltip()

	-- CRITICAL: Cancel any ongoing hide animation
	if activeTicker then
		activeTicker:Cancel()
		activeTicker = nil
	end

	-- Reset alpha to prepare for new fade in
	tt:SetAlpha(1)

	-- Set content
	tt.title:SetText(title or "")
	tt.description:SetText(description or "")

	-- Calculate height based on content
	local titleHeight = tt.title:GetStringHeight()
	local descHeight = tt.description:GetStringHeight()
	local calculatedHeight = 16 + titleHeight + 6 + descHeight + 10  -- Padding + title + spacing + desc + bottom padding

	tt:SetHeight(math.max(60, calculatedHeight))

	-- Position at cursor with smart offset
	-- NihuiParent now matches UIParent scale/size
	local x, y = GetCursorPosition()
	local scale = E.NihuiParent:GetEffectiveScale()
	x = x / scale
	y = y / scale

	-- Get screen dimensions from NihuiParent (matches UIParent)
	local screenWidth = E.NihuiParent:GetWidth()
	local screenHeight = E.NihuiParent:GetHeight()
	local ttWidth = tt:GetWidth()
	local ttHeight = tt:GetHeight()

	-- Smart positioning to avoid going off screen
	tt:ClearAllPoints()

	-- Smart positioning: offset from cursor to avoid covering it
	local offsetX = 15
	local offsetY = 15

	-- Check if tooltip would go off right edge
	if (x + offsetX + ttWidth) > screenWidth then
		-- Position to left of cursor
		offsetX = -(ttWidth + 15)
	end

	-- Check if tooltip would go off top edge
	if (y + offsetY + ttHeight) > screenHeight then
		-- Position below cursor
		offsetY = -(ttHeight + 15)
	end

	-- Position relative to NihuiParent (which fills WorldFrame)
	-- GetCursorPosition() with WorldFrame scale gives us correct coordinates
	tt:SetPoint("BOTTOMLEFT", E.NihuiParent, "BOTTOMLEFT", x + offsetX, y + offsetY)

	-- Fade in animation
	tt:SetAlpha(0)
	tt:Show()
	if E.Animations then
		E.Animations:FadeIn(tt, 0.15)
	else
		tt:SetAlpha(1)
	end

	print(string.format("[CursorTooltip] Shown at cursor: title='%s', height=%d", title or "", calculatedHeight))
end

-- Hide cursor tooltip
function CursorTooltip:Hide()
	if tooltip and tooltip:IsShown() then
		-- Cancel any existing ticker first
		if activeTicker then
			activeTicker:Cancel()
			activeTicker = nil
		end

		-- Quick fade out
		if E.Animations then
			local elapsed = 0
			local duration = 0.1
			local startAlpha = tooltip:GetAlpha()

			-- Store ticker in module-level variable so it can be cancelled from Show()
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
