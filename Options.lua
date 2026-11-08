-- DE Mailer: Options.lua
-- Puts DE Mailer in the game's Options window (Options > AddOns), built from
-- the same rows the game uses for its own settings, plus a small popup for
-- typing your enchanter's name.

local ADDON_NAME, ns = ...
local L = ns.L

local Options = {}
ns.Options = Options

-------------------------------------------------------------------------------
-- Name popup (used by the Options panel and the minimap menu)
-------------------------------------------------------------------------------

local popup

local function CreatePopup()
    local frame = CreateFrame("Frame", "DEMailerNamePopup", UIParent, "BackdropTemplate")
    frame:SetSize(320, 132)
    frame:SetPoint("TOP", 0, -135)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetBackdrop(BACKDROP_DIALOG_32_32)
    frame:Hide()

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("TOP", 0, -20)
    title:SetText(L.NAME_PROMPT)

    local realmText = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    realmText:SetPoint("TOP", title, "BOTTOM", 0, -4)
    frame.realmText = realmText

    local box = ns.CreateNameBox(frame, "DEMailerNamePopupBox", 200)
    box:SetPoint("TOP", realmText, "BOTTOM", 4, -6)
    frame.box = box

    local okay = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    okay:SetSize(110, 22)
    okay:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -4, 16)
    okay:SetText(OKAY)

    local cancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cancel:SetSize(110, 22)
    cancel:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 4, 16)
    cancel:SetText(CANCEL)

    local function Accept()
        local onAccept = frame.onAccept
        ns:SetRecipient(box:GetText())
        frame:Hide()
        if onAccept then
            onAccept()
        end
    end
    local function Cancel()
        frame:Hide()
    end
    okay:SetScript("OnClick", Accept)
    cancel:SetScript("OnClick", Cancel)
    box:SetScript("OnEnterPressed", Accept)
    box:SetScript("OnEscapePressed", Cancel)
    frame:SetScript("OnHide", function()
        box:ClearFocus()
        frame.onAccept = nil
    end)
    return frame
end

-- Opens the popup. onAccept runs after a new name is saved.
function Options:EditRecipient(onAccept)
    popup = popup or CreatePopup()
    local realm, faction = ns:GetRealmAndFaction()
    popup.realmText:SetText(L.NAME_REALM:format(realm, faction))
    popup.box:SetText(ns:GetRecipient())
    popup.onAccept = onAccept
    popup:Show()
    popup.box:SetFocus()
    popup.box:HighlightText()
    if SOUNDKIT then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
    end
end

-------------------------------------------------------------------------------
-- Options > AddOns > DE Mailer
-------------------------------------------------------------------------------

local function RecipientLabel()
    local name = ns:GetRecipient()
    return (name ~= "") and name or L.SET_NAME
end

local function KeptLabel()
    local count = ns:CountExcluded()
    return (count > 0) and L.KEPT_RESET:format(count) or L.KEPT_NONE
end

-- Row buttons are shared between rows by the Options window, so only touch
-- one if it is still showing the text we gave it.
local function UpdateRowButton(button, text)
    if button and button:IsVisible() and button:GetText() == button.deMailerText then
        button:SetText(text)
        button.deMailerText = text
    end
end

local function RememberRowButton(button)
    button.deMailerText = button:GetText()
    return button
end

function Options:Create()
    if self.created or not (Settings and Settings.RegisterVerticalLayoutCategory) then
        return
    end
    self.created = true
    self.settings = {}

    local category, layout = Settings.RegisterVerticalLayoutCategory(L.TITLE)
    self.category = category

    local function AddCheckbox(variable, name, tooltip, defaultValue, getValue, setValue)
        local setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.Boolean,
            name, defaultValue, getValue, setValue)
        Settings.CreateCheckbox(category, setting, tooltip)
        self.settings[#self.settings + 1] = setting
        return setting
    end

    -- Enchanter
    local enchanterRow = CreateSettingsButtonInitializer(L.ENCHANTER, RecipientLabel, function(button)
        Options.recipientButton = RememberRowButton(button)
        Options:EditRecipient()
    end, L.RECIPIENT_TIP, false)
    enchanterRow:AddSearchTags(L.ENCHANTER, L.TITLE)
    layout:AddInitializer(enchanterRow)

    -- Items to send
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.QUALITIES_HEADER))
    for _, quality in ipairs(ns.QUALITIES) do
        local qualityName = ns.QualityText(quality)
        AddCheckbox("DEMAILER_QUALITY_" .. quality, qualityName, L.QUALITY_TIP_BOTH:format(qualityName),
            ns.DEFAULTS.qualities[quality] and true or false,
            function()
                return ns.db.qualities[quality] and true or false
            end,
            function(value)
                ns:SetQualityEnabled(quality, value)
            end)
    end

    -- Mailbox
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.MAILBOX))
    AddCheckbox("DEMAILER_AUTO_SEND", L.AUTO_SEND_SHORT, L.AUTO_SEND_LONG, false,
        function()
            return ns.db.autoSend and true or false
        end,
        function(value)
            ns:SetAutoSend(value)
        end)

    local keptRow = CreateSettingsButtonInitializer(L.KEPT_ITEMS, KeptLabel, function(button)
        Options.keptButton = RememberRowButton(button)
        ns:ResetExcluded()
    end, L.KEPT_ITEMS_TIP, false)
    layout:AddInitializer(keptRow)

    -- Disenchanting
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.DISENCHANTING))
    AddCheckbox("DEMAILER_DE_ENABLED", L.DE_ENABLE, L.DE_ENABLE_TIP, true,
        function()
            return ns.db.disenchant.enabled and true or false
        end,
        function(value)
            ns:SetDisenchantEnabled(value)
        end)
    AddCheckbox("DEMAILER_DE_AUTO_OPEN", L.DE_AUTO_OPEN, L.DE_AUTO_OPEN_TIP, false,
        function()
            return ns.db.disenchant.autoOpen and true or false
        end,
        function(value)
            ns:SetDisenchantAutoOpen(value)
        end)

    -- Minimap
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.MINIMAP))
    AddCheckbox("DEMAILER_MINIMAP_BUTTON", L.SHOW_MINIMAP, L.SHOW_MINIMAP_TIP, true,
        function()
            return not ns.db.minimap.hide
        end,
        function(value)
            ns:SetMinimapShown(value)
        end)

    Settings.RegisterAddOnCategory(category)
end

-- Something changed elsewhere (mailbox tab, minimap menu, slash command):
-- update the rows if the Options window is showing them.
function Options:Refresh()
    if not self.created or self.refreshing then
        return
    end
    self.refreshing = true
    for _, setting in ipairs(self.settings) do
        setting:NotifyUpdate()
    end
    UpdateRowButton(self.recipientButton, RecipientLabel())
    UpdateRowButton(self.keptButton, KeptLabel())
    self.refreshing = false
end

function Options:Open()
    if not self.category then
        return
    end
    if InCombatLockdown() then
        ns.Print(L.NO_OPTIONS_COMBAT)
        return
    end
    Settings.OpenToCategory(self.category:GetID())
end
