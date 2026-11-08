-- DE Mailer: DisenchantFrame.lua
-- The Disenchanting window: the next item, what you've got this session, the
-- list of gear to disenchant and the Disenchant button. Built from the
-- game's own window, item slot and button templates.

local ADDON_NAME, ns = ...
local L = ns.L
local DE = ns.DE

local Frame = {}
ns.DEFrame = Frame

local WIDTH, HEIGHT = 338, 480
local ROW_HEIGHT = 22
local LIST_WIDTH = WIDTH - 40
local MATERIAL_SLOTS = 7
local POSSIBLE_LINES = 3
local DEFAULT_POSITION = { "CENTER", "CENTER", 260, 40 }
local PLACEHOLDER_ICON = "Interface\\Icons\\INV_Enchant_Disenchant"

local frame, button
local rows = {}

local function Play(sound)
    if SOUNDKIT and SOUNDKIT[sound] then
        PlaySound(SOUNDKIT[sound])
    end
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function ItemLevel(item)
    if item.link and C_Item.GetDetailedItemLevelInfo then
        return C_Item.GetDetailedItemLevelInfo(item.link)
    end
end

-- "Item Level 25   Back"
local function ItemInfoLine(item)
    local parts = {}
    local level = ItemLevel(item)
    if level then
        parts[#parts + 1] = L.DE_ITEM_LEVEL:format(level)
    end
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(item.itemID)
    local slotName = equipLoc and _G[equipLoc]
    if type(slotName) == "string" and slotName ~= "" then
        parts[#parts + 1] = slotName
    end
    return table.concat(parts, "   ")
end

local function FormatChance(chance)
    if chance == math.floor(chance) then
        return ("%d%%"):format(chance)
    end
    return ("%.1f%%"):format(chance)
end

local function FormatCount(minCount, maxCount)
    if not minCount then
        return nil
    elseif minCount == maxCount then
        return tostring(minCount)
    end
    return ("%d-%d"):format(minCount, maxCount)
end

-------------------------------------------------------------------------------
-- Position
-------------------------------------------------------------------------------

local function SavePosition()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point then
        ns.db.disenchant.position = { point, relativePoint, x, y }
    end
end

local function RestorePosition()
    local position = ns.db.disenchant.position or DEFAULT_POSITION
    frame:ClearAllPoints()
    frame:SetPoint(position[1], UIParent, position[2], position[3], position[4])
end

-------------------------------------------------------------------------------
-- List rows
-------------------------------------------------------------------------------

local function Row_OnEnter(self)
    local item = self.item
    if not item then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetBagItem(item.bag, item.slot)
    GameTooltip:AddLine(" ")
    if item.skipped then
        GameTooltip:AddLine(L.DE_ROW_SKIPPED:format(item.skipped), 1, 0.3, 0.3, true)
    elseif item.kept then
        GameTooltip:AddLine(L.DE_ROW_KEPT, 1, 0.82, 0)
        GameTooltip:AddLine(L.DE_ROW_UNKEEP, 0.1, 1, 0.1)
    else
        GameTooltip:AddLine(L.DE_ROW_KEEP, 0.1, 1, 0.1)
    end
    GameTooltip:AddLine(L.DE_ROW_REMOVE, 0.1, 1, 0.1)
    GameTooltip:Show()
end

local function Row_OnClick(self, mouseButton)
    local item = self.item
    if not item then
        return
    end
    Play("IG_MAINMENU_OPTION_CHECKBOX_ON")
    if mouseButton == "RightButton" then
        DE:Forget(item.guid)
    else
        ns:ToggleExcluded(item.itemID)
    end
    if GameTooltip:IsOwned(self) then
        Row_OnEnter(self)
    end
end

local function CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(LIST_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    -- Marks the item the Disenchant button will use next.
    local selected = row:CreateTexture(nil, "BACKGROUND")
    selected:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    selected:SetBlendMode("ADD")
    selected:SetVertexColor(1, 0.82, 0, 0.6)
    selected:SetAllPoints()
    selected:Hide()
    row.selected = selected

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 4, 0)
    row.icon = icon

    local mark = row:CreateTexture(nil, "OVERLAY")
    mark:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
    mark:SetSize(12, 12)
    mark:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 3, -2)
    mark:Hide()
    row.mark = mark

    local level = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    level:SetPoint("RIGHT", -6, 0)
    level:SetJustifyH("RIGHT")
    row.level = level

    local name = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    name:SetPoint("RIGHT", level, "LEFT", -8, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    row.name = name

    row:SetScript("OnClick", Row_OnClick)
    row:SetScript("OnEnter", Row_OnEnter)
    row:SetScript("OnLeave", HideTooltip)
    return row
end

local function SetRow(row, item, isNext)
    local dimmed = not item.ready
    row.item = item
    row.icon:SetTexture(item.icon)
    row.icon:SetDesaturated(dimmed)
    row.mark:SetShown(dimmed)
    row.name:SetText(ns.ColorByQuality(item.name or "", item.quality))
    row.name:SetAlpha(dimmed and 0.5 or 1)
    row.level:SetText(ItemLevel(item) or "")
    row.level:SetAlpha(dimmed and 0.5 or 1)
    row.selected:SetShown(isNext)
    row:Show()
    if GameTooltip:IsOwned(row) then
        Row_OnEnter(row)
    end
end

-------------------------------------------------------------------------------
-- The Disenchant button (a secure button: only it may cast Disenchant)
-------------------------------------------------------------------------------

local lastHint = 0

local function Button_PreClick(self, _, down)
    -- The button acts when it's released (mouse or key), so only check then.
    if down or InCombatLockdown() then
        return
    end
    local target = self.target
    local valid = target and frame:IsShown() and not DE.casting
        and DE.GetBagItemGUID(target.bag, target.slot) == target.guid
    if not valid then
        -- The bags changed since the button was set up: do nothing this
        -- time and point it at the right item again.
        self:SetAttribute("type", nil)
        if not frame:IsShown() and GetTime() - lastHint > 1 then
            lastHint = GetTime()
            ns.Print(L.DE_OPEN_FIRST)
        end
        C_Timer.After(0, function()
            Frame:Refresh()
        end)
        return
    end
    DE:BeginCast(target)
end

local function Button_PostClick()
    -- If the spell is still waiting for an item to target, cancel it.
    if SpellIsTargeting and SpellIsTargeting() then
        SpellStopTargeting()
    end
end

-- Points the button at an item (or nothing). Only outside combat.
function Frame:SetTarget(item)
    if not button then
        return
    end
    if item then
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", DE:GetSpellName())
        button:SetAttribute("target-bag", item.bag)
        button:SetAttribute("target-slot", item.slot)
        button.target = item
        button:Enable()
    else
        button:SetAttribute("type", nil)
        button.target = nil
        button:Disable()
    end
end

-------------------------------------------------------------------------------
-- Building the window
-------------------------------------------------------------------------------

function Frame:Create()
    if frame then
        return
    end

    frame = CreateFrame("Frame", "DEMailerDisenchantFrame", UIParent, "ButtonFrameTemplate")
    frame:SetSize(WIDTH, HEIGHT)
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
        SavePosition()
    end)
    frame:SetPortraitToAsset(PLACEHOLDER_ICON)
    frame:SetTitle(L.DE_TITLE)
    ButtonFrameTemplate_ShowButtonBar(frame)
    if frame.CloseButton then
        frame.CloseButton:SetScript("OnClick", function()
            frame:Hide()
        end)
    end
    frame:Hide()
    RestorePosition()
    -- Escape closes it, like the game's own windows.
    table.insert(UISpecialFrames, frame:GetName())

    -- Next item
    local nextButton = CreateFrame("ItemButton", "DEMailerDENextItem", frame)
    nextButton:SetPoint("TOPLEFT", 14, -68)
    nextButton:SetScript("OnEnter", function(self)
        if self.item then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetBagItem(self.item.bag, self.item.slot)
            GameTooltip:Show()
        end
    end)
    nextButton:SetScript("OnLeave", HideTooltip)
    self.nextButton = nextButton

    local nextName = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    nextName:SetPoint("TOPLEFT", nextButton, "TOPRIGHT", 10, -2)
    nextName:SetPoint("RIGHT", -16, 0)
    nextName:SetJustifyH("LEFT")
    nextName:SetWordWrap(false)
    self.nextName = nextName

    local nextInfo = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    nextInfo:SetPoint("TOPLEFT", nextName, "BOTTOMLEFT", 0, -5)
    nextInfo:SetPoint("RIGHT", -16, 0)
    nextInfo:SetJustifyH("LEFT")
    self.nextInfo = nextInfo

    -- Possible materials for the next item
    local possibleLabel = CreateFrame("Frame", nil, frame)
    possibleLabel:SetPoint("TOPLEFT", 16, -114)
    possibleLabel:SetSize(200, 14)
    local possibleText = possibleLabel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    possibleText:SetPoint("LEFT")
    possibleText:SetText(L.DE_POSSIBLE)
    possibleLabel:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.DE_POSSIBLE, 1, 1, 1)
        GameTooltip:AddLine(L.DE_POSSIBLE_TIP, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    possibleLabel:SetScript("OnLeave", HideTooltip)
    self.possibleLabel = possibleLabel

    self.possibleLines = {}
    for i = 1, POSSIBLE_LINES do
        local line = CreateFrame("Frame", nil, frame)
        line:SetSize(WIDTH - 44, 16)
        line:SetPoint("TOPLEFT", 22, -114 - i * 16)
        local chance = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        chance:SetPoint("LEFT")
        chance:SetWidth(40)
        chance:SetJustifyH("RIGHT")
        line.chance = chance
        local text = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        text:SetPoint("LEFT", chance, "RIGHT", 8, 0)
        text:SetPoint("RIGHT")
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)
        line.text = text
        line:SetScript("OnEnter", function(self)
            if self.itemID then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(self.itemID)
                GameTooltip:AddLine(L.DE_CHANCE_TIP:format(self.chanceText), 1, 0.82, 0, true)
                GameTooltip:Show()
            end
        end)
        line:SetScript("OnLeave", HideTooltip)
        line:Hide()
        self.possibleLines[i] = line
    end

    -- This session
    local sessionLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    sessionLabel:SetPoint("TOPLEFT", 16, -184)
    sessionLabel:SetText(L.DE_SESSION)

    local sessionCount = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sessionCount:SetPoint("TOPRIGHT", -16, -184)
    self.sessionCount = sessionCount

    self.materialButtons = {}
    for i = 1, MATERIAL_SLOTS do
        local material = CreateFrame("ItemButton", "DEMailerDEMaterial" .. i, frame)
        material:SetPoint("TOPLEFT", 14 + (i - 1) * 41, -200)
        material:SetScript("OnEnter", function(self)
            if self.link then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.link)
                GameTooltip:Show()
            end
        end)
        material:SetScript("OnLeave", HideTooltip)
        material:Hide()
        self.materialButtons[i] = material
    end

    local sessionEmpty = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    sessionEmpty:SetPoint("TOPLEFT", 16, -212)
    sessionEmpty:SetText(L.DE_SESSION_EMPTY)
    self.sessionEmpty = sessionEmpty

    -- The list
    local listHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    listHeader:SetPoint("TOPLEFT", 16, -250)
    self.listHeader = listHeader

    local addButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    addButton:SetSize(130, 20)
    addButton:SetPoint("TOPRIGHT", -12, -246)
    addButton:SetScript("OnClick", function()
        Play("IG_MAINMENU_OPTION_CHECKBOX_ON")
        DE:AddFromBags()
    end)
    addButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self:GetText(), 1, 1, 1)
        GameTooltip:AddLine(L.DE_ADD_FROM_BAGS_TIP, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    addButton:SetScript("OnLeave", HideTooltip)
    self.addButton = addButton

    local scroll = CreateFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -270)
    scroll:SetPoint("BOTTOMRIGHT", -30, 32)
    local list = CreateFrame("Frame", nil, scroll)
    list:SetSize(LIST_WIDTH, 1)
    scroll:SetScrollChild(list)
    self.list = list

    local listEmpty = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    listEmpty:SetPoint("TOP", scroll, "TOP", 0, -40)
    listEmpty:SetWidth(LIST_WIDTH - 20)
    self.listEmpty = listEmpty

    -- Status line and the Disenchant button
    button = CreateFrame("Button", "DEMailerDisenchantButton", frame, "UIPanelButtonTemplate, SecureActionButtonTemplate")
    button:SetSize(120, 22)
    button:SetPoint("BOTTOMRIGHT", -6, 4)
    button:SetText(L.DE_BUTTON)
    -- Act on release, for mouse clicks and key bindings alike, whatever the
    -- "cast on key down" setting says. That way each press checks once.
    button:SetAttribute("useOnKeyDown", false)
    button:RegisterForClicks("AnyUp")
    button:SetScript("PreClick", Button_PreClick)
    button:SetScript("PostClick", Button_PostClick)
    button:Disable()

    local status = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("BOTTOMLEFT", 12, 9)
    status:SetPoint("RIGHT", button, "LEFT", -8, 0)
    status:SetJustifyH("LEFT")
    status:SetWordWrap(false)
    self.statusText = status

    -- Hover the status line to read all of it when it's cut off.
    local statusHover = CreateFrame("Frame", nil, frame)
    statusHover:SetAllPoints(status)
    statusHover:SetScript("OnEnter", function(self)
        if status:IsTruncated() then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(status:GetText(), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    statusHover:SetScript("OnLeave", HideTooltip)

    frame:SetScript("OnShow", function()
        Play("IG_CHARACTER_INFO_OPEN")
        Frame:Refresh()
    end)
    frame:SetScript("OnHide", function()
        Play("IG_CHARACTER_INFO_CLOSE")
        if not InCombatLockdown() then
            Frame:SetTarget(nil)
        end
    end)
end

-------------------------------------------------------------------------------
-- Opening, closing and combat
-------------------------------------------------------------------------------

function Frame:IsOpen()
    return frame ~= nil and frame:IsShown()
end

function Frame:Open()
    self:Create()
    frame:Show()
end

function Frame:Close()
    if frame then
        frame:Hide()
    end
end

-- Nothing on the window may change during combat, so it closes while you
-- fight and comes back afterwards.
function Frame:OnCombatStart()
    if frame and frame:IsShown() then
        self.reopenAfterCombat = true
        self:SetTarget(nil)
        frame:Hide()
    end
end

function Frame:OnCombatEnd()
    if self.reopenAfterCombat then
        self.reopenAfterCombat = nil
        if DE:IsEnabled() then
            frame:Show()
        end
    end
end

-------------------------------------------------------------------------------
-- Refreshing
-------------------------------------------------------------------------------

function Frame:Refresh()
    if not frame or not frame:IsShown() then
        return
    end
    local active = DE:IsActive()
    local nextItem, items, readyCount = DE:GetNext()

    -- Next item
    local nextButton = self.nextButton
    nextButton.item = nextItem
    if nextItem then
        SetItemButtonTexture(nextButton, nextItem.icon)
        SetItemButtonQuality(nextButton, nextItem.quality, nextItem.link)
        SetItemButtonDesaturated(nextButton, false)
        self.nextName:SetText(ns.ColorByQuality(nextItem.name or "", nextItem.quality))
        self.nextInfo:SetText(ItemInfoLine(nextItem))
    else
        SetItemButtonTexture(nextButton, PLACEHOLDER_ICON)
        SetItemButtonQuality(nextButton, nil)
        SetItemButtonDesaturated(nextButton, true)
        self.nextName:SetText(L.DE_NEXT_NONE)
        self.nextInfo:SetText(active and L.DE_NEXT_NONE_SUB or "")
    end

    -- Possible materials
    local possible = nextItem and ns.PossibleMaterials(nextItem.itemID, nextItem.quality, ItemLevel(nextItem))
    self.possibleLabel:SetShown(possible ~= nil)
    for i, line in ipairs(self.possibleLines) do
        local entry = possible and possible[i]
        if entry then
            local name, icon, quality = ns.MaterialInfo(entry.itemID)
            local label = ns.ColorByQuality(name, quality)
            local count = FormatCount(entry.min, entry.max)
            if count then
                label = L.DE_COUNT:format(label, count)
            end
            if icon then
                label = ("|T%s:0|t %s"):format(icon, label)
            end
            line.itemID = entry.itemID
            line.chanceText = FormatChance(entry.chance)
            line.chance:SetText(line.chanceText)
            line.text:SetText(label)
            line:Show()
        else
            line.itemID = nil
            line:Hide()
        end
        if GameTooltip:IsOwned(line) then
            HideTooltip()
        end
    end

    -- This session
    local session = DE.session
    for i, material in ipairs(self.materialButtons) do
        local key = session.order[i]
        local entry = key and session.materials[key]
        if entry then
            material.link = entry.link
            SetItemButtonTexture(material, entry.icon)
            SetItemButtonQuality(material, entry.quality, entry.link)
            SetItemButtonCount(material, entry.count)
            material:Show()
        else
            material.link = nil
            material:Hide()
        end
    end
    self.sessionEmpty:SetShown(#session.order == 0)
    self.sessionCount:SetText(session.count > 0 and L.DE_SESSION_COUNT:format(session.count) or "")

    -- The list
    self.listHeader:SetText(readyCount > 0 and L.DE_LIST_COUNT:format(readyCount) or L.DE_LIST)
    local unrecorded = DE:CountUnrecorded()
    self.addButton:SetText(L.DE_ADD_FROM_BAGS:format(unrecorded))
    self.addButton:SetShown(unrecorded > 0)
    for i, item in ipairs(items) do
        rows[i] = rows[i] or CreateRow(self.list, i)
        SetRow(rows[i], item, item == nextItem)
    end
    for i = #items + 1, #rows do
        rows[i].item = nil
        rows[i]:Hide()
    end
    self.list:SetHeight(math.max(1, #items * ROW_HEIGHT))
    if not DE:IsEnabled() then
        self.listEmpty:SetText(L.DE_OFF)
    elseif not DE:CanDisenchant() then
        self.listEmpty:SetText(L.DE_CANT)
    else
        self.listEmpty:SetText(L.DE_NEXT_NONE_SUB)
    end
    self.listEmpty:SetShown(#items == 0)

    -- Status
    local text, kind
    if not active then
        text = DE:IsEnabled() and L.DE_CANT or L.DE_OFF
    elseif DE.casting and DE.pending then
        text = L.DE_STATUS_CASTING:format(DE.ItemText(DE.pending))
    elseif DE.status then
        text, kind = DE.status, DE.statusKind
    elseif nextItem then
        text = L.DE_STATUS_READY:format(DE.ItemText(nextItem))
    elseif session.count > 0 then
        text, kind = L.DE_STATUS_DONE, "good"
    else
        text = L.DE_STATUS_EMPTY
    end
    if kind == "bad" and RED_FONT_COLOR then
        text = RED_FONT_COLOR:WrapTextInColorCode(text)
    elseif kind == "good" and GREEN_FONT_COLOR then
        text = GREEN_FONT_COLOR:WrapTextInColorCode(text)
    end
    self.statusText:SetText(text)

    -- Point the Disenchant button at the next item.
    if not InCombatLockdown() then
        self:SetTarget((active and not DE.casting) and nextItem or nil)
    end
end
