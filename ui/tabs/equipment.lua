local _, ns = ...
local E = ns.E

-- ============================================================================
-- TAB 1: EQUIPMENT VIEW
-- Character on left/center, equipment slots on both sides, stats panel on right
-- ============================================================================

-- CONFIGURATION (modify here for easy adjustments)
local CONFIG = {
	-- Camera settings (handled by CameraPresets, but listed here for reference)
	cameraMode = "EQUIPMENT_VIEW",

	-- Equipment positioning
	equipment = {
		leftOffsetX = 0,      -- Distance from left edge
		rightOffsetX = 150,     -- Distance to right of center (150 = original)
		slotSpacing = 10,       -- Vertical spacing between slots
		titleOffset = 80,       -- Space for title at top
	},

	-- Stats panel positioning
	stats = {
		width = 320,
		marginRight = 20,
		marginTop = 80,
		marginBottom = 20,
	},

	-- Animations (when Camera.onReady fires)
	animations = {
		enabled = true,
		fadeInDuration = 0.5,
		staggerDelay = 0.08,    -- Delay between each slot appearing
	},
}

-- Export config for external access
E.EquipmentTabConfig = CONFIG

-- Create Equipment Tab UI
function E:CreateEquipmentTab(parent)
	-- Equipment frame: Full area for character and equipment slots
	local equipmentFrame = CreateFrame("Frame", nil, parent)
	equipmentFrame:SetAllPoints(parent)
	equipmentFrame:EnableMouse(true)  -- Block clicks to prevent interaction with UI below

	-- Stats panel: Anchored to RIGHT edge (responsive height)
	local statsFrame = CreateFrame("Frame", nil, parent)
	statsFrame:SetWidth(CONFIG.stats.width)
	statsFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -CONFIG.stats.marginRight, -CONFIG.stats.marginTop)
	statsFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -CONFIG.stats.marginRight, CONFIG.stats.marginBottom)
	statsFrame:SetFrameLevel(equipmentFrame:GetFrameLevel() + 20)  -- Above blocker and slots
	statsFrame:EnableMouse(true)  -- Allow hover on stats panel

	-- Create equipment slots (from components)
	self:CreateEquipmentSlots(equipmentFrame, CONFIG.equipment)

	-- Create stats panel (from components)
	self:CreateStatsPanel(statsFrame)

	-- Store references
	equipmentFrame.statsFrame = statsFrame

	-- Initialize all frames to alpha 0 (ready for animation)
	for _, slot in ipairs(equipmentFrame.equipmentSlots) do
		slot:SetAlpha(0)
	end
	statsFrame:SetAlpha(0)

	return equipmentFrame, statsFrame
end

-- Show Equipment Tab (called when tab becomes active)
function E:ShowEquipmentTab()
	if not self.MainFrame then return end

	print("[EquipmentTab] ShowEquipmentTab called")

	-- Prepare tab: reset all frames to hidden state
	self.AnimationManager:PrepareTab({
		equipmentSlots = self.MainFrame.equipmentSlots,
		statsFrame = self.MainFrame.statsFrame,
	})

	-- Set Camera.onReady callback for this tab's animations
	E.Camera.onReady = function()
		print("[EquipmentTab] Camera.onReady callback triggered")
		if CONFIG.animations.enabled then
			E.AnimationManager:AnimateTab(function()
				E.AnimationManager:AnimateEquipmentTab(E.MainFrame)
			end)
		else
			-- No animations, show everything instantly and release lock
			E.AnimationManager:ShowInstantFrames(E.MainFrame.equipmentSlots)
			E.AnimationManager:ShowInstant(E.MainFrame.statsFrame)
			E.AnimationManager.isTransitioning = false
		end
	end

	-- Apply camera mode (will trigger onReady when complete)
	self.CameraPresets:EnterEquipmentView(true)  -- Animate
end

-- Hide Equipment Tab (called when switching away)
function E:HideEquipmentTab()
	-- Cleanup if needed
end
