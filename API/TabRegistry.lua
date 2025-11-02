local _, ns = ...
local E = ns.E

-- ============================================================================
-- TAB REGISTRY API - Public API for external addons
-- ============================================================================

--[[
This API allows external addons to register custom tabs in Nihui Optimizer.

USAGE EXAMPLE:
```lua
-- In your addon's code:
local NihuiOptimizer = _G.NihuiOptimizer

if NihuiOptimizer and NihuiOptimizer.TabRegistry then
    -- Register a custom tab
    local tabIndex = NihuiOptimizer.TabRegistry:RegisterTab({
        name = "My Custom Tab",

        -- Called when MainFrame is created (create your UI here)
        onCreate = function(tabContent)
            -- tabContent is the Frame where you should create your UI
            local myFrame = CreateFrame("Frame", nil, tabContent)
            myFrame:SetAllPoints()

            local text = myFrame:CreateFontString(nil, "OVERLAY")
            text:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
            text:SetText("My Custom Content")
            text:SetPoint("CENTER")

            return myFrame
        end,

        -- Called when tab becomes active (before camera animation)
        onPrepare = function()
            -- Set up camera preset for this tab
            NihuiOptimizer.CameraPresets:EnterEquipmentView(false)
        end,

        -- Called when camera animation completes (show/animate your UI)
        onShow = function()
            -- Animate your UI elements here
            print("My custom tab is now visible!")
        end,

        -- Called when user switches away from this tab
        onHide = function()
            -- Hide/cleanup your UI (optional)
            print("User left my custom tab")
        end,

        -- Called when MainFrame closes completely (final cleanup)
        onCleanup = function()
            -- Restore any Blizzard frames you hijacked, cleanup resources
            print("Cleaning up my custom tab")
        end,
    })

    print("Registered custom tab at index: " .. tabIndex)
end
```

CAMERA PRESETS API:
Available camera presets you can use in onPrepare:
- NihuiOptimizer.CameraPresets:EnterEquipmentView(animated)  -- Character centered
- NihuiOptimizer.CameraPresets:EnterLeftPanelView(animated)  -- Character on right
- NihuiOptimizer.CameraPresets:EnterRightPanelView(animated) -- Character on left
- NihuiOptimizer.CameraPresets:EnterMapView(animated)        -- Character on right, wider view

Or create your own custom camera preset - see API/CameraPresets.lua for details.
]]

E.TabRegistry = {}
local TabRegistry = E.TabRegistry

-- Storage for registered tabs
local registeredTabs = {}
local nextTabIndex = 3  -- Start after Equipment (1) and Optimizer (2)

-- Register a new tab
-- @param config table with keys: name, onCreate, onPrepare, onShow, onHide, onCleanup
-- @return number tabIndex - the index of the registered tab
function TabRegistry:RegisterTab(config)
	if not config then
		error("TabRegistry:RegisterTab - config is required")
	end

	if not config.name then
		error("TabRegistry:RegisterTab - config.name is required")
	end

	if not config.onCreate then
		error("TabRegistry:RegisterTab - config.onCreate is required")
	end

	local tabIndex = nextTabIndex
	nextTabIndex = nextTabIndex + 1

	-- Store tab config
	registeredTabs[tabIndex] = config

	print(string.format("[TabRegistry] Registered tab '%s' at index %d", config.name, tabIndex))

	-- If MainFrame already exists, add the tab now
	if E.MainFrame then
		self:_CreateTabInMainFrame(tabIndex, config)
	end

	return tabIndex
end

-- Internal: Create tab in MainFrame (called when MainFrame exists)
function TabRegistry:_CreateTabInMainFrame(tabIndex, config)
	if not E.MainFrame then
		print("[TabRegistry] ERROR: MainFrame not created yet")
		return
	end

	local tabSystem = E.MainFrame.tabSystem
	if not tabSystem then
		print("[TabRegistry] ERROR: tabSystem not found")
		return
	end

	-- Create tab button
	tabSystem:CreateTab(config.name, tabIndex)

	-- Create tab content frame
	local tabContent = tabSystem:CreateTabContent()

	-- Call onCreate to build UI
	local success, result = pcall(config.onCreate, tabContent)
	if not success then
		print("[TabRegistry] ERROR in onCreate for tab '" .. config.name .. "': " .. tostring(result))
		return
	end

	-- Register callbacks
	if config.onPrepare then
		tabSystem.tabPrepareCallbacks[tabIndex] = config.onPrepare
	end

	if config.onShow then
		tabSystem.tabOnReadyCallbacks[tabIndex] = function()
			-- Call custom onShow
			local success, err = pcall(config.onShow)
			if not success then
				print("[TabRegistry] ERROR in onShow for tab '" .. config.name .. "': " .. tostring(err))
			end

			-- Always release animation lock
			if E.AnimationManager then
				E.AnimationManager.isTransitioning = false
			end
		end
	end

	if config.onHide then
		tabSystem.tabCleanupCallbacks[tabIndex] = config.onHide
	end

	-- Store cleanup callback separately for full cleanup on MainFrame close
	if config.onCleanup then
		if not tabSystem.tabFullCleanupCallbacks then
			tabSystem.tabFullCleanupCallbacks = {}
		end
		tabSystem.tabFullCleanupCallbacks[tabIndex] = config.onCleanup
	end

	print(string.format("[TabRegistry] Created tab '%s' in MainFrame", config.name))
end

-- Initialize all registered tabs when MainFrame is created
function TabRegistry:InitializeAllTabs()
	if not E.MainFrame then
		print("[TabRegistry] ERROR: MainFrame not created yet")
		return
	end

	for tabIndex, config in pairs(registeredTabs) do
		self:_CreateTabInMainFrame(tabIndex, config)
	end
end

-- Get list of registered tabs
function TabRegistry:GetRegisteredTabs()
	return registeredTabs
end

-- Check if a specific tab index is registered
function TabRegistry:IsTabRegistered(tabIndex)
	return registeredTabs[tabIndex] ~= nil
end
