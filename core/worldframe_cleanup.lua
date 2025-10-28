local _, ns = ...
local E = ns.E

-- ============================================================================
-- WORLDFRAME CLEANUP
-- Hides other addon frames parented to WorldFrame (like Narcissus UI)
-- ============================================================================

E.WorldFrameCleanup = {}
local WorldFrameCleanup = E.WorldFrameCleanup

-- Frames to hide (other addons that use WorldFrame)
local hiddenFrames = {}

-- Known frame patterns to hide (Narcissus, etc.)
local FRAME_PATTERNS_TO_HIDE = {
	"Narcissus",  -- Narcissus addon frames
	"NarciPlayer",
	"NarciAPI",
}

-- Hide all WorldFrame children except ours
function WorldFrameCleanup:HideOtherFrames()
	if not WorldFrame then return end

	print("[WorldFrameCleanup] Hiding other addon frames from WorldFrame...")

	local count = 0

	-- Iterate through all children of WorldFrame
	for _, child in ipairs({WorldFrame:GetChildren()}) do
		if child and child:IsShown() then
			local name = child:GetName()

			-- Check if it's not our NihuiParent
			if name ~= "NihuiOptimizerParent" then
				-- Check if it matches known addon patterns
				local shouldHide = false

				if name then
					for _, pattern in ipairs(FRAME_PATTERNS_TO_HIDE) do
						if string.find(name, pattern) then
							shouldHide = true
							break
						end
					end
				end

				-- Hide if matched
				if shouldHide then
					print(string.format("[WorldFrameCleanup] Hiding frame: %s", name or "unnamed"))
					child:Hide()
					table.insert(hiddenFrames, child)
					count = count + 1
				end
			end
		end
	end

	print(string.format("[WorldFrameCleanup] Hidden %d frames", count))
end

-- Restore all hidden frames
function WorldFrameCleanup:RestoreFrames()
	print("[WorldFrameCleanup] Restoring hidden frames...")

	for _, frame in ipairs(hiddenFrames) do
		if frame then
			frame:Show()
		end
	end

	-- Clear the list
	hiddenFrames = {}

	print("[WorldFrameCleanup] Frames restored")
end
