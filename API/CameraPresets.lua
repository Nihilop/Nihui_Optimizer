local _, ns = ...
local E = ns.E

-- CameraPresets API: High-level camera control for different tabs/modes
-- Coordinates Camera and GuideLines for seamless character positioning
E.CameraPresets = {}
local CameraPresets = E.CameraPresets

-- ============================================================================
-- CONFIGURATION (modify here to adjust camera transition speed and positions)
-- ============================================================================
local CONFIG = {
	-- Camera transition duration between tabs (in seconds)
	transitionDuration = 0.2,  -- Default: 0.2s (fast), try 0.15s (very fast) or 0.4s (slower)

	-- Initial zoom duration (when opening interface)
	initialZoomDuration = 0.7,  -- Time before camera is "ready" after ZoomIn starts

	-- Rotation duration (character spinning animation)
	rotationDuration = 0.8,  -- Default: 1.0s, try 0.8s (faster) or 1.2s (slower)

	-- Pitch adjustment duration (camera angle change)
	pitchDuration = 1,  -- Default: 1.5s, try 1.0s (faster) or 2.0s (slower)

	-- Shoulder transition duration (when changing tabs)
	shoulderTransitionDuration = 1.0,  -- Default: 1.0s, used when smoothly moving character left/right

	-- Zoom delay before starting zoom animation
	zoomDelay = 0.1,  -- Small delay before zoom starts (Narcissus approach)

	-- Camera positions for each mode (base values for 2560px resolution)
	-- These are scaled down for smaller resolutions automatically
	positions = {
		EQUIPMENT_VIEW = {
			shoulderOffset = 1,   -- Positive = character on left
			zoomDistance = 3.5,     -- Distance from character
		},
		LEFT_PANEL_VIEW = {
			shoulderOffset = -2.5,  -- Negative = character on right
			zoomDistance = 5.5,
		},
		RIGHT_PANEL_VIEW = {
			shoulderOffset = 2.5,  -- Positive = character on left (large panel right)
			zoomDistance = 5.5,
		},
		TALENTS_VIEW = {
			shoulderOffset = 3.5,  -- Positive = character on left (talent tree right)
			zoomDistance = 5.5,    -- Same as right panel view
		},
		MAP_VIEW = {
			shoulderOffset = -2.5,  -- Negative = character on right (map left)
			zoomDistance = 5.5,
		},
		CENTER_VIEW = {
			shoulderOffset = 0.0,   -- Centered
			zoomDistance = 4.5,
		},
	},
}

-- Export config for external access
E.CameraPresetsConfig = CONFIG

-- State tracking
CameraPresets.currentMode = nil
CameraPresets.isTransitioning = false

-- Calculate responsive shoulder offset based on screen resolution and current mode
-- Returns the appropriate shoulder offset for optimal character framing
function CameraPresets:CalculateShoulderOffset(modeName)
	local screenWidth = UIParent:GetWidth()

	-- Get base shoulder offset from CONFIG
	local modeConfig = CONFIG.positions[modeName]
	if not modeConfig then
		print("[CameraPresets] Warning: Unknown mode " .. tostring(modeName))
		modeConfig = CONFIG.positions.EQUIPMENT_VIEW
	end

	local baseOffset = modeConfig.shoulderOffset

	-- Scale factor based on screen width
	-- Small screens (<=1920): reduce offset by 40% (character more centered)
	-- Medium screens (1920-2560): linear scaling
	-- Large screens (>=2560): full offset
	local scaleFactor
	if screenWidth <= 1920 then
		scaleFactor = 0.6  -- 40% reduction (e.g., 2.0 → 1.2)
	elseif screenWidth <= 2560 then
		-- Linear interpolation between 0.6 and 1.0
		local ratio = (screenWidth - 1920) / (2560 - 1920)
		scaleFactor = 0.6 + (ratio * 0.4)
	else
		scaleFactor = 1.0  -- Full offset on ultra-wide/5K+
	end

	return baseOffset * scaleFactor
end

-- Camera Mode Definitions
-- Each mode defines a complete layout configuration
CameraPresets.Modes = {
	-- TAB 1: Equipment View (Narcissus-style)
	-- Character positioned left, equipment slots on both sides, stats panel on right
	EQUIPMENT_VIEW = {
		name = "EQUIPMENT_VIEW",
		guideLinePreset = "CHARACTER_LEFT",
		description = "Character on left, equipment flanking sides, stats on right",
	},

	-- TAB 2: Left Panel View
	-- Character positioned right, large panel on left side
	LEFT_PANEL_VIEW = {
		name = "LEFT_PANEL_VIEW",
		guideLinePreset = "CHARACTER_RIGHT",
		description = "Character on right, main panel on left",
	},

	-- TAB 3: Talents View
	-- Character positioned left, talent tree on right side
	TALENTS_VIEW = {
		name = "TALENTS_VIEW",
		guideLinePreset = "CHARACTER_LEFT",
		description = "Character on left, talent tree on right",
	},

	-- TAB 4: Map View
	-- Character positioned right, world map on left side
	MAP_VIEW = {
		name = "MAP_VIEW",
		guideLinePreset = "CHARACTER_RIGHT",
		description = "Character on right, world map on left",
	},

	-- Generic: Right Panel View (for future tabs)
	RIGHT_PANEL_VIEW = {
		name = "RIGHT_PANEL_VIEW",
		guideLinePreset = "CHARACTER_LEFT",
		description = "Character on left, main panel on right",
	},

	-- Future: Center view for other uses
	CENTER_VIEW = {
		name = "CENTER_VIEW",
		guideLinePreset = "CHARACTER_CENTER",
		description = "Character centered",
	},
}

-- Apply a camera mode (switch between tabs)
function CameraPresets:ApplyMode(modeName, options)
	local mode = self.Modes[modeName]
	if not mode then
		error("Invalid camera mode: " .. tostring(modeName))
		return
	end

	options = options or {}
	local animate = options.animate ~= false  -- Default: animate

	-- Don't transition if already in this mode
	if self.currentMode and self.currentMode.name == modeName and not options.force then
		return
	end

	-- Mark as transitioning
	self.isTransitioning = true

	-- Apply guide line preset (this will reposition UI anchor points)
	E.GuideLines:ApplyPreset(mode.guideLinePreset, animate)

	-- Calculate responsive camera settings
	local shoulderOffset = self:CalculateShoulderOffset(modeName)
	local _, zoomDistance = E.GuideLines:GetCameraSettings()  -- Only get zoom from GuideLines

	-- Store calculated shoulder for camera to use
	self.currentShoulderOffset = shoulderOffset

	-- Update camera with new settings
	if E.Camera.isZoomed then
		-- Camera is already zoomed, smoothly transition to new position
		self:TransitionCamera(shoulderOffset, zoomDistance)
	else
		-- Camera not yet active, settings will be applied on next ZoomIn
		E.Camera.debugZoom = zoomDistance
	end

	self.currentMode = mode
	self.isTransitioning = false

	-- Fire callback
	if self.onModeChanged then
		self.onModeChanged(mode)
	end
end

-- Smooth camera transition between modes (when camera is already active)
function CameraPresets:TransitionCamera(targetShoulder, targetZoom)
	local camera = E.Camera

	-- Smoothly transition shoulder offset (with configurable duration)
	camera:SmoothShoulder(targetShoulder, CONFIG.transitionDuration)

	-- Smoothly transition zoom (configurable duration)
	local DURATION = CONFIG.transitionDuration
	local startZoom = GetCameraZoom()
	local elapsed = 0

	local ticker = C_Timer.NewTicker(0.016, function(self)
		elapsed = elapsed + 0.016
		local progress = math.min(elapsed / DURATION, 1)

		-- Ease out sine
		local easeProgress = math.sin(progress * math.pi / 2)

		-- Calculate current zoom
		local currentZoom = startZoom + (targetZoom - startZoom) * easeProgress

		-- Apply zoom
		local actualZoom = GetCameraZoom()
		if actualZoom > currentZoom then
			CameraZoomIn(actualZoom - currentZoom)
		else
			CameraZoomOut(currentZoom - actualZoom)
		end

		if progress >= 1 then
			self:Cancel()

			-- Trigger Camera.onReady callback after transition completes
			if camera.onReady then
				camera.onReady()
			end
		end
	end)
end

-- Enter Equipment View (Tab 1)
function CameraPresets:EnterEquipmentView(animate)
	self:ApplyMode("EQUIPMENT_VIEW", {animate = animate})
end

-- Enter Left Panel View (Tab 2)
function CameraPresets:EnterLeftPanelView(animate)
	self:ApplyMode("LEFT_PANEL_VIEW", {animate = animate})
end

-- Enter Right Panel View
function CameraPresets:EnterRightPanelView(animate)
	self:ApplyMode("RIGHT_PANEL_VIEW", {animate = animate})
end

-- Enter Talents View (Tab 3)
function CameraPresets:EnterTalentsView(animate)
	self:ApplyMode("TALENTS_VIEW", {animate = animate})
end

-- Enter Map View (Tab 4)
function CameraPresets:EnterMapView(animate)
	self:ApplyMode("MAP_VIEW", {animate = animate})
end

-- Enter Center View
function CameraPresets:EnterCenterView(animate)
	self:ApplyMode("CENTER_VIEW", {animate = animate})
end

-- Get current mode info
function CameraPresets:GetCurrentMode()
	return self.currentMode
end

-- Check if currently transitioning
function CameraPresets:IsTransitioning()
	return self.isTransitioning
end

-- Get current camera settings (shoulder offset and zoom)
-- This is the authoritative source for camera settings (from CONFIG)
function CameraPresets:GetCameraSettings()
	local shoulderOffset = self.currentShoulderOffset

	-- Get zoom distance from CONFIG based on current mode
	local zoomDistance
	if self.currentMode then
		local modeConfig = CONFIG.positions[self.currentMode.name]
		if modeConfig then
			zoomDistance = modeConfig.zoomDistance
		end
	end

	-- Fallback if not initialized yet
	if not shoulderOffset then
		shoulderOffset = self:CalculateShoulderOffset("EQUIPMENT_VIEW")
	end
	if not zoomDistance then
		zoomDistance = CONFIG.positions.EQUIPMENT_VIEW.zoomDistance or 4.5
	end

	return shoulderOffset, zoomDistance
end

-- Future: Mouse-based character rotation
-- This will allow players to click+drag to rotate around the character
function CameraPresets:EnableMouseRotation()
	-- TODO: Implement mouse rotation control
	-- Will use MoveViewRightStart/Stop with mouse delta
	-- Store initial mouse position on mouse down
	-- Calculate rotation speed based on mouse movement
	-- Stop rotation on mouse up
	print("Mouse rotation not yet implemented")
end

function CameraPresets:DisableMouseRotation()
	-- TODO: Disable mouse rotation
	print("Mouse rotation not yet implemented")
end

-- Initialize camera presets system
function CameraPresets:Initialize()
	-- Link camera zoom to guide lines settings
	E.GuideLines.onPresetChanged = function(preset)
		-- Update camera debug zoom to match preset
		E.Camera.debugZoom = preset.cameraZoom
	end

	-- Set default mode
	self.currentMode = self.Modes.EQUIPMENT_VIEW
end
