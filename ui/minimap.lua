local _, ns = ...
local E = ns.E

local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

function E:InitMinimapButton()
	-- Create data broker object
	local dataObj = LDB:NewDataObject("NihuiOptimizer", {
		type = "launcher",
		icon = "Interface\\Icons\\INV_Misc_Gear_01",
		OnClick = function(_, button)
			if button == "LeftButton" then
				E:ToggleMainFrame()
			elseif button == "RightButton" then
				-- Future: Open settings
				print("|cff00ff00Nihui|r Optimizer: Right-click for settings (coming soon)")
			end
		end,
		OnTooltipShow = function(tooltip)
			if not tooltip or not tooltip.AddLine then return end
			tooltip:AddLine("|cff00ff00Nihui|r |cffffffffOptimizer|r")
			tooltip:AddLine("|cffffffffLeft-click:|r Toggle optimizer", 1, 1, 1)
			tooltip:AddLine("|cffffffffRight-click:|r Settings", 1, 1, 1)
		end,
	})

	-- Register with LibDBIcon
	LDBIcon:Register("NihuiOptimizer", dataObj, E.db.profile.minimap)
end

function E:ToggleMinimapButton()
	local db = E.db.profile.minimap
	db.hide = not db.hide

	if db.hide then
		LDBIcon:Hide("NihuiOptimizer")
	else
		LDBIcon:Show("NihuiOptimizer")
	end
end
