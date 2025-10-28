local addonName, ns = ...

-- Namespace
ns.E = ns.E or {}
local E = ns.E

-- Create a frame pool for reuse
function E:CreateFramePool(frameType, template)
	local pool = {}
	pool.frames = {}
	pool.activeFrames = {}

	function pool:Acquire()
		local frame = table.remove(self.frames)
		if not frame then
			-- Use NihuiParent for all pooled frames
			frame = CreateFrame(frameType, nil, E.NihuiParent, template)
		end
		table.insert(self.activeFrames, frame)
		return frame
	end

	function pool:Release(frame)
		for i, f in ipairs(self.activeFrames) do
			if f == frame then
				table.remove(self.activeFrames, i)
				break
			end
		end
		frame:Hide()
		frame:ClearAllPoints()
		table.insert(self.frames, frame)
	end

	function pool:ReleaseAll()
		for _, frame in ipairs(self.activeFrames) do
			frame:Hide()
			frame:ClearAllPoints()
			table.insert(self.frames, frame)
		end
		wipe(self.activeFrames)
	end

	return pool
end

-- Color utilities
E.colors = {
	green = CreateColor(0, 1, 0, 1),
	white = CreateColor(1, 1, 1, 1),
	gray = CreateColor(0.5, 0.5, 0.5, 1),
	black = CreateColor(0, 0, 0, 1),
}

-- Animation helpers
function E:CreateFadeAnimation(frame, duration, startAlpha, endAlpha, onFinished)
	local ag = frame:CreateAnimationGroup()
	local fade = ag:CreateAnimation("Alpha")
	fade:SetDuration(duration or 0.3)
	fade:SetFromAlpha(startAlpha or 0)
	fade:SetToAlpha(endAlpha or 1)

	if onFinished then
		ag:SetScript("OnFinished", onFinished)
	end

	return ag
end

function E:CreateSlideAnimation(frame, duration, startX, startY, endX, endY, onFinished)
	local ag = frame:CreateAnimationGroup()
	local translate = ag:CreateAnimation("Translation")
	translate:SetDuration(duration or 0.3)
	translate:SetOffset(endX - startX, endY - startY)

	if onFinished then
		ag:SetScript("OnFinished", onFinished)
	end

	return ag
end
