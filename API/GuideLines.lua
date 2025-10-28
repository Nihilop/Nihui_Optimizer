local _, ns = ...
local E = ns.E

-- GuideLines API: Dynamic UI positioning system (inspired by Narcissus)
-- Provides anchor points that adapt to screen resolution and camera position
E.GuideLines = {}
local GuideLines = E.GuideLines

-- Constants
local GOLDEN_RATIO = 0.618
local ANIMATION_DURATION = 0.8

-- Easing function (smooth deceleration)
local function outSine(t, from, to, duration)
	local progress = math.min(t / duration, 1)
	local delta = to - from
	return from + delta * math.sin(progress * math.pi / 2)
end

-- Guide Line Frame (invisible container for anchor points)
local GuideLineFrame = CreateFrame("Frame", "NihuiOptimizerGuideLineFrame")
GuideLineFrame:SetAllPoints(UIParent)
GuideLineFrame:SetFrameStrata("MEDIUM")
GuideLines.frame = GuideLineFrame

-- Left Guide Line (for left-side UI elements)
local LeftLine = CreateFrame("Frame", nil, GuideLineFrame)
LeftLine:SetSize(1, 1)  -- Invisible anchor point
GuideLines.LeftLine = LeftLine

-- Right Guide Line (for right-side UI elements)
local RightLine = CreateFrame("Frame", nil, GuideLineFrame)
RightLine:SetSize(1, 1)  -- Invisible anchor point
GuideLines.RightLine = RightLine

-- Center Guide Line (for center UI elements)
local CenterLine = CreateFrame("Frame", nil, GuideLineFrame)
CenterLine:SetSize(1, 1)  -- Invisible anchor point
GuideLines.CenterLine = CenterLine

-- Debug visualization (show guide lines if debug mode)
if E.DEBUG_MODE then
	local function CreateDebugLine(parent, r, g, b)
		local line = parent:CreateTexture(nil, "OVERLAY")
		line:SetColorTexture(r, g, b, 0.5)
		line:SetSize(2, UIParent:GetHeight())
		line:SetPoint("CENTER")
		return line
	end

	LeftLine.debugLine = CreateDebugLine(LeftLine, 1, 0, 0)     -- Red
	RightLine.debugLine = CreateDebugLine(RightLine, 0, 1, 0)   -- Green
	CenterLine.debugLine = CreateDebugLine(CenterLine, 0, 0, 1) -- Blue
end

-- Camera Presets: Define where the character should be positioned
GuideLines.Presets = {
	-- Tab 1: Equipment View (Narcissus style)
	-- Layout: [LEFT EQUIP] [CHARACTER] [RIGHT EQUIP] ..... [STATS PANEL (far right)]
	-- Left equipment: juste à droite du personnage (qui est à gauche de l'écran)
	-- Right equipment: à droite du personnage
	-- Stats: tout à droite de l'écran (indépendant des guide lines)
	CHARACTER_LEFT = {
		name = "CHARACTER_LEFT",
		characterPosition = "left",
		leftLineOffset = 200,       -- Equipment gauche (200px from left edge - laisse place au perso)
		rightLineOffset = -600,     -- Equipment droite (600px from right - laisse place stats)
		centerLineOffset = 0,       -- Center (unused)
		cameraShoulderOffset = 2,   -- Camera shoulder = perso décalé à droite dans son espace
		cameraZoom = 4.5,
	},

	-- Tab 2+: Character on right, left panel takes space
	CHARACTER_RIGHT = {
		name = "CHARACTER_RIGHT",
		characterPosition = "right",
		leftLineOffset = 80,        -- Left panel anchor
		rightLineOffset = -80,      -- Right equipment anchor
		centerLineOffset = 0,
		cameraShoulderOffset = -2,  -- Negative shoulder = character on right
		cameraZoom = 4.5,
	},

	-- Center mode: Character centered (for future use)
	CHARACTER_CENTER = {
		name = "CHARACTER_CENTER",
		characterPosition = "center",
		leftLineOffset = 80,
		rightLineOffset = -80,
		centerLineOffset = 0,
		cameraShoulderOffset = 0,   -- No shoulder offset = centered
		cameraZoom = 4.5,
	},
}

-- Current active preset
GuideLines.currentPreset = nil

-- Calculate optimal guide line positions based on screen size
function GuideLines:CalculatePositions()
	local screenWidth, screenHeight = UIParent:GetSize()

	-- Calculate optimal width (16:9 aspect ratio, max 1920px like our ContentFrame)
	local optimalWidth = math.min(screenHeight / 9 * 16, screenWidth, 1920)

	-- Calculate center point
	local centerX = 0  -- Center of screen

	-- Store calculated values
	self.screenWidth = screenWidth
	self.screenHeight = screenHeight
	self.optimalWidth = optimalWidth
	self.centerX = centerX

	return optimalWidth, centerX
end

-- Apply a preset (with optional animation)
function GuideLines:ApplyPreset(presetName, animate)
	local preset = self.Presets[presetName]
	if not preset then
		error("Invalid preset: " .. tostring(presetName))
		return
	end

	-- Calculate base positions (this also calculates responsive shoulder offset)
	local optimalWidth, centerX = self:CalculatePositions()

	-- Calculate target positions for each guide line
	local leftTargetX = preset.leftLineOffset
	local rightTargetX = preset.rightLineOffset
	local centerTargetX = centerX + preset.centerLineOffset

	if animate and self.currentPreset then
		-- Animate from current position to target
		self:AnimateLineTo(self.LeftLine, "LEFT", leftTargetX, 0)
		self:AnimateLineTo(self.RightLine, "RIGHT", rightTargetX, 0)
		self:AnimateLineTo(self.CenterLine, "CENTER", centerTargetX, 0)
	else
		-- Instant positioning (no animation)
		self.LeftLine:ClearAllPoints()
		self.LeftLine:SetPoint("LEFT", GuideLineFrame, "LEFT", leftTargetX, 0)

		self.RightLine:ClearAllPoints()
		self.RightLine:SetPoint("RIGHT", GuideLineFrame, "RIGHT", rightTargetX, 0)

		self.CenterLine:ClearAllPoints()
		self.CenterLine:SetPoint("CENTER", GuideLineFrame, "CENTER", centerTargetX, 0)
	end

	self.currentPreset = preset

	-- Fire callback for camera adjustment
	if self.onPresetChanged then
		self.onPresetChanged(preset)
	end
end

-- Animate a guide line to a new position
function GuideLines:AnimateLineTo(line, anchorPoint, targetX, targetY)
	-- Get current position
	local _, _, _, currentX, currentY = line:GetPoint()
	currentX = currentX or 0
	currentY = currentY or 0

	-- Stop any existing animation
	if line.animationTicker then
		line.animationTicker:Cancel()
	end

	-- Start new animation
	local elapsed = 0
	line.animationTicker = C_Timer.NewTicker(0.016, function(ticker)
		elapsed = elapsed + 0.016

		if elapsed >= ANIMATION_DURATION then
			-- Animation complete
			line:ClearAllPoints()
			line:SetPoint(anchorPoint, GuideLineFrame, anchorPoint, targetX, targetY)
			ticker:Cancel()
			line.animationTicker = nil
			return
		end

		-- Calculate eased position
		local newX = outSine(elapsed, currentX, targetX, ANIMATION_DURATION)
		local newY = outSine(elapsed, currentY, targetY, ANIMATION_DURATION)

		-- Update position
		line:ClearAllPoints()
		line:SetPoint(anchorPoint, GuideLineFrame, anchorPoint, newX, newY)
	end)
end

-- Initialize with default preset
function GuideLines:Initialize(defaultPreset)
	defaultPreset = defaultPreset or "CHARACTER_LEFT"
	self:ApplyPreset(defaultPreset, false)

	-- Register for resolution changes
	GuideLineFrame:SetScript("OnSizeChanged", function()
		-- Reapply current preset to recalculate positions
		if self.currentPreset then
			self:ApplyPreset(self.currentPreset.name, false)
		end
	end)
end

-- Get anchor points for UI elements
function GuideLines:GetLeftAnchor()
	return self.LeftLine, "LEFT"
end

function GuideLines:GetRightAnchor()
	return self.RightLine, "RIGHT"
end

function GuideLines:GetCenterAnchor()
	return self.CenterLine, "CENTER"
end

-- Get current camera settings from active preset
-- NOTE: Camera settings (shoulder, zoom) are now managed by CameraPresets API
function GuideLines:GetCameraSettings()
	if not self.currentPreset then
		return nil, 4.5  -- Return nil for shoulder (CameraPresets will calculate it)
	end

	return nil, self.currentPreset.cameraZoom  -- Return nil for shoulder, only zoom
end
