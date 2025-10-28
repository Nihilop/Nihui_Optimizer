local _, ns = ...
local E = ns.E

-- ============================================================================
-- TAB 3: TALENTS VIEW
-- Character on left, Blizzard talent tree embedded on right half
-- ============================================================================

-- CONFIGURATION
local CONFIG = {
	-- Camera settings
	cameraMode = "TALENTS_VIEW",

	-- Container margins (space around talent frame)
	container = {
		marginRight = 40,   -- Space from right edge of screen
		marginTop = 40,     -- Space from top
		marginBottom = 40,  -- Space from bottom
		marginLeft = 40,    -- Space from left (if needed)

		-- Optional: Add extra padding inside container
		paddingTop = 10,
		paddingRight = 10,
		paddingBottom = 10,
		paddingLeft = 10,
	},

	-- Container backdrop (optional, can be disabled)
	backdrop = {
		enabled = false,  -- Disabled (talent frame provides its own background)
		bgColor = {0.05, 0.05, 0.05, 0.9},
		borderColor = {0.3, 0.3, 0.3, 1},
	},

	-- Animations
	animations = {
		enabled = true,
		fadeInDuration = 0.4,
	},
}

-- Export config
E.TalentsTabConfig = CONFIG

-- Store original parent and state
local originalTalentParent = nil
local originalTalentPoints = {}
local isEmbedded = false

-- Get Blizzard's talent frame (retail uses PlayerSpellsFrame)
local function GetBlizzardTalentFrame()
	-- Try different possible talent frame names based on WoW version
	if PlayerSpellsFrame then
		return PlayerSpellsFrame
	elseif ClassTalentFrame then
		return ClassTalentFrame
	elseif PlayerTalentFrame then
		return PlayerTalentFrame
	end
	return nil
end

-- Hide unwanted elements from Blizzard talent UI
local function HideUnwantedElements(talentFrame)
	if not talentFrame then return end

	print("[TalentsTab] Hiding unwanted elements...")

	-- Hide common UI elements we don't want
	local elementsToHide = {
		"PortraitContainer",
		"TitleContainer",
		"CloseButton",
		"TopBar",
		-- "TabSystem",  -- KEEP VISIBLE: This contains the navigation tabs (Talents, Specialization, etc.)
		"MaximizeMinimizeButton",
	}

	for _, elementName in ipairs(elementsToHide) do
		local element = talentFrame[elementName]
		if element and element.Hide then
			element:Hide()
			print("[TalentsTab] Hidden: " .. elementName)
		end
	end

	-- Keep TabSystem visible but log it
	if talentFrame.TabSystem then
		print("[TalentsTab] TabSystem kept visible for navigation")
	end

	-- Hide title bar if it exists
	if talentFrame.TitleBar then
		talentFrame.TitleBar:Hide()
	end

	-- Hide borders/backdrop if we want clean integration
	if talentFrame.NineSlice then
		talentFrame.NineSlice:Hide()
	end
	if talentFrame.Border then
		talentFrame.Border:Hide()
	end

	print("[TalentsTab] Finished hiding unwanted elements")
end

-- Show previously hidden elements (when restoring)
local function ShowHiddenElements(talentFrame)
	if not talentFrame then return end

	print("[TalentsTab] Restoring hidden elements...")

	local elementsToShow = {
		"PortraitContainer",
		"TitleContainer",
		"CloseButton",
		"TopBar",
		-- "TabSystem",  -- Already visible, no need to restore
	}

	for _, elementName in ipairs(elementsToShow) do
		local element = talentFrame[elementName]
		if element and element.Show then
			element:Show()
			print("[TalentsTab] Restored: " .. elementName)
		end
	end

	if talentFrame.TitleBar then
		talentFrame.TitleBar:Show()
	end
	if talentFrame.NineSlice then
		talentFrame.NineSlice:Show()
	end
	if talentFrame.Border then
		talentFrame.Border:Show()
	end

	print("[TalentsTab] Finished restoring elements")
end

-- Embed talent frame into our custom container
-- The container controls size, the talent frame fills it completely
local function EmbedTalentFrame(container)
	local talentFrame = GetBlizzardTalentFrame()
	if not talentFrame then
		print("[TalentsTab] ERROR: Could not find Blizzard talent frame")
		return nil
	end

	-- Store original parent and positioning for restoration
	if not originalTalentParent then
		originalTalentParent = talentFrame:GetParent()
		-- Store original positioning
		originalTalentPoints = {}
		for i = 1, talentFrame:GetNumPoints() do
			local point, relativeTo, relativePoint, xOfs, yOfs = talentFrame:GetPoint(i)
			table.insert(originalTalentPoints, {point, relativeTo, relativePoint, xOfs, yOfs})
		end
		-- No need to store scale - we don't modify it anymore!
	end

	-- Read natural dimensions of talent frame (NOW it should be initialized)
	local naturalWidth = talentFrame:GetWidth()
	local naturalHeight = talentFrame:GetHeight()

	-- Validate dimensions
	if not naturalWidth or naturalWidth <= 0 or not naturalHeight or naturalHeight <= 0 then
		print(string.format("[TalentsTab] ERROR: Invalid talent frame dimensions (w=%.1f, h=%.1f), using fallbacks",
			naturalWidth or 0, naturalHeight or 0))
		naturalWidth = 1000
		naturalHeight = 750
	end

	print(string.format("[TalentsTab] Talent frame natural size: %.0fx%.0f", naturalWidth, naturalHeight))

	-- Resize container to fit talent frame + padding
	local padding = CONFIG.container.paddingLeft or 10
	local paddingTop = CONFIG.container.paddingTop or 10
	local paddingRight = CONFIG.container.paddingRight or 10
	local paddingBottom = CONFIG.container.paddingBottom or 10

	local containerWidth = naturalWidth + padding + paddingRight
	local containerHeight = naturalHeight + paddingTop + paddingBottom

	container:SetSize(containerWidth, containerHeight)

	print(string.format("[TalentsTab] Container resized: %.0fx%.0f (to fit talent frame)",
		containerWidth, containerHeight))

	-- Reparent to our custom container
	talentFrame:SetParent(container)
	talentFrame:ClearAllPoints()

	-- Position talent frame within container (respecting padding)
	talentFrame:SetPoint("TOPLEFT", container, "TOPLEFT", padding, -paddingTop)

	print("[TalentsTab] Talent frame positioned - NO scale/size modifications")

	-- Hide unwanted elements
	HideUnwantedElements(talentFrame)

	-- Show the frame
	talentFrame:Show()
	talentFrame:SetAlpha(0)  -- Start hidden for animation

	isEmbedded = true

	print(string.format("[TalentsTab] Embedded talent frame: size=%.0fx%.0f", containerWidth, containerHeight))

	return talentFrame
end

-- Restore talent frame to original state
local function RestoreTalentFrame()
	local talentFrame = GetBlizzardTalentFrame()
	if not talentFrame or not isEmbedded then return end

	print("[TalentsTab] Restoring talent frame to original state...")

	-- CRITICAL: Restore in correct order
	-- Since we don't modify scale or size anymore, restoration is simpler!

	-- 1. Restore parent first
	if originalTalentParent then
		talentFrame:SetParent(originalTalentParent)
		print("[TalentsTab] - Restored parent")
	end

	-- 2. Restore positioning
	talentFrame:ClearAllPoints()
	for _, pointData in ipairs(originalTalentPoints) do
		talentFrame:SetPoint(unpack(pointData))
	end
	print("[TalentsTab] - Restored anchors")

	-- 3. Restore hidden elements
	ShowHiddenElements(talentFrame)
	print("[TalentsTab] - Restored hidden elements")

	-- 4. Hide the frame (Blizzard will show it when player opens talents normally)
	talentFrame:Hide()

	isEmbedded = false

	print("[TalentsTab] Talent frame fully restored!")
end

-- Create Talents Tab UI
function E:CreateTalentsTab(parent)
	-- Main container (fills entire tab)
	local tabContainer = CreateFrame("Frame", nil, parent)
	tabContainer:SetAllPoints(parent)
	tabContainer:EnableMouse(true)  -- Block clicks to prevent interaction with UI below

	-- Create container (size will be set when embedding talent frame)
	local talentContainer = CreateFrame("Frame", nil, tabContainer, "BackdropTemplate")

	-- Position container on right side with margins (size set later)
	talentContainer:SetPoint("TOPRIGHT", tabContainer, "TOPRIGHT",
		-CONFIG.container.marginRight,
		-CONFIG.container.marginTop)

	print("[TalentsTab] Container created (size will be determined when embedding talent frame)")

	-- Optional backdrop
	if CONFIG.backdrop.enabled then
		talentContainer:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			tile = false,
			edgeSize = 1,
		})
		local bgColor = CONFIG.backdrop.bgColor
		local borderColor = CONFIG.backdrop.borderColor
		talentContainer:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
		talentContainer:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
	end

	-- Store references (embed will happen later in ShowTalentsTab)
	tabContainer.talentContainer = talentContainer
	tabContainer.talentFrame = nil  -- Will be set when embedded

	return tabContainer
end

-- Show Talents Tab (called when tab becomes active)
function E:ShowTalentsTab()
	if not self.MainFrame or not self.MainFrame.talentsContainer then return end

	print("[TalentsTab] ShowTalentsTab called")

	-- Access the talent frame and its custom container
	local tabContainer = self.MainFrame.talentsContainer
	local talentContainer = tabContainer.talentContainer
	local talentFrame = tabContainer.talentFrame

	-- Embed talent frame if not already done
	if not talentFrame then
		print("[TalentsTab] Embedding talent frame...")

		-- Wait one frame to ensure layout is complete
		C_Timer.After(0.01, function()
			if not tabContainer.talentFrame then
				talentFrame = EmbedTalentFrame(talentContainer)
				tabContainer.talentFrame = talentFrame

				if talentFrame then
					talentFrame:Show()
					talentFrame:SetAlpha(0)
					print("[TalentsTab] Talent frame embedded successfully")
				else
					print("[TalentsTab] ERROR: Failed to embed talent frame")
				end
			end
		end)
	else
		-- Frame already exists, just ensure it's visible
		talentFrame:Show()
		talentFrame:SetAlpha(0)
	end

	-- Set Camera.onReady callback for this tab's animations
	E.Camera.onReady = function()
		print("[TalentsTab] Camera.onReady callback triggered")

		-- Get fresh reference to talent frame (in case it was re-created)
		local currentTalentFrame = tabContainer.talentFrame

		if not currentTalentFrame then
			print("[TalentsTab] ERROR: No talent frame found in callback")
			E.AnimationManager.isTransitioning = false
			return
		end

		local animDuration = CONFIG.animations.fadeInDuration or 0.4

		if CONFIG.animations.enabled then
			-- Simple fade in animation for talent frame
			E.AnimationManager:AnimateTab(function()
				if E.Animations then
					print(string.format("[TalentsTab] Starting FadeIn with duration=%.2f", animDuration))
					E.Animations:FadeIn(currentTalentFrame, animDuration, function()
						E.AnimationManager.isTransitioning = false
					end)
				else
					currentTalentFrame:SetAlpha(1)
					E.AnimationManager.isTransitioning = false
				end
			end)
		else
			currentTalentFrame:SetAlpha(1)
			E.AnimationManager.isTransitioning = false
		end
	end

	-- Apply camera mode (character on left, talent tree visible on right)
	if self.CameraPresets and self.CameraPresets.EnterTalentsView then
		self.CameraPresets:EnterTalentsView(true)  -- Animate
	end
end

-- Hide Talents Tab (called when switching away)
function E:HideTalentsTab()
	print("[TalentsTab] HideTalentsTab called")

	local talentFrame = GetBlizzardTalentFrame()
	if talentFrame and isEmbedded then
		-- Hide without restoring (we'll restore only when main frame closes)
		talentFrame:Hide()
	end
end

-- Cleanup when main frame closes (restore Blizzard frame)
function E:CleanupTalentsTab()
	RestoreTalentFrame()
end
