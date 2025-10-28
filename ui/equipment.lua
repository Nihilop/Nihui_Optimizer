local _, ns = ...
local E = ns.E

-- Equipment slot IDs (WoW standard)
local EQUIPMENT_SLOTS = {
	-- Left side (8 slots)
	{id = 1, name = "Head", side = "left"},
	{id = 2, name = "Neck", side = "left"},
	{id = 3, name = "Shoulder", side = "left"},
	{id = 15, name = "Back", side = "left"},
	{id = 5, name = "Chest", side = "left"},
	{id = 4, name = "Shirt", side = "left"},
	{id = 9, name = "Wrist", side = "left"},
	{id = 10, name = "Hands", side = "left"},

	-- Right side (8 slots)
	{id = 6, name = "Waist", side = "right"},
	{id = 7, name = "Legs", side = "right"},
	{id = 8, name = "Feet", side = "right"},
	{id = 11, name = "Ring 1", side = "right"},
	{id = 12, name = "Ring 2", side = "right"},
	{id = 13, name = "Trinket 1", side = "right"},
	{id = 14, name = "Trinket 2", side = "right"},
	{id = 16, name = "Main Hand", side = "right"},
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

-- Create a single equipment slot button
local function CreateEquipmentSlot(parent, slotData, slotHeight)
	local slot = CreateFrame("Button", nil, parent, "BackdropTemplate")
	slot:SetSize(slotHeight, slotHeight) -- Square button
	slot.slotID = slotData.id
	slot.slotName = slotData.name

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

	-- Item level text
	local ilvl = slot:CreateFontString(nil, "OVERLAY")
	ilvl:SetFont("Fonts\\FRIZQT__.TTF", math.max(10, slotHeight * 0.25), "OUTLINE")
	ilvl:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
	ilvl:SetTextColor(1, 1, 0, 1)
	slot.ilvl = ilvl

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

				-- Update ilvl
				self.ilvl:SetText(itemLevel or "")

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
				return
			end
		end

		-- No item equipped
		self.icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
		self.ilvl:SetText("")
		self.qualityBorder:Hide()
		self.hasItem = false
		self.itemLink = nil
	end

	-- Click handler - show upgrade dropdown
	slot:SetScript("OnClick", function(self)
		E:ToggleUpgradeDropdown(self)
	end)

	-- Tooltip on hover
	slot:SetScript("OnEnter", function(self)
		if self.hasItem then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetInventoryItem("player", self.slotID)
			GameTooltip:Show()
		else
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.slotName, 1, 1, 1)
			GameTooltip:AddLine("No item equipped", 0.8, 0.8, 0.8)
			GameTooltip:Show()
		end
	end)

	slot:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Initial update
	slot:Update()

	return slot
end

-- Create equipment panel (left or right side)
function E:CreateEquipmentSlots(parent)
	if not parent then return end

	-- Calculate slot size based on parent height
	-- We have 8 slots per side, with spacing between them
	local parentHeight = parent:GetHeight() or 600
	local numSlots = 8
	local spacing = 10
	local titleOffset = 80 -- Space for title at top
	local availableHeight = parentHeight - titleOffset - (spacing * (numSlots + 1))
	local slotHeight = math.floor(availableHeight / numSlots)

	-- Ensure reasonable size limits
	slotHeight = math.max(40, math.min(slotHeight, 70))

	-- Left side container (anchored directly to parent, stays within ContentFrame)
	local leftContainer = CreateFrame("Frame", nil, parent)
	leftContainer:SetSize(slotHeight, parentHeight)
	leftContainer:SetPoint("LEFT", parent, "LEFT", 100, 0)  -- 100px from left edge

	-- Right side container (anchored directly to parent, stays within ContentFrame)
	local rightContainer = CreateFrame("Frame", nil, parent)
	rightContainer:SetSize(slotHeight, parentHeight)
	rightContainer:SetPoint("LEFT", parent, "CENTER", 0, 0)  -- 150px to the right of center (closer to character)

	-- Create slots
	parent.equipmentSlots = {}
	local leftIndex = 1
	local rightIndex = 1

	for _, slotData in ipairs(EQUIPMENT_SLOTS) do
		local slot

		if slotData.side == "left" then
			slot = CreateEquipmentSlot(leftContainer, slotData, slotHeight)
			local yOffset = -titleOffset - (leftIndex - 1) * (slotHeight + spacing)
			slot:SetPoint("TOP", leftContainer, "TOP", 0, yOffset)
			leftIndex = leftIndex + 1
		else
			slot = CreateEquipmentSlot(rightContainer, slotData, slotHeight)
			local yOffset = -titleOffset - (rightIndex - 1) * (slotHeight + spacing)
			slot:SetPoint("TOP", rightContainer, "TOP", 0, yOffset)
			rightIndex = rightIndex + 1
		end

		table.insert(parent.equipmentSlots, slot)
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

-- Upgrade dropdown (placeholder for now)
function E:ToggleUpgradeDropdown(slot)
	print("Clicked slot:", slot.slotName)
	print("Item level:", slot.ilvl:GetText())

	-- TODO: Create dropdown showing available upgrades
	-- For now just print
	if slot.hasItem then
		print("Item equipped:", slot.itemLink)
		print("TODO: Show upgrade options")
	else
		print("No item equipped")
		print("TODO: Show equippable items for this slot")
	end
end
