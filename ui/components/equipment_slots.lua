local _, ns = ...
local E = ns.E

-- Equipment slot IDs (WoW standard)
local EQUIPMENT_SLOTS = {
	-- Left side (9 slots)
	{id = 1, name = "Head", side = "left"},
	{id = 2, name = "Neck", side = "left"},
	{id = 3, name = "Shoulder", side = "left"},
	{id = 15, name = "Back", side = "left"},
	{id = 5, name = "Chest", side = "left"},
	{id = 4, name = "Shirt", side = "left"},
	{id = 19, name = "Tabard", side = "left"},
	{id = 9, name = "Wrist", side = "left"},
	{id = 10, name = "Hands", side = "left"},

	-- Right side (9 slots)
	{id = 6, name = "Waist", side = "right"},
	{id = 7, name = "Legs", side = "right"},
	{id = 8, name = "Feet", side = "right"},
	{id = 11, name = "Ring 1", side = "right"},
	{id = 12, name = "Ring 2", side = "right"},
	{id = 13, name = "Trinket 1", side = "right"},
	{id = 14, name = "Trinket 2", side = "right"},
	{id = 16, name = "Main Hand", side = "right"},
	{id = 17, name = "Off Hand", side = "right"},
}

-- Get item quality color
local function GetQualityColor(quality)
	if quality then
		local color = ITEM_QUALITY_COLORS[quality]
		if color then
			return color.r, color.g, color.b
		end
	end
	return 1, 1, 1 -- White by default
end

-- ============================================================================
-- GAP DETECTOR
-- Invisible frame between slots to maintain tooltip when hovering between slots
-- ============================================================================
local function CreateGapDetector(container, slotHeight, spacing)
	local gap = CreateFrame("Frame", nil, container)
	gap:SetSize(slotHeight, spacing)  -- Same width as slot, height = gap between slots
	gap:EnableMouse(true)  -- CRITICAL: Must detect mouse
	gap:SetFrameLevel(container:GetFrameLevel() + 10)  -- Same level as slots

	-- Invisible (no backdrop, no textures)
	-- Just a hitbox to detect mouse in the gap

	-- OnEnter: Cancel scheduled tooltip hide (keep tooltip visible)
	gap:SetScript("OnEnter", function(self)
		if E.SlotTooltip then
			E.SlotTooltip:CancelHide()
		end
	end)

	-- OnLeave: Schedule tooltip hide (allow hiding when leaving gap)
	gap:SetScript("OnLeave", function(self)
		if E.SlotTooltip then
			E.SlotTooltip:ScheduleHide()
		end
	end)

	return gap
end

-- Create a single equipment slot button
local function CreateEquipmentSlot(parent, slotData, slotHeight)
	local slot = CreateFrame("Button", nil, parent, "BackdropTemplate")
	slot:SetSize(slotHeight, slotHeight) -- Square button
	slot.slotID = slotData.id
	slot.slotName = slotData.name
	slot.side = slotData.side  -- Store side (left or right)

	-- Raise frame level to be above parent blocker frame
	slot:SetFrameLevel(parent:GetFrameLevel() + 10)

	-- Enable mouse interactions
	slot:EnableMouse(true)
	slot:RegisterForClicks("LeftButtonUp")

	-- Backdrop
	slot:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		tile = false,
		edgeSize = 1,
	})
	slot:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
	slot:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

	-- Item icon
	local icon = slot:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", 2, -2)
	icon:SetPoint("BOTTOMRIGHT", -2, 2)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	slot.icon = icon

	-- Item level text (REMOVED - info is shown in info panel now)
	-- local ilvl = slot:CreateFontString(nil, "OVERLAY")
	-- ilvl:SetFont("Fonts\\FRIZQT__.TTF", math.max(10, slotHeight * 0.25), "OUTLINE")
	-- ilvl:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
	-- ilvl:SetTextColor(1, 1, 0, 1)
	-- slot.ilvl = ilvl

	-- No label needed (user doesn't want slot names displayed)

	-- Quality border (will be colored based on item quality)
	slot.qualityBorder = slot:CreateTexture(nil, "BORDER")
	slot.qualityBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
	slot.qualityBorder:SetPoint("TOPLEFT", -1, 1)
	slot.qualityBorder:SetPoint("BOTTOMRIGHT", 1, -1)
	slot.qualityBorder:Hide() -- Hidden by default

	-- Update slot with equipped item data
	function slot:Update()
		local itemLocation = ItemLocation:CreateFromEquipmentSlot(self.slotID)

		if C_Item.DoesItemExist(itemLocation) then
			local itemLink = C_Item.GetItemLink(itemLocation)

			if itemLink then
				-- Get item info
				local itemTexture = C_Item.GetItemIcon(itemLocation)
				local itemLevel = C_Item.GetCurrentItemLevel(itemLocation)
				local quality = C_Item.GetItemQuality(itemLocation)

				-- Update icon
				self.icon:SetTexture(itemTexture)

				-- Update ilvl (REMOVED - shown in info panel now)
				-- self.ilvl:SetText(itemLevel or "")

				-- Update quality border
				if quality and quality > 1 then -- Only show for uncommon+
					local r, g, b = GetQualityColor(quality)
					self.qualityBorder:SetVertexColor(r, g, b, 1)
					self.qualityBorder:Show()
				else
					self.qualityBorder:Hide()
				end

				self.hasItem = true
				self.itemLink = itemLink

				-- Update info panel
				if self.infoPanel then
					E.SlotInfoPanel:Update(self.infoPanel, self.slotID)
				end
				return
			end
		end

		-- No item equipped
		self.icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
		-- self.ilvl:SetText("") -- REMOVED
		self.qualityBorder:Hide()
		self.hasItem = false
		self.itemLink = nil

		-- Hide info panel
		if self.infoPanel then
			E.SlotInfoPanel:Hide(self.infoPanel)
		end
	end

	-- Click handlers
	slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	slot:SetScript("OnClick", function(self, button)
		print("[Slot] Click detected:", button, "on", self.slotName)

		-- Hide tooltip when clicking (dropdown or context menu will open)
		if E.SlotTooltip then
			E.SlotTooltip:Hide()
		end

		if button == "LeftButton" then
			-- Left click: Open dropdown
			print("[Slot] Opening dropdown for", self.slotName)
			if E.SlotDropdown then
				E.SlotDropdown:Toggle(self)
			else
				print("[Slot] ERROR: E.SlotDropdown is nil")
			end
		elseif button == "RightButton" then
			-- Right click: Open context menu (positioned relative to slot)
			print("[Slot] Opening context menu for", self.slotName)
			if E.SlotContextMenu then
				E.SlotContextMenu:Show(self)
			else
				print("[Slot] ERROR: E.SlotContextMenu is nil")
			end
		end
	end)

	-- Tooltip on hover
	slot:SetScript("OnEnter", function(self)
		print("[Slot] OnEnter for", self.slotName, "hasItem:", self.hasItem, "side:", self.side)

		-- Cancel any pending hide timer (allows returning to slot from tooltip)
		if E.SlotTooltip then
			E.SlotTooltip:CancelHide()
		end

		-- Check if THIS slot has an active dropdown open
		if E.SlotDropdown and E.SlotDropdown.activeDropdown and E.SlotDropdown.activeDropdown.parentSlot == self then
			print("[Slot] This slot has dropdown open, not showing tooltip")
			return
		end

		-- Show modern sliding tooltip for slots
		if E.SlotTooltip then
			E.SlotTooltip:Show(self)
		else
			print("[Slot] ERROR: E.SlotTooltip is nil")
		end
	end)

	slot:SetScript("OnLeave", function(self)
		print("[Slot] OnLeave for", self.slotName)
		-- Schedule hide with delay (allows moving to tooltip)
		if E.SlotTooltip then
			E.SlotTooltip:ScheduleHide()
		end
	end)

	-- Equip item (from dropdown)
	function slot:EquipItem(itemData)
		if itemData and itemData.itemLocation then
			-- Use C_Item API to equip item
			C_Item.EquipItemByName(itemData.itemLink, self.slotID)
			C_Timer.After(0.1, function()
				self:Update()
			end)
		end
	end

	-- Unequip item (from context menu)
	function slot:UnequipItem()
		if self.hasItem then
			-- Pick up item from slot
			PickupInventoryItem(self.slotID)
			-- Put it in first empty bag slot
			PutItemInBackpack()
			C_Timer.After(0.1, function()
				self:Update()
			end)
		end
	end

	-- Create info panel (Narcissus-style)
	slot.infoPanel = E.SlotInfoPanel:Create(slot, slotData.side)

	-- Initial update
	slot:Update()

	return slot
end

-- Create equipment panel (left or right side)
-- config parameter contains: leftOffsetX, rightOffsetX, slotSpacing, titleOffset
function E:CreateEquipmentSlots(parent, config)
	if not parent then return end

	-- Use config values or fallback to defaults
	local leftOffsetX = (config and config.leftOffsetX) or 100
	local rightOffsetX = (config and config.rightOffsetX) or 150
	local spacing = (config and config.slotSpacing) or 10

	-- Get parent height (NihuiParent height)
	local parentHeight = E.NihuiParent:GetHeight() or 600
	local numSlots = 9

	-- Calculate slot height (without titleOffset - we'll center vertically)
	local availableHeight = parentHeight * 0.85  -- Use 85% of screen height for slots

	-- Calculate slot height: (available height - total spacing) / number of slots
	local slotHeight = math.floor((availableHeight - (numSlots - 1) * spacing) / numSlots)

	-- Ensure reasonable size limits
	slotHeight = math.max(35, math.min(slotHeight, 65))

	-- Calculate total height of slot group (for vertical centering)
	local totalSlotsHeight = (numSlots * slotHeight) + ((numSlots - 1) * spacing)

	-- Calculate vertical offset to center slots on screen
	local verticalCenterOffset = (parentHeight - totalSlotsHeight) / 2

	print(string.format("[EquipmentSlots] Vertical centering: parentHeight=%.0f, totalSlotsHeight=%.0f, centerOffset=%.0f",
		parentHeight, totalSlotsHeight, verticalCenterOffset))

	-- Left side container (anchored directly to parent, stays within ContentFrame)
	local leftContainer = CreateFrame("Frame", nil, parent)
	leftContainer:SetSize(slotHeight, parentHeight)
	leftContainer:SetPoint("LEFT", parent, "LEFT", leftOffsetX, 0)
	leftContainer:SetFrameLevel(parent:GetFrameLevel() + 5)  -- Above blocker frame

	-- Right side container (anchored directly to parent, stays within ContentFrame)
	local rightContainer = CreateFrame("Frame", nil, parent)
	rightContainer:SetSize(slotHeight, parentHeight)
	rightContainer:SetPoint("LEFT", parent, "CENTER", rightOffsetX, 0)
	rightContainer:SetFrameLevel(parent:GetFrameLevel() + 5)  -- Above blocker frame

	-- Create slots and gap detectors
	parent.equipmentSlots = {}
	parent.gapDetectors = {}
	local leftIndex = 1
	local rightIndex = 1
	local leftSlots = {}
	local rightSlots = {}

	-- First pass: create all slots and store them by side
	for _, slotData in ipairs(EQUIPMENT_SLOTS) do
		local slot

		if slotData.side == "left" then
			slot = CreateEquipmentSlot(leftContainer, slotData, slotHeight)
			local yOffset = -verticalCenterOffset - (leftIndex - 1) * (slotHeight + spacing)
			slot:SetPoint("TOP", leftContainer, "TOP", 0, yOffset)
			table.insert(leftSlots, slot)
			leftIndex = leftIndex + 1
		else
			slot = CreateEquipmentSlot(rightContainer, slotData, slotHeight)
			local yOffset = -verticalCenterOffset - (rightIndex - 1) * (slotHeight + spacing)
			slot:SetPoint("TOP", rightContainer, "TOP", 0, yOffset)
			table.insert(rightSlots, slot)
			rightIndex = rightIndex + 1
		end

		table.insert(parent.equipmentSlots, slot)
	end

	-- Second pass: create gap detectors between slots (except after last slot)
	-- Left side gaps
	for i = 1, #leftSlots - 1 do
		local gap = CreateGapDetector(leftContainer, slotHeight, spacing)
		-- Position between slot i and slot i+1
		gap:SetPoint("TOP", leftSlots[i], "BOTTOM", 0, 0)
		table.insert(parent.gapDetectors, gap)
	end

	-- Right side gaps
	for i = 1, #rightSlots - 1 do
		local gap = CreateGapDetector(rightContainer, slotHeight, spacing)
		-- Position between slot i and slot i+1
		gap:SetPoint("TOP", rightSlots[i], "BOTTOM", 0, 0)
		table.insert(parent.gapDetectors, gap)
	end

	parent.leftContainer = leftContainer
	parent.rightContainer = rightContainer
end

-- Update all equipment slots
function E:UpdateEquipmentSlots()
	if not self.MainFrame or not self.MainFrame.equipmentSlots then return end

	for _, slot in ipairs(self.MainFrame.equipmentSlots) do
		slot:Update()
	end
end
