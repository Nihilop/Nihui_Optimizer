local _, ns = ...
local E = ns.E

-- ============================================================================
-- TAB 4: MAP VIEW
-- Character on right, Blizzard world map embedded on left half
-- ============================================================================

-- CONFIGURATION
local CONFIG = {
	-- Camera settings
	cameraMode = "MAP_VIEW",

	-- Container margins (space around map frame)
	container = {
		marginLeft = 40,    -- Space from left edge of screen
		marginTop = 40,     -- Space from top
		marginBottom = 40,  -- Space from bottom
		marginRight = 40,   -- Space from right (space for character)

		-- Optional: Add extra padding inside container
		paddingTop = 10,
		paddingRight = 10,
		paddingBottom = 10,
		paddingLeft = 10,
	},

	-- Container backdrop (optional)
	backdrop = {
		enabled = false,  -- Disabled (map provides its own background)
		bgColor = {0.05, 0.05, 0.05, 0.9},
		borderColor = {0.3, 0.3, 0.3, 1},
	},

	-- Animations
	animations = {
		enabled = true,
		fadeInDuration = 0.4,
	},
}

-- Export config
E.MapTabConfig = CONFIG

-- Store original parent and state
local originalMapParent = nil
local originalMapPoints = {}
local isEmbedded = false

-- Get Blizzard's world map frame
local function GetBlizzardMapFrame()
	-- WorldMapFrame is the main map frame in retail
	if WorldMapFrame then
		return WorldMapFrame
	end
	return nil
end

-- Hide unwanted elements from Blizzard map UI
local function HideUnwantedElements(mapFrame)
	if not mapFrame then return end

	print("[MapTab] Hiding unwanted WorldMapFrame elements...")

	-- Hide common UI elements we don't want
	local elementsToHide = {
		"BorderFrame",      -- Close button and title bar
		"TitleContainer",   -- Title "Carte & journal des quêtes"
		"CloseButton",
		"QuestLog",         -- IMPORTANT: Hide quest log panel (right side)
		"SidePanelToggle",  -- Toggle button for quest log
		"NavBar",           -- Navigation bar (dropdowns: Monde, Azeroth, etc.)
		"overlayFrames",    -- Overlay frames (pins, tracking, etc.)
	}

	for _, elementName in ipairs(elementsToHide) do
		local element = mapFrame[elementName]
		if element and element.Hide then
			element:Hide()
			print("[MapTab] Hidden: " .. elementName)
		end
	end

	-- Hide title bar if it exists
	if mapFrame.TitleBar then
		mapFrame.TitleBar:Hide()
	end

	-- Hide borders/backdrop for clean integration
	if mapFrame.BorderFrame then
		mapFrame.BorderFrame:Hide()
	end

	-- CRITICAL: Force map to full width (hide quest log)
	if mapFrame.QuestLog then
		mapFrame.QuestLog:Hide()
		mapFrame.QuestLog:SetAlpha(0)
	end

	-- Hide side panel toggle button (quest log toggle)
	if mapFrame.SidePanelToggle then
		mapFrame.SidePanelToggle:Hide()
	end

	-- Hide navigation bar (zone dropdowns)
	if mapFrame.NavBar then
		mapFrame.NavBar:Hide()
	end

	-- Hide overlay frames (quest objectives, pins, etc.) - OPTIONAL
	-- if mapFrame.overlayFrames then
	-- 	for _, overlay in ipairs(mapFrame.overlayFrames) do
	-- 		if overlay.Hide then
	-- 			overlay:Hide()
	-- 		end
	-- 	end
	-- end

	print("[MapTab] Finished hiding unwanted elements")
end

-- Show previously hidden elements (when restoring)
local function ShowHiddenElements(mapFrame)
	if not mapFrame then return end

	print("[MapTab] Restoring hidden WorldMapFrame elements...")

	-- Show elements
	local elementsToShow = {
		"BorderFrame",
		"TitleContainer",
		"CloseButton",
		"TitleBar",
		"QuestLog",        -- Restore quest log
		"SidePanelToggle", -- Restore toggle button
		"NavBar",          -- Restore navigation bar
	}

	for _, elementName in ipairs(elementsToShow) do
		local element = mapFrame[elementName]
		if element and element.Show then
			element:Show()
			print("[MapTab] Restored: " .. elementName)
		end
	end

	if mapFrame.BorderFrame then
		mapFrame.BorderFrame:Show()
	end

	-- Restore quest log alpha
	if mapFrame.QuestLog then
		mapFrame.QuestLog:SetAlpha(1)
	end

	print("[MapTab] Finished restoring elements")
end

-- Embed map frame into our container
local function EmbedMap(container)
	local mapFrame = GetBlizzardMapFrame()
	if not mapFrame then
		print("[MapTab] ERROR: WorldMapFrame not found")
		return false
	end

	-- Save original state (only once)
	if not originalMapParent then
		originalMapParent = mapFrame:GetParent()
		originalMapPoints = {}
		for i = 1, mapFrame:GetNumPoints() do
			local point, relativeTo, relativePoint, xOfs, yOfs = mapFrame:GetPoint(i)
			table.insert(originalMapPoints, {point, relativeTo, relativePoint, xOfs, yOfs})
		end
		print("[MapTab] Saved original map state")
	end

	-- CRITICAL: Force map into maximized mode (fullscreen-like, clean map)
	-- Try multiple approaches to get clean map
	if mapFrame.Maximize then
		mapFrame:Maximize()
		print("[MapTab] Map set to Maximize mode")
	elseif mapFrame.SetFullscreenMode then
		mapFrame:SetFullscreenMode(true)
		print("[MapTab] Map set to Fullscreen mode")
	else
		print("[MapTab] WARNING: No Maximize/SetFullscreenMode method found")
	end

	-- Force hide quest log explicitly (redundant but safer)
	if mapFrame.QuestLog then
		mapFrame.QuestLog:Hide()
		mapFrame.QuestLog:SetAlpha(0)
		print("[MapTab] Forcefully hid QuestLog")
	end

	-- Hide unwanted UI elements (title bar, close button, etc.)
	HideUnwantedElements(mapFrame)

	-- Reparent to our container
	mapFrame:SetParent(container)
	mapFrame:ClearAllPoints()

	-- Fill container with padding
	local padding = CONFIG.container.paddingTop
	mapFrame:SetPoint("TOPLEFT", container, "TOPLEFT", padding, -padding)
	mapFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -padding, padding)

	-- Set frame level
	mapFrame:SetFrameLevel(container:GetFrameLevel() + 10)

	-- Force map to be visible
	mapFrame:Show()

	-- Set map to current zone
	if mapFrame.SetMapID then
		local mapID = C_Map.GetBestMapForUnit("player")
		if mapID then
			mapFrame:SetMapID(mapID)
		end
	end

	isEmbedded = true
	print("[MapTab] Map embedded successfully in maximized mode")
	return true
end

-- Restore map to original state
local function RestoreMap()
	local mapFrame = GetBlizzardMapFrame()
	if not mapFrame or not originalMapParent then
		print("[MapTab] No original state to restore")
		return
	end

	print("[MapTab] Restoring map to original position...")

	-- Restore map to normal mode (minimize)
	if mapFrame.Minimize then
		mapFrame:Minimize()
		print("[MapTab] Map set to Minimize mode")
	elseif mapFrame.SetFullscreenMode then
		mapFrame:SetFullscreenMode(false)
		print("[MapTab] Map fullscreen mode disabled")
	end

	-- Show hidden elements
	ShowHiddenElements(mapFrame)

	-- Restore parent
	mapFrame:SetParent(originalMapParent)

	-- Restore position
	mapFrame:ClearAllPoints()
	for _, pointData in ipairs(originalMapPoints) do
		mapFrame:SetPoint(unpack(pointData))
	end

	isEmbedded = false
	print("[MapTab] Map restored to normal mode")
end

-- Create Map Tab UI
function E:CreateMapTab(parent)
	-- Map container: Left side of screen
	local mapContainer = CreateFrame("Frame", nil, parent)
	mapContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", CONFIG.container.marginLeft, -CONFIG.container.marginTop)
	mapContainer:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", CONFIG.container.marginLeft, CONFIG.container.marginBottom)

	-- Width: Half screen minus character space
	local screenWidth = parent:GetWidth()
	local containerWidth = (screenWidth * 0.5) - CONFIG.container.marginLeft - 50  -- Leave space for character
	mapContainer:SetWidth(containerWidth)

	mapContainer:SetFrameLevel(parent:GetFrameLevel() + 10)
	mapContainer:EnableMouse(true)  -- Block clicks from going through

	-- Optional backdrop
	if CONFIG.backdrop.enabled then
		mapContainer:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			tile = false,
			edgeSize = 1,
		})
		mapContainer:SetBackdropColor(unpack(CONFIG.backdrop.bgColor))
		mapContainer:SetBackdropBorderColor(unpack(CONFIG.backdrop.borderColor))
	end

	-- Store reference
	parent.mapContainer = mapContainer

	-- Initialize container to alpha 0 (ready for animation)
	mapContainer:SetAlpha(0)

	print("[MapTab] Map container created")
	return mapContainer
end

-- Show Map Tab (called when tab becomes active)
function E:ShowMapTab()
	if not self.MainFrame then return end

	print("[MapTab] ShowMapTab called")

	-- Prepare tab: reset to hidden state
	if self.MainFrame.mapContainer then
		self.MainFrame.mapContainer:SetAlpha(0)
	end

	-- Apply camera preset
	E.CameraPresets:EnterMapView(true)

	-- Set Camera.onReady callback for this tab's animations
	E.Camera.onReady = function()
		print("[MapTab] Camera.onReady callback triggered")

		-- Embed map into container
		if self.MainFrame.mapContainer then
			EmbedMap(self.MainFrame.mapContainer)

			-- Animate container
			if CONFIG.animations.enabled and E.Animations then
				E.Animations:FadeIn(self.MainFrame.mapContainer, CONFIG.animations.fadeInDuration)
			else
				self.MainFrame.mapContainer:SetAlpha(1)
			end
		end
	end

	-- Trigger camera transition (which will call onReady when done)
	if E.Camera.isZoomed then
		-- Camera already active, transition will trigger onReady
		print("[MapTab] Camera already zoomed, transition in progress")
	else
		-- Camera not active yet, will trigger onReady after initial zoom
		print("[MapTab] Camera not yet zoomed, waiting for initial zoom")
	end
end

-- Hide Map Tab (called when switching away from this tab)
function E:HideMapTab()
	print("[MapTab] HideMapTab called")

	-- Restore map to original state
	RestoreMap()

	-- Hide container
	if self.MainFrame and self.MainFrame.mapContainer then
		self.MainFrame.mapContainer:Hide()
	end
end
