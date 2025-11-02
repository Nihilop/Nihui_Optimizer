local addonName, ns = ...

-- Namespace
ns.E = ns.E or {}
local E = ns.E

-- ============================================================================
-- NIHUI PARENT - Global parent frame for all addon UI elements
-- ============================================================================
-- HYBRID SOLUTION - Best of both worlds:
--   - Parented to WorldFrame (complete independence, never hidden/faded)
--   - Copies ALL properties from UIParent (scale, size, behavior)
--   - Result: Same coordinate system as UIParent, but isolated from its lifecycle
--
-- Why this matters:
--   - All Blizzard frames (PlayerSpellsFrame, etc.) are designed for UIParent scale
--   - By matching UIParent properties, we can reparent Blizzard frames seamlessly
--   - No scale conversion, no size mismatches, perfect compatibility
--
-- What we copy from UIParent:
--   - Scale (GetEffectiveScale)
--   - Size (GetWidth/GetHeight)
--   - Updates automatically when UI scale changes
-- ============================================================================

local function UpdateNihuiParentScale()
	local NihuiParent = E.NihuiParent
	if not NihuiParent then return end

	-- Get UIParent scale and size
	local uiScale = UIParent:GetEffectiveScale()
	local uiWidth = UIParent:GetWidth()
	local uiHeight = UIParent:GetHeight()

	-- Apply same scale to NihuiParent
	NihuiParent:SetScale(uiScale)

	-- Set size to match UIParent (accounting for scale)
	-- NihuiParent is anchored to WorldFrame, so we need to calculate the right size
	NihuiParent:SetSize(uiWidth, uiHeight)

	print(string.format("[NihuiParent] Updated: scale=%.3f, size=%.0fx%.0f (matching UIParent)",
		uiScale, uiWidth, uiHeight))
end

local NihuiParent = CreateFrame("Frame", "NihuiOptimizerParent", WorldFrame)
NihuiParent:SetFrameStrata("TOOLTIP")  -- Highest possible strata (blocks all interaction below)
NihuiParent:SetFrameLevel(500)  -- Very high level to ensure we're on top

-- Position at screen center (like UIParent)
NihuiParent:SetPoint("CENTER", WorldFrame, "CENTER", 0, 0)

E.NihuiParent = NihuiParent

-- Initial setup
UpdateNihuiParentScale()

-- Listen for UI scale changes
local scaleEventFrame = CreateFrame("Frame")
scaleEventFrame:RegisterEvent("UI_SCALE_CHANGED")
scaleEventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
scaleEventFrame:SetScript("OnEvent", function(self, event)
	print("[NihuiParent] UI scale changed, updating...")
	UpdateNihuiParentScale()
end)

-- Also hook SetScale in case it's called directly
hooksecurefunc(UIParent, "SetScale", function()
	C_Timer.After(0.1, UpdateNihuiParentScale)
end)

print(string.format("[Nihui Optimizer] NihuiParent created (parent=WorldFrame, mimics UIParent properties)"))

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local addon = ...
		if addon == addonName then
			E:OnAddonLoaded()
		end
	elseif event == "PLAYER_LOGIN" then
		E:OnPlayerLogin()
	elseif event == "PLAYER_ENTERING_WORLD" then
		E:OnPlayerEnteringWorld()
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		E:OnEquipmentChanged()
	end
end)

function E:OnAddonLoaded()
	-- Initialize database
	self:InitDatabase()

	-- Enable experimental camera features ASAP (before popup appears)
	C_CVar.SetCVar("ActionCam", "1")

	print("|cff00ff00Nihui|r |cffffffffOptimizer|r loaded! Type /nihopt to toggle or use the minimap button.")
end

function E:OnPlayerLogin()
	-- Force enable experimental camera again (in case it was reset)
	C_CVar.SetCVar("ActionCam", "1")

	-- Also set the CVar that controls the warning popup
	C_CVar.SetCVar("ActionCamOn", "1")

	-- Mark as already shown (this prevents the popup from appearing)
	if not C_CVar.GetCVarBool("ActionCam") then
		C_CVar.SetCVar("ActionCam", "1")
		-- Simulate accepting the dialog
		C_Timer.After(0.1, function()
			if StaticPopup_Visible("ACTION_CAM_EXPERIMENTAL") then
				local dialog = StaticPopup_FindVisible("ACTION_CAM_EXPERIMENTAL")
				if dialog then
					dialog.button1:Click()  -- Click "Accept" button
				end
			end
		end)
	end

	-- Initialize minimap button
	self:InitMinimapButton()

	-- Register slash commands
	SLASH_NIHOPT1 = "/nihopt"
	SLASH_NIHOPT2 = "/nihuioptimizer"
	SlashCmdList["NIHOPT"] = function(msg)
		msg = msg:lower():trim()

		if msg == "minimap" then
			self:ToggleMinimapButton()
		elseif msg == "debug" then
			self:ToggleDebugWindow()
			print("|cff00ff00Nihui Optimizer:|r Debug window toggled")
		elseif msg == "showstats" then
			-- Debug command: force show stats panel
			if self.MainFrame and self.MainFrame.statsFrame then
				local sf = self.MainFrame.statsFrame
				sf:SetAlpha(1)
				sf:Show()
				print(string.format("|cff00ff00Nihui Optimizer:|r Stats panel forced visible (alpha=%.2f, shown=%s, width=%.0f, height=%.0f)",
					sf:GetAlpha(), tostring(sf:IsShown()), sf:GetWidth(), sf:GetHeight()))

				-- Also show the inner panel
				if sf.statsPanel then
					sf.statsPanel:SetAlpha(1)
					sf.statsPanel:Show()
					print(string.format("|cff00ff00Nihui Optimizer:|r Inner stats panel (alpha=%.2f, shown=%s, width=%.0f, height=%.0f)",
						sf.statsPanel:GetAlpha(), tostring(sf.statsPanel:IsShown()), sf.statsPanel:GetWidth(), sf.statsPanel:GetHeight()))
				else
					print("|cffff0000Nihui Optimizer:|r statsFrame.statsPanel is NIL!")
				end
			else
				print("|cffff0000Nihui Optimizer:|r MainFrame or statsFrame is NIL!")
			end
		elseif msg == "help" then
			print("|cff00ff00Nihui Optimizer|r |cffffffffCommands:|r")
			print("  /nihopt - Toggle main interface")
			print("  /nihopt minimap - Toggle minimap button")
			print("  /nihopt debug - Toggle debug window")
			print("  /nihopt showstats - Debug: force show stats panel")
			print("  /nihopt help - Show this help")
		else
			self:ToggleMainFrame()
		end
	end
end

function E:OnPlayerEnteringWorld()
	-- Update equipment when entering world
	C_Timer.After(1, function()
		E:UpdateEquipmentSlots()
		-- Stats update automatically via event handlers
	end)
end

function E:OnEquipmentChanged()
	-- Update equipment when equipment changes
	if self.MainFrame and self.MainFrame:IsShown() then
		E:UpdateEquipmentSlots()
		-- Stats update automatically via event handlers
	end
end
