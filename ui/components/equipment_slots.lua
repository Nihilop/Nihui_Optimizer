local _, ns = ...
local E = ns.E

-- ========================================
-- SLOT STYLE CONFIGURATION (from Nihui_iv)
-- ========================================
-- Customize these to change the slot appearance
local SLOT_STYLE = {
	-- Mask for icon and quality border (circular)
	maskAtlas = "UI-HUD-CoolDownManager-Mask",

	-- Overlay texture (decorative border under quality border)
	overlayAtlas = "UI-HUD-CoolDownManager-IconOverlay",

	-- Quality/Rarity border (colored glow for item rarity)
	quality = {
		atlas = "perks-slot-glow",      -- Atlas for quality border glow
		sizeRatio = 1,                -- Size relative to slot (1.0 = same size)
		alpha = 0.9,                    -- Transparency (0-1)
		blendMode = "ADD",              -- Blend mode: "ADD" for glow effect
		drawLayer = "OVERLAY",          -- Draw layer (OVERLAY = on top of icon)
		sublevel = 0,                   -- Sublevel within draw layer
		useBrightness = true,           -- Multiply colors for extra brightness?
		brightnessMultiplier = 1.0,     -- Brightness multiplier (only if useBrightness = true)
	},

	-- Hover/Highlight effect
	hover = {
		atlas = "bags-newitem",         -- Texture for hover effect
		sizeRatio = 1.05,               -- Size relative to slot (105% = slightly larger)
		alpha = 0.5,                    -- Transparency (0-1)
		blendMode = "ADD",              -- Blend mode: "BLEND", "ADD", "MOD", etc.
		vertexColor = { r = 1, g = 1, b = 1 },  -- Color tint (white by default)
	},

	-- Sizes (relative to slot size)
	maskSizeRatio = 0.94,      -- Mask is 94% of slot size (slightly smaller)
	overlaySizeRatio = 1.25,   -- Overlay is 125% of slot size (extends beyond)
}

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

-- Create a single equipment slot button (Nihui_iv style)
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

	-- NO BACKDROP (Nihui_iv style - clean, no background)

	-- Empty slot background (shown when slot is empty)
	local emptyBg = slot:CreateTexture(nil, "BACKGROUND")
	emptyBg:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, 0)
	emptyBg:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 0, 0)
	emptyBg:SetColorTexture(0.15, 0.15, 0.15, 0.6)  -- Dark gray, semi-transparent
	slot.emptyBg = emptyBg

	-- Item icon
	local icon = slot:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
	icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	slot.icon = icon

	-- Apply circular mask to icon and empty background (Nihui_iv style)
	local iconMask = slot:CreateMaskTexture()
	local maskSize = slotHeight * SLOT_STYLE.maskSizeRatio
	iconMask:SetSize(maskSize, maskSize)
	iconMask:SetPoint("CENTER", slot, "CENTER", 0, 0)
	iconMask:SetAtlas(SLOT_STYLE.maskAtlas, false)
	icon:AddMaskTexture(iconMask)
	emptyBg:AddMaskTexture(iconMask)  -- Also mask the empty background
	slot.iconMask = iconMask

	-- Create decorative overlay (black border base)
	local overlayTexture = slot:CreateTexture(nil, "ARTWORK", nil, 2)
	local overlaySize = slotHeight * SLOT_STYLE.overlaySizeRatio
	overlayTexture:SetSize(overlaySize, overlaySize)
	overlayTexture:SetPoint("CENTER", slot, "CENTER", 0, 0)
	overlayTexture:SetAtlas(SLOT_STYLE.overlayAtlas, false)
	slot.nihuiOverlay = overlayTexture

	-- Create custom quality border texture (for rarity glow on top of black border)
	local qualityBorder = slot:CreateTexture(nil, SLOT_STYLE.quality.drawLayer, nil, SLOT_STYLE.quality.sublevel)
	local qualitySize = slotHeight * SLOT_STYLE.quality.sizeRatio
	qualityBorder:SetSize(qualitySize, qualitySize)
	qualityBorder:SetPoint("CENTER", slot, "CENTER", 0, 0)
	qualityBorder:SetAtlas(SLOT_STYLE.quality.atlas, false)
	qualityBorder:SetBlendMode(SLOT_STYLE.quality.blendMode)
	qualityBorder:Hide()  -- Hidden by default, shown when item has quality
	slot.nihuiQualityBorder = qualityBorder

	-- Create custom hover/highlight texture
	local highlight = slot:CreateTexture(nil, "HIGHLIGHT")
	if SLOT_STYLE.hover.atlas then
		highlight:SetAtlas(SLOT_STYLE.hover.atlas, false)
	end

	-- Size and position
	local hoverSize = slotHeight * SLOT_STYLE.hover.sizeRatio
	highlight:SetSize(hoverSize, hoverSize)
	highlight:SetPoint("CENTER", slot, "CENTER", 0, 0)

	-- Visual properties
	highlight:SetAlpha(SLOT_STYLE.hover.alpha)
	highlight:SetBlendMode(SLOT_STYLE.hover.blendMode)

	if SLOT_STYLE.hover.vertexColor then
		local c = SLOT_STYLE.hover.vertexColor
		highlight:SetVertexColor(c.r, c.g, c.b, 1)
	end

	-- Set as highlight texture (appears on mouse over)
	slot:SetHighlightTexture(highlight)
	slot.nihuiHighlight = highlight

	-- Create info panel (shows item name, ilvl, bonuses)
	if E.SlotInfoPanel then
		slot.infoPanel = E.SlotInfoPanel:Create(slot, slotData.side)
	end

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

				-- Hide empty background when item is present
				self.emptyBg:Hide()

				-- Update quality border (Nihui_iv style)
				if quality and quality >= Enum.ItemQuality.Uncommon then
					local r, g, b = C_Item.GetItemQualityColor(quality)

					-- Apply brightness multiplier if enabled
					if SLOT_STYLE.quality.useBrightness then
						local brightness = SLOT_STYLE.quality.brightnessMultiplier
						r = r * brightness
						g = g * brightness
						b = b * brightness
					end

					-- Apply colors with configured alpha
					self.nihuiQualityBorder:SetVertexColor(r, g, b, SLOT_STYLE.quality.alpha)
					self.nihuiQualityBorder:Show()
				else
					self.nihuiQualityBorder:Hide()
				end

				self.hasItem = true
				self.itemLink = itemLink

				-- Update info panel (pass slotID, not itemLocation)
				if self.infoPanel and E.SlotInfoPanel then
					E.SlotInfoPanel:Update(self.infoPanel, self.slotID)
				end
			else
				-- No item link available yet
				self.icon:SetTexture(nil)
				self.emptyBg:Show()  -- Show empty background
				self.nihuiQualityBorder:Hide()
				self.hasItem = false
				self.itemLink = nil

				if self.infoPanel and E.SlotInfoPanel then
					E.SlotInfoPanel:Hide(self.infoPanel)
				end
			end
		else
			-- Empty slot
			self.icon:SetTexture(nil)
			self.emptyBg:Show()  -- Show empty background
			self.nihuiQualityBorder:Hide()
			self.hasItem = false
			self.itemLink = nil

			if self.infoPanel and E.SlotInfoPanel then
				E.SlotInfoPanel:Hide(self.infoPanel)
			end
		end
	end

	-- Click handler (open context menu)
	slot:SetScript("OnClick", function(self, button)
		if button == "LeftButton" then
			-- Show slot context menu
			if E.SlotContextMenu then
				E.SlotContextMenu:Show(self)
			end
		end
	end)

	-- Tooltip handlers (keep tooltip visible when hovering between slots)
	slot:SetScript("OnEnter", function(self)
		-- Cancel any pending hide
		if E.SlotTooltip then
			E.SlotTooltip:CancelHide()
			E.SlotTooltip:Show(self)
		end
	end)

	slot:SetScript("OnLeave", function(self)
		-- Schedule hide (will be cancelled if entering another slot)
		if E.SlotTooltip then
			E.SlotTooltip:ScheduleHide()
		end
	end)

	return slot
end

-- Create equipment slots (called from equipment tab)
function E:CreateEquipmentSlots(parent, config)
	local slots = {}

	-- Calculate positions
	local screenWidth = parent:GetWidth()
	local screenHeight = parent:GetHeight()

	-- Default slot height (can be configured) - 2x bigger now
	local slotHeight = 64

	-- Spacing between slots
	local spacing = config.slotSpacing or 10

	-- Calculate total height of slot group (9 slots per side)
	local slotsPerSide = 9
	local totalHeight = (slotsPerSide * slotHeight) + ((slotsPerSide - 1) * spacing)

	-- Calculate vertical center offset
	local verticalOffset = (screenHeight - totalHeight) / 2

	-- Create slots for each side
	for _, slotData in ipairs(EQUIPMENT_SLOTS) do
		local slot = CreateEquipmentSlot(parent, slotData, slotHeight)

		-- Position based on side
		local slotIndex = 0
		for i, s in ipairs(EQUIPMENT_SLOTS) do
			if s.id == slotData.id then
				slotIndex = i
				break
			end
		end

		if slotData.side == "left" then
			-- Left side slots (9 slots, indices 1-9)
			local leftSideIndex = 0
			for i = 1, slotIndex do
				if EQUIPMENT_SLOTS[i].side == "left" then
					leftSideIndex = leftSideIndex + 1
				end
			end

			local x = config.leftOffsetX
			-- Use negative offset to go DOWN from top, then subtract for each slot
			local y = -verticalOffset - ((leftSideIndex - 1) * (slotHeight + spacing))

			slot:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
		else
			-- Right side slots (9 slots, indices 10-18)
			local rightSideIndex = 0
			for i = 1, slotIndex do
				if EQUIPMENT_SLOTS[i].side == "right" then
					rightSideIndex = rightSideIndex + 1
				end
			end

			local x = config.rightOffsetX
			-- Use negative offset to go DOWN from top, then subtract for each slot
			local y = -verticalOffset - ((rightSideIndex - 1) * (slotHeight + spacing))

			slot:SetPoint("TOP", parent, "TOP", x, y)
		end

		-- Create gap detector between this slot and the next
		if slotIndex < #EQUIPMENT_SLOTS then
			local nextSlotData = EQUIPMENT_SLOTS[slotIndex + 1]
			if nextSlotData.side == slotData.side then
				-- Same side, create gap detector
				local gap = CreateGapDetector(parent, slotHeight, spacing)

				if slotData.side == "left" then
					local leftSideIndex = 0
					for i = 1, slotIndex do
						if EQUIPMENT_SLOTS[i].side == "left" then
							leftSideIndex = leftSideIndex + 1
						end
					end

					local x = config.leftOffsetX
					local y = -verticalOffset - ((leftSideIndex - 1) * (slotHeight + spacing)) - slotHeight

					gap:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
				else
					local rightSideIndex = 0
					for i = 1, slotIndex do
						if EQUIPMENT_SLOTS[i].side == "right" then
							rightSideIndex = rightSideIndex + 1
						end
					end

					local x = config.rightOffsetX
					local y = -verticalOffset - ((rightSideIndex - 1) * (slotHeight + spacing)) - slotHeight

					gap:SetPoint("TOP", parent, "TOP", x, y)
				end
			end
		end

		table.insert(slots, slot)
	end

	-- Store references
	parent.equipmentSlots = slots

	return slots
end

-- Update all equipment slots
function E:UpdateEquipmentSlots()
	if not self.MainFrame or not self.MainFrame.equipmentSlots then
		return
	end

	for _, slot in ipairs(self.MainFrame.equipmentSlots) do
		slot:Update()
	end
end
