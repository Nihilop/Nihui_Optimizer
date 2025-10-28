local _, ns = ...
local E = ns.E

-- Movement Detector Helper
-- Detects player movement and triggers callback
-- Usage: E.MovementDetector:Enable(callback) / E.MovementDetector:Disable()

E.MovementDetector = {}
local MovementDetector = E.MovementDetector

-- State
MovementDetector.enabled = false
MovementDetector.callback = nil
MovementDetector.frame = nil

-- Enable movement detection
function MovementDetector:Enable(callback)
	if not callback then
		error("MovementDetector:Enable() requires a callback function")
		return
	end

	-- Store callback
	self.callback = callback

	-- Create frame if needed
	if not self.frame then
		self.frame = CreateFrame("Frame")
		self.frame:SetScript("OnEvent", function(frame, event)
			if MovementDetector.enabled and MovementDetector.callback then
				MovementDetector.callback()
			end
		end)
	end

	-- Register event
	self.frame:RegisterEvent("PLAYER_STARTED_MOVING")
	self.enabled = true
end

-- Disable movement detection
function MovementDetector:Disable()
	if self.frame then
		self.frame:UnregisterEvent("PLAYER_STARTED_MOVING")
	end
	self.enabled = false
	self.callback = nil
end

-- Check if enabled
function MovementDetector:IsEnabled()
	return self.enabled
end

-- Future: Add option in settings
-- E.db.profile.closeOnMove = true/false
function MovementDetector:ShouldCloseOnMove()
	-- TODO: Check user settings when implemented
	-- return E.db.profile.closeOnMove
	return true  -- For now, always enabled
end
