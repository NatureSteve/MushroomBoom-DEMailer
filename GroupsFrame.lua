-- DE Mailer: GroupsFrame.lua
-- The Mail Groups editor: a window to make, rename, move and delete groups,
-- set who gets each one and how much to keep or send, and put items in
-- them (drag an item onto a group, or Alt-click it in your bags while the
-- window is open). Also adds a line to item tooltips naming the group.

local ADDON_NAME, ns = ...
local L = ns.L
local Groups = ns.Groups

local Editor = {}
ns.GroupsEditor = Editor

L.GE_TITLE          = "Mail Groups"
L.GE_NEW            = "New Group"
L.GE_NEW_SUB        = "New Subgroup"
L.GE_RENAME         = "Rename"
L.GE_DELETE         = "Delete"
L.GE_MOVE           = "Move To"
L.GE_TOP_LEVEL      = "Top level"
L.GE_TURN_OFF       = "Switch Off"
L.GE_TURN_ON        = "Switch On"
L.GE_DELETE_KEEP    = "Delete, keep its items and subgroups"
L.GE_DELETE_ALL     = "Delete with its subgroups and items"
L.GE_NEW_TITLE      = "Name the new group"
L.GE_NEW_INSIDE     = "Inside %s."
L.GE_RENAME_TITLE   = "Rename %s"
L.GE_EMPTY          = "No groups yet. Press New Group to make one."
L.GE_SELECT         = "Pick a group on the left."
L.GE_SEND_TO        = "Send to:"
L.GE_KEEP           = "Keep:"
L.GE_CAP            = "Send at most:"
L.GE_KEEP_HINT      = "of each item in your bags"
L.GE_CAP_HINT       = "of each item per send (0: no limit)"
L.GE_SAME           = "Empty: same as above (%s)"
L.GE_DEFAULT        = "Empty: %s"
L.GE_NOBODY         = "nobody"
L.GE_NO_LIMIT       = "no limit"
L.GE_ENABLED        = "Switched on"
L.GE_ENABLED_TIP    = "A switched-off group, and every group inside it, is never sent."
L.GE_ITEMS          = "Items (%d)"
L.GE_ITEMS_EMPTY    = "Drag items here, or Alt-click them in your bags while this window is open."
L.GE_ITEM_REMOVE    = "<Right-click to take it out of the group>"
L.GE_ITEM_CARRIED   = "You carry %d."
L.GE_ROW_TIP        = "<Right-click for more>"
L.GE_TOOLTIP        = "DE Mailer: %s, to %s"
L.GE_OFF            = "(off)"

local WIDTH, HEIGHT = 600, 480
local TREE_WIDTH = 230
local ROW_HEIGHT = 20
local INDENT = 12
local ITEM_COLUMNS = 7
local ITEM_STEP = 41

local frame
local treeRows, itemButtons = {}, {}
Editor.treeRows, Editor.itemButtons = treeRows, itemButtons

local function Play(sound)
    if SOUNDKIT and SOUNDKIT[sound] then
        PlaySound(SOUNDKIT[sound])
    end
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

-- If an item is on the cursor, put it in a group. Returns true if it did.
local function DropCursorItemOn(id)
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" or not itemID or not id then
        return false
    end
    ClearCursor()
    Groups:AddItems(id, { itemID })
    Play("IG_BACKPACK_COIN_SELECT")
    Editor:Select(id)
    return true
end

-------------------------------------------------------------------------------
-- Menus and prompts
-------------------------------------------------------------------------------

function Editor:PromptNew(parent)
    local subtitle = parent and L.GE_NEW_INSIDE:format(Groups:GetPath(parent)) or nil
    ns.ShowPrompt(L.GE_NEW_TITLE, subtitle, "", function(text)
        local id, err = Groups:Create(text, parent)
        if id then
            if parent then
                Groups.db.groupsCollapsed[parent] = nil
            end
            self:Select(id)
        else
            ns.Print(err)
        end
    end)
end

function Editor:PromptRename(id)
    local path = Groups:GetPath(id)
    ns.ShowPrompt(L.GE_RENAME_TITLE:format(path), nil, Groups:Get(id).name, function(text)
        local ok, err = Groups:Rename(id, text)
        if not ok then
            ns.Print(err)
        end
    end)
end

local function AddDeleteChoices(menu, id)
    menu:CreateButton(L.GE_DELETE_KEEP, function()
        if Editor.selected == id then
            Editor.selected = Groups:Get(id).parent
        end
        Groups:Delete(id, true)
    end)
    menu:CreateButton(L.GE_DELETE_ALL, function()
        if Editor.selected == id then
            Editor.selected = Groups:Get(id).parent
        end
        Groups:Delete(id, false)
    end)
end

function Editor:OpenGroupMenu(owner, id)
    local group = Groups:Get(id)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(Groups:GetPath(id))
        root:CreateButton(L.GE_NEW_SUB, function()
            Editor:PromptNew(id)
        end)
        root:CreateButton(L.GE_RENAME, function()
            Editor:PromptRename(id)
        end)
        local move = root:CreateButton(L.GE_MOVE)
        if group.parent then
            move:CreateButton(L.GE_TOP_LEVEL, function()
                local ok, err = Groups:Move(id, nil)
                if not ok then ns.Print(err) end
            end)
        end
        local height = Groups:GetHeight(id)
        Groups:Walk(function(target, depth)
            if target ~= group.parent and not Groups:IsInside(target, id)
                and depth + height <= Groups.MAX_DEPTH then
                move:CreateButton(string.rep("   ", depth - 1) .. Groups:Get(target).name, function()
                    local ok, err = Groups:Move(id, target)
                    if not ok then ns.Print(err) end
                end)
            end
        end)
        root:CreateButton(group.enabled and L.GE_TURN_OFF or L.GE_TURN_ON, function()
            Groups:SetEnabled(id, not group.enabled)
        end)
        local delete = root:CreateButton(L.GE_DELETE)
        AddDeleteChoices(delete, id)
    end)
end

-------------------------------------------------------------------------------
-- The tree on the left
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

local function Row_OnClick(self, mouseButton)
    if DropCursorItemOn(self.id) then
        return
    end
    if mouseButton == "RightButton" then
        Editor:OpenGroupMenu(self, self.id)
    else
        Play("IG_MAINMENU_OPTION_CHECKBOX_ON")
        Editor:Select(self.id)
    end
end

local function Row_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(Groups:GetPath(self.id), 1, 1, 1)
    GameTooltip:AddLine(L.GE_ROW_TIP, 0.1, 1, 0.1)
    GameTooltip:Show()
end

local function CreateTreeRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(TREE_WIDTH - 30, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    local selected = row:CreateTexture(nil, "BACKGROUND")
    selected:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    selected:SetBlendMode("ADD")
    selected:SetVertexColor(1, 0.82, 0, 0.6)
    selected:SetAllPoints()
    selected:Hide()
    row.selected = selected

    local toggle = CreateFrame("Button", nil, row)
    toggle:SetSize(14, 14)
    toggle:SetScript("OnClick", function(self)
        local id = self:GetParent().id
        Groups.db.groupsCollapsed[id] = not Groups.db.groupsCollapsed[id] or nil
        Editor:Refresh()
    end)
    row.toggle = toggle

    local count = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    count:SetPoint("RIGHT", -4, 0)
    row.count = count

    local name = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    name:SetPoint("LEFT", toggle, "RIGHT", 4, 0)
    name:SetPoint("RIGHT", count, "LEFT", -4, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    row.name = name

    row:SetScript("OnClick", Row_OnClick)
    row:SetScript("OnReceiveDrag", function(self)
        DropCursorItemOn(self.id)
    end)
    row:SetScript("OnEnter", Row_OnEnter)
    row:SetScript("OnLeave", HideTooltip)
    return row
end

local function SetTreeRow(row, entry)
    local id, group = entry.id, Groups:Get(entry.id)
    row.id = id
    row.toggle:ClearAllPoints()
    row.toggle:SetPoint("LEFT", 2 + (entry.depth - 1) * INDENT, 0)
    if #Groups:GetChildren(id) > 0 then
        local collapsed = Groups.db.groupsCollapsed[id]
        row.toggle:SetNormalTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
        row.toggle:Show()
    else
        row.toggle:Hide()
    end
    local active = Groups:IsActive(id)
    row.name:SetText(group.name .. (group.enabled and "" or (" " .. L.GE_OFF)))
    row.name:SetAlpha(active and 1 or 0.5)
    local items = Groups:CountItems(id)
    row.count:SetText(items > 0 and items or "")
    row.selected:SetShown(Editor.selected == id)
    row:Show()
end

-------------------------------------------------------------------------------
-- The settings on the right
-------------------------------------------------------------------------------

-- Saves the recipient, keep and cap boxes for the selected group.
local function SaveBox(box)
    local id = box.groupId
    if not id or not Groups:Get(id) then
        return
    end
    local text = ns.Trim(box:GetText())
    if box.kind == "recipient" then
        if text ~= (Groups:GetOwnRecipient(id) or "") then
            Groups:SetRecipient(id, text ~= "" and text or nil)
        end
    elseif box.kind == "keep" then
        local value = tonumber(text)
        if value ~= Groups:Get(id).keep then
            Groups:SetKeep(id, value)
        end
    elseif box.kind == "cap" then
        local value = tonumber(text)
        local cap
        if value == nil then
            cap = nil
        elseif value == 0 then
            cap = false
        else
            cap = value
        end
        if cap ~= Groups:Get(id).cap then
            Groups:SetCap(id, cap)
        end
    end
end

local function SetupBox(box, kind)
    box.kind = kind
    box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self)
        self.cancelled = true
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusGained", function(self)
        self.cancelled = nil
        self.groupId = Editor.selected -- save to this group even if another gets picked
        self:HighlightText()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        if self.cancelled then
            self.cancelled = nil
            Editor:Refresh()
        else
            SaveBox(self)
        end
    end)
end

local function Item_OnEnter(self)
    if not self.itemID then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.itemID)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.GE_ITEM_CARRIED:format(self.carried or 0), 1, 0.82, 0)
    GameTooltip:AddLine(L.GE_ITEM_REMOVE, 0.1, 1, 0.1)
    GameTooltip:Show()
end

local function Item_OnClick(self, mouseButton)
    if DropCursorItemOn(Editor.selected) then
        return
    end
    if mouseButton == "RightButton" and self.itemID then
        Play("IG_MAINMENU_OPTION_CHECKBOX_OFF")
        Groups:RemoveItems({ self.itemID })
        HideTooltip()
    end
end

local function ItemCount(itemID)
    if C_Item.GetItemCount then
        return C_Item.GetItemCount(itemID) or 0
    end
    return 0
end

-------------------------------------------------------------------------------
-- Building the window
-------------------------------------------------------------------------------

function Editor:Create()
    if frame then
        return
    end
    frame = CreateFrame("Frame", "DEMailerGroupsFrame", UIParent, "ButtonFrameTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        ns.db.groupsEditorPosition = { point, relativePoint, x, y }
    end)
    frame:SetPortraitToAsset("Interface\\Icons\\INV_Letter_15")
    frame:SetTitle(L.GE_TITLE)
    ButtonFrameTemplate_ShowButtonBar(frame)
    if frame.CloseButton then
        frame.CloseButton:SetScript("OnClick", function()
            frame:Hide()
        end)
    end
    if frame.Inset then
        frame.Inset:Hide()
    end
    frame:Hide()
    local position = ns.db.groupsEditorPosition or { "CENTER", "CENTER", 0, 40 }
    frame:ClearAllPoints()
    frame:SetPoint(position[1], UIParent, position[2], position[3], position[4])
    table.insert(UISpecialFrames, frame:GetName())

    -- Two panes, each in the game's usual sunken inset.
    local left = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    left:SetPoint("TOPLEFT", 4, -60)
    left:SetPoint("BOTTOMLEFT", 4, 26)
    left:SetWidth(TREE_WIDTH)
    local right = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 4, 0)
    right:SetPoint("BOTTOMRIGHT", -6, 26)
    self.right = right

    -- Tree
    local treeScroll = CreateFrame("ScrollFrame", nil, left, "ScrollFrameTemplate")
    treeScroll:SetPoint("TOPLEFT", 6, -6)
    treeScroll:SetPoint("BOTTOMRIGHT", -24, 6)
    local tree = CreateFrame("Frame", nil, treeScroll)
    tree:SetSize(TREE_WIDTH - 30, 1)
    treeScroll:SetScrollChild(tree)
    self.tree = tree

    local treeEmpty = left:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    treeEmpty:SetPoint("TOPLEFT", 12, -20)
    treeEmpty:SetPoint("RIGHT", -12, 0)
    treeEmpty:SetText(L.GE_EMPTY)
    self.treeEmpty = treeEmpty

    -- Settings for the selected group
    local title = right:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetPoint("RIGHT", -14, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    self.title = title

    local pick = right:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    pick:SetPoint("TOPLEFT", 14, -14)
    pick:SetText(L.GE_SELECT)
    self.pick = pick

    local details = CreateFrame("Frame", nil, right)
    details:SetAllPoints()
    self.details = details

    local function Label(text, y)
        local label = details:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", 14, y)
        label:SetText(text)
        return label
    end
    local function Hint(anchor)
        local hint = details:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        hint:SetPoint("LEFT", anchor, "RIGHT", 10, 0)
        hint:SetPoint("RIGHT", details, "RIGHT", -12, 0)
        hint:SetJustifyH("LEFT")
        return hint
    end

    Label(L.GE_SEND_TO, -48)
    local recipient = ns.CreateNameBox(details, "DEMailerGroupRecipientBox", 150)
    recipient:SetPoint("TOPLEFT", 120, -42)
    SetupBox(recipient, "recipient")
    self.recipientBox = recipient
    self.recipientHint = details:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    self.recipientHint:SetPoint("TOPLEFT", recipient, "BOTTOMLEFT", 0, 0)

    Label(L.GE_KEEP, -92)
    local keep = ns.CreateNameBox(details, "DEMailerGroupKeepBox", 50)
    keep:SetPoint("TOPLEFT", 120, -86)
    keep:SetNumeric(true)
    keep:SetMaxLetters(6)
    SetupBox(keep, "keep")
    self.keepBox = keep
    local keepHint = Hint(keep)
    keepHint:SetText(L.GE_KEEP_HINT)
    self.keepDefault = details:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    self.keepDefault:SetPoint("TOPLEFT", keep, "BOTTOMLEFT", 0, 0)

    Label(L.GE_CAP, -136)
    local cap = ns.CreateNameBox(details, "DEMailerGroupCapBox", 50)
    cap:SetPoint("TOPLEFT", 120, -130)
    cap:SetNumeric(true)
    cap:SetMaxLetters(6)
    SetupBox(cap, "cap")
    self.capBox = cap
    local capHint = Hint(cap)
    capHint:SetText(L.GE_CAP_HINT)
    self.capDefault = details:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    self.capDefault:SetPoint("TOPLEFT", cap, "BOTTOMLEFT", 0, 0)

    local enabled = CreateFrame("CheckButton", nil, details, "UICheckButtonTemplate")
    enabled:SetSize(24, 24)
    enabled:SetPoint("TOPLEFT", 10, -170)
    enabled.Text:SetFontObject(GameFontHighlightSmall)
    enabled.Text:SetText(L.GE_ENABLED)
    enabled:SetHitRectInsets(0, -(enabled.Text:GetStringWidth() + 4), 0, 0)
    enabled:SetScript("OnClick", function(self)
        Play(self:GetChecked() and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
        if Editor.selected then
            Groups:SetEnabled(Editor.selected, self:GetChecked())
        end
    end)
    enabled:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.GE_ENABLED, 1, 1, 1)
        GameTooltip:AddLine(L.GE_ENABLED_TIP, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    enabled:SetScript("OnLeave", HideTooltip)
    self.enabledCheck = enabled

    -- Items
    local itemsLabel = details:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    itemsLabel:SetPoint("TOPLEFT", 14, -206)
    self.itemsLabel = itemsLabel

    local itemScroll = CreateFrame("ScrollFrame", nil, details, "ScrollFrameTemplate")
    itemScroll:SetPoint("TOPLEFT", 10, -226)
    itemScroll:SetPoint("BOTTOMRIGHT", -26, 8)
    local itemArea = CreateFrame("Button", nil, itemScroll)
    itemArea:SetSize(ITEM_COLUMNS * ITEM_STEP, 1)
    itemArea:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    itemArea:SetScript("OnClick", function()
        DropCursorItemOn(Editor.selected)
    end)
    itemArea:SetScript("OnReceiveDrag", function()
        DropCursorItemOn(Editor.selected)
    end)
    itemScroll:SetScrollChild(itemArea)
    self.itemArea = itemArea

    local itemsEmpty = details:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    itemsEmpty:SetPoint("TOPLEFT", itemScroll, "TOPLEFT", 6, -16)
    itemsEmpty:SetPoint("RIGHT", itemScroll, "RIGHT", -6, 0)
    itemsEmpty:SetText(L.GE_ITEMS_EMPTY)
    self.itemsEmpty = itemsEmpty

    -- Buttons along the bottom
    local function BarButton(text, onClick)
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(116, 22)
        button:SetText(text)
        button:SetScript("OnClick", onClick)
        return button
    end
    local newButton = BarButton(L.GE_NEW, function()
        Editor:PromptNew(nil)
    end)
    newButton:SetPoint("BOTTOMLEFT", 4, 4)
    local subButton = BarButton(L.GE_NEW_SUB, function()
        if Editor.selected then
            Editor:PromptNew(Editor.selected)
        end
    end)
    subButton:SetPoint("LEFT", newButton, "RIGHT", 2, 0)
    self.subButton = subButton
    local deleteButton = BarButton(L.GE_DELETE, function(self)
        local id = Editor.selected
        if id then
            MenuUtil.CreateContextMenu(self, function(_, root)
                root:CreateTitle(Groups:GetPath(id))
                AddDeleteChoices(root, id)
            end)
        end
    end)
    deleteButton:SetPoint("BOTTOMRIGHT", -6, 4)
    self.deleteButton = deleteButton
    local renameButton = BarButton(L.GE_RENAME, function()
        if Editor.selected then
            Editor:PromptRename(Editor.selected)
        end
    end)
    renameButton:SetPoint("RIGHT", deleteButton, "LEFT", -2, 0)
    self.renameButton = renameButton

    frame:SetScript("OnShow", function()
        Play("IG_CHARACTER_INFO_OPEN")
        Editor:Refresh()
    end)
    frame:SetScript("OnHide", function()
        Play("IG_CHARACTER_INFO_CLOSE")
    end)
    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:SetScript("OnEvent", function()
        Editor:Refresh()
    end)
end

-------------------------------------------------------------------------------
-- Opening and refreshing
-------------------------------------------------------------------------------

function Editor:IsOpen()
    return frame ~= nil and frame:IsShown()
end

function Editor:Open()
    self:Create()
    frame:Show()
    frame:Raise()
end

function Editor:Toggle()
    if self:IsOpen() then
        frame:Hide()
    else
        self:Open()
    end
end

function Editor:Select(id)
    -- Finish any edit for the group being left first.
    for _, box in ipairs({ self.recipientBox, self.keepBox, self.capBox }) do
        if box and box:HasFocus() then
            box:ClearFocus()
        end
    end
    self.selected = id
    self:Refresh()
end

function Editor:Refresh()
    if not frame or not frame:IsShown() then
        return
    end
    if self.selected and not Groups:Get(self.selected) then
        self.selected = nil
    end

    -- Tree
    local visible = VisibleGroups()
    if not self.selected and visible[1] then
        self.selected = visible[1].id
    end
    for i, entry in ipairs(visible) do
        treeRows[i] = treeRows[i] or CreateTreeRow(self.tree, i)
        SetTreeRow(treeRows[i], entry)
    end
    for i = #visible + 1, #treeRows do
        treeRows[i]:Hide()
    end
    self.tree:SetHeight(math.max(1, #visible * ROW_HEIGHT))
    self.treeEmpty:SetShown(#visible == 0)

    local id = self.selected
    self.subButton:SetEnabled(id ~= nil)
    self.renameButton:SetEnabled(id ~= nil)
    self.deleteButton:SetEnabled(id ~= nil)
    self.details:SetShown(id ~= nil)
    self.title:SetShown(id ~= nil)
    self.pick:SetShown(id == nil and #visible > 0)
    if not id then
        return
    end

    -- Settings
    local group = Groups:Get(id)
    self.title:SetText(Groups:GetPath(id))
    local hasParent = group.parent ~= nil
    local parentRecipient, parentKeep, parentCap = "", 0, nil
    if hasParent then
        parentRecipient, parentKeep, parentCap = Groups:Resolve(group.parent)
    end

    if not self.recipientBox:HasFocus() then
        self.recipientBox:SetText(Groups:GetOwnRecipient(id) or "")
    end
    local who = (parentRecipient ~= "") and parentRecipient or L.GE_NOBODY
    self.recipientHint:SetText(hasParent and L.GE_SAME:format(who) or L.GE_DEFAULT:format(L.GE_NOBODY))

    if not self.keepBox:HasFocus() then
        self.keepBox:SetText(group.keep and tostring(group.keep) or "")
    end
    self.keepDefault:SetText(hasParent and L.GE_SAME:format(parentKeep) or L.GE_DEFAULT:format(0))

    if not self.capBox:HasFocus() then
        local cap = group.cap
        self.capBox:SetText((cap == false) and "0" or (cap and tostring(cap)) or "")
    end
    local capText = parentCap and tostring(parentCap) or L.GE_NO_LIMIT
    self.capDefault:SetText(hasParent and L.GE_SAME:format(capText) or L.GE_DEFAULT:format(L.GE_NO_LIMIT))

    self.enabledCheck:SetChecked(group.enabled)

    -- Items, named ones in name order
    local items = {}
    for itemID in pairs(group.items) do
        local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
        items[#items + 1] = { itemID = itemID, name = name or "" }
    end
    table.sort(items, function(a, b)
        if a.name ~= b.name then
            return a.name < b.name
        end
        return a.itemID < b.itemID
    end)
    self.itemsLabel:SetText(L.GE_ITEMS:format(#items))
    for i, item in ipairs(items) do
        local button = itemButtons[i]
        if not button then
            button = CreateFrame("ItemButton", "DEMailerGroupItem" .. i, self.itemArea)
            local column, row = (i - 1) % ITEM_COLUMNS, math.floor((i - 1) / ITEM_COLUMNS)
            button:SetPoint("TOPLEFT", column * ITEM_STEP, -row * ITEM_STEP)
            button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            button:SetScript("OnClick", Item_OnClick)
            button:SetScript("OnReceiveDrag", function()
                DropCursorItemOn(Editor.selected)
            end)
            button:SetScript("OnEnter", Item_OnEnter)
            button:SetScript("OnLeave", HideTooltip)
            itemButtons[i] = button
        end
        button.itemID = item.itemID
        button.carried = ItemCount(item.itemID)
        SetItemButtonTexture(button, C_Item.GetItemIconByID(item.itemID))
        SetItemButtonQuality(button, C_Item.GetItemQualityByID(item.itemID), item.itemID)
        SetItemButtonCount(button, button.carried)
        SetItemButtonDesaturated(button, button.carried == 0)
        button:Show()
        if GameTooltip:IsOwned(button) then
            Item_OnEnter(button)
        end
    end
    for i = #items + 1, #itemButtons do
        itemButtons[i].itemID = nil
        itemButtons[i]:Hide()
    end
    local rows = math.ceil(#items / ITEM_COLUMNS)
    self.itemArea:SetHeight(math.max(160, rows * ITEM_STEP))
    self.itemsEmpty:SetShown(#items == 0)
end

-------------------------------------------------------------------------------
-- Alt-click in your bags, and the tooltip line
-------------------------------------------------------------------------------

-- Bag buttons made after this point carry the hook; if the game made some
-- earlier, dragging still works.
if ContainerFrameItemButtonMixin and ContainerFrameItemButtonMixin.OnModifiedClick then
    hooksecurefunc(ContainerFrameItemButtonMixin, "OnModifiedClick", function(button, mouseButton)
        if mouseButton ~= "LeftButton" or not IsAltKeyDown() or not Editor:IsOpen() or not Editor.selected then
            return
        end
        local info = C_Container.GetContainerItemInfo(button:GetBagID(), button:GetID())
        if info and info.itemID then
            Groups:AddItems(Editor.selected, { info.itemID })
            Play("IG_BACKPACK_COIN_SELECT")
        end
    end)
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) or not ns.db or not Groups.itemIndex then
            return
        end
        local itemID = data and data.id
        if not itemID or IsSecret(itemID) then
            return
        end
        local id = Groups:GetGroupOfItem(itemID)
        if not id then
            return
        end
        local who = Groups:Resolve(id)
        tooltip:AddLine(L.GE_TOOLTIP:format(Groups:GetPath(id), who ~= "" and who or L.GE_NOBODY), 0.76, 0.55, 1)
    end)
end
