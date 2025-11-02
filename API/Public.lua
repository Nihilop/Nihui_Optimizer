local _, ns = ...
local E = ns.E

-- ============================================================================
-- PUBLIC API - Expose Nihui Optimizer API to external addons
-- ============================================================================

--[[
This file exposes the Nihui Optimizer API globally so other addons can use it.

AVAILABLE APIS:
- NihuiOptimizer.TabRegistry    - Register custom tabs
- NihuiOptimizer.CameraPresets  - Access camera preset system
- NihuiOptimizer.Camera         - Low-level camera controls

USAGE:
```lua
-- Check if Nihui Optimizer is loaded
local NihuiOptimizer = _G.NihuiOptimizer

if NihuiOptimizer then
    -- Use the APIs
    NihuiOptimizer.TabRegistry:RegisterTab({...})
    NihuiOptimizer.CameraPresets:EnterEquipmentView(true)
end
```
]]

-- Create global namespace
_G.NihuiOptimizer = {
	-- Tab system API
	TabRegistry = E.TabRegistry,

	-- Camera system APIs
	CameraPresets = E.CameraPresets,
	Camera = E.Camera,

	-- Version info (use modern API)
	Version = C_AddOns.GetAddOnMetadata("Nihui_Optimizer", "Version") or "1.0.0",
	Author = C_AddOns.GetAddOnMetadata("Nihui_Optimizer", "Author") or "Nihui",
}

print("|cff00ff00Nihui Optimizer|r |cffffffffAPI exposed globally as|r |cff00ff00_G.NihuiOptimizer|r")
