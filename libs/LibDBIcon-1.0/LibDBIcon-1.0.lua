--[[
LibDBIcon-1.0
Minimap button library
]]

local DBICON10 = "LibDBIcon-1.0"
local lib = LibStub:NewLibrary(DBICON10, 1)
if not lib then return end

lib.objects = lib.objects or {}
lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)
local LDB = LibStub("LibDataBroker-1.1", true)

local function OnDragStart(self)
    self:LockHighlight()
    self.isMouseDown = true
    self.icon:SetTexCoord(0, 1, 0, 1)
    self:SetScript("OnUpdate", function(self)
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale

        local angle = math.atan2(py - my, px - mx)
        local x, y = math.cos(angle) * 80, math.sin(angle) * 80
        self:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end)
end

local function OnDragStop(self)
    self:SetScript("OnUpdate", nil)
    self.isMouseDown = false
    self.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    self:UnlockHighlight()
end

local function OnEnter(self)
    if self.dataObject.OnTooltipShow then
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMRIGHT")
        self.dataObject.OnTooltipShow(GameTooltip)
        GameTooltip:Show()
    elseif self.dataObject.tooltip then
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMRIGHT")
        GameTooltip:AddLine(self.dataObject.tooltip)
        GameTooltip:Show()
    end

    if self.dataObject.OnEnter then
        self.dataObject.OnEnter(self)
    end
end

local function OnLeave(self)
    GameTooltip:Hide()
    if self.dataObject.OnLeave then
        self.dataObject.OnLeave(self)
    end
end

local function OnClick(self, button)
    if self.dataObject.OnClick then
        self.dataObject.OnClick(self, button)
    end
end

local function CreateButton(name, object, db)
    local button = CreateFrame("Button", "LibDBIcon10_" .. name, Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetSize(31, 31)
    button:SetFrameLevel(8)
    button:RegisterForClicks("anyUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture(136477)
    button:GetHighlightTexture():SetSize(18, 18)
    button:GetHighlightTexture():SetPoint("TOPLEFT", 7, -5)
    button.dataObject = object

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture(136430)
    overlay:SetPoint("TOPLEFT")
    button.overlay = overlay

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetTexture(136467)
    background:SetPoint("TOPLEFT", 7, -5)
    button.background = background

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    icon:SetPoint("TOPLEFT", 7, -5)
    button.icon = icon

    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", OnLeave)
    button:SetScript("OnClick", OnClick)
    button:SetScript("OnDragStart", OnDragStart)
    button:SetScript("OnDragStop", OnDragStop)

    lib.objects[name] = button

    if object.icon then
        icon:SetTexture(object.icon)
    end

    -- Position button
    local angle = db.minimapPos or math.random(1, 360)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)

    return button
end

function lib:Register(name, object, db)
    if not name or not object then return end
    if lib.objects[name] then return end

    db = db or {}
    db.hide = db.hide or false
    db.minimapPos = db.minimapPos or math.random(1, 360)

    CreateButton(name, object, db)

    if db.hide then
        lib:Hide(name)
    end
end

function lib:Hide(name)
    local button = lib.objects[name]
    if button then
        button:Hide()
    end
end

function lib:Show(name)
    local button = lib.objects[name]
    if button then
        button:Show()
    end
end

function lib:GetMinimapButton(name)
    return lib.objects[name]
end
