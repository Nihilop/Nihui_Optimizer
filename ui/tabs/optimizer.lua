local _, ns = ...
local E = ns.E

-- ============================================================================
-- TAB 2: OPTIMIZER VIEW
-- Large panel on left for optimization content, character on right
-- ============================================================================

-- CONFIGURATION (modify here for easy adjustments)
local CONFIG = {
	-- Camera settings (handled by CameraPresets, but listed here for reference)
	cameraMode = "LEFT_PANEL_VIEW",

	-- Left panel positioning
	panel = {
		width = 700,          -- Panel width
		marginLeft = 20,
		marginTop = 80,
		marginBottom = 20,
	},

	-- Future: Optimizer content layout
	content = {
		titleFontSize = 16,
		descriptionFontSize = 12,
	},
}

-- Export config for external access
E.OptimizerTabConfig = CONFIG

-- Create Optimizer Tab UI
function E:CreateOptimizerTab(parent)
	-- Main container: Covers entire tab area and blocks clicks
	local container = CreateFrame("Frame", nil, parent)
	container:SetAllPoints(parent)
	container:EnableMouse(true)  -- Block clicks to prevent interaction with UI below

	-- Left panel: Takes most of the space (for optimization content)
	local leftPanel = CreateFrame("Frame", nil, container, "BackdropTemplate")
	leftPanel:SetWidth(CONFIG.panel.width)

	-- Anchor to fill height on the left
	leftPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", CONFIG.panel.marginLeft, -CONFIG.panel.marginTop)
	leftPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", CONFIG.panel.marginLeft, CONFIG.panel.marginBottom)

	-- Create simple backdrop
	E:CreateSimpleBackdrop(leftPanel, 0.9)

	-- Title
	local title = leftPanel:CreateFontString(nil, "OVERLAY")
	title:SetFont("Fonts\\FRIZQT__.TTF", CONFIG.content.titleFontSize, "OUTLINE")
	title:SetPoint("TOP", leftPanel, "TOP", 0, -15)
	title:SetTextColor(0, 1, 0, 1)
	title:SetText("Gear Optimizer")
	leftPanel.title = title

	-- Placeholder content
	local description = leftPanel:CreateFontString(nil, "OVERLAY")
	description:SetFont("Fonts\\FRIZQT__.TTF", CONFIG.content.descriptionFontSize, "OUTLINE")
	description:SetPoint("TOP", title, "BOTTOM", 0, -20)
	description:SetTextColor(0.8, 0.8, 0.8, 1)
	description:SetText("Optimization features coming soon...")
	description:SetJustifyH("CENTER")

	-- TODO: Add optimizer content here
	-- - Slot recommendations
	-- - Item comparisons
	-- - Upgrade paths
	-- - Best-in-slot suggestions
	-- - etc.

	-- Initialize panel to alpha 0 (ready for animation)
	leftPanel:SetAlpha(0)

	-- Store reference for access
	container.leftPanel = leftPanel

	return container
end

-- Show Optimizer Tab (called when tab becomes active)
function E:ShowOptimizerTab()
	if not self.MainFrame then return end

	-- Prepare tab: reset all frames to hidden state
	-- optimizerPanel is now a container, prepare its leftPanel child
	local panel = self.MainFrame.optimizerPanel and self.MainFrame.optimizerPanel.leftPanel
	if panel then
		self.AnimationManager:PrepareTab({
			optimizerPanel = panel,
		})
	end

	-- Set Camera.onReady callback for this tab's animations
	E.Camera.onReady = function()
		E.AnimationManager:AnimateTab(function()
			E.AnimationManager:AnimateOptimizerTab(E.MainFrame)
		end)
	end

	-- Apply camera mode (character moves to right, will trigger onReady when complete)
	self.CameraPresets:EnterLeftPanelView(true)  -- Animate
end

-- Hide Optimizer Tab (called when switching away)
function E:HideOptimizerTab()
	-- Cleanup if needed
end
