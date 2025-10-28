local _, ns = ...
local E = ns.E

-- ============================================================================
-- ANIMATIONS API
-- Provides smooth animations for UI elements (FadeIn, SlideIn, etc.)
-- ============================================================================

E.Animations = {}
local Animations = E.Animations

-- Easing functions
local function EaseOutSine(t)
	return math.sin((t * math.pi) / 2)
end

local function EaseInOutSine(t)
	return -(math.cos(math.pi * t) - 1) / 2
end

-- ============================================================================
-- FADE IN
-- Smoothly fades in a frame from alpha 0 to 1
-- ============================================================================
-- @param frame: Frame to animate
-- @param duration: Animation duration in seconds (default: 0.3)
-- @param callback: Function to call when animation completes (optional)
-- @param delay: Delay before starting in seconds (default: 0)
function Animations:FadeIn(frame, duration, callback, delay)
	if not frame then return end

	-- Validate and set defaults
	duration = tonumber(duration) or 0.3
	delay = tonumber(delay) or 0

	-- Validate that duration and delay are finite numbers
	if not (duration > 0 and duration < math.huge) then
		print("[Animations] ERROR: Invalid duration, using default 0.3s")
		duration = 0.3
	end
	if not (delay >= 0 and delay < math.huge) then
		print("[Animations] ERROR: Invalid delay, using default 0s")
		delay = 0
	end

	-- Set initial state (invisible)
	frame:SetAlpha(0)
	frame:Show()

	-- Start animation after delay
	C_Timer.After(delay, function()
		local elapsed = 0
		local ticker

		ticker = C_Timer.NewTicker(0.01, function()
			elapsed = elapsed + 0.01
			local progress = math.min(elapsed / duration, 1)
			local easedProgress = EaseOutSine(progress)

			frame:SetAlpha(easedProgress)

			-- Animation complete
			if progress >= 1 then
				ticker:Cancel()
				if callback then
					callback()
				end
			end
		end)
	end)
end

-- ============================================================================
-- SLIDE IN
-- Slides in a frame from a direction with optional fade
-- ============================================================================
-- @param frame: Frame to animate
-- @param direction: "UP", "DOWN", "LEFT", "RIGHT"
-- @param distance: Distance to slide in pixels (default: 50)
-- @param duration: Animation duration in seconds (default: 0.4)
-- @param delay: Delay before starting in seconds (default: 0)
-- @param fadeIn: Also fade in during slide (default: true)
-- @param callback: Function to call when animation completes (optional)
function Animations:SlideIn(frame, direction, distance, duration, delay, fadeIn, callback)
	if not frame then return end

	direction = direction or "UP"
	distance = distance or 50
	duration = duration or 0.4
	delay = delay or 0
	fadeIn = (fadeIn ~= false)  -- Default true

	-- Store original position
	local points = {}
	for i = 1, frame:GetNumPoints() do
		local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(i)
		table.insert(points, {point, relativeTo, relativePoint, xOfs, yOfs})
	end

	-- Calculate offset based on direction
	local offsetX, offsetY = 0, 0
	if direction == "UP" then
		offsetY = -distance
	elseif direction == "DOWN" then
		offsetY = distance
	elseif direction == "LEFT" then
		offsetX = distance
	elseif direction == "RIGHT" then
		offsetX = -distance
	end

	-- Set initial state (offset position, invisible if fading)
	frame:ClearAllPoints()
	for _, pointData in ipairs(points) do
		local point, relativeTo, relativePoint, xOfs, yOfs = unpack(pointData)
		frame:SetPoint(point, relativeTo, relativePoint, xOfs + offsetX, yOfs + offsetY)
	end

	if fadeIn then
		frame:SetAlpha(0)
	end
	frame:Show()

	-- Start animation after delay
	C_Timer.After(delay, function()
		local elapsed = 0
		local ticker

		ticker = C_Timer.NewTicker(0.01, function()
			elapsed = elapsed + 0.01
			local progress = math.min(elapsed / duration, 1)
			local easedProgress = EaseInOutSine(progress)

			-- Update position
			frame:ClearAllPoints()
			for _, pointData in ipairs(points) do
				local point, relativeTo, relativePoint, xOfs, yOfs = unpack(pointData)
				local currentOffsetX = offsetX * (1 - easedProgress)
				local currentOffsetY = offsetY * (1 - easedProgress)
				frame:SetPoint(point, relativeTo, relativePoint, xOfs + currentOffsetX, yOfs + currentOffsetY)
			end

			-- Update alpha if fading
			if fadeIn then
				frame:SetAlpha(easedProgress)
			end

			-- Animation complete
			if progress >= 1 then
				ticker:Cancel()
				if callback then
					callback()
				end
			end
		end)
	end)
end

-- ============================================================================
-- STAGGERED ANIMATION
-- Animates multiple frames with a delay between each
-- ============================================================================
-- @param frames: Array of frames to animate
-- @param animFunc: Function(frame, index) that triggers animation for each frame
-- @param staggerDelay: Delay between each frame animation (default: 0.05)
-- @param callback: Function to call when ALL animations complete (optional)
function Animations:Staggered(frames, animFunc, staggerDelay, callback)
	if not frames or #frames == 0 then
		if callback then callback() end
		return
	end

	staggerDelay = staggerDelay or 0.05
	local completedCount = 0
	local totalFrames = #frames

	for i, frame in ipairs(frames) do
		local delay = (i - 1) * staggerDelay

		C_Timer.After(delay, function()
			-- Call animation function with callback to track completion
			animFunc(frame, i, function()
				completedCount = completedCount + 1
				if completedCount >= totalFrames and callback then
					callback()
				end
			end)
		end)
	end
end

-- ============================================================================
-- CONVENIENCE: Staggered Slide In for multiple frames
-- ============================================================================
-- @param frames: Array of frames to animate
-- @param direction: "UP", "DOWN", "LEFT", "RIGHT"
-- @param distance: Distance to slide (default: 30)
-- @param duration: Duration per frame (default: 0.4)
-- @param staggerDelay: Delay between frames (default: 0.08)
-- @param fadeIn: Also fade in (default: true)
-- @param callback: Called when all complete
function Animations:StaggeredSlideIn(frames, direction, distance, duration, staggerDelay, fadeIn, callback)
	self:Staggered(frames, function(frame, index, frameCallback)
		self:SlideIn(frame, direction, distance, duration, 0, fadeIn, frameCallback)
	end, staggerDelay, callback)
end

-- ============================================================================
-- CONVENIENCE: Slide Right (from left to right)
-- ============================================================================
-- @param frame: Frame to animate
-- @param duration: Animation duration in seconds (default: 0.3)
-- @param distance: Distance to slide in pixels (default: 30)
-- @param delay: Delay before starting in seconds (default: 0)
-- @param callback: Function to call when animation completes (optional)
function Animations:SlideRight(frame, duration, distance, delay, callback)
	print("[Animations] SlideRight called: duration=" .. tostring(duration) .. ", distance=" .. tostring(distance) .. ", delay=" .. tostring(delay))
	self:SlideIn(frame, "RIGHT", distance or 30, duration or 0.3, delay or 0, true, callback)
end

-- ============================================================================
-- CONVENIENCE: Slide Left (from right to left)
-- ============================================================================
-- @param frame: Frame to animate
-- @param duration: Animation duration in seconds (default: 0.3)
-- @param distance: Distance to slide in pixels (default: 30)
-- @param delay: Delay before starting in seconds (default: 0)
-- @param callback: Function to call when animation completes (optional)
function Animations:SlideLeft(frame, duration, distance, delay, callback)
	print("[Animations] SlideLeft called: duration=" .. tostring(duration) .. ", distance=" .. tostring(distance) .. ", delay=" .. tostring(delay))
	self:SlideIn(frame, "LEFT", distance or 30, duration or 0.3, delay or 0, true, callback)
end

-- ============================================================================
-- HIDE (instant, for resetting state)
-- ============================================================================
function Animations:Hide(frame)
	if not frame then return end
	frame:SetAlpha(0)
	frame:Hide()
end

-- ============================================================================
-- RESET (show at full alpha, for resetting state)
-- ============================================================================
function Animations:Reset(frame)
	if not frame then return end
	frame:SetAlpha(1)
	frame:Show()
end
