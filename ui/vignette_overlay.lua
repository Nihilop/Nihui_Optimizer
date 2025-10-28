local _, ns = ...
local E = ns.E

-- ============================================================================
-- VIGNETTE OVERLAY
-- Edge darkening effect like Narcissus (not full screen black)
-- ============================================================================

E.VignetteOverlay = {}
local VignetteOverlay = E.VignetteOverlay

local vignetteFrame

function VignetteOverlay:Create()
	if vignetteFrame then return vignetteFrame end

	-- Parent to NihuiParent for stable positioning hierarchy
	vignetteFrame = CreateFrame("Frame", "NihuiOptimizerVignette", E.NihuiParent)
	vignetteFrame:SetAllPoints(E.NihuiParent)  -- Fill entire NihuiParent
	vignetteFrame:SetFrameStrata("BACKGROUND")
	vignetteFrame:SetFrameLevel(1)
	vignetteFrame:Hide()

	-- Create gradient textures for each edge
	-- Top gradient (starts dark at top edge, fades toward center)
	local top = vignetteFrame:CreateTexture(nil, "ARTWORK")
	top:SetColorTexture(0, 0, 0, 1)
	top:SetPoint("TOPLEFT")
	top:SetPoint("TOPRIGHT")
	top:SetHeight(200)
	-- Gradient goes from minValue to maxValue, but texture is anchored at TOP
	-- So we want: dark at top anchor point, transparent at bottom of texture
	top:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.8))
	top:SetTexCoord(0, 1, 1, 0)  -- Flip texture vertically
	vignetteFrame.top = top

	-- Bottom gradient (starts dark at bottom edge, fades toward center)
	local bottom = vignetteFrame:CreateTexture(nil, "ARTWORK")
	bottom:SetColorTexture(0, 0, 0, 1)
	bottom:SetPoint("BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT")
	bottom:SetHeight(200)
	-- Want: transparent at top of texture, dark at bottom (anchor point)
	bottom:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.8), CreateColor(0, 0, 0, 0))
	bottom:SetTexCoord(0, 1, 1, 0)  -- Flip texture vertically
	vignetteFrame.bottom = bottom

	-- Left gradient (starts dark at left edge, fades toward center)
	local left = vignetteFrame:CreateTexture(nil, "ARTWORK")
	left:SetColorTexture(0, 0, 0, 1)
	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	left:SetWidth(200)
	-- Want: dark at left anchor point, transparent at right of texture
	left:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0.8), CreateColor(0, 0, 0, 0))
	left:SetTexCoord(1, 0, 0, 1)  -- Flip texture horizontally
	vignetteFrame.left = left

	-- Right gradient (starts dark at right edge, fades toward center)
	local right = vignetteFrame:CreateTexture(nil, "ARTWORK")
	right:SetColorTexture(0, 0, 0, 1)
	right:SetPoint("TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT")
	right:SetWidth(200)
	-- Want: transparent at left of texture, dark at right anchor point
	right:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.8))
	right:SetTexCoord(1, 0, 0, 1)  -- Flip texture horizontally
	vignetteFrame.right = right

	return vignetteFrame
end

function VignetteOverlay:Show()
	local frame = self:Create()
	frame:SetAlpha(0)
	frame:Show()

	-- Fade in (no callback, no delay)
	E.Animations:FadeIn(frame, 0.3)
end

function VignetteOverlay:Hide()
	if vignetteFrame and vignetteFrame:IsShown() then
		-- Fade out then hide
		local alpha = vignetteFrame:GetAlpha()
		local duration = 0.3
		local elapsed = 0

		local ticker
		ticker = C_Timer.NewTicker(0.016, function(self)
			elapsed = elapsed + 0.016
			local progress = math.min(elapsed / duration, 1)
			local newAlpha = alpha * (1 - progress)

			vignetteFrame:SetAlpha(newAlpha)

			if progress >= 1 then
				self:Cancel()
				vignetteFrame:Hide()
			end
		end)
	end
end
