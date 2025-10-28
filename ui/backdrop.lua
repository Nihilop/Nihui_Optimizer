local _, ns = ...
local E = ns.E

-- Create glass backdrop with Nihui style
function E:CreateGlassBackdrop(parent, alpha, addGlass)
	local backdrop = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	backdrop:SetFrameLevel(parent:GetFrameLevel() - 1)
	backdrop:SetPoint("TOPLEFT", -12, 12)
	backdrop:SetPoint("BOTTOMRIGHT", 12, -12)
	backdrop:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\AddOns\\Nihui_Optimizer\\textures\\MirroredFrameSingleUF",
		tile = false,
		edgeSize = 16,
		insets = {left = 12, right = 12, top = 12, bottom = 12},
	})

	backdrop:SetBackdropColor(0, 0, 0, alpha or 0.8)
	backdrop:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

	if addGlass then
		local glass = parent:CreateTexture(nil, "ARTWORK", nil, 7)
		glass:SetTexture("Interface\\AddOns\\Nihui_Optimizer\\textures\\HPGlass.tga")
		glass:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
		glass:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
		glass:SetTextureSliceMargins(16, 16, 16, 16)
		glass:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
		glass:SetAlpha(0.2)
		glass:SetBlendMode("ADD")
		backdrop.glass = glass
	end

	return backdrop
end

-- Create simple backdrop without glass (pure WHITE8x8)
function E:CreateSimpleBackdrop(parent, alpha)
	local backdrop = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	backdrop:SetAllPoints(parent)
	backdrop:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		tile = false,
		edgeSize = 1,
		insets = {left = 1, right = 1, top = 1, bottom = 1},
	})

	backdrop:SetBackdropColor(0.1, 0.1, 0.1, alpha or 0.9)
	backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

	return backdrop
end
