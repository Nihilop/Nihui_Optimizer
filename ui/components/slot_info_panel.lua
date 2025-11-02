local _, ns = ...
local E = ns.E

-- ============================================================================
-- SLOT INFO PANEL (Narcissus-style)
-- Shows item name, ilvl, and stats next to equipment slots
-- ============================================================================

E.SlotInfoPanel = {}
local SlotInfoPanel = E.SlotInfoPanel

local CONFIG = {
	panelWidth = 200,
	panelHeight = 40,
	offsetX = 0,  -- Distance from slot (négatif = overlap pour compenser le style)
}

-- Create info panel for a slot
function SlotInfoPanel:Create(slot, side)
	local panel = CreateFrame("Frame", nil, slot, "BackdropTemplate")
	panel:SetSize(CONFIG.panelWidth, CONFIG.panelHeight)
	panel:Hide()

	-- Gradient background (like Narcissus)
	local gradient = panel:CreateTexture(nil, "BACKGROUND")
	gradient:SetAllPoints(panel)
	gradient:SetTexture("Interface\\Buttons\\WHITE8X8")

	if side == "left" then
		-- Left slots: panel goes TOWARD CENTER (to the right of slot)
		-- Gradient: dark on left (near slot), fade to right
		gradient:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0.8), CreateColor(0, 0, 0, 0))
		panel:SetPoint("LEFT", slot, "RIGHT", CONFIG.offsetX, 0)
	else
		-- Right slots: panel goes TOWARD CENTER (to the left of slot)
		-- Gradient: dark on right (near slot), fade to left
		gradient:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.8))
		panel:SetPoint("RIGHT", slot, "LEFT", -CONFIG.offsetX, 0)
	end

	panel.gradient = gradient
	panel.side = side

	-- Ligne 1: Item name
	local itemName = panel:CreateFontString(nil, "OVERLAY")
	itemName:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
	itemName:SetPoint("TOP", panel, "TOP", 0, -4)
	if side == "left" then
		itemName:SetPoint("LEFT", panel, "LEFT", 5, 0)
		itemName:SetPoint("RIGHT", panel, "RIGHT", -5, 0)
		itemName:SetJustifyH("LEFT")
	else
		itemName:SetPoint("LEFT", panel, "LEFT", 5, 0)
		itemName:SetPoint("RIGHT", panel, "RIGHT", -5, 0)
		itemName:SetJustifyH("RIGHT")
	end
	itemName:SetTextColor(1, 1, 1, 1)
	itemName:SetWordWrap(false)
	panel.itemName = itemName

	-- Ligne 2: Spécificités + ilvl (format: "Socket • Speed   506")
	local secondLine = panel:CreateFontString(nil, "OVERLAY")
	secondLine:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
	secondLine:SetPoint("TOP", itemName, "BOTTOM", 0, -2)
	if side == "left" then
		secondLine:SetPoint("LEFT", panel, "LEFT", 5, 0)
		secondLine:SetJustifyH("LEFT")
	else
		secondLine:SetPoint("RIGHT", panel, "RIGHT", -5, 0)
		secondLine:SetJustifyH("RIGHT")
	end
	secondLine:SetTextColor(0.5, 1, 0.5, 1)  -- Green for bonuses
	panel.secondLine = secondLine

	return panel
end

-- Update panel with item data
function SlotInfoPanel:Update(panel, slotID)
	if not panel then return end

	local itemLocation = ItemLocation:CreateFromEquipmentSlot(slotID)

	if C_Item.DoesItemExist(itemLocation) then
		local itemLink = C_Item.GetItemLink(itemLocation)

		if itemLink then
			-- Get item info
			local itemName = C_Item.GetItemName(itemLocation)
			local itemLevel = C_Item.GetCurrentItemLevel(itemLocation)
			local quality = C_Item.GetItemQuality(itemLocation)

			-- Update name
			panel.itemName:SetText(itemName or "")

			-- Update quality color
			if quality then
				local r, g, b = C_Item.GetItemQualityColor(quality)
				panel.itemName:SetTextColor(r, g, b, 1)
			end

			-- Build ligne 2: "Socket • Speed   506" ou juste "506"
			local bonuses = {}

			-- Check for gem/socket info
			local stats = C_Item.GetItemStats(itemLink)
			if stats and stats["EMPTY_SOCKET_PRISMATIC"] then
				local numSockets = stats["EMPTY_SOCKET_PRISMATIC"]
				if numSockets > 0 then
					table.insert(bonuses, "Socket (" .. numSockets .. ")")
				end
			end

			-- Check for tertiary stats (Leech, Speed, Avoidance, Indestructible)
			if stats then
				if stats["ITEM_MOD_CR_LIFESTEAL_SHORT"] then
					table.insert(bonuses, "Leech")
				end
				if stats["ITEM_MOD_CR_SPEED_SHORT"] then
					table.insert(bonuses, "Speed")
				end
				if stats["ITEM_MOD_CR_AVOIDANCE_SHORT"] then
					table.insert(bonuses, "Avoidance")
				end
			end

			-- Format ligne 2
			local secondLineText = ""
			if #bonuses > 0 then
				secondLineText = table.concat(bonuses, " • ") .. "   " .. (itemLevel or "")
			else
				secondLineText = (itemLevel or "")
			end

			-- Color ilvl in yellow
			panel.secondLine:SetText(secondLineText)
			if #bonuses > 0 then
				-- Green for bonuses, will show ilvl in yellow separately if needed
				panel.secondLine:SetTextColor(0.5, 1, 0.5, 1)
			else
				-- Yellow for ilvl only
				panel.secondLine:SetTextColor(1, 1, 0, 1)
			end

			panel:Show()
			return
		end
	end

	-- No item equipped
	panel:Hide()
end

-- Show panel for slot
function SlotInfoPanel:Show(panel)
	if panel then
		panel:Show()
	end
end

-- Hide panel for slot
function SlotInfoPanel:Hide(panel)
	if panel then
		panel:Hide()
	end
end
