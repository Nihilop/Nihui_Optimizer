local _, ns = ...
local E = ns.E

-- ============================================================================
-- CHAT OVERLAY (CUSTOM CHAT - NO REPARENTING)
-- Floating chat button (bottom-left) that opens custom chat in center overlay
-- - Click button or press Enter to open
-- - Custom ScrollingMessageFrame displays messages
-- - Press Enter again or Escape to close
-- ============================================================================

E.ChatOverlay = {}
local ChatOverlay = E.ChatOverlay

-- CONFIGURATION
local CONFIG = {
	button = {
		size = 50,
		offsetX = 20,
		offsetY = 20,
		icon = "Interface\\GossipFrame\\GossipGossipIcon",
	},
	overlay = {
		bgAlpha = 0.95,  -- Much darker
		fadeInDuration = 0.2,
		fadeOutDuration = 0.15,
	},
	chat = {
		width = 800,
		height = 400,
		padding = 20,
	},
}

-- State
local chatButton
local overlay
local chatContainer
local chatMessageFrame  -- ScrollingMessageFrame for displaying messages
local customEditBox     -- Our custom EditBox for input
local isOpen = false

-- ============================================================================
-- CUSTOM CHAT MESSAGE FRAME (ScrollingMessageFrame)
-- ============================================================================
local function CreateChatMessageFrame(parent)
	if chatMessageFrame then return chatMessageFrame end

	chatMessageFrame = CreateFrame("ScrollingMessageFrame", "NihuiOptimizerChatMessageFrame", parent)
	chatMessageFrame:SetSize(CONFIG.chat.width - CONFIG.chat.padding * 2, CONFIG.chat.height - CONFIG.chat.padding * 2 - 50)
	chatMessageFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", CONFIG.chat.padding, -CONFIG.chat.padding)
	chatMessageFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -CONFIG.chat.padding, CONFIG.chat.padding + 50)

	-- Set font and spacing
	chatMessageFrame:SetFontObject(ChatFontNormal)
	chatMessageFrame:SetJustifyH("LEFT")
	chatMessageFrame:SetFading(false)
	chatMessageFrame:SetMaxLines(500)
	chatMessageFrame:SetIndentedWordWrap(false)

	-- Frame level
	chatMessageFrame:SetFrameLevel(parent:GetFrameLevel() + 10)

	print("[ChatOverlay] Custom ChatMessageFrame created")
	return chatMessageFrame
end

-- ============================================================================
-- CUSTOM EDITBOX (Input field)
-- ============================================================================
local function CreateCustomEditBox(parent)
	if customEditBox then return customEditBox end

	customEditBox = CreateFrame("EditBox", "NihuiOptimizerChatEditBox", parent, "BackdropTemplate")
	customEditBox:SetSize(760, 30)
	customEditBox:SetAutoFocus(false)
	customEditBox:SetFontObject(ChatFontNormal)
	customEditBox:SetMaxLetters(255)
	customEditBox:SetHistoryLines(128)

	-- Set EXPLICIT strata and level
	customEditBox:SetFrameStrata("FULLSCREEN_DIALOG")
	customEditBox:SetFrameLevel(parent:GetFrameLevel() + 100)
	customEditBox:SetToplevel(true)

	-- Enable interactions
	customEditBox:EnableMouse(true)
	customEditBox:EnableKeyboard(true)

	-- Visual styling
	customEditBox:SetTextInsets(10, 10, 0, 0)
	customEditBox:SetTextColor(1, 1, 1, 1)

	-- Backdrop (simple border)
	customEditBox:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		tile = false,
		edgeSize = 1,
	})
	customEditBox:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
	customEditBox:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

	-- OnEnterPressed: Send message to OUR chat frame AND to server
	customEditBox:SetScript("OnEnterPressed", function(self)
		local text = self:GetText()
		if text and text ~= "" then
			-- Add to our custom chat display
			if chatMessageFrame then
				chatMessageFrame:AddMessage("|cff00ff00[You]:|r " .. text, 1, 1, 1)
				-- Auto-scroll to bottom
				chatMessageFrame:ScrollToBottom()
			end

			-- Send to server
			SendChatMessage(text, "SAY")
			self:SetText("")
		end
		self:SetFocus()
	end)

	-- OnEscapePressed: Clear text
	customEditBox:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)

	-- OnEditFocusGained: Highlight
	customEditBox:SetScript("OnEditFocusGained", function(self)
		self:SetBackdropBorderColor(1, 1, 0, 1)  -- Yellow border
	end)

	-- OnEditFocusLost: Remove highlight
	customEditBox:SetScript("OnEditFocusLost", function(self)
		self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)  -- Gray border
	end)

	print("[ChatOverlay] Custom EditBox created")
	return customEditBox
end

-- ============================================================================
-- CHAT EVENT LISTENER (Receive messages)
-- ============================================================================
local chatEventFrame = CreateFrame("Frame")

local function OnChatMessage(self, event, message, sender, ...)
	if not chatMessageFrame or not isOpen then return end

	-- Color based on event type
	local color = {1, 1, 1}  -- White default
	local prefix = ""

	if event == "CHAT_MSG_SAY" then
		color = {1, 1, 1}  -- White
		prefix = string.format("|cffffffff[%s]:|r", sender)
	elseif event == "CHAT_MSG_YELL" then
		color = {1, 0.25, 0.25}  -- Red
		prefix = string.format("|cffff4040[%s] (Yell):|r", sender)
	elseif event == "CHAT_MSG_GUILD" then
		color = {0.25, 1, 0.25}  -- Green
		prefix = string.format("|cff40ff40[Guild][%s]:|r", sender)
	elseif event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" then
		color = {0.66, 0.66, 1}  -- Blue
		prefix = string.format("|cffaaaaff[Party][%s]:|r", sender)
	elseif event == "CHAT_MSG_WHISPER" then
		color = {1, 0.5, 1}  -- Pink
		prefix = string.format("|cffff80ff[Whisper][%s]:|r", sender)
	elseif event == "CHAT_MSG_SYSTEM" then
		color = {1, 1, 0}  -- Yellow
		prefix = "|cffffff00[System]:|r"
	end

	-- Add message to our custom chat
	chatMessageFrame:AddMessage(prefix .. " " .. message, color[1], color[2], color[3])

	-- Auto-scroll to bottom
	chatMessageFrame:ScrollToBottom()
end

-- Register chat events
chatEventFrame:RegisterEvent("CHAT_MSG_SAY")
chatEventFrame:RegisterEvent("CHAT_MSG_YELL")
chatEventFrame:RegisterEvent("CHAT_MSG_GUILD")
chatEventFrame:RegisterEvent("CHAT_MSG_PARTY")
chatEventFrame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
chatEventFrame:RegisterEvent("CHAT_MSG_WHISPER")
chatEventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
chatEventFrame:SetScript("OnEvent", OnChatMessage)

-- ============================================================================
-- CHAT BUTTON (bottom-left corner)
-- ============================================================================
local function CreateChatButton()
	if chatButton then return chatButton end

	chatButton = CreateFrame("Button", "NihuiOptimizerChatButton", E.NihuiParent, "BackdropTemplate")
	chatButton:SetSize(CONFIG.button.size, CONFIG.button.size)
	chatButton:SetPoint("BOTTOMLEFT", E.NihuiParent, "BOTTOMLEFT", CONFIG.button.offsetX, CONFIG.button.offsetY)
	chatButton:SetFrameStrata("FULLSCREEN_DIALOG")  -- Same as overlay, highest strata
	chatButton:SetFrameLevel(950)  -- Very high to be clickable
	chatButton:SetToplevel(true)  -- Force always on top

	-- Backdrop
	chatButton:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		tile = false,
		edgeSize = 2,
	})
	chatButton:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
	chatButton:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

	-- Icon
	local icon = chatButton:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("CENTER")
	icon:SetSize(CONFIG.button.size * 0.7, CONFIG.button.size * 0.7)
	icon:SetTexture(CONFIG.button.icon)
	icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	chatButton.icon = icon

	-- Hover effect
	chatButton:SetScript("OnEnter", function(self)
		self:SetBackdropBorderColor(1, 1, 0, 1)
		if E.CursorTooltip then
			E.CursorTooltip:Show("Chat", "Click or press Enter to open chat")
		end
	end)

	chatButton:SetScript("OnLeave", function(self)
		self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
		if E.CursorTooltip then
			E.CursorTooltip:Hide()
		end
	end)

	-- Click handler
	chatButton:EnableMouse(true)
	chatButton:RegisterForClicks("LeftButtonUp")
	chatButton:SetScript("OnClick", function(self, button)
		print("[ChatButton] Clicked!")
		ChatOverlay:Toggle()
	end)

	chatButton:Hide()  -- Hidden by default

	return chatButton
end

-- ============================================================================
-- OVERLAY (dark transparent background)
-- ============================================================================
local function CreateOverlay()
	if overlay then return overlay end

	-- Full screen overlay
	overlay = CreateFrame("Frame", "NihuiOptimizerChatOverlay", E.NihuiParent, "BackdropTemplate")
	overlay:SetAllPoints(E.NihuiParent)
	overlay:SetFrameStrata("FULLSCREEN_DIALOG")  -- Above FULLSCREEN
	overlay:SetFrameLevel(1000)  -- Very high to be above all slots
	overlay:EnableMouse(true)  -- Block clicks below
	overlay:Hide()

	-- Dark backdrop
	overlay:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
	})
	overlay:SetBackdropColor(0, 0, 0, CONFIG.overlay.bgAlpha)

	-- Close on click (outside chat area)
	overlay:SetScript("OnMouseDown", function(self, button)
		ChatOverlay:Close()
	end)

	-- Create chat container (centered)
	chatContainer = CreateFrame("Frame", nil, overlay)
	chatContainer:SetSize(CONFIG.chat.width, CONFIG.chat.height)
	chatContainer:SetPoint("CENTER", overlay, "CENTER", 0, 0)
	chatContainer:SetFrameLevel(overlay:GetFrameLevel() + 10)

	-- Prevent clicks from closing overlay when clicking inside chat
	chatContainer:EnableMouse(true)
	chatContainer:SetScript("OnMouseDown", function(self)
		-- Do nothing, just prevent click from propagating to overlay
	end)

	-- Create custom chat message frame (ScrollingMessageFrame)
	CreateChatMessageFrame(chatContainer)

	-- Create custom edit box
	local editBox = CreateCustomEditBox(overlay)
	editBox:ClearAllPoints()
	editBox:SetPoint("BOTTOMLEFT", chatContainer, "BOTTOMLEFT", CONFIG.chat.padding, CONFIG.chat.padding)
	editBox:SetPoint("BOTTOMRIGHT", chatContainer, "BOTTOMRIGHT", -CONFIG.chat.padding, CONFIG.chat.padding)

	overlay.chatContainer = chatContainer

	print("[ChatOverlay] Overlay created with custom chat")
	return overlay
end


-- ============================================================================
-- PUBLIC API
-- ============================================================================

function ChatOverlay:Open()
	if isOpen then return end

	-- Create components if needed
	CreateOverlay()

	-- Show overlay with fade in
	overlay:SetAlpha(0)
	overlay:Show()

	if E.Animations then
		E.Animations:FadeIn(overlay, CONFIG.overlay.fadeInDuration)
	else
		overlay:SetAlpha(1)
	end

	isOpen = true

	-- Focus custom edit box after animation starts
	C_Timer.After(0.05, function()
		if customEditBox then
			customEditBox:Show()
			customEditBox:SetFocus()
			print("[ChatOverlay] CustomEditBox focused")
		end
	end)

	print("[ChatOverlay] Opened (custom chat)")
end

function ChatOverlay:Close()
	if not isOpen then return end

	-- Fade out overlay
	local duration = CONFIG.overlay.fadeOutDuration
	local elapsed = 0

	local ticker
	ticker = C_Timer.NewTicker(0.016, function(self)
		elapsed = elapsed + 0.016
		local progress = math.min(elapsed / duration, 1)
		local alpha = 1 - progress

		overlay:SetAlpha(alpha)

		if progress >= 1 then
			self:Cancel()
			overlay:Hide()

			-- Hide custom edit box
			if customEditBox then
				customEditBox:Hide()
				customEditBox:ClearFocus()
			end
		end
	end)

	isOpen = false
	print("[ChatOverlay] Closed (custom chat)")
end

function ChatOverlay:Toggle()
	if isOpen then
		self:Close()
	else
		self:Open()
	end
end

function ChatOverlay:IsOpen()
	return isOpen
end

-- Show/hide button when main frame opens/closes
function ChatOverlay:ShowButton()
	local btn = CreateChatButton()
	btn:SetAlpha(0)
	btn:Show()

	if E.Animations then
		E.Animations:FadeIn(btn, 0.3)
	else
		btn:SetAlpha(1)
	end
end

function ChatOverlay:HideButton()
	if chatButton and chatButton:IsShown() then
		chatButton:Hide()
	end

	-- Close overlay if open
	if isOpen then
		-- Force immediate close without animation
		if overlay then
			overlay:Hide()
		end
		if customEditBox then
			customEditBox:Hide()
			customEditBox:ClearFocus()
		end
		isOpen = false
		print("[ChatOverlay] Force closed on main frame hide")
	end
end

-- ============================================================================
-- KEYBINDING (Enter to open chat or focus editbox)
-- ============================================================================
function ChatOverlay:EnableKeybinding(parentFrame)
	if not parentFrame then return end

	-- Make frame accept keyboard input
	parentFrame:SetPropagateKeyboardInput(true)

	-- Register for key events
	parentFrame:SetScript("OnKeyDown", function(self, key)
		-- CRITICAL: Only process keys if addon frame is visible
		if not self:IsShown() then
			self:SetPropagateKeyboardInput(true)
			return
		end

		if key == "ENTER" or key == "RETURN" then
			if ChatOverlay:IsOpen() then
				-- Chat is open: refocus custom editbox
				if customEditBox then
					if customEditBox:HasFocus() then
						-- Already focused, do nothing (let message send)
						self:SetPropagateKeyboardInput(true)
					else
						-- Not focused, focus it
						customEditBox:Show()
						customEditBox:SetFocus()
						self:SetPropagateKeyboardInput(false)  -- Consume the key
					end
				else
					self:SetPropagateKeyboardInput(true)
				end
			else
				-- Chat is closed: open it
				ChatOverlay:Open()
				self:SetPropagateKeyboardInput(false)  -- Consume the key
			end
		elseif key == "ESCAPE" then
			-- First Escape: close chat if open
			-- Second Escape: close main frame
			if ChatOverlay:IsOpen() then
				ChatOverlay:Close()
				self:SetPropagateKeyboardInput(false)  -- Consume the key
			else
				-- Chat already closed, close the main frame
				if E and E.HideMainFrame then
					E:HideMainFrame()
				end
				self:SetPropagateKeyboardInput(false)  -- Consume the key
			end
		else
			self:SetPropagateKeyboardInput(true)  -- Let other keys through
		end
	end)

	print("[ChatOverlay] Keybinding enabled (Enter to open/focus chat)")
end

function ChatOverlay:DisableKeybinding(parentFrame)
	if not parentFrame then return end

	parentFrame:SetScript("OnKeyDown", nil)
	parentFrame:SetPropagateKeyboardInput(true)
end
