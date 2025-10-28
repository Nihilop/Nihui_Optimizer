local _, ns = ...
local E = ns.E

-- ============================================================================
-- SLOT CONTEXT MENU
-- Right-click menu for equipment slots
-- ============================================================================

E.SlotContextMenu = {}
local SlotContextMenu = E.SlotContextMenu

-- Active menu tracking
SlotContextMenu.activeMenu = nil

-- CONFIG
local CONFIG = {
	buttonHeight = 24,
	buttonWidth = 150,
}

-- ============================================================================
-- CREATE CONTEXT MENU
-- ============================================================================

function SlotContextMenu:Create()
	-- Parent to NihuiParent for stable positioning hierarchy
	local menu = CreateFrame("Frame", nil, E.NihuiParent, "BackdropTemplate")
	menu:SetSize(CONFIG.buttonWidth, CONFIG.buttonHeight)
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:SetFrameLevel(250)
	menu:Hide()

	-- Simple backdrop
	menu:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		tile = false,
		edgeSize = 1,
	})
	menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
	menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

	menu:EnableMouse(true)
	menu.buttons = {}

	return menu
end

-- ============================================================================
-- ADD MENU BUTTON
-- ============================================================================

function SlotContextMenu:AddButton(menu, text, onClick)
	local index = #menu.buttons + 1

	local button = CreateFrame("Button", nil, menu)
	button:SetSize(CONFIG.buttonWidth - 4, CONFIG.buttonHeight - 2)
	button:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -(index - 1) * CONFIG.buttonHeight - 2)

	-- Background (for hover)
	button.bg = button:CreateTexture(nil, "BACKGROUND")
	button.bg:SetAllPoints()
	button.bg:SetColorTexture(0, 0, 0, 0)

	-- Text
	button.text = button:CreateFontString(nil, "OVERLAY")
	button.text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	button.text:SetPoint("LEFT", button, "LEFT", 5, 0)
	button.text:SetTextColor(1, 1, 1, 1)
	button.text:SetText(text)

	-- Click handler
	button:RegisterForClicks("LeftButtonUp")
	button:SetScript("OnClick", function(self)
		onClick()
		menu:Hide()
	end)

	-- Hover effects
	button:SetScript("OnEnter", function(self)
		self.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
	end)

	button:SetScript("OnLeave", function(self)
		self.bg:SetColorTexture(0, 0, 0, 0)
	end)

	table.insert(menu.buttons, button)

	-- Update menu height
	menu:SetHeight(#menu.buttons * CONFIG.buttonHeight + 2)

	return button
end

-- ============================================================================
-- SHOW CONTEXT MENU FOR SLOT
-- ============================================================================

function SlotContextMenu:Show(slot)
	-- Close existing menu
	if self.activeMenu then
		self.activeMenu:Hide()
	end

	-- Create new menu
	local menu = self:Create()

	-- Add menu items
	if slot.hasItem then
		-- Unequip item
		self:AddButton(menu, "Déséquiper", function()
			slot:UnequipItem()
		end)

		-- View in bags
		self:AddButton(menu, "Trouver dans les sacs", function()
			-- TODO: Highlight item in bags
			print("Recherche de l'objet dans les sacs...")
		end)

		-- Item info
		self:AddButton(menu, "Infos de l'objet", function()
			if slot.itemLink then
				ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
				ItemRefTooltip:SetHyperlink(slot.itemLink)
				ItemRefTooltip:Show()
			end
		end)
	else
		-- Browse items
		self:AddButton(menu, "Parcourir les objets", function()
			E.SlotDropdown:Open(slot)
		end)
	end

	-- FIX: Position menu RELATIVE to slot (like dropdown does)
	-- This avoids issues with UIParent scale and coordinate systems
	local menuWidth = menu:GetWidth()
	local menuHeight = menu:GetHeight()
	local screenWidth = UIParent:GetWidth()
	local screenHeight = UIParent:GetHeight()

	-- Get slot position to determine if we should open left or right
	local slotX = slot:GetCenter()
	local slotCenterX = screenWidth / 2

	menu:ClearAllPoints()

	-- Smart positioning based on slot position
	if slotX > slotCenterX then
		-- Slot is on right side, open menu to LEFT of slot
		menu:SetPoint("TOPRIGHT", slot, "TOPLEFT", -5, 0)
		print("[SlotContextMenu] Opening LEFT of slot")
	else
		-- Slot is on left side, open menu to RIGHT of slot
		menu:SetPoint("TOPLEFT", slot, "TOPRIGHT", 5, 0)
		print("[SlotContextMenu] Opening RIGHT of slot")
	end

	menu:Show()

	print(string.format("[SlotContextMenu] Menu positioned relative to slot: %s", slot.slotName or "unknown"))

	self.activeMenu = menu

	-- Close on click outside
	if not menu.closeHandler then
		menu.closeHandler = CreateFrame("Frame")
		menu.closeHandler:RegisterEvent("GLOBAL_MOUSE_DOWN")
		menu.closeHandler:SetScript("OnEvent", function(self, event, button)
			if menu:IsShown() and not MouseIsOver(menu) then
				menu:Hide()
			end
		end)
	end

	menu:SetScript("OnHide", function(self)
		if self.closeHandler then
			self.closeHandler:UnregisterEvent("GLOBAL_MOUSE_DOWN")
		end
	end)
end

-- ============================================================================
-- HIDE CONTEXT MENU
-- ============================================================================

function SlotContextMenu:Hide(menu)
	if menu then
		menu:Hide()
	end
	if self.activeMenu and self.activeMenu == menu then
		self.activeMenu = nil
	end
end

