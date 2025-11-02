local _, ns = ...
local E = ns.E

-- ============================================================================
-- TAB 4: MAP VIEW - CANVAS SOLUTION
-- Character on right, PURE map canvas (no Blizzard UI chrome) on left
-- ============================================================================

--[[
APPROACH: Instead of embedding entire WorldMapFrame (which contains borders,
title bars, quest log, etc.), we reparent the ScrollContainer:

WorldMapFrame hierarchy:
├── BorderFrame          ← UI chrome (hidden)
├── NavBar               ← Navigation (hidden)
├── QuestLog             ← Quest panel (hidden)
├── ScrollContainer      ← ✅ Reparent this! (contains zoom/pan logic + canvas)
│   └── Child            ← Map canvas (inside ScrollContainer)
└── overlayFrames        ← Pins, icons (kept)

By reparenting ScrollContainer, we get:
- Clean map without Blizzard UI chrome
- Full interaction support (pan, zoom, click)
- All zoom/scroll logic preserved

IMPORTANT: ScrollContainer expects callback methods on its parent:
- OnCanvasScaleChanged(child) - called when zoom changes
- OnCanvasPanChanged(child) - called when map is panned/scrolled
- UpdateAreaTriggers() - called to refresh area triggers
- ProcessCanvasClickHandlers(button, x, y) - called on map clicks
- NavigateToParentMap() - called on right-click to zoom to parent map

We provide stub implementations to prevent errors.

FEATURES:
- Configurable width (default: 70% screen width)
- Configurable aspect ratio (default: 16:9, no cropping)
- Fully interactive: click, drag, zoom (mousewheel)
- Ready for custom markers (C_Map.SetUserWaypoint API)

CONFIGURATION:
- CONFIG.container.widthPercent - percentage of screen width (0.70 = 70%)
- CONFIG.container.maintainAspectRatio - keep aspect ratio (true/false)
- CONFIG.container.aspectRatio - target ratio (default 16/9)
]]

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

		-- Size settings (percentage of screen)
		widthPercent = 0.80,  -- 70% of screen width for map (character takes 30%)
		maintainAspectRatio = true,  -- Keep 16:9 aspect ratio
		aspectRatio = 16 / 9,

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
local originalMapCanvasParent = nil
local originalMapCanvasPoints = {}
local originalMapCanvasScale = nil
local originalMapCanvasStrata = nil
local originalMapCanvasLevel = nil
local isEmbedded = false

-- Store map zones for searchbar/dropdown
local mapZones = {}
local mapZonesLoaded = false

-- Note: GetMapScrollContainer removed - we don't reparent ScrollContainer anymore

-- Load all available map zones
local function LoadMapZones()
	if mapZonesLoaded then return mapZones end

	mapZones = {}

	-- Get all maps from C_Map API
	for continentID = 1, 20 do  -- Iterate through continents
		local continentInfo = C_Map.GetMapInfo(continentID)
		if continentInfo then
			table.insert(mapZones, {
				mapID = continentID,
				name = continentInfo.name,
				type = "continent"
			})

			-- Get child zones
			local childMaps = C_Map.GetMapChildrenInfo(continentID, Enum.UIMapType.Zone, true)
			if childMaps then
				for _, child in ipairs(childMaps) do
					table.insert(mapZones, {
						mapID = child.mapID,
						name = child.name,
						type = "zone"
					})
				end
			end
		end
	end

	-- Sort alphabetically
	table.sort(mapZones, function(a, b) return a.name < b.name end)

	mapZonesLoaded = true
	print("[MapTab] Loaded " .. #mapZones .. " map zones")
	return mapZones
end

-- Navigate to a specific map by ID
local function NavigateToMap(mapID)
	if WorldMapFrame and WorldMapFrame.SetMapID then
		WorldMapFrame:SetMapID(mapID)
		print("[MapTab] Navigated to map: " .. (C_Map.GetMapInfo(mapID).name or "Unknown"))
		return true
	end
	return false
end

-- Hide all parasite dataProviders (quests, POIs, etc.)
local function HideParasiteDataProviders()
	if not WorldMapFrame then return end

	local hiddenCount = 0

	-- Method 1: Hide via pinPools (if they exist)
	if WorldMapFrame.pinPools then
		for pinTemplate, pinPool in pairs(WorldMapFrame.pinPools) do
			-- Check if this is a parasite template
			if pinTemplate:find("Quest") or
			   pinTemplate:find("BonusObjective") or
			   pinTemplate:find("Campaign") or
			   pinTemplate:find("FlightPoint") or
			   pinTemplate:find("ThreatObjective") then

				-- Hide all active pins in this pool
				for pin in pinPool:EnumerateActive() do
					pin:Hide()
					hiddenCount = hiddenCount + 1
				end
			end
		end
	end

	-- Method 2: Suppress specific dataProviders
	if WorldMapFrame.dataProviders then
		for _, provider in ipairs(WorldMapFrame.dataProviders) do
			-- Check provider type and suppress parasite ones
			if provider.RemoveAllData then
				-- Try to identify parasite providers by their class/type
				local providerName = tostring(provider)
				if providerName:find("Quest") or
				   providerName:find("BonusObjective") or
				   providerName:find("FlightPoint") or
				   providerName:find("WorldQuest") then
					provider:RemoveAllData()
					print("[MapTab] Removed data from provider: " .. providerName)
				end
			end
		end
	end

	print(string.format("[MapTab] Cleaned parasite pins/providers (hidden: %d)", hiddenCount))
end

-- Embed WorldMapFrame using overlay approach (keeps it fully functional)
local function EmbedMapCanvas(container)
	if not WorldMapFrame then
		print("[MapTab] ERROR: WorldMapFrame not found")
		return false
	end

	-- Save original state (only once)
	if not originalMapCanvasParent then
		originalMapCanvasParent = WorldMapFrame:GetParent()
		originalMapCanvasScale = WorldMapFrame:GetScale()
		originalMapCanvasStrata = WorldMapFrame:GetFrameStrata()
		originalMapCanvasLevel = WorldMapFrame:GetFrameLevel()

		originalMapCanvasPoints = {}
		for i = 1, WorldMapFrame:GetNumPoints() do
			local point, relativeTo, relativePoint, xOfs, yOfs = WorldMapFrame:GetPoint(i)
			table.insert(originalMapCanvasPoints, {point, relativeTo, relativePoint, xOfs, yOfs})
		end

		print("[MapTab] Saved original WorldMapFrame state")
		print(string.format("  - Original strata: %s, level: %d", originalMapCanvasStrata, originalMapCanvasLevel))
	end

	-- Set map to current zone
	local mapID = C_Map.GetBestMapForUnit("player")
	if mapID then
		WorldMapFrame:SetMapID(mapID)
	end

	-- Hide parasite dataProviders for clean map
	HideParasiteDataProviders()

	-- CRITICAL: Hide ALL Blizzard UI chrome
	if WorldMapFrame.BorderFrame then WorldMapFrame.BorderFrame:Hide() end
	if WorldMapFrame.NavBar then WorldMapFrame.NavBar:Hide() end
	if WorldMapFrame.QuestLog then WorldMapFrame.QuestLog:Hide() end
	if WorldMapFrame.SidePanelToggle then WorldMapFrame.SidePanelToggle:Hide() end
	if WorldMapFrame.TitleContainer then WorldMapFrame.TitleContainer:Hide() end

	-- OVERLAY APPROACH: Position WorldMapFrame as fullscreen overlay
	-- Keep original parent (UIParent) for stability
	WorldMapFrame:ClearAllPoints()

	-- Get container position - use GetRect for safety
	local containerLeft = container:GetLeft()
	local containerBottom = container:GetBottom()
	local containerWidth = container:GetWidth()
	local containerHeight = container:GetHeight()

	-- Safety check: if container position is nil, use fallback
	if not containerLeft or not containerBottom or not containerWidth or not containerHeight then
		print("[MapTab] ERROR: Container position not ready, using fallback")
		-- Fallback: position on left side of screen
		containerLeft = 40
		containerBottom = 40
		containerWidth = E.NihuiParent:GetWidth() * 0.6
		containerHeight = E.NihuiParent:GetHeight() - 140
	end

	WorldMapFrame:SetPoint("BOTTOMLEFT", E.NihuiParent, "BOTTOMLEFT", containerLeft, containerBottom)
	WorldMapFrame:SetSize(containerWidth, containerHeight)

	-- CRITICAL: Set frame strata HIGH to be above EVERYTHING
	WorldMapFrame:SetFrameStrata("TOOLTIP")  -- Highest non-fullscreen strata
	WorldMapFrame:SetFrameLevel(9999)  -- Maximum level

	-- Raise to top
	WorldMapFrame:Raise()

	-- Force WorldMapFrame to be interactive
	WorldMapFrame:EnableMouse(true)
	WorldMapFrame:EnableMouseWheel(true)

	-- Make sure it's visible
	WorldMapFrame:Show()
	WorldMapFrame:SetAlpha(1)

	-- CRITICAL: Force WorldMapFrame to open properly first
	-- This ensures all internal systems are initialized
	if not WorldMapFrame:IsShown() then
		WorldMapFrame:SetMapID(C_Map.GetBestMapForUnit("player"))
	end

	-- Force a refresh of the map canvas
	local currentMapID = WorldMapFrame:GetMapID()
	if currentMapID then
		-- Refresh twice to ensure textures load
		WorldMapFrame:SetMapID(currentMapID)
		C_Timer.After(0.1, function()
			if WorldMapFrame and WorldMapFrame:GetMapID() == currentMapID then
				WorldMapFrame:SetMapID(currentMapID)
			end
		end)
	end

	-- Force the ScrollContainer to refresh (if it exists)
	if WorldMapFrame.ScrollContainer then
		WorldMapFrame.ScrollContainer:SetCanvasScale(WorldMapFrame.ScrollContainer:GetCanvasScale())
	end

	isEmbedded = true
	print("[MapTab] WorldMapFrame positioned as overlay")
	print(string.format("[MapTab] Position: %.0f, %.0f | Size: %.0fx%.0f",
		containerLeft or 0, containerBottom or 0, containerWidth or 0, containerHeight or 0))

	return true
end

-- Restore WorldMapFrame to original state
local function RestoreMapCanvas()
	if not WorldMapFrame or not originalMapCanvasParent then
		print("[MapTab] No original state to restore")
		return
	end

	print("[MapTab] Restoring WorldMapFrame to original state...")

	-- Restore parent (CRITICAL: this was missing!)
	WorldMapFrame:SetParent(originalMapCanvasParent)

	-- Restore position
	WorldMapFrame:ClearAllPoints()
	for _, pointData in ipairs(originalMapCanvasPoints) do
		WorldMapFrame:SetPoint(unpack(pointData))
	end

	-- Restore scale
	if originalMapCanvasScale then
		WorldMapFrame:SetScale(originalMapCanvasScale)
	end

	-- Restore frame strata/level to original values
	if originalMapCanvasStrata then
		WorldMapFrame:SetFrameStrata(originalMapCanvasStrata)
	end
	if originalMapCanvasLevel then
		WorldMapFrame:SetFrameLevel(originalMapCanvasLevel)
	end

	-- Restore Blizzard UI chrome
	if WorldMapFrame.BorderFrame then WorldMapFrame.BorderFrame:Show() end
	if WorldMapFrame.NavBar then WorldMapFrame.NavBar:Show() end
	if WorldMapFrame.QuestLog then WorldMapFrame.QuestLog:Show() end
	if WorldMapFrame.SidePanelToggle then WorldMapFrame.SidePanelToggle:Show() end
	if WorldMapFrame.TitleContainer then WorldMapFrame.TitleContainer:Show() end

	isEmbedded = false
	print("[MapTab] WorldMapFrame restored to original state")
end

-- Create map navigation controls (searchbar + dropdown + zoom buttons)
local function CreateMapControls(parent, mapContainer)
	-- Control bar container (top of map)
	local controlBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	controlBar:SetPoint("BOTTOMLEFT", mapContainer, "TOPLEFT", 0, 5)
	controlBar:SetPoint("BOTTOMRIGHT", mapContainer, "TOPRIGHT", 0, 5)
	controlBar:SetHeight(35)
	controlBar:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		tile = false,
		edgeSize = 1,
	})
	controlBar:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
	controlBar:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

	-- Searchbar with autocomplete
	local searchBar = CreateFrame("EditBox", nil, controlBar, "InputBoxTemplate")
	searchBar:SetPoint("LEFT", controlBar, "LEFT", 10, 0)
	searchBar:SetSize(200, 25)
	searchBar:SetAutoFocus(false)
	searchBar:SetMaxLetters(50)
	searchBar:SetFontObject("ChatFontNormal")

	-- Placeholder text
	local placeholder = searchBar:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	placeholder:SetPoint("LEFT", searchBar, "LEFT", 5, 0)
	placeholder:SetText("Search zone...")

	searchBar:SetScript("OnTextChanged", function(self, userInput)
		if self:GetText() == "" then
			placeholder:Show()
		else
			placeholder:Hide()
		end

		if userInput then
			-- Filter zones based on input
			local text = self:GetText():lower()
			-- TODO: Show autocomplete suggestions
		end
	end)

	searchBar:SetScript("OnEnterPressed", function(self)
		local text = self:GetText():lower()
		local zones = LoadMapZones()

		-- Find matching zone
		for _, zone in ipairs(zones) do
			if zone.name:lower():find(text, 1, true) then
				NavigateToMap(zone.mapID)
				self:ClearFocus()
				return
			end
		end

		print("[MapTab] Zone not found: " .. text)
	end)

	searchBar:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)

	-- Dropdown for quick zone selection
	local dropdown = CreateFrame("Frame", nil, controlBar, "UIDropDownMenuTemplate")
	dropdown:SetPoint("LEFT", searchBar, "RIGHT", 10, -2)
	UIDropDownMenu_SetWidth(dropdown, 150)
	UIDropDownMenu_SetText(dropdown, "Quick Select")

	UIDropDownMenu_Initialize(dropdown, function(self, level)
		local zones = LoadMapZones()
		local info = UIDropDownMenu_CreateInfo()

		-- Current zone
		info.text = "Current Zone"
		info.func = function()
			local mapID = C_Map.GetBestMapForUnit("player")
			if mapID then
				NavigateToMap(mapID)
			end
		end
		UIDropDownMenu_AddButton(info, level)

		-- Separator
		info = UIDropDownMenu_CreateInfo()
		info.text = ""
		info.isTitle = true
		info.notCheckable = true
		UIDropDownMenu_AddButton(info, level)

		-- Popular zones (first 10)
		for i = 1, math.min(10, #zones) do
			info = UIDropDownMenu_CreateInfo()
			info.text = zones[i].name
			info.value = zones[i].mapID
			info.func = function()
				NavigateToMap(zones[i].mapID)
				UIDropDownMenu_SetText(dropdown, zones[i].name)
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end)

	-- Note: Zoom is handled natively by WorldMapFrame now (mousewheel)
	-- No custom zoom buttons needed

	-- Load zones on first show
	LoadMapZones()

	return controlBar
end

-- Create Map Tab UI
function E:CreateMapTab(parent)
	-- Map container: Left side of screen with configurable size
	local mapContainer = CreateFrame("Frame", nil, parent, "BackdropTemplate")

	-- Calculate available space for map (left side)
	local screenWidth = parent:GetWidth()
	local screenHeight = parent:GetHeight()

	-- Calculate maximum width (using CONFIG.container.widthPercent)
	local maxWidth = (screenWidth * CONFIG.container.widthPercent) - CONFIG.container.marginLeft - CONFIG.container.marginRight
	local maxHeight = screenHeight - CONFIG.container.marginTop - CONFIG.container.marginBottom

	local containerWidth = maxWidth
	local containerHeight = maxHeight

	-- Maintain aspect ratio if enabled
	if CONFIG.container.maintainAspectRatio then
		local aspectRatio = CONFIG.container.aspectRatio or (16 / 9)
		containerHeight = containerWidth / aspectRatio

		-- If height exceeds available space, adjust based on height instead
		if containerHeight > maxHeight then
			containerHeight = maxHeight
			containerWidth = containerHeight * aspectRatio
		end
	end

	-- Set size and position
	mapContainer:SetSize(containerWidth, containerHeight)
	mapContainer:SetPoint("LEFT", parent, "LEFT", CONFIG.container.marginLeft, 0)

	mapContainer:SetFrameLevel(parent:GetFrameLevel() + 10)
	-- IMPORTANT: Do NOT EnableMouse - we want clicks to pass through to the ScrollContainer!
	mapContainer:EnableMouse(false)

	-- Optional backdrop (useful for debugging)
	if CONFIG.backdrop.enabled then
		mapContainer:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			tile = false,
			edgeSize = 2,
		})
		mapContainer:SetBackdropColor(unpack(CONFIG.backdrop.bgColor))
		mapContainer:SetBackdropBorderColor(unpack(CONFIG.backdrop.borderColor))
	end

	-- Store reference
	parent.mapContainer = mapContainer

	-- DON'T create controls at load time - create them on first show
	-- (Blizzard templates may not be ready yet)
	parent.mapControlBar = nil
	parent.mapControlsCreated = false

	-- Initialize to alpha 0 (ready for animation)
	mapContainer:SetAlpha(0)

	print(string.format("[MapTab] Map container created: %.0fx%.0f (controls deferred)",
		containerWidth, containerHeight))
	return mapContainer
end

-- Show Map Tab (called when tab becomes active)
function E:ShowMapTab()
	if not self.MainFrame then return end

	print("[MapTab] ShowMapTab called (canvas solution)")

	-- Create controls on first show (when Blizzard templates are ready)
	if not self.MainFrame.mapControlsCreated and self.MainFrame.mapContainer then
		print("[MapTab] Creating controls on first show...")
		local success, controlBar = pcall(CreateMapControls, self.MainFrame, self.MainFrame.mapContainer)

		if success then
			self.MainFrame.mapControlBar = controlBar
			self.MainFrame.mapControlsCreated = true
			print("[MapTab] Controls created successfully")
		else
			print("[MapTab] ERROR creating controls:", controlBar)
			self.MainFrame.mapControlsCreated = true -- Don't retry
		end
	end

	-- Prepare tab: reset to hidden state
	if self.MainFrame.mapContainer then
		self.MainFrame.mapContainer:SetAlpha(0)
		self.MainFrame.mapContainer:Show()  -- Make sure container is visible
	end
	if self.MainFrame.mapControlBar then
		self.MainFrame.mapControlBar:SetAlpha(0)
		self.MainFrame.mapControlBar:Show()  -- Make sure controls are visible
	end

	-- Apply camera preset
	E.CameraPresets:EnterMapView(true)

	-- Set Camera.onReady callback for this tab's animations
	E.Camera.onReady = function()
		print("[MapTab] Camera.onReady callback triggered")

		-- Embed pure map canvas into container
		if self.MainFrame.mapContainer then
			-- Debug: check if WorldMapFrame exists
			if not WorldMapFrame then
				print("[MapTab] ERROR: WorldMapFrame is nil!")
				return
			end

			print("[MapTab] WorldMapFrame state before embed:")
			print("  - IsShown:", WorldMapFrame:IsShown())
			print("  - Alpha:", WorldMapFrame:GetAlpha())
			print("  - MapID:", WorldMapFrame:GetMapID())
			print("  - Parent:", WorldMapFrame:GetParent() and WorldMapFrame:GetParent():GetName() or "nil")

			local success = EmbedMapCanvas(self.MainFrame.mapContainer)

			print("[MapTab] WorldMapFrame state after embed:")
			print("  - IsShown:", WorldMapFrame:IsShown())
			print("  - Alpha:", WorldMapFrame:GetAlpha())
			print("  - Strata:", WorldMapFrame:GetFrameStrata())
			print("  - Level:", WorldMapFrame:GetFrameLevel())

			if success then
				-- Animate container and controls
				if CONFIG.animations.enabled and E.Animations then
					E.Animations:FadeIn(self.MainFrame.mapContainer, CONFIG.animations.fadeInDuration)
					if self.MainFrame.mapControlBar then
						E.Animations:FadeIn(self.MainFrame.mapControlBar, CONFIG.animations.fadeInDuration)
					end
				else
					self.MainFrame.mapContainer:SetAlpha(1)
					if self.MainFrame.mapControlBar then
						self.MainFrame.mapControlBar:SetAlpha(1)
					end
				end
			else
				print("[MapTab] ERROR: Failed to embed map canvas")
				self.MainFrame.mapContainer:SetAlpha(1)  -- Show container anyway
			end
		end
	end

	-- Trigger camera transition (which will call onReady when done)
	if E.Camera.isZoomed then
		print("[MapTab] Camera already zoomed, transition in progress")
	else
		print("[MapTab] Camera not yet zoomed, waiting for initial zoom")
	end
end

-- Hide Map Tab (called when switching away from this tab)
function E:HideMapTab()
	print("[MapTab] HideMapTab called")

	-- CRITICAL: Close any open dropdowns FIRST
	if self.MainFrame and self.MainFrame.mapControlBar then
		-- Close all UIDropDownMenus (they're global and stay open otherwise)
		CloseDropDownMenus()
	end

	-- CRITICAL: Restore WorldMapFrame so user can use it normally outside our addon
	RestoreMapCanvas()

	-- Hide container and controls (but don't destroy them, we might come back)
	if self.MainFrame and self.MainFrame.mapContainer then
		self.MainFrame.mapContainer:Hide()
	end
	if self.MainFrame and self.MainFrame.mapControlBar then
		self.MainFrame.mapControlBar:Hide()
	end

	print("[MapTab] Map tab hidden, WorldMapFrame restored")
end

-- Cleanup when addon closes (complete teardown)
function E:CleanupMapTab()
	print("[MapTab] CleanupMapTab called")

	-- Close any open dropdowns first
	CloseDropDownMenus()

	-- Restore WorldMapFrame completely
	RestoreMapCanvas()

	-- Destroy control bar and all its children
	if self.MainFrame and self.MainFrame.mapControlBar then
		-- UIDropDownMenu creates global frames, we need to clean them up
		-- Hide first to prevent any lingering interactions
		self.MainFrame.mapControlBar:Hide()

		-- Clear references
		self.MainFrame.mapControlBar = nil
		self.MainFrame.mapControlsCreated = false

		print("[MapTab] Control bar destroyed")
	end

	-- Reset state flags
	isEmbedded = false

	-- Note: We don't clear originalMapCanvasParent here because we might reopen the addon
	-- If we clear it, we'd lose the ability to restore properly on next open

	print("[MapTab] Map tab cleanup complete")
end
