-- DE Mailer: UI.lua
-- Adds a "Disenchant" tab to the mailbox, next to Inbox and Send Mail.
-- The page uses the game's own mailbox art, fonts, item slots and buttons.

local ADDON_NAME, ns = ...
local L = ns.L

local UI = {}
ns.UI = UI

local COLUMNS, ROWS = 7, 4
local SLOT_SIZE, SLOT_GAP = 37, 4
local GRID_LEFT, GRID_TOP = 28, -150

-- Text in an item quality's color (green for Uncommon and so on).
function ns.ColorByQuality(text, quality)
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color and color.color and color.color.WrapTextInColorCode then
        return color.color:WrapTextInColorCode(text)
    elseif color and color.hex then
        return color.hex .. text .. "|r"
    end
    return text
end

-- A quality's name in its own color, like "Uncommon" in green.
local function QualityText(quality)
    return ns.ColorByQuality(_G["ITEM_QUALITY" .. quality .. "_DESC"] or tostring(quality), quality)
end
ns.QualityText = QualityText

-- A name box with the same look as the "To:" box on the Send Mail tab.
-- Shared with the name popup in Options.lua.
function ns.CreateNameBox(parent, name, width)
    local box = CreateFrame("EditBox", name, parent)
    box:SetSize(width, 25)
    box:SetFontObject(ChatFontNormal)
    box:SetAutoFocus(false)
    box:SetMaxLetters(77)
    local border = "Interface\\Common\\Common-Input-Border"
    local left = box:CreateTexture(nil, "BACKGROUND")
    left:SetTexture(border)
    left:SetTexCoord(0, 0.0625, 0, 0.625)
    left:SetSize(8, 20)
    left:SetPoint("TOPLEFT", -8, -2)
    local middle = box:CreateTexture(nil, "BACKGROUND")
    middle:SetTexture(border)
    middle:SetTexCoord(0.0625, 0.9375, 0, 0.625)
    middle:SetSize(width - 9, 20)
    middle:SetPoint("LEFT", left, "RIGHT")
    local right = box:CreateTexture(nil, "BACKGROUND")
    right:SetTexture(border)
    right:SetTexCoord(0.9375, 1, 0, 0.625)
    right:SetSize(8, 20)
    right:SetPoint("LEFT", middle, "RIGHT")
    return box
end

local function ColorText(text, kind)
    local color = (kind == "good" and GREEN_FONT_COLOR) or (kind == "bad" and RED_FONT_COLOR) or nil
    if color and color.WrapTextInColorCode then
        return color:WrapTextInColorCode(text)
    end
    return text
end

local function PlayCheckSound(checked)
    if SOUNDKIT then
        PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end
end

local function MakeLabelClickable(check)
    check:SetHitRectInsets(0, -(check.Text:GetStringWidth() + 4), 0, 0)
end

-------------------------------------------------------------------------------
-- Item slots
-------------------------------------------------------------------------------

local function Slot_OnEnter(self)
    if not self.itemID then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetBagItem(self.bag, self.slot)
    GameTooltip:AddLine(" ")
    if self.excluded then
        GameTooltip:AddLine(L.ITEM_TIP_EXCLUDED, 1, 0.82, 0)
        GameTooltip:AddLine(L.ITEM_TIP_INCLUDE, 0.1, 1, 0.1)
    else
        GameTooltip:AddLine(L.ITEM_TIP_SEND, 0.1, 1, 0.1)
    end
    GameTooltip:Show()
end

local function Slot_OnLeave()
    GameTooltip:Hide()
end

local function Slot_OnClick(self)
    if not self.itemID or ns.run then
        return
    end
    PlayCheckSound(self.excluded)
    ns:ToggleExcluded(self.itemID)
    if GameTooltip:IsOwned(self) then
        Slot_OnEnter(self)
    end
end

local function SetSlot(button, item)
    button.itemID = item.itemID
    button.bag, button.slot = item.bag, item.slot
    button.excluded = item.excluded
    SetItemButtonTexture(button, item.icon)
    SetItemButtonQuality(button, item.quality, item.link)
    SetItemButtonDesaturated(button, item.excluded)
    button.ExcludedMark:SetShown(item.excluded)
    button:Show()
end

local function ClearSlot(button)
    button.itemID, button.bag, button.slot, button.excluded = nil, nil, nil, nil
    button:Hide()
end

-------------------------------------------------------------------------------
-- Building the tab and page
-------------------------------------------------------------------------------

function UI:Create()
    if self.created or not MailFrame or not MailFrameTab2 then
        return
    end
    self.created = true

    -- The tab. It lives in its own holder frame so the mailbox's own tab
    -- list is left exactly as the game made it.
    local holder = CreateFrame("Frame", nil, MailFrame)
    holder:SetSize(1, 1)
    holder:SetPoint("TOPLEFT")
    holder.maxTabWidth = MailFrame.maxTabWidth
    self.tabHolder = holder

    local tab = CreateFrame("Button", "DEMailerMailTab", holder, "PanelTabButtonTemplate")
    -- Same spacing the game gives its own tabs (see PanelTemplates_AnchorTabs).
    tab:SetPoint("TOPLEFT", MailFrameTab2, "TOPRIGHT", 3, 0)
    tab:SetText(L.TAB)
    tab:SetScript("OnClick", function()
        UI:ShowPage()
    end)
    PanelTemplates_DeselectTab(tab)
    PanelTemplates_TabResize(tab, 0, nil, nil, holder.maxTabWidth)
    self.tab = tab

    -- The page, laid over the same area as the inbox.
    local page = CreateFrame("Frame", "DEMailerPage", MailFrame)
    page:SetAllPoints(MailFrame)
    page:Hide()
    self.page = page

    local background = page:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\MailFrame\\UI-MailFrameBG")
    background:SetSize(512, 512)
    background:SetPoint("TOPLEFT", 7, -62)

    -- Recipient
    local toLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    toLabel:SetPoint("TOPLEFT", 24, -76)
    toLabel:SetText(L.SEND_TO)

    local box = ns.CreateNameBox(page, "DEMailerRecipientBox", 160)
    box:SetPoint("LEFT", toLabel, "RIGHT", 12, 0)
    box:SetScript("OnEditFocusGained", function(self)
        self.textBeforeEdit = self:GetText()
        self:HighlightText()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        ns:SetRecipient(self:GetText())
    end)
    box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText(self.textBeforeEdit or ns:GetRecipient())
        self:ClearFocus()
    end)
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            ns:SetRecipient(self:GetText())
        end
    end)
    box:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.RECIPIENT_TITLE, 1, 1, 1)
        GameTooltip:AddLine(L.RECIPIENT_TIP, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    box:SetScript("OnLeave", Slot_OnLeave)
    self.recipientBox = box

    -- Item qualities
    local includeLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    includeLabel:SetPoint("TOPLEFT", 24, -104)
    includeLabel:SetText(L.INCLUDE)

    self.qualityChecks = {}
    local anchor, offset = includeLabel, 6
    for _, quality in ipairs(ns.QUALITIES) do
        local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        check:SetSize(24, 24)
        check:SetPoint("LEFT", anchor, "RIGHT", offset, 0)
        check.Text:SetFontObject(GameFontHighlightSmall)
        check.Text:SetText(QualityText(quality))
        MakeLabelClickable(check)
        check.quality = quality
        check:SetScript("OnClick", function(self)
            local checked = self:GetChecked() and true or false
            PlayCheckSound(checked)
            ns:SetQualityEnabled(self.quality, checked)
        end)
        self.qualityChecks[#self.qualityChecks + 1] = check
        anchor, offset = check.Text, 10
    end

    -- Item grid
    local header = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", 24, -134)
    header:SetText(L.IN_YOUR_BAGS)

    local countText = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    countText:SetPoint("TOPRIGHT", -28, -136)
    countText:SetJustifyH("RIGHT")
    self.countText = countText

    self.slots = {}
    for i = 1, COLUMNS * ROWS do
        local button = CreateFrame("ItemButton", "DEMailerSlot" .. i, page)
        local column, row = (i - 1) % COLUMNS, math.floor((i - 1) / COLUMNS)
        button:SetPoint("TOPLEFT", GRID_LEFT + column * (SLOT_SIZE + SLOT_GAP), GRID_TOP - row * (SLOT_SIZE + SLOT_GAP))
        local mark = button:CreateTexture(nil, "OVERLAY", nil, 7)
        mark:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
        mark:SetSize(16, 16)
        mark:SetPoint("TOPRIGHT", -2, -2)
        mark:Hide()
        button.ExcludedMark = mark
        button:SetScript("OnClick", Slot_OnClick)
        button:SetScript("OnEnter", Slot_OnEnter)
        button:SetScript("OnLeave", Slot_OnLeave)
        button:Hide()
        self.slots[i] = button
    end

    local gridBottom = GRID_TOP - (ROWS - 1) * (SLOT_SIZE + SLOT_GAP) - SLOT_SIZE

    local emptyText = page:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    emptyText:SetPoint("TOP", page, "TOPLEFT", 169, GRID_TOP - 60)
    emptyText:SetWidth(260)
    emptyText:SetText(L.EMPTY)
    self.emptyText = emptyText

    local moreText = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    moreText:SetPoint("TOPRIGHT", -28, gridBottom - 4)
    moreText:SetJustifyH("RIGHT")
    self.moreText = moreText

    -- Automatic sending
    local auto = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    auto:SetSize(24, 24)
    auto:SetPoint("TOPLEFT", 20, -322)
    auto.Text:SetFontObject(GameFontHighlightSmall)
    auto.Text:SetText(L.AUTO_SEND)
    MakeLabelClickable(auto)
    auto:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        PlayCheckSound(checked)
        ns:SetAutoSend(checked)
    end)
    auto:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.AUTO_SEND, 1, 1, 1, 1, true)
        GameTooltip:AddLine(L.AUTO_SEND_TIP, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    auto:SetScript("OnLeave", Slot_OnLeave)
    self.autoCheck = auto

    -- Status line and Send button, where the inbox has Open All.
    local status = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("BOTTOM", 0, 46)
    status:SetWidth(300)
    status:SetJustifyH("CENTER")
    self.statusText = status

    local send = CreateFrame("Button", "DEMailerSendButton", page, "UIPanelButtonTemplate")
    send:SetSize(140, 24)
    send:SetPoint("CENTER", page, "BOTTOM", 0, 26)
    send:SetText(L.SEND)
    send:SetScript("OnClick", function()
        UI:OnSendClicked()
    end)
    self.sendButton = send

    page:SetScript("OnShow", function()
        UI:Refresh()
    end)

    -- Hide the page whenever one of the game's own tabs is chosen, and
    -- when the mailbox closes.
    hooksecurefunc("MailFrameTab_OnClick", function()
        UI:HidePage()
    end)
    MailFrame:HookScript("OnHide", function()
        UI:HidePage()
    end)

    self:Refresh()
end

-------------------------------------------------------------------------------
-- Switching tabs
-------------------------------------------------------------------------------

-- Mail text boxes that might keep the keyboard after their tab is hidden.
local MAIL_EDIT_BOXES = {
    "SendMailNameEditBox", "SendMailSubjectEditBox", "SendMailBodyEditBox",
    "SendMailMoneyGold", "SendMailMoneySilver", "SendMailMoneyCopper",
}

local function ReleaseHiddenMailFocus()
    for _, name in ipairs(MAIL_EDIT_BOXES) do
        local box = _G[name]
        if box and box.HasFocus and box:HasFocus() and not box:IsVisible() then
            local autoComplete = AutoCompleteBox
            if not (autoComplete and autoComplete.parent == box) then
                box:ClearFocus()
            end
        end
    end
end

function UI:ShowPage()
    if not self.created or self.page:IsShown() then
        return
    end
    for i = 1, 2 do
        local blizzardTab = _G["MailFrameTab" .. i]
        if blizzardTab then
            PanelTemplates_DeselectTab(blizzardTab)
        end
    end
    PanelTemplates_SelectTab(self.tab)

    if InboxFrame then
        InboxFrame:Hide()
    end
    if SendMailFrame then
        SendMailFrame:Hide()
    end
    ReleaseHiddenMailFocus()

    -- Same layout as the inbox.
    ButtonFrameTemplate_HideButtonBar(MailFrame)
    if MailFrameInset then
        MailFrameInset:SetPoint("TOPLEFT", 4, -58)
    end
    if not ns.run then
        SetSendMailShowing(false)
    end
    MailFrame:SetTitle(L.TITLE)

    self.page:Show()
    if SOUNDKIT then
        PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
    end
end

function UI:HidePage()
    if not self.created then
        return
    end
    if self.recipientBox:HasFocus() then
        self.recipientBox:ClearFocus()
    end
    self.page:Hide()
    PanelTemplates_DeselectTab(self.tab)
end

function UI:OnMailShow()
    if not self.created then
        return
    end
    local trial = GameLimitedMode_IsActive and GameLimitedMode_IsActive()
    self.tab:SetShown(not trial)
end

function UI:OnSendClicked()
    local run = ns.run
    if run and run.state ~= "paused" then
        ns:Stop()
        return
    end
    if self.recipientBox:HasFocus() then
        self.recipientBox:ClearFocus()
    end
    ns:Start("click", true)
end

-------------------------------------------------------------------------------
-- Refreshing
-------------------------------------------------------------------------------

function UI:UpdateTabLabel(sendable)
    local label = (sendable > 0) and ("%s (%d)"):format(L.TAB, sendable) or L.TAB
    if self.tab:GetText() ~= label then
        self.tab:SetText(label)
        PanelTemplates_TabResize(self.tab, 0, nil, nil, self.tabHolder.maxTabWidth)
    end
end

function UI:Refresh()
    if not self.created or not ns.db then
        return
    end
    local items, sendable = ns:ScanBags()
    self:UpdateTabLabel(sendable)
    if not self.page:IsShown() then
        return
    end

    if not self.recipientBox:HasFocus() then
        self.recipientBox:SetText(ns:GetRecipient())
        self.recipientBox:SetCursorPosition(0)
    end
    for _, check in ipairs(self.qualityChecks) do
        check:SetChecked(ns.db.qualities[check.quality] and true or false)
    end
    self.autoCheck:SetChecked(ns.db.autoSend)

    -- Grid
    for i, button in ipairs(self.slots) do
        local item = items[i]
        if item then
            SetSlot(button, item)
        else
            ClearSlot(button)
        end
        if GameTooltip:IsOwned(button) then
            if item then
                Slot_OnEnter(button)
            else
                GameTooltip:Hide()
            end
        end
    end
    self.emptyText:SetShown(#items == 0)
    local hidden = #items - #self.slots
    self.moreText:SetText(hidden > 0 and L.MORE:format(hidden) or "")

    local run = ns.run
    local letters = math.ceil(sendable / ns.MAX_ATTACHMENTS)
    if sendable > 0 then
        self.countText:SetText(L.COUNT_SUMMARY:format(sendable, letters))
    else
        self.countText:SetText("")
    end

    -- Status and button
    local statusText, kind, buttonText, enabled
    if run then
        if run.state == "paused" then
            statusText = L.PAUSED:format(run.letters)
            buttonText, enabled = L.SEND_NEXT, true
        else
            local current = run.letters + 1
            local inFlight = (run.state == "sending" or run.state == "attaching") and 1 or 0
            local total = math.max(current, run.letters + inFlight + letters)
            if run.state == "waiting" then
                statusText = L.WAITING
            else
                statusText = L.SENDING:format(current, total, run.recipient)
            end
            buttonText, enabled = L.STOP, not run.stopRequested
        end
    else
        local ok, result = ns:CanStart()
        buttonText, enabled = L.SEND, ok
        if ns.message then
            statusText, kind = ns.message, ns.messageKind
        elseif ok then
            statusText = L.READY:format(result, ns:GetRecipient())
        else
            statusText = result
        end
    end
    self.statusText:SetText(ColorText(statusText or "", kind))
    self.sendButton:SetText(buttonText)
    self.sendButton:SetEnabled(enabled)
end
