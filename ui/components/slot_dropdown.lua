local _, ns = ...
local E = ns.E

-- ============================================================================
-- SLOT DROPDOWN SYSTEM
-- Intelligent dropdown for equipment slots showing compatible bag items
-- Opens left or right based on slot position
-- ============================================================================

E.SlotDropdown = {}
local SlotDropdown = E.SlotDropdown

-- CONFIG
local CONFIG = {
	itemHeight = 32,        -- Height of each item in dropdown
	itemWidth = 250,        -- Width of dropdown
	maxItems = 10,          -- Max items to show before scrolling
	animationDuration = 0.2,-- Open animation duration
	offsetX = 5,            -- Distance from slot
}

-- Active dropdown tracking
SlotDropdown.activeDropdown = nil

-- ============================================================================
-- DROPDOWN CREATION
-- ============================================================================

function SlotDropdown:Create(parentSlot)
	-- Parent to NihuiParent for stable positioning hierarchy
	local dropdown = CreateFrame("Frame", nil, E.NihuiParent, "BackdropTemplate")
	dropdown:SetSize(CONFIG.itemWidth, CONFIG.itemHeight)
	dropdown:SetFrameStrata("FULLSCREEN_DIALOG")
	dropdown:SetFrameLevel(200)
	dropdown:Hide()

	-- Simple backdrop
	dropdown:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		tile = false,
		edgeSize = 1,
	})
	dropdown:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
	dropdown:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

	-- Close on click outside
	dropdown:EnableMouse(true)
	dropdown:SetScript("OnHide", function(self)
		if SlotDropdown.activeDropdown == self then
			SlotDropdown.activeDropdown = nil
		end
	end)

	dropdown.parentSlot = parentSlot
	dropdown.items = {}

	return dropdown
end

-- ============================================================================
-- POSITIONING (Intelligent left/right and up/down placement)
-- ============================================================================

-- Calculate intelligent vertical position (up or down) based on available space
local function GetVerticalPosition(slot, dropdownHeight)
	local slotX, slotY = slot:GetCenter()
	local screenHeight = UIParent:GetHeight()
	local slotHeight = slot:GetHeight()

	-- Calculate space available below and above the slot
	local spaceBelow = slotY - (slotHeight / 2)  -- Space from slot bottom to screen bottom
	local spaceAbove = screenHeight - slotY - (slotHeight / 2)  -- Space from slot top to screen top

	print(string.format("[SlotDropdown] Vertical check: slotY=%.1f, dropdownHeight=%.1f, spaceBelow=%.1f, spaceAbove=%.1f",
		slotY, dropdownHeight, spaceBelow, spaceAbove))

	-- If not enough space below, open upward
	if spaceBelow < dropdownHeight and spaceAbove > spaceBelow then
		return "up"
	else
		return "down"
	end
end

function SlotDropdown:PositionDropdown(dropdown, slot, direction)
	-- If no direction specified, auto-detect based on slot.side property
	if not direction then
		-- SIMPLE LOGIC:
		-- slot.side = "left" → dropdown opens to RIGHT
		-- slot.side = "right" → dropdown opens to LEFT
		direction = (slot.side == "left") and "right" or "left"

		print(string.format("[SlotDropdown] PositionDropdown: slot=%s, slot.side=%s, dropdown direction=%s",
			slot.slotName or "?", slot.side or "?", direction))
	end

	-- Get dropdown height (after items are populated)
	local dropdownHeight = dropdown:GetHeight()

	-- Intelligent vertical positioning
	local verticalPos = GetVerticalPosition(slot, dropdownHeight)

	dropdown:ClearAllPoints()

	if direction == "right" then
		-- Open to right
		if verticalPos == "up" then
			print("[SlotDropdown] Positioning dropdown to RIGHT and ABOVE slot")
			dropdown:SetPoint("BOTTOMLEFT", slot, "TOPRIGHT", CONFIG.offsetX, 0)
			dropdown.openDirection = "right_up"
		else
			print("[SlotDropdown] Positioning dropdown to RIGHT and BELOW slot")
			dropdown:SetPoint("TOPLEFT", slot, "TOPRIGHT", CONFIG.offsetX, 0)
			dropdown.openDirection = "right"
		end
	else
		-- Open to left
		if verticalPos == "up" then
			print("[SlotDropdown] Positioning dropdown to LEFT and ABOVE slot")
			dropdown:SetPoint("BOTTOMRIGHT", slot, "TOPLEFT", -CONFIG.offsetX, 0)
			dropdown.openDirection = "left_up"
		else
			print("[SlotDropdown] Positioning dropdown to LEFT and BELOW slot")
			dropdown:SetPoint("TOPRIGHT", slot, "TOPLEFT", -CONFIG.offsetX, 0)
			dropdown.openDirection = "left"
		end
	end
end

-- ============================================================================
-- POPULATE WITH COMPATIBLE ITEMS
-- ============================================================================

function SlotDropdown:PopulateItems(dropdown, slotID)
	-- Clear existing items
	for _, item in ipairs(dropdown.items) do
		item:Hide()
		item:SetParent(nil)
	end
	dropdown.items = {}

	-- Get compatible items from bags
	local compatibleItems = self:GetCompatibleItemsForSlot(slotID)

	if #compatibleItems == 0 then
		-- Show "No items" message
		local noItemsText = dropdown:CreateFontString(nil, "OVERLAY")
		noItemsText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
		noItemsText:SetPoint("CENTER")
		noItemsText:SetTextColor(0.6, 0.6, 0.6, 1)
		noItemsText:SetText("No compatible items")
		dropdown.noItemsText = noItemsText
		return
	end

	-- Hide "no items" text if it exists
	if dropdown.noItemsText then
		dropdown.noItemsText:Hide()
	end

	-- Create item buttons
	local numItems = math.min(#compatibleItems, CONFIG.maxItems)
	dropdown:SetHeight(numItems * CONFIG.itemHeight + 2)

	for i, itemData in ipairs(compatibleItems) do
		if i > CONFIG.maxItems then break end

		local itemButton = self:CreateItemButton(dropdown, itemData, i)
		table.insert(dropdown.items, itemButton)
	end
end

-- ============================================================================
-- CREATE ITEM BUTTON
-- ============================================================================

function SlotDropdown:CreateItemButton(parent, itemData, index)
	local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
	button:SetSize(CONFIG.itemWidth - 4, CONFIG.itemHeight - 2)
	button:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, -(index - 1) * CONFIG.itemHeight - 2)

	-- Backdrop (hover effect)
	button:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		tile = false,
	})
	button:SetBackdropColor(0, 0, 0, 0)

	-- Gradient background (like Narcissus)
	local gradient = button:CreateTexture(nil, "BACKGROUND")
	gradient:SetAllPoints(button)
	gradient:SetTexture("Interface\\Buttons\\WHITE8X8")
	gradient:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0), CreateColor(0.1, 0.1, 0.1, 0.6))
	button.gradient = gradient

	-- Icon
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(CONFIG.itemHeight - 6, CONFIG.itemHeight - 6)
	icon:SetPoint("LEFT", button, "LEFT", 3, 0)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	icon:SetTexture(itemData.icon)
	button.icon = icon

	-- Item name
	local name = button:CreateFontString(nil, "OVERLAY")
	name:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	name:SetPoint("LEFT", icon, "RIGHT", 5, 0)
	name:SetPoint("RIGHT", button, "RIGHT", -60, 0)  -- More space for ilvl delta
	name:SetJustifyH("LEFT")
	name:SetTextColor(1, 1, 1, 1)
	name:SetText(itemData.name)
	button.name = name

	-- Item level delta (comparison with equipped)
	local ilvlDelta = button:CreateFontString(nil, "OVERLAY")
	ilvlDelta:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
	ilvlDelta:SetPoint("RIGHT", button, "RIGHT", -5, 0)
	button.ilvlDelta = ilvlDelta

	-- Calculate ilvl delta
	if itemData.equippedIlvl and itemData.ilvl then
		local delta = itemData.ilvl - itemData.equippedIlvl
		if delta > 0 then
			ilvlDelta:SetTextColor(0, 1, 0, 1)  -- Green = upgrade
			ilvlDelta:SetText("+" .. delta)
		elseif delta < 0 then
			ilvlDelta:SetTextColor(1, 0, 0, 1)  -- Red = downgrade
			ilvlDelta:SetText(delta)
		else
			ilvlDelta:SetTextColor(0.7, 0.7, 0.7, 1)  -- Gray = same
			ilvlDelta:SetText("=" .. itemData.ilvl)
		end
	else
		ilvlDelta:SetTextColor(1, 1, 0, 1)
		ilvlDelta:SetText(itemData.ilvl or "")
	end

	-- Store item data
	button.itemData = itemData

	-- Click to equip
	button:RegisterForClicks("LeftButtonUp")
	button:SetScript("OnClick", function(self)
		self:GetParent().parentSlot:EquipItem(itemData)
		self:GetParent():Hide()
	end)

	-- Hover effects
	button:SetScript("OnEnter", function(self)
		self:SetBackdropColor(0.2, 0.2, 0.2, 0.8)

		-- Show tooltip
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetBagItem(itemData.bag, itemData.slot)
		GameTooltip:Show()
	end)

	button:SetScript("OnLeave", function(self)
		self:SetBackdropColor(0, 0, 0, 0)
		GameTooltip:Hide()
	end)

	return button
end

-- ============================================================================
-- GET COMPATIBLE ITEMS FROM BAGS
-- ============================================================================

function SlotDropdown:GetCompatibleItemsForSlot(slotID)
	local items = {}

	print("[SlotDropdown] Scanning bags for slotID:", slotID)

	-- Get equipped item ilvl for comparison
	local equippedIlvl
	local equippedLocation = ItemLocation:CreateFromEquipmentSlot(slotID)
	if C_Item.DoesItemExist(equippedLocation) then
		equippedIlvl = C_Item.GetCurrentItemLevel(equippedLocation)
		print("[SlotDropdown] Equipped ilvl:", equippedIlvl)
	end

	-- Iterate through all bags (0-4 = backpack + bags)
	for bag = 0, 4 do
		local numSlots = C_Container.GetContainerNumSlots(bag)
		for slot = 1, numSlots do
			local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)

			if C_Item.DoesItemExist(itemLocation) then
				local itemLink = C_Item.GetItemLink(itemLocation)
				if itemLink then
					-- Check if item can be equipped in this slot
					local canEquip = self:CanItemBeEquippedInSlot(itemLocation, slotID)

					local itemName = C_Item.GetItemName(itemLocation)
					print(string.format("[SlotDropdown] Bag %d Slot %d: %s - canEquip: %s", bag, slot, itemName or "unknown", tostring(canEquip)))

					if canEquip then
						local itemIcon = C_Item.GetItemIcon(itemLocation)
						local itemLevel = C_Item.GetCurrentItemLevel(itemLocation)

						table.insert(items, {
							bag = bag,
							slot = slot,
							icon = itemIcon,
							name = itemName,
							ilvl = itemLevel,
							itemLink = itemLink,
							itemLocation = itemLocation,
							equippedIlvl = equippedIlvl,  -- Add equipped ilvl for comparison
						})
						print(string.format("[SlotDropdown] Added: %s (ilvl %s)", itemName, itemLevel or "?"))
					end
				end
			end
		end
	end

	print("[SlotDropdown] Total compatible items found:", #items)

	-- Sort by item level (highest first)
	table.sort(items, function(a, b)
		return (a.ilvl or 0) > (b.ilvl or 0)
	end)

	return items
end

-- ============================================================================
-- CHECK IF ITEM CAN BE EQUIPPED IN SLOT
-- ============================================================================

function SlotDropdown:CanItemBeEquippedInSlot(itemLocation, slotID)
	-- Get item equip location (returns Enum.InventoryType - a number)
	local itemInventoryType = C_Item.GetItemInventoryType(itemLocation)

	if not itemInventoryType then
		return false
	end

	-- Enum.InventoryType values (numbers, not strings!)
	-- 1 = Head, 2 = Neck, 3 = Shoulder, 4 = Shirt, 5 = Chest, etc.
	local InventoryType = {
		IndexNonEquipType = 0,
		IndexHeadType = 1,
		IndexNeckType = 2,
		IndexShoulderType = 3,
		IndexBodyType = 4,
		IndexChestType = 5,
		IndexWaistType = 6,
		IndexLegsType = 7,
		IndexFeetType = 8,
		IndexWristType = 9,
		IndexHandType = 10,
		IndexFingerType = 11,
		IndexTrinketType = 12,
		IndexWeaponType = 13,
		IndexShieldType = 14,
		IndexRangedType = 15,
		IndexCloakType = 16,
		Index2HweaponType = 17,
		IndexBagType = 18,
		IndexTabardType = 19,
		IndexRobeType = 20,
		IndexWeaponmainhandType = 21,
		IndexWeaponoffhandType = 22,
		IndexHoldableType = 23,
		IndexAmmoType = 24,
		IndexThrownType = 25,
		IndexRangedrightType = 26,
		IndexQuiverType = 27,
		IndexRelicType = 28,
	}

	-- Map slot IDs to accepted inventory types
	local slotMapping = {
		[1] = {InventoryType.IndexHeadType},                                    -- Head
		[2] = {InventoryType.IndexNeckType},                                    -- Neck
		[3] = {InventoryType.IndexShoulderType},                                -- Shoulder
		[15] = {InventoryType.IndexCloakType},                                  -- Back
		[5] = {InventoryType.IndexChestType, InventoryType.IndexRobeType},      -- Chest
		[4] = {InventoryType.IndexBodyType},                                    -- Shirt
		[19] = {InventoryType.IndexTabardType},                                 -- Tabard
		[9] = {InventoryType.IndexWristType},                                   -- Wrist
		[10] = {InventoryType.IndexHandType},                                   -- Hands
		[6] = {InventoryType.IndexWaistType},                                   -- Waist
		[7] = {InventoryType.IndexLegsType},                                    -- Legs
		[8] = {InventoryType.IndexFeetType},                                    -- Feet
		[11] = {InventoryType.IndexFingerType},                                 -- Ring 1
		[12] = {InventoryType.IndexFingerType},                                 -- Ring 2
		[13] = {InventoryType.IndexTrinketType},                                -- Trinket 1
		[14] = {InventoryType.IndexTrinketType},                                -- Trinket 2
		[16] = {InventoryType.IndexWeaponType, InventoryType.Index2HweaponType, InventoryType.IndexWeaponmainhandType, InventoryType.IndexWeaponoffhandType, InventoryType.IndexRangedType, InventoryType.IndexRangedrightType},  -- Main Hand
		[17] = {InventoryType.IndexWeaponType, InventoryType.IndexWeaponoffhandType, InventoryType.IndexShieldType, InventoryType.IndexHoldableType},  -- Off Hand
	}

	local allowedTypes = slotMapping[slotID]
	if not allowedTypes then
		print("[SlotDropdown] No mapping for slotID:", slotID)
		return false
	end

	for _, allowedType in ipairs(allowedTypes) do
		if itemInventoryType == allowedType then
			return true
		end
	end

	return false
end

-- ============================================================================
-- OPEN/CLOSE DROPDOWN
-- ============================================================================

function SlotDropdown:Toggle(slot)
	print("[SlotDropdown] Toggle called for slot:", slot.slotName)

	-- Close existing dropdown
	if self.activeDropdown then
		print("[SlotDropdown] Closing existing dropdown")
		self:Close(self.activeDropdown)
	end

	-- If clicking same slot, just close
	if self.activeDropdown and self.activeDropdown.parentSlot == slot then
		print("[SlotDropdown] Same slot clicked, just closing")
		return
	end

	-- Open new dropdown
	print("[SlotDropdown] Opening dropdown")
	self:Open(slot)
end

function SlotDropdown:Open(slot, direction)
	print("[SlotDropdown] Open called for slot:", slot.slotName, "slotID:", slot.slotID, "direction:", direction or "auto")

	local dropdown = self:Create(slot)
	print("[SlotDropdown] Dropdown created")

	-- Populate with items FIRST (so we know the height)
	self:PopulateItems(dropdown, slot.slotID)
	print("[SlotDropdown] Dropdown populated with", #dropdown.items, "items")

	-- Position based on slot location and dropdown height (intelligent positioning)
	self:PositionDropdown(dropdown, slot, direction)
	print("[SlotDropdown] Dropdown positioned, openDirection:", dropdown.openDirection)

	-- Show dropdown immediately (no fade animation, just slide)
	dropdown:SetAlpha(1)
	dropdown:Show()
	print("[SlotDropdown] Dropdown shown")

	-- Animate slide based on direction
	if E.Animations then
		local slideDistance = 20
		local slideDuration = 0.15

		if dropdown.openDirection == "right" or dropdown.openDirection == "right_up" then
			-- Slide from left (start offset to left, slide right)
			print("[SlotDropdown] Animating slide RIGHT")
			E.Animations:SlideRight(dropdown, slideDuration, slideDistance)
		else
			-- Slide from right (start offset to right, slide left)
			print("[SlotDropdown] Animating slide LEFT")
			E.Animations:SlideLeft(dropdown, slideDuration, slideDistance)
		end
	else
		print("[SlotDropdown] ERROR: E.Animations is nil")
	end

	self.activeDropdown = dropdown
	print("[SlotDropdown] activeDropdown set")
end

function SlotDropdown:Close(dropdown)
	if dropdown then
		dropdown:Hide()
	end
	self.activeDropdown = nil
end

-- Close dropdown when clicking outside
local closeFrame = CreateFrame("Frame")
closeFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
closeFrame:SetScript("OnEvent", function(self, event, button)
	if SlotDropdown.activeDropdown and SlotDropdown.activeDropdown:IsShown() then
		-- Check if mouse is over dropdown or its parent slot
		if not MouseIsOver(SlotDropdown.activeDropdown) and not MouseIsOver(SlotDropdown.activeDropdown.parentSlot) then
			SlotDropdown:Close(SlotDropdown.activeDropdown)
		end
	end
end)
