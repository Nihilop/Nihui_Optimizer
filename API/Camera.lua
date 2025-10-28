local _, ns = ...
local E = ns.E

E.Camera = {}
local Camera = E.Camera

-- Camera State
Camera.isReady = false      -- TRUE when camera zoom/rotation complete and UI can animate in
Camera.isZoomed = false     -- TRUE when camera is in zoomed state
Camera.isTransitioning = false  -- TRUE during camera animations

-- Store original camera settings (Narcissus approach)
Camera.savedZoom = nil
Camera.savedShoulder = nil
Camera.savedViewBlendStyle = nil
Camera.savedDynamicPitch = nil
Camera.savedMotionSickness1 = nil
Camera.savedMotionSickness2 = nil
Camera.debugZoom = 4.5  -- Default zoom for debug (wider view)

-- Callbacks
Camera.onReady = nil        -- Callback when camera is ready (zoom + rotation complete)
Camera.onZoomComplete = nil -- Callback when zoom complete (before rotation finishes)

-- View save index (like Narcissus uses 5)
local VIEW_SAVE_INDEX = 5

-- CVars for motion sickness (locks shoulder offset)
local MS_CVAR_1 = "CameraKeepCharacterCentered"
local MS_CVAR_2 = "CameraReduceUnexpectedMovement"

-- Easing functions
local function outSine(t)
	return math.sin(t * math.pi / 2)
end

local function inOutSine(t, from, to, duration)
	local delta = to - from
	return delta * (1 - math.cos(t * math.pi / duration)) / 2 + from
end

-- Calculate shoulder offset based on zoom (Narcissus formula)
local function GetShoulderOffsetByZoom(zoom)
	-- Default parameters (can be adjusted per race later)
	local SHOULDER_PARA_1 = 0.361
	local SHOULDER_PARA_2 = -0.1654
	return zoom * SHOULDER_PARA_1 + SHOULDER_PARA_2
end

-- Disable motion sickness CVars for better camera control
function Camera:DisableMotionSickness()
	self.savedMotionSickness1 = C_CVar.GetCVar(MS_CVAR_1)
	self.savedMotionSickness2 = C_CVar.GetCVar(MS_CVAR_2)

	C_CVar.SetCVar(MS_CVAR_1, 0)
	C_CVar.SetCVar(MS_CVAR_2, 0)
end

-- Restore motion sickness CVars
function Camera:RestoreMotionSickness()
	if self.savedMotionSickness1 then
		C_CVar.SetCVar(MS_CVAR_1, self.savedMotionSickness1)
		self.savedMotionSickness1 = nil
	end
	if self.savedMotionSickness2 then
		C_CVar.SetCVar(MS_CVAR_2, self.savedMotionSickness2)
		self.savedMotionSickness2 = nil
	end
end

-- Smooth Yaw rotation (rotate to face character, then STOP)
-- Narcissus approach: start rotation ONCE, then stop after duration
function Camera:SmoothYaw()
	-- Get rotation duration from config
	local ROTATION_DURATION = E.CameraPresetsConfig.rotationDuration

	-- Get yaw speed setting
	local yawMoveSpeed = tonumber(C_CVar.GetCVar("cameraYawMoveSpeed")) or 180

	-- Calculate base speed (normalized 0-1 range)
	local baseSpeed = 180 / yawMoveSpeed

	-- Start rotation at standard speed (Narcissus uses baseSpeed * 1.05 initially)
	-- We use just baseSpeed for simpler, predictable rotation
	MoveViewRightStart(baseSpeed)

	-- Stop rotation after exactly ROTATION_DURATION
	C_Timer.After(ROTATION_DURATION, function()
		MoveViewRightStop()
	end)
end

-- Smooth Pitch adjustment (adjust camera angle)
function Camera:SmoothPitch()
	-- Get pitch duration from config
	local ANGLE_SMOOTH_DURATION = E.CameraPresetsConfig.pitchDuration
	local elapsed = 0

	local ticker = C_Timer.NewTicker(0.016, function(self)
		elapsed = elapsed + 0.016
		local progress = math.min(elapsed / ANGLE_SMOOTH_DURATION, 1)

		-- Transition from 88 (normal) to 4 (more horizontal)
		local pitchLimit = 88 - (outSine(progress) * 84)

		ConsoleExec("pitchlimit " .. pitchLimit)

		if progress >= 1 then
			self:Cancel()
			ConsoleExec("pitchlimit 4")
		end
	end)
end

-- Zoom in on character (IDENTICAL to Narcissus approach)
function Camera:ZoomIn(callback)
	print("[Camera] ZoomIn called")

	if self.isZoomed then
		print("[Camera] Already zoomed, skipping")
		return
	end

	-- Mark as transitioning
	self.isReady = false
	self.isTransitioning = true

	-- Save current view using WoW native function (like Narcissus does)
	SaveView(VIEW_SAVE_INDEX)

	-- Backup CVars (Narcissus approach)
	self.savedZoom = GetCameraZoom()
	self.savedShoulder = tonumber(C_CVar.GetCVar("test_cameraOverShoulder")) or 0
	self.savedViewBlendStyle = C_CVar.GetCVar("cameraViewBlendStyle")
	self.savedDynamicPitch = C_CVar.GetCVar("test_cameraDynamicPitch")

	-- Disable motion sickness for better control (Narcissus does this)
	self:DisableMotionSickness()

	-- Enable dynamic pitch (Narcissus does this)
	C_CVar.SetCVar("test_cameraDynamicPitch", 1)

	-- Change view mode (Narcissus uses SetView(2))
	SetView(2)

	-- Get camera settings from CameraPresets (responsive shoulder offset)
	local shoulderOffset, zoomDistance = E.CameraPresets:GetCameraSettings()

	-- Set shoulder offset for proper character framing
	C_CVar.SetCVar("test_cameraOverShoulder", shoulderOffset)

	-- Start rotation immediately (if not moving)
	if not IsPlayerMoving() then
		self:SmoothYaw()
	end

	-- Start pitch adjustment
	if not (UnitInVehicle("player") or IsFlying("player")) then
		self:SmoothPitch()
	end

	-- Get timing configs
	local zoomDelay = E.CameraPresetsConfig.zoomDelay
	local initialZoomDuration = E.CameraPresetsConfig.initialZoomDuration

	-- Zoom after a small delay
	C_Timer.After(zoomDelay, function()
		self:ZoomToTarget()

		-- Call zoom complete callback (optional)
		if self.onZoomComplete then
			self.onZoomComplete()
		end

		-- Camera ready after zoom + rotation complete
		C_Timer.After(initialZoomDuration, function()
			self.isZoomed = true
			self.isReady = true
			self.isTransitioning = false

			print("[Camera] Camera ready, calling onReady callback")

			-- Call ready callback (API style)
			if self.onReady then
				self.onReady()
			else
				print("[Camera] Warning: onReady callback not set")
			end

			-- Call legacy callback (for compatibility)
			if callback then
				callback()
			end
		end)
	end)
end

-- Zoom to target distance (Narcissus: ZoomToDefault)
function Camera:ZoomToTarget()
	-- Get zoom distance from CameraPresets
	local _, targetZoom = E.CameraPresets:GetCameraSettings()
	local currentZoom = GetCameraZoom()

	if currentZoom >= targetZoom then
		CameraZoomIn(currentZoom - targetZoom)
	else
		CameraZoomOut(targetZoom - currentZoom)
	end
end

-- Zoom out to original position (IDENTICAL to Narcissus approach)
function Camera:ZoomOut(callback)
	if not self.isZoomed then return end

	-- Reset camera state
	self.isReady = false
	self.isTransitioning = true

	-- Stop any ongoing rotation immediately and multiple times (ensure it stops)
	MoveViewRightStop()
	MoveViewLeftStop()

	-- Restore motion sickness CVars
	self:RestoreMotionSickness()

	-- Smooth shoulder offset back to saved value (Narcissus does this)
	self:SmoothShoulder(self.savedShoulder or 0)

	-- Reset pitch limit immediately (Narcissus does this)
	ConsoleExec("pitchlimit 88")

	-- Restore view blend style immediately
	if self.savedViewBlendStyle then
		C_CVar.SetCVar("cameraViewBlendStyle", self.savedViewBlendStyle)
	end

	-- Restore dynamic pitch immediately (instead of waiting)
	C_CVar.SetCVar("test_cameraDynamicPitch", self.savedDynamicPitch or 0)

	-- Restore view after a small delay (Narcissus does After(0.1))
	C_Timer.After(0.1, function()
		-- RESTORE THE SAVED VIEW (Narcissus magic!)
		local cameraSmoothStyle = tonumber(C_CVar.GetCVar("cameraSmoothStyle")) or 0
		if cameraSmoothStyle == 0 then
			-- Use SetView with saved index to restore EXACTLY (Narcissus approach)
			SetView(VIEW_SAVE_INDEX)
		else
			-- Fallback: manual restore
			SetView(2)
			local targetZoom = self.savedZoom or GetCameraZoom()
			if GetCameraZoom() > targetZoom then
				CameraZoomIn(GetCameraZoom() - targetZoom)
			else
				CameraZoomOut(targetZoom - GetCameraZoom())
			end
		end

		-- Ensure rotation is stopped again after view restoration
		MoveViewRightStop()
		MoveViewLeftStop()

		self.isZoomed = false
		self.isTransitioning = false
		if callback then callback() end
	end)
end

-- Smooth shoulder transition (Narcissus method)
function Camera:SmoothShoulder(targetShoulder, duration)
	-- Get duration from config if not specified
	duration = duration or E.CameraPresetsConfig.shoulderTransitionDuration
	local startShoulder = tonumber(C_CVar.GetCVar("test_cameraOverShoulder")) or 0
	local elapsed = 0

	local ticker = C_Timer.NewTicker(0.016, function(self)
		elapsed = elapsed + 0.016
		local progress = math.min(elapsed / duration, 1)
		local easeValue = outSine(progress)

		local newShoulder = startShoulder + (targetShoulder - startShoulder) * easeValue
		C_CVar.SetCVar("test_cameraOverShoulder", newShoulder)

		if progress >= 1 then
			self:Cancel()
			C_CVar.SetCVar("test_cameraOverShoulder", targetShoulder)
		end
	end)
end

-- Reset camera instantly
function Camera:Reset()
	-- Stop any ongoing rotation
	MoveViewRightStop()

	if self.savedZoom then
		-- Restore original values
		C_CVar.SetCVar("test_cameraOverShoulder", self.savedShoulder or 0)
		ConsoleExec("pitchlimit 88")

		-- Restore original zoom instantly
		local currentZoom = GetCameraZoom()
		if currentZoom > self.savedZoom then
			CameraZoomIn(currentZoom - self.savedZoom)
		else
			CameraZoomOut(self.savedZoom - currentZoom)
		end
	end

	-- Restore motion sickness CVars
	self:RestoreMotionSickness()

	self.isZoomed = false
end
