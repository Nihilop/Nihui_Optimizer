local _, ns = ...
local E = ns.E

-- ============================================================================
-- ANIMATION MANAGER
-- Central system for managing UI animations with state tracking
-- Ensures clean transitions and prevents animation bugs
-- ============================================================================

E.AnimationManager = {}
local AnimationManager = E.AnimationManager

-- ============================================================================
-- CONFIGURATION (modify here to adjust animation timings)
-- ============================================================================
local CONFIG = {
	-- Transition lock duration (prevents tab switching during animations)
	-- Should be: camera transition + animation duration
	-- Example: 0.3s (camera) + 0.5s (animations) = 0.8s total
	lockDuration = 0.8,  -- Default: 0.8s, adjust if you change camera speed

	-- Safety timeout (force unlock if something fails)
	safetyTimeout = 3.0,  -- Default: 3s, prevents permanent lock

	-- Equipment slot animations
	slots = {
		distance = 40,        -- Slide distance in pixels
		duration = 0.3,       -- Fade duration (fast, slide does heavy lifting)
		staggerDelay = 0.06,  -- Delay between each slot
	},

	-- Panel animations (stats, optimizer)
	panels = {
		duration = 0.4,       -- Fade duration
		delay = 0.2,          -- Delay after camera ready
	},
}

-- Export config for external access
E.AnimationManagerConfig = CONFIG

-- State tracking
AnimationManager.frameStates = {}  -- Tracks state of each frame
AnimationManager.activeAnimations = {}  -- Tracks running animations for cancellation
AnimationManager.isTransitioning = false  -- Global transition lock

-- Frame states
local STATE = {
	HIDDEN = "hidden",
	ANIMATING = "animating",
	VISIBLE = "visible",
}

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

-- Get frame state
function AnimationManager:GetState(frame)
	if not frame then return STATE.HIDDEN end
	return self.frameStates[frame] or STATE.HIDDEN
end

-- Set frame state
function AnimationManager:SetState(frame, state)
	if not frame then return end
	self.frameStates[frame] = state
end

-- Reset frame to hidden state (for re-animation)
function AnimationManager:ResetFrame(frame)
	if not frame then return end

	-- IMPORTANT: Always reset to alpha 0 (all animations start from 0)
	frame:SetAlpha(0)
	frame:Show()  -- Show but invisible (ready for animation)
	self:SetState(frame, STATE.HIDDEN)
end

-- Reset multiple frames
function AnimationManager:ResetFrames(frames)
	if not frames then return end

	for _, frame in ipairs(frames) do
		self:ResetFrame(frame)
	end
end

-- ============================================================================
-- ANIMATION CANCELLATION
-- ============================================================================

-- Cancel all active animations
function AnimationManager:CancelAll()
	for _, animation in ipairs(self.activeAnimations) do
		if animation.ticker then
			animation.ticker:Cancel()
		end
		if animation.timer then
			animation.timer:Cancel()
		end
	end

	self.activeAnimations = {}
end

-- Register an animation (for cancellation tracking)
function AnimationManager:RegisterAnimation(animation)
	table.insert(self.activeAnimations, animation)
end

-- ============================================================================
-- ANIMATION PROFILES
-- Different animation types for different UI elements
-- ============================================================================

-- Profile: Equipment slot group (slides horizontally + fade)
function AnimationManager:AnimateSlotGroup(frames, direction, config)
	if not frames or #frames == 0 then return end

	-- Don't re-animate if already visible
	if self:GetState(frames[1]) == STATE.VISIBLE then
		return
	end

	config = config or {}
	local distance = config.distance or 40
	local duration = config.duration or 0.5
	local staggerDelay = config.staggerDelay or 0.08
	local startDelay = config.startDelay or 0

	-- Reset all frames first
	self:ResetFrames(frames)

	-- Animate each frame with stagger
	for i, frame in ipairs(frames) do
		self:SetState(frame, STATE.ANIMATING)

		local delay = startDelay + (i - 1) * staggerDelay

		print("[AnimationManager] Animating frame", i, "direction:", direction, "distance:", distance, "duration:", duration, "delay:", delay)

		-- Use direction-specific slide functions
		if direction == "RIGHT" then
			print("[AnimationManager] Using SlideRight for frame", i)
			E.Animations:SlideRight(frame, duration, distance, delay, function()
				print("[AnimationManager] SlideRight completed for frame", i)
				self:SetState(frame, STATE.VISIBLE)
			end)
		elseif direction == "LEFT" then
			print("[AnimationManager] Using SlideLeft for frame", i)
			E.Animations:SlideLeft(frame, duration, distance, delay, function()
				print("[AnimationManager] SlideLeft completed for frame", i)
				self:SetState(frame, STATE.VISIBLE)
			end)
		else
			-- Fallback to generic SlideIn for other directions
			print("[AnimationManager] Using generic SlideIn for frame", i)
			E.Animations:SlideIn(
				frame,
				direction,
				distance,
				duration,
				delay,
				true,  -- fadeIn
				function()
					self:SetState(frame, STATE.VISIBLE)
				end
			)
		end
	end
end

-- Profile: Panel/Window (fade in only, no slide)
function AnimationManager:AnimatePanel(frame, config)
	if not frame then return end

	-- Don't re-animate if already visible
	if self:GetState(frame) == STATE.VISIBLE then
		return
	end

	config = config or {}
	local duration = config.duration or 0.5
	local delay = config.delay or 0

	-- Reset frame first
	self:ResetFrame(frame)
	self:SetState(frame, STATE.ANIMATING)

	E.Animations:FadeIn(
		frame,
		duration,
		function()
			self:SetState(frame, STATE.VISIBLE)
		end,
		delay
	)
end

-- ============================================================================
-- TAB TRANSITION SYSTEM
-- Manages switching between tabs with clean state transitions
-- ============================================================================

-- Prepare tab for showing (reset all frames to hidden state)
function AnimationManager:PrepareTab(tabFrames)
	if not tabFrames then
		print("[AnimationManager] PrepareTab called with no frames")
		return
	end

	print("[AnimationManager] PrepareTab: Canceling animations and locking")

	-- Cancel any ongoing animations
	self:CancelAll()

	-- Activate transition lock (prevents tab switching during camera + animations)
	self.isTransitioning = true

	-- Safety timeout: force unlock after X seconds (in case animation fails)
	C_Timer.After(CONFIG.safetyTimeout, function()
		if self.isTransitioning then
			print("[AnimationManager] Safety timeout: Unlocking animations")
			self.isTransitioning = false
		end
	end)

	-- Reset all frames in this tab to alpha 0
	local frameCount = 0
	for _, frameGroup in pairs(tabFrames) do
		if type(frameGroup) == "table" then
			frameCount = frameCount + #frameGroup
			self:ResetFrames(frameGroup)
		else
			frameCount = frameCount + 1
			self:ResetFrame(frameGroup)
		end
	end

	print("[AnimationManager] PrepareTab: Reset " .. frameCount .. " frames to alpha 0")
end

-- Animate tab (called when camera is ready)
function AnimationManager:AnimateTab(animationFunc, duration)
	if not animationFunc then
		print("[AnimationManager] AnimateTab called with no function")
		return
	end

	-- Don't prevent if already transitioning, just reset the lock
	-- (This handles the case where PrepareTab set the lock)
	if not self.isTransitioning then
		print("[AnimationManager] Warning: AnimateTab called but lock was not active")
	end

	self.isTransitioning = true

	-- Execute animation function
	animationFunc()

	-- Clear transition lock after animations complete
	-- Duration from CONFIG (camera transition + animations)
	duration = duration or CONFIG.lockDuration
	C_Timer.After(duration, function()
		self.isTransitioning = false
		print("[AnimationManager] Animation lock released")
	end)
end

-- ============================================================================
-- TAB-SPECIFIC ANIMATION HELPERS
-- ============================================================================

-- Animate Equipment Tab (called when camera ready)
function AnimationManager:AnimateEquipmentTab(mainFrame)
	if not mainFrame or not mainFrame.equipmentSlots then return end

	print("[AnimationManager] AnimateEquipmentTab: Starting animation for", #mainFrame.equipmentSlots, "slots")

	-- Split slots into left and right groups based on slot.side property
	local leftSlots = {}
	local rightSlots = {}

	for _, slot in ipairs(mainFrame.equipmentSlots) do
		if slot.side == "left" then
			table.insert(leftSlots, slot)
			print("[AnimationManager] Slot", slot.slotName, "added to LEFT group")
		elseif slot.side == "right" then
			table.insert(rightSlots, slot)
			print("[AnimationManager] Slot", slot.slotName, "added to RIGHT group")
		else
			print("[AnimationManager] WARNING: Slot", slot.slotName, "has no side property!")
		end
	end

	print(string.format("[AnimationManager] Split: %d left slots, %d right slots", #leftSlots, #rightSlots))

	-- Animate left group: slides from LEFT to RIGHT + quick fadeIn
	self:AnimateSlotGroup(leftSlots, "RIGHT", {
		distance = CONFIG.slots.distance,
		duration = CONFIG.slots.duration,
		staggerDelay = CONFIG.slots.staggerDelay,
		startDelay = 0,
	})

	-- Animate right group: slides from RIGHT to LEFT + quick fadeIn
	self:AnimateSlotGroup(rightSlots, "LEFT", {
		distance = CONFIG.slots.distance,
		duration = CONFIG.slots.duration,
		staggerDelay = CONFIG.slots.staggerDelay,
		startDelay = 0,
	})

	-- Animate stats panel: fade in only
	if mainFrame.statsFrame then
		self:AnimatePanel(mainFrame.statsFrame, {
			duration = CONFIG.panels.duration,
			delay = CONFIG.panels.delay,
		})
	end
end

-- Animate Optimizer Tab (called when camera ready)
function AnimationManager:AnimateOptimizerTab(mainFrame)
	if not mainFrame or not mainFrame.optimizerPanel then return end

	-- Animate left panel: fade in only (no slide)
	-- optimizerPanel is now a container, animate its leftPanel child
	local panelToAnimate = mainFrame.optimizerPanel.leftPanel or mainFrame.optimizerPanel
	self:AnimatePanel(panelToAnimate, {
		duration = CONFIG.panels.duration,
		delay = CONFIG.panels.delay,
	})
end

-- ============================================================================
-- CONVENIENCE: Show frame without animation
-- ============================================================================
function AnimationManager:ShowInstant(frame)
	if not frame then return end

	frame:SetAlpha(1)
	frame:Show()
	self:SetState(frame, STATE.VISIBLE)
end

function AnimationManager:ShowInstantFrames(frames)
	if not frames then return end

	for _, frame in ipairs(frames) do
		self:ShowInstant(frame)
	end
end
