-- DE Mailer: Minimap.lua
-- A round minimap button you can drag around the edge of the minimap, and an
-- entry in the minimap's AddOns menu. Left-click opens the options;
-- right-click shows quick settings.

local ADDON_NAME, ns = ...
local L = ns.L

local MinimapButton = {}
ns.Minimap = MinimapButton

local button

-------------------------------------------------------------------------------
-- Tooltip and quick-settings menu (shared by the button and the AddOns menu)
-------------------------------------------------------------------------------

local function SelectedQualities()
    local names = {}
    for _, quality in ipairs(ns.QUALITIES) do
        if ns.db.qualities[quality] then
            names[#names + 1] = ns.QualityText(quality)
        end
    end
    return (#names > 0) and table.concat(names, ", ") or L.NOTHING_SELECTED
end

local function ShowTooltip(owner, showDragHint)
    local name = ns:GetRecipient()
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText(L.TITLE, 1, 1, 1)
    GameTooltip:AddLine(L.TIP_ENCHANTER:format((name ~= "") and name or L.NOT_SET), 1, 0.82, 0)
    GameTooltip:AddLine(L.TIP_SENDS:format(SelectedQualities()), 1, 0.82, 0)
    GameTooltip:AddLine(L.TIP_AUTO:format(ns.db.autoSend and L.ON or L.OFF), 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.TIP_LEFT, 0.1, 1, 0.1)
    GameTooltip:AddLine(L.TIP_RIGHT, 0.1, 1, 0.1)
    if ns.DE:IsEnabled() then
        GameTooltip:AddLine(L.TIP_SHIFT, 0.1, 1, 0.1)
    end
    if showDragHint then
        GameTooltip:AddLine(L.TIP_DRAG, 0.1, 1, 0.1)
    end
    GameTooltip:Show()
end

function MinimapButton:OpenMenu(owner)
    GameTooltip:Hide()
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(L.TITLE)

        local name = ns:GetRecipient()
        root:CreateButton(L.TIP_ENCHANTER:format((name ~= "") and name or L.NOT_SET), function()
            ns.Options:EditRecipient()
        end)

        root:CreateDivider()
        for _, quality in ipairs(ns.QUALITIES) do
            root:CreateCheckbox(ns.QualityText(quality),
                function()
                    return ns.db.qualities[quality] and true or false
                end,
                function()
                    ns:SetQualityEnabled(quality, not ns.db.qualities[quality])
                end)
        end
        root:CreateCheckbox(L.AUTO_SEND_SHORT,
            function()
                return ns.db.autoSend and true or false
            end,
            function()
                ns:SetAutoSend(not ns.db.autoSend)
            end)
        root:CreateCheckbox(L.DE_ENABLE,
            function()
                return ns.db.disenchant.enabled and true or false
            end,
            function()
                ns:SetDisenchantEnabled(not ns.db.disenchant.enabled)
            end)
        root:CreateCheckbox(L.SHOW_MINIMAP,
            function()
                return not ns.db.minimap.hide
            end,
            function()
                ns:SetMinimapShown(ns.db.minimap.hide)
            end)

        root:CreateDivider()
        root:CreateButton(L.OPEN_OPTIONS, function()
            ns.Options:Open()
        end)
        if ns.DE:IsEnabled() then
            root:CreateButton(L.DE_OPEN_WINDOW, function()
                ns.DE:OpenWindow()
            end)
        end
    end)
end

-- Left-click: options. Shift-click: Disenchanting window. Right-click: menu.
local function HandleClick(owner, mouseButton)
    if mouseButton == "RightButton" then
        MinimapButton:OpenMenu(owner)
    elseif IsShiftKeyDown() and ns.DE:IsEnabled() then
        ns.DE:ToggleWindow()
    else
        ns.Options:Open()
    end
end

-------------------------------------------------------------------------------
-- Placing the button around the minimap
-------------------------------------------------------------------------------

-- Some minimap addons change its shape. For each shape: which corners are
-- round (bottom-right, bottom-left, top-right, top-left).
local ROUND_CORNERS = {
    ["ROUND"]                 = { true,  true,  true,  true  },
    ["SQUARE"]                = { false, false, false, false },
    ["CORNER-TOPLEFT"]        = { false, false, false, true  },
    ["CORNER-TOPRIGHT"]       = { false, false, true,  false },
    ["CORNER-BOTTOMLEFT"]     = { false, true,  false, false },
    ["CORNER-BOTTOMRIGHT"]    = { true,  false, false, false },
    ["SIDE-LEFT"]             = { false, true,  false, true  },
    ["SIDE-RIGHT"]            = { true,  false, true,  false },
    ["SIDE-TOP"]              = { false, false, true,  true  },
    ["SIDE-BOTTOM"]           = { true,  true,  false, false },
    ["TRICORNER-TOPLEFT"]     = { false, true,  true,  true  },
    ["TRICORNER-TOPRIGHT"]    = { true,  false, true,  true  },
    ["TRICORNER-BOTTOMLEFT"]  = { true,  true,  false, true  },
    ["TRICORNER-BOTTOMRIGHT"] = { true,  true,  true,  false },
}

local EDGE_OFFSET = 5 -- how far past the minimap's edge the button sits
local ICON_X, ICON_Y = 7, -6

local function UpdatePosition()
    local angle = math.rad(ns.db.minimap.angle or 225)
    local x, y = math.cos(angle), math.sin(angle)
    local corner = 1
    if x < 0 then
        corner = corner + 1
    end
    if y > 0 then
        corner = corner + 2
    end
    local shape = (GetMinimapShape and GetMinimapShape()) or "ROUND"
    local rounded = (ROUND_CORNERS[shape] or ROUND_CORNERS.ROUND)[corner]
    local halfWidth = Minimap:GetWidth() / 2 + EDGE_OFFSET
    local halfHeight = Minimap:GetHeight() / 2 + EDGE_OFFSET
    if rounded then
        x, y = x * halfWidth, y * halfHeight
    else
        -- Square corner: slide along the edge instead of the circle.
        local reachX = math.sqrt(2) * halfWidth - 10
        local reachY = math.sqrt(2) * halfHeight - 10
        x = math.max(-halfWidth, math.min(x * reachX, halfWidth))
        y = math.max(-halfHeight, math.min(y * reachY, halfHeight))
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function FollowCursor()
    local centerX, centerY = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cursorX, cursorY = cursorX / scale, cursorY / scale
    ns.db.minimap.angle = math.deg(math.atan2(cursorY - centerY, cursorX - centerX)) % 360
    UpdatePosition()
end

-------------------------------------------------------------------------------
-- The button
-------------------------------------------------------------------------------

function MinimapButton:Create()
    if self.created or not Minimap then
        return
    end
    self.created = true

    -- Same round button the game uses on its World Map: icon, dark backing
    -- and gold ring, with identical sizes and offsets.
    button = CreateFrame("Button", "DEMailerMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(25, 25)
    background:SetPoint("TOPLEFT", 2, -4)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Enchant_Disenchant")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", ICON_X, ICON_Y)
    local mask = button:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)
    button.icon = icon

    local ring = button:CreateTexture(nil, "OVERLAY")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetSize(54, 54)
    ring:SetPoint("TOPLEFT")

    -- The icon dips slightly while pressed, like the game's own buttons.
    button:SetScript("OnMouseDown", function(self)
        self.icon:SetPoint("TOPLEFT", ICON_X + 1, ICON_Y - 1)
    end)
    button:SetScript("OnMouseUp", function(self)
        self.icon:SetPoint("TOPLEFT", ICON_X, ICON_Y)
    end)

    button:SetScript("OnClick", function(self, mouseButton)
        if self.draggedAt and GetTime() - self.draggedAt < 0.2 then
            return
        end
        HandleClick(self, mouseButton)
    end)
    button:SetScript("OnEnter", function(self)
        if not self.dragging then
            ShowTooltip(self, true)
        end
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:LockHighlight()
        GameTooltip:Hide()
        self:SetScript("OnUpdate", FollowCursor)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
        self.icon:SetPoint("TOPLEFT", ICON_X, ICON_Y)
        self.dragging = nil
        self.draggedAt = GetTime()
    end)

    self:Update()
end

function MinimapButton:Update()
    if not button then
        return
    end
    button:SetShown(not ns.db.minimap.hide)
    UpdatePosition()
    if GameTooltip:IsOwned(button) then
        ShowTooltip(button, true)
    end
end

-------------------------------------------------------------------------------
-- The minimap's AddOns menu (named in DEMailer.toc)
-------------------------------------------------------------------------------

function DEMailer_OnAddonCompartmentClick(_, mouseButton)
    HandleClick(AddonCompartmentFrame or UIParent, mouseButton)
end

function DEMailer_OnAddonCompartmentEnter(_, menuButton)
    ShowTooltip(menuButton, false)
end

function DEMailer_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
