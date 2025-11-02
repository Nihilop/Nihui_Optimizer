local _, ns = ...
local E = ns.E

E.MainFrame = nil
E.DEBUG_MODE = false -- Debug mode disabled (no colored borders)

-- Helper function to add debug border (only borders, no background)
local function AddDebugBorder(frame, r, g, b)
	if not E.DEBUG_MODE then return end

	-- Create border using separate textures (TOP, BOTTOM, LEFT, RIGHT only)
	frame.borderTop = frame:CreateTexture(nil, "OVERLAY")
	frame.borderTop:SetColorTexture(r or 1, g or 0, b or 0, 1)
	frame.borderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	frame.borderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	frame.borderTop:SetHeight(2)

	frame.borderBottom = frame:CreateTexture(nil, "OVERLAY")
	frame.borderBottom:SetColorTexture(r or 1, g or 0, b or 0, 1)
	frame.borderBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	frame.borderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	frame.borderBottom:SetHeight(2)

	frame.borderLeft = frame:CreateTexture(nil, "OVERLAY")
	frame.borderLeft:SetColorTexture(r or 1, g or 0, b or 0, 1)
	frame.borderLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	frame.borderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	frame.borderLeft:SetWidth(2)

	frame.borderRight = frame:CreateTexture(nil, "OVERLAY")
	frame.borderRight:SetColorTexture(r or 1, g or 0, b or 0, 1)
	frame.borderRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	frame.borderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	frame.borderRight:SetWidth(2)
end

-- Create responsive content frame (max-width 1920px, centered)
local function CreateContentFrame(parent)
	local content = CreateFrame("Frame", nil, parent)
	content:SetPoint("TOP", parent, "TOP", 0, 0)
	content:SetPoint("BOTTOM", parent, "BOTTOM", 0, 0)

	-- Calculate width based on screen size (max 1920px)
	local screenWidth = GetScreenWidth() * UIParent:GetEffectiveScale()
	local contentWidth = math.min(screenWidth, 1920)
	content:SetWidth(contentWidth)

	-- Add debug border
	AddDebugBorder(content, 1, 0, 0) -- Red border

	-- Update width on screen resize
	content:SetScript("OnSizeChanged", function(self)
		local newScreenWidth = GetScreenWidth() * UIParent:GetEffectiveScale()
		local newWidth = math.min(newScreenWidth, 1920)
		self:SetWidth(newWidth)
	end)

	return content
end

-- Create tab system
local function CreateTabSystem(parent)
	local tabContainer = CreateFrame("Frame", nil, parent)
	tabContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -60)
	tabContainer:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, -60)
	tabContainer:SetHeight(40)

	AddDebugBorder(tabContainer, 0, 1, 0) -- Green border for tabs

	tabContainer.tabs = {}
	tabContainer.contentFrames = {}
	tabContainer.activeTab = nil

	function tabContainer:CreateTab(name, index)
		local tab = CreateFrame("Button", nil, self)
		tab:SetSize(150, 35)
		tab:SetPoint("LEFT", self, "LEFT", (index - 1) * 160, 0)

		-- Tab background
		tab.bg = tab:CreateTexture(nil, "BACKGROUND")
		tab.bg:SetAllPoints()
		tab.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

		-- Tab text
		tab.text = tab:CreateFontString(nil, "OVERLAY")
		tab.text:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
		tab.text:SetText(name)
		tab.text:SetPoint("CENTER")

		tab.index = index
		tab.name = name

		-- Tab click handler
		tab:SetScript("OnClick", function()
			tabContainer:SelectTab(index)
		end)

		-- Hover effects
		tab:SetScript("OnEnter", function(self)
			if tabContainer.activeTab ~= index then
				self.bg:SetColorTexture(0.3, 0.3, 0.3, 0.9)
			end
		end)

		tab:SetScript("OnLeave", function(self)
			if tabContainer.activeTab ~= index then
				self.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
			end
		end)

		table.insert(self.tabs, tab)
		return tab
	end

	function tabContainer:CreateTabContent()
		local content = CreateFrame("Frame", nil, parent)
		content:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -10)
		content:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -10)
		content:SetPoint("BOTTOM", parent, "BOTTOM", 0, 20)
		content:Hide()

		AddDebugBorder(content, 0, 0, 1) -- Blue border for tab content

		table.insert(self.contentFrames, content)
		return content
	end

	function tabContainer:SelectTab(index)
		-- Prevent tab switching during transitions (avoid animation bugs)
		if E.AnimationManager and E.AnimationManager.isTransitioning then
			return
		end

		-- Don't switch if already on this tab
		if self.activeTab == index then
			return
		end

		self.activeTab = index

		-- Update tab appearances
		for i, tab in ipairs(self.tabs) do
			if i == index then
				tab.bg:SetColorTexture(0, 0.5, 0, 1) -- Active green
				tab.text:SetTextColor(1, 1, 1, 1)
			else
				tab.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
				tab.text:SetTextColor(0.7, 0.7, 0.7, 1)
			end
		end

		-- Show/hide content frames
		for i, content in ipairs(self.contentFrames) do
			if i == index then
				content:Show()
			else
				content:Hide()
			end
		end

		-- Call tab changed callback (for camera transitions)
		if self.onTabChanged then
			self.onTabChanged(index)
		end
	end

	return tabContainer
end

-- Note: Tab content creation moved to ui/tabs/equipment.lua and ui/tabs/optimizer.lua

function E:CreateMainFrame()
	if self.MainFrame then return self.MainFrame end

	-- Initialize GuideLines and CameraPresets systems FIRST
	if not self.GuideLines.initialized then
		self.GuideLines:Initialize("CHARACTER_LEFT")
		self.CameraPresets:Initialize()
		self.GuideLines.initialized = true
	end

	-- Layer 1: Main container (fullscreen overlay)
	-- Parented to NihuiParent (based on WorldFrame) for stable, reliable positioning
	local frame = CreateFrame("Frame", "NihuiOptimizerFrame", E.NihuiParent)
	frame:SetAllPoints(E.NihuiParent)  -- Fill entire NihuiParent (which fills WorldFrame)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetFrameLevel(100)
	frame:Hide()
	frame:EnableMouse(true)

	-- No full screen backdrop - using vignette overlay instead (edge darkening only)
	-- Vignette is shown/hidden separately in ShowMainFrame/HideMainFrame

	-- Layer 2: Content frame (centered, max-width 1920px)
	local contentFrame = CreateContentFrame(frame)
	frame.contentFrame = contentFrame

	-- Create close button
	local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeButton:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", -10, -10)
	closeButton:SetScript("OnClick", function()
		E:HideMainFrame()
	end)
	frame.closeButton = closeButton

	-- ESC key handler
	frame:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			-- Check if dropdown is open first
			if E.SlotDropdown and E.SlotDropdown.activeDropdown and E.SlotDropdown.activeDropdown:IsShown() then
				-- Close dropdown instead of closing frame
				E.SlotDropdown:Close(E.SlotDropdown.activeDropdown)
				self:SetPropagateKeyboardInput(false)
			-- Check if context menu is open
			elseif E.SlotContextMenu and E.SlotContextMenu.activeMenu and E.SlotContextMenu.activeMenu:IsShown() then
				-- Close context menu instead of closing frame
				E.SlotContextMenu:Hide(E.SlotContextMenu.activeMenu)
				self:SetPropagateKeyboardInput(false)
			else
				-- Nothing open, close the main frame
				E:HideMainFrame()
				self:SetPropagateKeyboardInput(false)
			end
		else
			self:SetPropagateKeyboardInput(true)
		end
	end)

	-- Make frame receive keyboard input
	frame:EnableKeyboard(true)
	frame:SetPropagateKeyboardInput(false)

	-- Register for ESC key closing
	tinsert(UISpecialFrames, "NihuiOptimizerFrame")

	-- Create title
	local title = contentFrame:CreateFontString(nil, "OVERLAY")
	title:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
	title:SetText("|cff00ff00Nihui|r |cffffffffOptimizer|r")
	title:SetPoint("TOP", contentFrame, "TOP", 0, -20)
	frame.title = title

	-- Layer 3: Tab system
	local tabSystem = CreateTabSystem(contentFrame)
	frame.tabSystem = tabSystem

	-- Create tabs (only core tabs, more can be added via TabRegistry API)
	tabSystem:CreateTab("Equipment", 1)
	tabSystem:CreateTab("Optimizer", 2)

	-- Create tab content frames
	local equipmentTabContent = tabSystem:CreateTabContent()
	local optimizerTabContent = tabSystem:CreateTabContent()

	-- Tab 1: Equipment view (character + stats) - uses ui/tabs/equipment.lua
	local equipmentFrame, statsFrame = E:CreateEquipmentTab(equipmentTabContent)
	frame.equipmentFrame = equipmentFrame
	frame.statsFrame = statsFrame

	-- Tab 2: Optimizer view (left panel + character right) - uses ui/tabs/optimizer.lua
	local optimizerPanel = E:CreateOptimizerTab(optimizerTabContent)
	frame.optimizerPanel = optimizerPanel

	-- Tab change handler (camera transitions)
	tabSystem.onTabChanged = function(tabIndex)
		-- Call cleanup for previous tab (if custom tabs have cleanup logic)
		local previousTab = tabSystem.previousTab
		if previousTab and tabSystem.tabCleanupCallbacks and tabSystem.tabCleanupCallbacks[previousTab] then
			tabSystem.tabCleanupCallbacks[previousTab]()
		end

		-- Store current tab as previous for next change
		tabSystem.previousTab = tabIndex

		-- Show new tab (core tabs)
		if tabIndex == 1 then
			-- Equipment View: character on left/center
			E:ShowEquipmentTab()
		elseif tabIndex == 2 then
			-- Optimizer View: character on right
			E:ShowOptimizerTab()
		else
			-- Custom tabs: call their show callback if registered
			if tabSystem.tabShowCallbacks and tabSystem.tabShowCallbacks[tabIndex] then
				tabSystem.tabShowCallbacks[tabIndex]()
			end
		end
	end

	-- Initialize callback registries for custom tabs
	tabSystem.tabShowCallbacks = {}
	tabSystem.tabCleanupCallbacks = {}
	tabSystem.tabPrepareCallbacks = {}
	tabSystem.tabOnReadyCallbacks = {}

	-- Store reference BEFORE initializing custom tabs
	self.MainFrame = frame

	-- Initialize custom tabs registered via TabRegistry API
	if E.TabRegistry then
		E.TabRegistry:InitializeAllTabs()
	end

	-- Select first tab by default (after all tabs are created)
	tabSystem.previousTab = nil  -- No previous tab initially
	tabSystem:SelectTab(1)

	-- Store equipment slots reference on main frame (created by tab)
	frame.equipmentSlots = equipmentFrame.equipmentSlots

	return frame
end

-- Create floating debug window for camera/positioning adjustments
local function CreateDebugWindow(parent)
	-- Parent to NihuiParent for stable positioning
	local debugWindow = CreateFrame("Frame", "NihuiOptimizerDebugWindow", E.NihuiParent, "BackdropTemplate")
	debugWindow:SetSize(300, 400)
	debugWindow:SetPoint("TOPLEFT", E.NihuiParent, "TOPLEFT", 50, -50)
	debugWindow:SetFrameStrata("FULLSCREEN_DIALOG")
	debugWindow:SetFrameLevel(200)
	debugWindow:SetMovable(true)
	debugWindow:EnableMouse(true)
	debugWindow:RegisterForDrag("LeftButton")
	debugWindow:SetClampedToScreen(true)

	-- Backdrop
	debugWindow:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	})
	debugWindow:SetBackdropColor(0, 0, 0, 0.9)
	debugWindow:SetBackdropBorderColor(1, 0, 0, 1)

	-- Make draggable
	debugWindow:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	debugWindow:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)

	-- Title
	local title = debugWindow:CreateFontString(nil, "OVERLAY")
	title:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
	title:SetText("|cffff0000DEBUG|r Camera & Position")
	title:SetPoint("TOP", debugWindow, "TOP", 0, -10)

	-- Close button
	local closeBtn = CreateFrame("Button", nil, debugWindow, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", debugWindow, "TOPRIGHT", 0, 0)

	-- Container for sliders
	local yOffset = -40
	debugWindow.sliders = {}

	local function CreateSlider(name, minVal, maxVal, defaultVal, step, onValueChanged)
		local sliderFrame = CreateFrame("Frame", nil, debugWindow)
		sliderFrame:SetSize(280, 50)
		sliderFrame:SetPoint("TOP", debugWindow, "TOP", 0, yOffset)
		yOffset = yOffset - 60

		local label = sliderFrame:CreateFontString(nil, "OVERLAY")
		label:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
		label:SetText(name)
		label:SetPoint("TOPLEFT", sliderFrame, "TOPLEFT", 10, -5)

		local valueText = sliderFrame:CreateFontString(nil, "OVERLAY")
		valueText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
		valueText:SetText(string.format("%.2f", defaultVal))
		valueText:SetPoint("TOPRIGHT", sliderFrame, "TOPRIGHT", -10, -5)

		local slider = CreateFrame("Slider", nil, sliderFrame, "OptionsSliderTemplate")
		slider:SetPoint("BOTTOM", sliderFrame, "BOTTOM", 0, 5)
		slider:SetWidth(260)
		slider:SetMinMaxValues(minVal, maxVal)
		slider:SetValue(defaultVal)
		slider:SetValueStep(step)
		slider:SetObeyStepOnDrag(true)

		slider:SetScript("OnValueChanged", function(self, value)
			valueText:SetText(string.format("%.2f", value))
			if onValueChanged then
				onValueChanged(value)
			end
		end)

		sliderFrame.slider = slider
		sliderFrame.valueText = valueText

		return sliderFrame
	end

	-- Camera distance slider
	CreateSlider("Camera Distance", 0.5, 10, 4.5, 0.1, function(value)
		if E.Camera.isZoomed then
			E.Camera.debugZoom = value
			-- Apply zoom change
			local currentZoom = GetCameraZoom()
			if currentZoom > value then
				CameraZoomIn(currentZoom - value)
			else
				CameraZoomOut(value - currentZoom)
			end
		end
	end)

	-- Camera shoulder offset
	CreateSlider("Camera Shoulder", -2, 2, -0.66, 0.01, function(value)
		if E.Camera.isZoomed then
			C_CVar.SetCVar("test_cameraOverShoulder", value)
		end
	end)

	-- Camera yaw (rotation)
	CreateSlider("Camera Yaw", -180, 180, 0, 1, function(value)
		if E.Camera.isZoomed then
			E.Camera.debugYaw = value
			-- Note: WoW API has limited control over camera yaw in this mode
		end
	end)

	-- Equipment X offset
	CreateSlider("Equipment X Offset", -500, 500, 0, 10, function(value)
		if parent and parent.equipmentFrame then
			-- Store offset for repositioning
			E.equipmentOffsetX = value
		end
	end)

	-- Equipment Y offset
	CreateSlider("Equipment Y Offset", -500, 500, 0, 10, function(value)
		if parent and parent.equipmentFrame then
			E.equipmentOffsetY = value
		end
	end)

	-- Reset button
	local resetBtn = CreateFrame("Button", nil, debugWindow, "UIPanelButtonTemplate")
	resetBtn:SetSize(120, 25)
	resetBtn:SetPoint("BOTTOM", debugWindow, "BOTTOM", 0, 10)
	resetBtn:SetText("Reset Values")
	resetBtn:SetScript("OnClick", function()
		for _, sliderFrame in ipairs(debugWindow.sliders) do
			sliderFrame.slider:SetValue(sliderFrame.slider:GetMinMaxValues())
		end
	end)

	debugWindow:Hide()
	return debugWindow
end

function E:CreateDebugWindow()
	if self.DebugWindow then return self.DebugWindow end
	self.DebugWindow = CreateDebugWindow(self.MainFrame)
	return self.DebugWindow
end

function E:ToggleDebugWindow()
	if not self.DebugWindow then
		self:CreateDebugWindow()
	end

	if self.DebugWindow:IsShown() then
		self.DebugWindow:Hide()
	else
		self.DebugWindow:Show()
	end
end

function E:ShowMainFrame()
	if not self.MainFrame then
		self:CreateMainFrame()
	end

	local frame = self.MainFrame

	-- STEP 1: Fade OUT the WoW UI FIRST (before showing anything)
	E.UIParentFade:FadeOutUIParent()

	-- STEP 1.5: Hide other addon frames from WorldFrame (Narcissus, etc.)
	if E.WorldFrameCleanup then
		E.WorldFrameCleanup:HideOtherFrames()
	end

	-- Prepare active tab for animation
	local activeTab = frame.tabSystem.activeTab or 1

	if activeTab == 1 then
		-- Prepare Equipment Tab
		self.AnimationManager:PrepareTab({
			equipmentSlots = frame.equipmentSlots,
			statsFrame = frame.statsFrame,
		})
		self.CameraPresets:EnterEquipmentView(false)  -- No animation
	elseif activeTab == 2 then
		-- Prepare Optimizer Tab
		self.AnimationManager:PrepareTab({
			optimizerPanel = frame.optimizerPanel,
		})
		self.CameraPresets:EnterLeftPanelView(false)  -- No animation
	else
		-- Custom tabs: call their prepare callback if registered
		if frame.tabSystem.tabPrepareCallbacks and frame.tabSystem.tabPrepareCallbacks[activeTab] then
			frame.tabSystem.tabPrepareCallbacks[activeTab]()
		end
	end

	-- STEP 2: Show vignette overlay (edge darkening effect like Narcissus)
	E.VignetteOverlay:Show()

	-- STEP 3: Show frame
	frame:Show()

	-- STEP 3.5: Start tooltip enforcer (forces GameTooltip visible despite SetUIVisibility)
	E:StartTooltipEnforcer()

	-- STEP 3.6: Show chat button (bottom-left floating button)
	if E.ChatOverlay then
		E.ChatOverlay:ShowButton()
		E.ChatOverlay:EnableKeybinding(frame)
	end

	-- Enable auto-close on movement (if enabled in settings)
	if E.MovementDetector:ShouldCloseOnMove() then
		E.MovementDetector:Enable(function()
			E:HideMainFrame()
		end)
	end

	-- Show debug window if in debug mode
	if self.DEBUG_MODE then
		if not self.DebugWindow then
			self:CreateDebugWindow()
		end
		self.DebugWindow:Show()
	end

	-- Set Camera.onReady callback BEFORE starting zoom
	-- This triggers animations when camera animation completes
	E.Camera.onReady = function()
		print("[MainFrame] Camera.onReady called for tab " .. activeTab)

		-- Trigger animations based on active tab
		if activeTab == 1 then
			E.AnimationManager:AnimateTab(function()
				E.AnimationManager:AnimateEquipmentTab(frame)
			end)
		elseif activeTab == 2 then
			E.AnimationManager:AnimateTab(function()
				E.AnimationManager:AnimateOptimizerTab(frame)
			end)
		else
			-- Custom tabs: call their onReady callback if registered
			if frame.tabSystem.tabOnReadyCallbacks and frame.tabSystem.tabOnReadyCallbacks[activeTab] then
				frame.tabSystem.tabOnReadyCallbacks[activeTab]()
			else
				-- No custom callback, just release the transition lock
				E.AnimationManager.isTransitioning = false
			end
		end
	end

	-- STEP 4: Start camera zoom with callback
	E.Camera:ZoomIn()
end

function E:HideMainFrame()
	if not self.MainFrame then return end

	local frame = self.MainFrame

	-- Stop tooltip enforcer
	E:StopTooltipEnforcer()

	-- Hide chat button and disable keybinding
	if E.ChatOverlay then
		E.ChatOverlay:HideButton()
		E.ChatOverlay:DisableKeybinding(frame)
	end

	-- Disable movement detection
	E.MovementDetector:Disable()

	-- Hide debug window
	if self.DebugWindow then
		self.DebugWindow:Hide()
	end

	-- Cleanup custom tabs (if they registered cleanup callbacks)
	if self.MainFrame and self.MainFrame.tabSystem then
		local tabSystem = self.MainFrame.tabSystem

		-- Call onHide callbacks
		if tabSystem.tabCleanupCallbacks then
			for tabIndex, cleanupCallback in pairs(tabSystem.tabCleanupCallbacks) do
				cleanupCallback()
			end
		end

		-- Call full cleanup (onCleanup) callbacks
		if tabSystem.tabFullCleanupCallbacks then
			for tabIndex, cleanupCallback in pairs(tabSystem.tabFullCleanupCallbacks) do
				cleanupCallback()
			end
		end
	end

	-- STEP 1: Hide vignette overlay FIRST
	E.VignetteOverlay:Hide()

	-- STEP 2: Zoom out camera and hide frame
	E.Camera:ZoomOut(function()
		frame:Hide()

		-- STEP 3: Restore WorldFrame addon frames
		if E.WorldFrameCleanup then
			E.WorldFrameCleanup:RestoreFrames()
		end

		-- STEP 4: Fade IN the WoW UI AFTER everything is hidden
		E.UIParentFade:FadeInUIParent()
	end)
end

function E:ToggleMainFrame()
	if not self.MainFrame then
		self:ShowMainFrame()
	elseif self.MainFrame:IsShown() then
		self:HideMainFrame()
	else
		self:ShowMainFrame()
	end
end
