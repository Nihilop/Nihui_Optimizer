local _, ns = ...
local E = ns.E

-- UIParent Fade system (IDENTICAL to Narcissus)
local UIParentFade = CreateFrame("Frame")
UIParentFade:Hide()
E.UIParentFade = UIParentFade

local ALPHA_UPDATE_INTERVAL = 0.08  -- Limit update frequency
local FADE_IN_RATE = 2  -- 0.5 second (alpha 0 -> 1)
local FADE_OUT_RATE = 2  -- 0.5 second (alpha 1 -> 0)

-- Tooltip visibility enforcer (forces GameTooltip to stay visible)
local TooltipEnforcer = CreateFrame("Frame")
TooltipEnforcer:Hide()

local function TooltipEnforcer_OnUpdate(self, elapsed)
	-- Force GameTooltip to be visible if it has an owner
	if GameTooltip and GameTooltip:GetOwner() then
		if not GameTooltip:IsShown() then
			print("[TooltipEnforcer] GameTooltip has owner but is hidden, forcing Show()")
			GameTooltip:Show()
		end
	end
end

function E:StartTooltipEnforcer()
	if not TooltipEnforcer.isRunning then
		print("[TooltipEnforcer] Starting enforcer")
		TooltipEnforcer:SetScript("OnUpdate", TooltipEnforcer_OnUpdate)
		TooltipEnforcer:Show()
		TooltipEnforcer.isRunning = true
	end
end

function E:StopTooltipEnforcer()
	if TooltipEnforcer.isRunning then
		print("[TooltipEnforcer] Stopping enforcer")
		TooltipEnforcer:SetScript("OnUpdate", nil)
		TooltipEnforcer:Hide()
		TooltipEnforcer.isRunning = false
	end
end

-- Fade In (show UI)
local function FadeIn_OnUpdate(self, elapsed)
	self.t = self.t + elapsed
	self.alpha = self.alpha + FADE_IN_RATE * elapsed

	if self.t < ALPHA_UPDATE_INTERVAL then
		return
	else
		self.t = 0
	end

	if self.alpha >= 1 then
		self.alpha = 1
		self:StopOnUpdate()
	end

	UIParent:SetAlpha(self.alpha)
end

-- Fade Out (hide UI)
local function FadeOut_OnUpdate(self, elapsed)
	self.t = self.t + elapsed
	self.alpha = self.alpha - FADE_OUT_RATE * elapsed

	if self.t < ALPHA_UPDATE_INTERVAL then
		return
	else
		self.t = 0
	end

	if self.alpha <= 0 then
		self.alpha = 0
		self:StopOnUpdate()
		SetUIVisibility(false)  -- Same as Alt + Z (hides UIParent children)
		UIParent:SetAlpha(1)  -- Reset alpha for when we show again

		-- CRITICAL: Re-show our frames after SetUIVisibility hides them
		-- SetUIVisibility(false) hides ALL UIParent children, even with SetIgnoreParentAlpha
		-- Our frames have NO parent (just anchored to UIParent), so they stay visible
		-- But we force Show() just to be safe
		if E.MainFrame and E.MainFrame:IsShown() then
			E.MainFrame:Show()  -- Force back to visible
		end
		if E.DebugWindow and E.DebugWindow:IsShown() then
			E.DebugWindow:Show()  -- Force debug window visible too
		end
		-- Force GameTooltip to be visible (it's a UIParent child)
		if GameTooltip then
			GameTooltip:SetIgnoreParentAlpha(true)
			-- Force Show() if tooltip is being displayed
			if GameTooltip:GetOwner() then
				C_Timer.After(0.01, function()
					if GameTooltip:GetOwner() then
						GameTooltip:Show()
					end
				end)
			end
		end
		return
	end

	UIParent:SetAlpha(self.alpha)
end

function UIParentFade:StopOnUpdate()
	self:SetScript("OnUpdate", nil)
	self.t = nil
end

function UIParentFade:UpdateAlpha()
	self.alpha = UIParent:GetAlpha()
end

-- Fade IN the UIParent (show WoW UI progressively)
function UIParentFade:FadeInUIParent()
	if UIParent:IsVisible() and UIParent:GetAlpha() == 1 then
		return
	end

	if InCombatLockdown() then
		return
	end

	self.t = 0
	self.alpha = 0
	UIParent:SetAlpha(self.alpha)
	self:SetScript("OnUpdate", FadeIn_OnUpdate)
	self:Show()
	SetUIVisibility(true)

	-- Re-enable Narcissus after fade in complete
	C_Timer.After(0.5, function()
		self:EnableNarcissus()
	end)
end

-- Fade OUT the UIParent (hide WoW UI progressively)
function UIParentFade:FadeOutUIParent()
	if not UIParent:IsVisible() then
		return
	end

	-- CRITICAL: Disable Narcissus before calling SetUIVisibility
	-- SetUIVisibility(false) triggers Narcissus photo mode
	self:DisableNarcissus()

	self.t = 0
	self:UpdateAlpha()
	self:SetScript("OnUpdate", FadeOut_OnUpdate)
	self:Show()
end

-- Hide UIParent instantly (no fade)
function UIParentFade:HideUIParent()
	if not UIParent:IsVisible() then
		return
	end

	-- Disable Narcissus before SetUIVisibility
	self:DisableNarcissus()

	self:StopOnUpdate()
	UIParent:SetAlpha(1)
	SetUIVisibility(false)
end

-- Show UIParent instantly (no fade)
function UIParentFade:ShowUIParent()
	if self.t == nil and UIParent:IsVisible() and UIParent:GetAlpha() == 1 then
		return
	end

	self:StopOnUpdate()
	UIParent:SetAlpha(1)
	SetUIVisibility(true)

	-- Re-enable Narcissus after showing UI
	self:EnableNarcissus()
end

-- ============================================================================
-- NARCISSUS INTEGRATION
-- Temporarily disable Narcissus to prevent it from triggering on SetUIVisibility
-- ============================================================================

-- Disable Narcissus photo mode
function UIParentFade:DisableNarcissus()
	-- Check if Narcissus addon is loaded
	if not _G.Narci then
		return
	end

	print("[UIParentFade] Disabling Narcissus temporarily...")

	-- Store original state
	self.narcissusWasActive = _G.Narci and _G.Narci.isActive

	-- Disable Narcissus photo mode if active
	if _G.Narci and _G.Narci.isActive then
		-- Call Narcissus exit function if available
		if _G.Narci.Refresh then
			_G.Narci:Refresh()
		end
		_G.Narci.isActive = false
	end

	-- Block Narcissus from activating (hook its activation function)
	if _G.Narci and _G.Narci.Open then
		if not self.narcissusOriginalOpen then
			self.narcissusOriginalOpen = _G.Narci.Open
			_G.Narci.Open = function()
				-- Blocked during our addon usage
			end
		end
	end

	print("[UIParentFade] Narcissus disabled")
end

-- Re-enable Narcissus
function UIParentFade:EnableNarcissus()
	if not _G.Narci then
		return
	end

	print("[UIParentFade] Re-enabling Narcissus...")

	-- Restore original Open function
	if self.narcissusOriginalOpen then
		_G.Narci.Open = self.narcissusOriginalOpen
		self.narcissusOriginalOpen = nil
	end

	print("[UIParentFade] Narcissus re-enabled")
end
