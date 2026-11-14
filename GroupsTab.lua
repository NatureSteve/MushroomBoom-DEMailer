-- DE Mailer: GroupsTab.lua
-- The "Groups" tab on the mailbox, next to "Disenchant": your groups with a
-- checkbox each, who gets them and how much is ready, the items that will go
-- out, automatic sending, and a Send button for every checked group.

local ADDON_NAME, ns = ...
local L = ns.L
local Groups = ns.Groups

local Tab = {}
ns.GroupsTab = Tab

L.GT_TAB            = "Groups"
L.GT_TITLE          = "Mail Groups"
L.GT_HEADER         = "Groups to send"
L.GT_EDIT           = "Edit Groups"
L.GT_EMPTY          = "No mail groups yet. Press Edit Groups to make some."
L.GT_ROW_TIP        = "Checked groups are sent when you press Send. A checked group includes the groups inside it."
L.GT_ROW_OFF        = "Switched off in the group editor."
L.GT_ROW_INCLUDED   = "Included because a group above it is checked."
L.GT_READY          = "%d ready"
L.GT_SUMMARY        = "%d |4item:items; to %s, %d |4letter:letters;"
L.GT_SKIPPED_NOBODY = "%d |4group:groups; without a recipient."
L.GT_AUTO           = "Send checked groups when I open a mailbox"
L.GT_AUTO_TIP       = "Hold Shift while opening the mailbox to skip it once. If the Disenchant tab sends too, groups go right after it."
L.GT_READY_STATUS   = "Ready to send %d |4item:items;."
L.GT_NOTHING        = "Nothing to send from your checked groups."
L.GT_BUSY           = "The Disenchant tab is sending; wait for it to finish."
L.GT_AUTO_NEEDS_CLICK = "%d |4item:items; from your mail groups are ready. Open the Groups tab and press Send."
L.GT_MORE           = "+%d more"
L.OPT_GROUPS_AUTO   = "Send Groups Automatically"
L.OPT_GROUP_EDITOR  = "Group Editor"
L.OPT_GROUP_EDITOR_TIP = "Make groups of items (herbs, cloth, ore...), choose who gets each one, and how much to keep. Also: /dem groups edit."
L.OPEN_GROUPS       = "Open Mail Groups"

local ROW_HEIGHT = 20
local INDENT = 12
local LIST_TOP, LIST_ROWS = -96, 6
local GRID_TOP, GRID_COLUMNS, GRID_ROWS = -248, 7, 2
local SLOT_STEP = 41
local AUTO_RETRIES = 60

local rows, slots = {}, {}
Tab.rows, Tab.slots = rows, slots

local function Play(sound)
    if SOUNDKIT and SOUNDKIT[sound] then
        PlaySound(SOUNDKIT[sound])
    end
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function ColorText(text, kind)
    local color = (kind == "good" and GREEN_FONT_COLOR) or (kind == "bad" and RED_FONT_COLOR) or nil
    if color and color.WrapTextInColorCode then
        return color:WrapTextInColorCode(text)
    end
    return text
end

local function JoinNames(names)
    if #names <= 1 then
        return names[1] or ""
    end
    return table.concat(names, ", ", 1, #names - 1) .. " " .. L.DE_AND .. " " .. names[#names]
end

-------------------------------------------------------------------------------
-- Rows
-------------------------------------------------------------------------------

local function VisibleGroups()
    local list = {}
    local function Add(parent, depth)
        for _, id in ipairs(Groups:GetChildren(parent)) do
            list[#list + 1] = { id = id, depth = depth }
            if not Groups.db.groupsCollapsed[id] then
                Add(id, depth + 1)
            end
        end
    end
    Add(nil, 1)
    return list
end

local function Row_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(Groups:GetPath(self.id), 1, 1, 1)
    if not Groups:IsActive(self.id) then
        GameTooltip:AddLine(L.GT_ROW_OFF, 1, 0.3, 0.3, true)
    elseif self.included then
        GameTooltip:AddLine(L.GT_ROW_INCLUDED, nil, nil, nil, true)
    else
        GameTooltip:AddLine(L.GT_ROW_TIP, nil, nil, nil, true)
    end
    GameTooltip:Show()
end

local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(270, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:EnableMouse(true)

    local toggle = CreateFrame("Button", nil, row)
    toggle:SetSize(14, 14)
    toggle:SetScript("OnClick", function(self)
        local id = self:GetParent().id
        Groups.db.groupsCollapsed[id] = not Groups.db.groupsCollapsed[id] or nil
        Tab:Refresh()
    end)
    row.toggle = toggle

    local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    check:SetSize(20, 20)
    check:SetScript("OnClick", function(self)
        Play(self:GetChecked() and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
        Groups:SetChecked(self:GetParent().id, self:GetChecked())
    end)
    check:SetScript("OnEnter", function(self)
        Row_OnEnter(self:GetParent())
    end)
    check:SetScript("OnLeave", HideTooltip)
    row.check = check

    local info = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    info:SetPoint("RIGHT", -2, 0)
    info:SetJustifyH("RIGHT")
    row.info = info

    local name = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    name:SetPoint("LEFT", check, "RIGHT", 2, 0)
    name:SetPoint("RIGHT", info, "LEFT", -6, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    row.name = name

    row:SetScript("OnEnter", Row_OnEnter)
    row:SetScript("OnLeave", HideTooltip)
    return row
end

local function SetRow(row, entry, ready)
    local id, group = entry.id, Groups:Get(entry.id)
    row.id = id
    local x = (entry.depth - 1) * INDENT
    row.toggle:ClearAllPoints()
    row.toggle:SetPoint("LEFT", x, 0)
    if #Groups:GetChildren(id) > 0 then
        local collapsed = Groups.db.groupsCollapsed[id]
        row.toggle:SetNormalTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
        row.toggle:Show()
    else
        row.toggle:Hide()
    end
    row.check:ClearAllPoints()
    row.check:SetPoint("LEFT", x + 14, 0)

    local active = Groups:IsActive(id)
    local own = Groups.db.groupsSelected[id] and true or false
    row.included = not own and Groups:IsChecked(id)
    row.check:SetChecked(own or row.included)
    row.check:SetEnabled(active and not row.included)
    row.name:SetText(group.name)
    row.name:SetAlpha(active and 1 or 0.5)

    local who = Groups:Resolve(id)
    local parts = {}
    if who ~= "" then
        parts[#parts + 1] = who
    end
    if (ready or 0) > 0 then
        parts[#parts + 1] = "|cff20ff20" .. L.GT_READY:format(ready) .. "|r"
    end
    row.info:SetText(table.concat(parts, "  "))
    row.info:SetAlpha(active and 1 or 0.5)
    row:Show()
end

-------------------------------------------------------------------------------
-- Items going out
-------------------------------------------------------------------------------

local function Slot_OnEnter(self)
    if not self.itemID then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.itemID)
    if self.to then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(self.count .. " -> " .. self.to, 1, 0.82, 0)
    end
    GameTooltip:Show()
end

-------------------------------------------------------------------------------
-- Building the tab and page
-------------------------------------------------------------------------------

function Tab:Create()
    local UI = ns.UI
    if self.created or not UI.created then
        return
    end
    self.created = true
    self.title = L.GT_TITLE

    local tab = CreateFrame("Button", "DEMailerGroupsTab", UI.tabHolder, "PanelTabButtonTemplate")
    tab:SetPoint("TOPLEFT", UI.tab, "TOPRIGHT", 3, 0)
    tab:SetText(L.GT_TAB)
    tab:SetScript("OnClick", function()
        Tab:ShowPage()
    end)
    PanelTemplates_DeselectTab(tab)
    PanelTemplates_TabResize(tab, 0, nil, nil, UI.tabHolder.maxTabWidth)
    self.tab = tab

    local page = CreateFrame("Frame", "DEMailerGroupsPage", MailFrame)
    page:SetAllPoints(MailFrame)
    page:Hide()
    self.page = page

    local background = page:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\MailFrame\\UI-MailFrameBG")
    background:SetSize(512, 512)
    background:SetPoint("TOPLEFT", 7, -62)

    local header = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", 24, -76)
    header:SetText(L.GT_HEADER)

    local edit = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    edit:SetSize(110, 20)
    edit:SetPoint("TOPRIGHT", -24, -72)
    edit:SetText(L.GT_EDIT)
    edit:SetScript("OnClick", function()
        ns.GroupsEditor:Open()
    end)

    local scroll = CreateFrame("ScrollFrame", nil, page, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, LIST_TOP)
    scroll:SetSize(270, LIST_ROWS * ROW_HEIGHT)
    local list = CreateFrame("Frame", nil, scroll)
    list:SetSize(270, 1)
    scroll:SetScrollChild(list)
    self.list = list

    local empty = page:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    empty:SetPoint("TOP", page, "TOPLEFT", 169, LIST_TOP - 40)
    empty:SetWidth(260)
    empty:SetText(L.GT_EMPTY)
    self.empty = empty

    local summary = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    summary:SetPoint("TOPLEFT", 24, LIST_TOP - LIST_ROWS * ROW_HEIGHT - 8)
    summary:SetPoint("RIGHT", -24, 0)
    summary:SetJustifyH("LEFT")
    summary:SetWordWrap(false)
    self.summary = summary

    for i = 1, GRID_COLUMNS * GRID_ROWS do
        local slot = CreateFrame("ItemButton", "DEMailerGroupsSlot" .. i, page)
        local column, row = (i - 1) % GRID_COLUMNS, math.floor((i - 1) / GRID_COLUMNS)
        slot:SetPoint("TOPLEFT", 28 + column * SLOT_STEP, GRID_TOP - row * SLOT_STEP)
        slot:SetScript("OnEnter", Slot_OnEnter)
        slot:SetScript("OnLeave", HideTooltip)
        slot:Hide()
        slots[i] = slot
    end
    local more = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    more:SetPoint("TOPRIGHT", -28, GRID_TOP - GRID_ROWS * SLOT_STEP + 2)
    self.more = more

    local auto = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    auto:SetSize(24, 24)
    auto:SetPoint("TOPLEFT", 20, GRID_TOP - GRID_ROWS * SLOT_STEP - 2)
    auto.Text:SetFontObject(GameFontHighlightSmall)
    auto.Text:SetText(L.GT_AUTO)
    auto:SetHitRectInsets(0, -(auto.Text:GetStringWidth() + 4), 0, 0)
    auto:SetScript("OnClick", function(self)
        Play(self:GetChecked() and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
        ns:SetGroupsAutoSend(self:GetChecked())
    end)
    auto:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.GT_AUTO, 1, 1, 1, 1, true)
        GameTooltip:AddLine(L.GT_AUTO_TIP, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    auto:SetScript("OnLeave", HideTooltip)
    self.autoCheck = auto

    local status = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("BOTTOM", 0, 46)
    status:SetWidth(300)
    self.statusText = status

    local send = CreateFrame("Button", "DEMailerGroupsSendButton", page, "UIPanelButtonTemplate")
    send:SetSize(140, 24)
    send:SetPoint("CENTER", page, "BOTTOM", 0, 26)
    send:SetText(L.SEND)
    send:SetScript("OnClick", function()
        Tab:OnSendClicked()
    end)
    self.sendButton = send

    page:SetScript("OnShow", function()
        Tab:Refresh()
    end)

    table.insert(ns.mailPages, self)
    hooksecurefunc("MailFrameTab_OnClick", function()
        Tab:HidePage()
    end)
    MailFrame:HookScript("OnHide", function()
        Tab:HidePage()
    end)

    self:Refresh()
end

function Tab:ShowPage()
    if not self.created or self.page:IsShown() then
        return
    end
    ns.ShowMailPage(self)
end

function Tab:HidePage()
    if not self.created then
        return
    end
    self.page:Hide()
    PanelTemplates_DeselectTab(self.tab)
end

function Tab:OnMailShow()
    if self.created then
        local trial = GameLimitedMode_IsActive and GameLimitedMode_IsActive()
        self.tab:SetShown(not trial)
    end
end

function Tab:OnSendClicked()
    local run = ns.run
    if run and run.state ~= "paused" then
        ns:Stop()
        return
    end
    local ok, reason = ns:StartGroups("click", true)
    if not ok and reason then
        ns:SetMessage(reason, "bad", false, "groups")
        self:Refresh()
    end
end

-------------------------------------------------------------------------------
-- Refreshing
-------------------------------------------------------------------------------

function Tab:Refresh()
    if not self.created or not ns.db or not Groups.db then
        return
    end
    local plan = Groups:BuildPlan(false)
    local label = (plan.items > 0) and ("%s (%d)"):format(L.GT_TAB, plan.items) or L.GT_TAB
    if self.tab:GetText() ~= label then
        self.tab:SetText(label)
        PanelTemplates_TabResize(self.tab, 0, nil, nil, ns.UI.tabHolder.maxTabWidth)
    end
    if not self.page:IsShown() then
        return
    end

    -- How much each group has ready, whether checked or not.
    local everything = Groups:BuildPlan(true)
    local ready = {}
    for _, entry in ipairs(everything.recipients) do
        for _, attachment in ipairs(entry.attachments) do
            local id = Groups:GetGroupOfItem(attachment.itemID)
            ready[id] = (ready[id] or 0) + attachment.count
        end
    end

    local visible = VisibleGroups()
    for i, entry in ipairs(visible) do
        rows[i] = rows[i] or CreateRow(self.list, i)
        SetRow(rows[i], entry, ready[entry.id])
    end
    for i = #visible + 1, #rows do
        rows[i]:Hide()
    end
    self.list:SetHeight(math.max(1, #visible * ROW_HEIGHT))
    self.empty:SetShown(#visible == 0)

    -- Summary and the items going out
    local names = {}
    for _, entry in ipairs(plan.recipients) do
        names[#names + 1] = entry.name
    end
    local summary = ""
    if plan.items > 0 then
        summary = L.GT_SUMMARY:format(plan.items, JoinNames(names), plan.letters)
    end
    local nobody = 0
    for _, skip in ipairs(plan.skipped) do
        if skip.reason == "nobody" then
            nobody = nobody + 1
        end
    end
    if nobody > 0 then
        summary = (summary ~= "" and (summary .. "  ") or "") .. "|cffff6060" .. L.GT_SKIPPED_NOBODY:format(nobody) .. "|r"
    end
    self.summary:SetText(summary)

    local outgoing = {}
    for _, entry in ipairs(plan.recipients) do
        local byItem = {}
        for _, attachment in ipairs(entry.attachments) do
            local item = byItem[attachment.itemID]
            if not item then
                item = { itemID = attachment.itemID, link = attachment.link, icon = attachment.icon,
                    quality = attachment.quality, count = 0, to = entry.name }
                byItem[attachment.itemID] = item
                outgoing[#outgoing + 1] = item
            end
            item.count = item.count + attachment.count
        end
    end
    for i, slot in ipairs(slots) do
        local item = outgoing[i]
        if item then
            slot.itemID, slot.count, slot.to = item.itemID, item.count, item.to
            SetItemButtonTexture(slot, item.icon)
            SetItemButtonQuality(slot, item.quality, item.link)
            SetItemButtonCount(slot, item.count)
            slot:Show()
        else
            slot.itemID = nil
            slot:Hide()
        end
    end
    local hidden = #outgoing - #slots
    self.more:SetText(hidden > 0 and L.GT_MORE:format(hidden) or "")
    self.autoCheck:SetChecked(ns.db.groupsAutoSend)

    -- Status and the Send button
    local run = ns.run
    local text, kind, buttonText, enabled = "", nil, L.SEND, false
    if run and not run.groups then
        text, buttonText = L.GT_BUSY, L.SEND
    elseif run then
        if run.state == "paused" then
            text, buttonText, enabled = L.PAUSED:format(run.letters), L.SEND_NEXT, true
        else
            local current = run.letters + 1
            text = run.state == "waiting" and L.WAITING
                or L.SENDING:format(current, math.max(current, run.totalLetters or current), run.recipient)
            buttonText, enabled = L.STOP, not run.stopRequested
        end
    else
        enabled = plan.items > 0 and ns:IsMailOpen()
        if ns.message and ns.messageFor == "groups" then
            text, kind = ns.message, ns.messageKind
        elseif plan.items > 0 then
            text = L.GT_READY_STATUS:format(plan.items)
        else
            text = L.GT_NOTHING
        end
    end
    self.statusText:SetText(ColorText(text, kind))
    self.sendButton:SetText(buttonText)
    self.sendButton:SetEnabled(enabled)
end

-------------------------------------------------------------------------------
-- Automatic sending when the mailbox opens
-------------------------------------------------------------------------------

function ns:SetGroupsAutoSend(enabled)
    self.db.groupsAutoSend = enabled and true or false
    self:OnSettingsChanged()
end

function Tab:TryAutoSend(attempt)
    if not ns:IsMailOpen() then
        return
    end
    if ns.run then
        -- Probably the Disenchant tab sending: try again when it's done.
        if attempt < AUTO_RETRIES then
            C_Timer.After(1, function()
                Tab:TryAutoSend(attempt + 1)
            end)
        end
        return
    end
    local plan = Groups:BuildPlan(false)
    if plan.items == 0 then
        return
    end
    if ns.needsClick then
        ns.Print(L.GT_AUTO_NEEDS_CLICK:format(plan.items))
        return
    end
    ns:StartGroups("auto", false)
end

local events = CreateFrame("Frame")
events:RegisterEvent("MAIL_SHOW")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:SetScript("OnEvent", function(_, event)
    if not ns.db or not Groups.db then
        return
    end
    if event == "MAIL_SHOW" then
        Tab:OnMailShow()
        if ns.db.groupsAutoSend and not IsShiftKeyDown() then
            C_Timer.After(1, function()
                Tab:TryAutoSend(1)
            end)
        end
    end
    Tab:Refresh()
end)
