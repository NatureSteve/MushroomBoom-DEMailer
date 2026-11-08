-- DE Mailer: Core.lua
-- Finds disenchantable gear in your bags and mails it to your enchanter.
-- This file holds the settings, the bag scan and the sending logic.
-- UI.lua draws the "Disenchant" tab on the mailbox.

local ADDON_NAME, ns = ...

-------------------------------------------------------------------------------
-- Text
-------------------------------------------------------------------------------

local L = {}
ns.L = L

L.TITLE             = "DE Mailer"
L.TAB               = "Disenchant"
L.SEND_TO           = "Send to:"
L.RECIPIENT_TITLE   = "Your enchanter"
L.RECIPIENT_TIP     = "The character who disenchants for you. Remembered separately for each realm and faction."
L.INCLUDE           = "Include:"
L.IN_YOUR_BAGS      = "In your bags"
L.COUNT_SUMMARY     = "%d |4item:items;, %d |4letter:letters;"
L.MORE              = "+%d more"
L.EMPTY             = "No disenchantable gear in your bags."
L.ITEM_TIP_SEND     = "<Click to keep this item>"
L.ITEM_TIP_EXCLUDED = "This item stays with you."
L.ITEM_TIP_INCLUDE  = "<Click to send it again>"
L.AUTO_SEND         = "Send automatically when I open a mailbox"
L.AUTO_SEND_TIP     = "Hold Shift while you open the mailbox to skip it once."
L.SEND              = "Send"
L.STOP              = "Stop"
L.SEND_NEXT         = "Send Next Letter"
L.SUBJECT           = "Gear to disenchant"

L.NEED_MAILBOX      = "Open a mailbox to send."
L.TRIAL             = "Trial accounts can't send mail."
L.NEED_RECIPIENT    = "Type your enchanter's name above."
L.IS_SELF           = "This character is your enchanter. Nothing to send!"
L.NOTHING           = "No disenchantable gear in your bags."
L.HAS_ATTACHMENTS   = "Your unsent letter already has items attached. Send it or take them off on the Send Mail tab first."
L.HAS_MONEY         = "Your unsent letter has money or C.O.D. set. Close and reopen the mailbox, then try again."
L.CURSOR            = "Put down the item on your cursor first."
L.READY             = "Ready to send %d |4item:items; to %s."
L.SENDING           = "Sending letter %d of %d to %s..."
L.WAITING           = "Waiting for the mailbox..."
L.PAUSED            = "Letter %d sent. The game wants a click for each letter: press Send Next Letter."
L.DONE              = "Sent %d |4item:items; to %s in %d |4letter:letters;."
L.STOPPED           = "Stopped. Sent %d |4item:items; to %s."
L.FAILED            = "The letter could not be sent: %s"
L.UNKNOWN_ERROR     = "the mailbox refused it."
L.NOTHING_ATTACHED  = "no items could be attached."
L.TIMEOUT           = "The mailbox didn't answer. Your items are back in your bags. Try again in a moment."
L.FORBIDDEN         = "The game blocked DE Mailer from sending mail."
L.REFUND            = "An item asked for a refund confirmation. Answer the popup, then press Send again."
L.SKIPPED           = "Some items couldn't be mailed and were skipped."
L.SKIPPED_ALL       = "The mailbox wouldn't take any of these items, so nothing was sent."
L.AUTO_NEEDS_CLICK  = "%d |4item:items; ready for your enchanter. Open the Disenchant tab and press Send."

-- Options panel, minimap button and name box
L.ENCHANTER         = "Enchanter"
L.NOT_SET           = "Not set"
L.SET_NAME          = "Set Name"
L.ITEMS_TO_SEND     = "Items to Send"
L.QUALITY_TIP       = "Send unbound %s weapons and armor."
L.MAILBOX           = "Mailbox"
L.AUTO_SEND_SHORT   = "Send Automatically"
L.AUTO_SEND_LONG    = "Send as soon as you open a mailbox. Hold Shift while opening it to skip once."
L.KEPT_ITEMS        = "Items You Keep"
L.KEPT_ITEMS_TIP    = "Items you clicked on the Disenchant tab stay in your bags. Reset to send them again."
L.KEPT_NONE         = "None"
L.KEPT_RESET        = "Reset (%d)"
L.MINIMAP           = "Minimap"
L.SHOW_MINIMAP      = "Show Minimap Button"
L.SHOW_MINIMAP_TIP  = "DE Mailer is always in the minimap's AddOns menu too."
L.NAME_PROMPT       = "Who disenchants for you?"
L.NAME_REALM        = "Remembered for %s (%s)."
L.OPEN_OPTIONS      = "Open Options"
L.HIDE_BUTTON       = "Hide Minimap Button"
L.TIP_ENCHANTER     = "Enchanter: %s"
L.TIP_SENDS         = "Sends: %s"
L.TIP_AUTO          = "Automatic: %s"
L.ON                = "On"
L.OFF               = "Off"
L.NOTHING_SELECTED  = "nothing"
L.TIP_LEFT          = "Left-click: Options"
L.TIP_RIGHT         = "Right-click: Quick settings"
L.TIP_DRAG          = "Drag: Move this button"
L.NO_OPTIONS_COMBAT = "Options can't be opened during combat."

-- Disenchanting window
L.DE_TITLE              = "Disenchanting"
L.DE_NEXT_NONE          = "Nothing to disenchant"
L.DE_NEXT_NONE_SUB      = "Gear you pick up shows up below."
L.DE_ITEM_LEVEL         = "Item Level %d"
L.DE_SESSION            = "This session"
L.DE_SESSION_COUNT      = "%d disenchanted"
L.DE_SESSION_EMPTY      = "The materials you get will show up here."
L.DE_LIST               = "To disenchant"
L.DE_LIST_COUNT         = "To disenchant (%d)"
L.DE_ADD_FROM_BAGS      = "Add from Bags (%d)"
L.DE_ADD_FROM_BAGS_TIP  = "Add disenchantable gear that was already in your bags before DE Mailer started recording."
L.DE_BUTTON             = "Disenchant"
L.DE_ROW_KEEP           = "<Click to keep this item>"
L.DE_ROW_KEPT           = "This item stays with you."
L.DE_ROW_UNKEEP         = "<Click to disenchant it after all>"
L.DE_ROW_REMOVE         = "<Right-click to take it off the list>"
L.DE_ROW_SKIPPED        = "Couldn't be disenchanted: %s"
L.DE_STATUS_READY       = "Next: %s"
L.DE_STATUS_CASTING     = "Disenchanting %s..."
L.DE_STATUS_GOT         = "Got %s."
L.DE_STATUS_FAILED      = "Couldn't disenchant %s: %s"
L.DE_STATUS_SKIPPED     = "Skipped %s: %s"
L.DE_STATUS_INTERRUPTED = "Interrupted. Try again."
L.DE_STATUS_DONE        = "All done!"
L.DE_STATUS_EMPTY       = "Nothing to disenchant yet."
L.DE_STATUS_COMBAT      = "Not available during combat."
L.DE_CANT               = "This character doesn't know Disenchant."
L.DE_OFF                = "Disenchanting is turned off in DE Mailer's options."
L.DE_NO_COMBAT_OPEN     = "The Disenchanting window can't open during combat."
L.DE_OPEN_FIRST         = "Open the Disenchanting window first."
L.DE_UNKNOWN_REASON     = "the game didn't allow it"
L.DE_AND                = "and"
L.DE_POSSIBLE           = "Possible materials"
L.DE_POSSIBLE_TIP       = "What disenchanting this item usually gives on WoW Forever. Each disenchant varies."
L.DE_CHANCE_TIP         = "About %s of disenchants give this."
L.DE_COUNT              = "%s (%s)"

-- Disenchanting options
L.DISENCHANTING         = "Disenchanting"
L.DE_ENABLE             = "Disenchanting Window"
L.DE_ENABLE_TIP         = "Record disenchantable gear as you pick it up (loot, mail or trades) on characters that know Disenchant, and disenchant it from its own window. Open the window with Shift-click on the minimap button, /dem de, or a key set in Keybindings > AddOns."
L.DE_AUTO_OPEN          = "Open When You Pick Up Gear"
L.DE_AUTO_OPEN_TIP      = "Open the Disenchanting window when you pick up something to disenchant. Never during combat."
L.DE_OPEN               = "Open"
L.DE_OPEN_TIP           = "Open the Disenchanting window."
L.DE_OPEN_WINDOW        = "Open Disenchanting"
L.TIP_SHIFT             = "Shift-click: Disenchanting window"
L.QUALITIES_HEADER      = "Item Qualities"
L.QUALITY_TIP_BOTH      = "Mail and disenchant %s weapons and armor."

-- Key bindings (Esc > Options > Keybindings > AddOns)
BINDING_HEADER_DEMAILER = "DE Mailer"
BINDING_NAME_DEMAILER_TOGGLE = "Toggle Disenchanting window"
_G["BINDING_NAME_CLICK DEMailerDisenchantButton:LeftButton"] = "Disenchant next item"

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local function EnumValue(enumName, key, fallback)
    local enum = Enum and Enum[enumName]
    local value = enum and enum[key]
    if value == nil then
        return fallback
    end
    return value
end

local CLASS_WEAPON        = EnumValue("ItemClass", "Weapon", 2)
local CLASS_ARMOR         = EnumValue("ItemClass", "Armor", 4)
local ARMOR_COSMETIC      = EnumValue("ItemArmorSubclass", "Cosmetic", 5)
local WEAPON_FISHING_POLE = EnumValue("ItemWeaponSubclass", "Fishingpole", 20)
local FIRST_BAG           = EnumValue("BagIndex", "Backpack", 0)
local LAST_BAG            = FIRST_BAG + (NUM_BAG_SLOTS or 4)
local MAX_ATTACHMENTS     = ATTACHMENTS_MAX_SEND or 12

ns.MAX_ATTACHMENTS = MAX_ATTACHMENTS
ns.FIRST_BAG, ns.LAST_BAG = FIRST_BAG, LAST_BAG
ns.QUALITIES = {
    EnumValue("ItemQuality", "Uncommon", 2),
    EnumValue("ItemQuality", "Rare", 3),
    EnumValue("ItemQuality", "Epic", 4),
}

-- Equipment slots that are never disenchantable (shirts, tabards, bags...).
local SKIP_EQUIP_LOC = {
    [""]                       = true,
    INVTYPE_NON_EQUIP_IGNORE   = true,
    INVTYPE_BODY               = true,
    INVTYPE_TABARD             = true,
    INVTYPE_BAG                = true,
    INVTYPE_QUIVER             = true,
    INVTYPE_AMMO               = true,
    INVTYPE_PROFESSION_TOOL    = true,
    INVTYPE_PROFESSION_GEAR    = true,
}

local AUTO_SEND_DELAY = 0.75 -- seconds after the mailbox opens
local LETTER_DELAY    = 1.0  -- pause between letters so the bags can update
local SEND_TIMEOUT    = 15   -- give up waiting for the mailbox after this long

local DEFAULTS = {
    recipients = {}, -- ["Realm-Faction"] = "Name"
    qualities  = { [2] = true, [3] = true, [4] = false },
    autoSend   = false,
    excluded   = {}, -- [itemID] = true for items you never want mailed
    minimap    = { hide = false, angle = 225 }, -- angle in degrees around the minimap
    disenchant = { enabled = true, autoOpen = false }, -- the Disenchanting window
}
ns.DEFAULTS = DEFAULTS

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local function Print(msg)
    if msg and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffc28cffDE Mailer|r: " .. msg)
    end
end
ns.Print = Print

local function Trim(text)
    return (tostring(text or ""):match("^%s*(.-)%s*$"))
end

local function CopyDefaults(src, dst)
    for key, value in pairs(src) do
        if type(value) == "table" then
            if type(dst[key]) ~= "table" then
                dst[key] = {}
            end
            CopyDefaults(value, dst[key])
        elseif dst[key] == nil then
            dst[key] = value
        end
    end
end

local function RealmKey()
    local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName() or "?"
    local faction = UnitFactionGroup("player") or "Neutral"
    return realm .. "-" .. faction
end

local function CountAttachments()
    local count = 0
    for i = 1, MAX_ATTACHMENTS do
        if HasSendMailItem(i) then
            count = count + 1
        end
    end
    return count
end

local function FirstFreeAttachmentSlot()
    for i = 1, MAX_ATTACHMENTS do
        if not HasSendMailItem(i) then
            return i
        end
    end
end

local function HasPendingMoney()
    local money = GetSendMailMoney and GetSendMailMoney() or 0
    local cod = GetSendMailCOD and GetSendMailCOD() or 0
    return (money or 0) > 0 or (cod or 0) > 0
end

local function IsRefundable(bag, slot)
    if not C_Container.GetContainerItemPurchaseInfo then
        return false
    end
    local ok, info = pcall(C_Container.GetContainerItemPurchaseInfo, bag, slot, false)
    return ok and type(info) == "table" and (info.refundSeconds or 0) > 0
end

local function GetQuality(info)
    if info.quality then
        return info.quality
    end
    if C_Item.GetItemQualityByID then
        return C_Item.GetItemQualityByID(info.itemID)
    end
end

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------

ns.unmailable = {} -- itemIDs the mailbox refused this session

function ns:GetRecipient()
    return (self.db and self.db.recipients[RealmKey()]) or ""
end

function ns:SetRecipient(name)
    name = Trim(name)
    if name == self:GetRecipient() then
        return
    end
    self.db.recipients[RealmKey()] = (name ~= "") and name or nil
    self:SetMessage(nil)
    self:OnSettingsChanged()
end

function ns:GetRealmAndFaction()
    local realm = GetRealmName() or "?"
    local faction = UnitFactionGroup("player")
    local factionName = faction and (_G["FACTION_" .. faction:upper()] or faction) or "?"
    return realm, factionName
end

function ns:IsSelf(name)
    local who, realm = strsplit("-", name, 2)
    local me = UnitName("player")
    if not who or not me or who:lower() ~= me:lower() then
        return false
    end
    if realm and realm ~= "" then
        local myRealm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName() or "")
        return (realm:gsub("[%s%-']", "")):lower() == (myRealm:gsub("[%s%-']", "")):lower()
    end
    return true
end

function ns:SetQualityEnabled(quality, enabled)
    self.db.qualities[quality] = enabled and true or false
    self:SetMessage(nil)
    self:OnSettingsChanged()
end

function ns:SetAutoSend(enabled)
    self.db.autoSend = enabled and true or false
    self:OnSettingsChanged()
end

function ns:SetDisenchantEnabled(enabled)
    self.db.disenchant.enabled = enabled and true or false
    self:OnSettingsChanged()
end

function ns:SetDisenchantAutoOpen(enabled)
    self.db.disenchant.autoOpen = enabled and true or false
    self:OnSettingsChanged()
end

function ns:SetMinimapShown(shown)
    self.db.minimap.hide = not shown
    self:OnSettingsChanged()
end

function ns:CountExcluded()
    local count = 0
    for _ in pairs(self.db.excluded) do
        count = count + 1
    end
    return count
end

function ns:ResetExcluded()
    wipe(self.db.excluded)
    self:SetMessage(nil)
    self:OnSettingsChanged()
end

function ns:ToggleExcluded(itemID)
    if not itemID then
        return
    end
    if self.db.excluded[itemID] then
        self.db.excluded[itemID] = nil
    else
        self.db.excluded[itemID] = true
    end
    self:SetMessage(nil)
    self:OnSettingsChanged()
end

-- A status message for the Disenchant tab. Sticky messages (results of a
-- send) stay until you change something; others clear when your bags do.
function ns:SetMessage(text, kind, sticky)
    self.message = text
    self.messageKind = kind
    self.messageSticky = sticky and true or false
end

function ns:Notify()
    if self.UI and self.UI.Refresh then
        self.UI:Refresh()
    end
end

-- A setting changed somewhere (mailbox tab, Options panel, minimap menu or
-- slash command): bring every place that shows it up to date.
function ns:OnSettingsChanged()
    self:Notify()
    if self.Options and self.Options.Refresh then
        self.Options:Refresh()
    end
    if self.Minimap and self.Minimap.Update then
        self.Minimap:Update()
    end
    if self.DE and self.DE.OnSettingsChanged then
        self.DE:OnSettingsChanged()
    end
end

-------------------------------------------------------------------------------
-- Finding disenchantable gear
-------------------------------------------------------------------------------

-- Weapons and armor of the chosen qualities that aren't bound, so they can
-- be mailed. Cosmetic items, shirts, tabards and fishing poles can't be
-- disenchanted and are left alone.
function ns:IsCandidate(bag, slot, info)
    if info.isBound or self.unmailable[info.itemID] then
        return false
    end
    if not self:IsQualityEnabled(info) or not self:IsDisenchantableItem(info) then
        return false
    end
    if IsRefundable(bag, slot) then
        return false
    end
    return true
end

-- Uncommon, Rare or Epic quality, whatever the settings say.
local DISENCHANT_QUALITIES = {}
for _, quality in ipairs(ns.QUALITIES) do
    DISENCHANT_QUALITIES[quality] = true
end

function ns:IsQualityEnabled(info)
    local quality = GetQuality(info)
    return (quality and self.db.qualities[quality]) and true or false
end

ns.GetQuality = GetQuality
ns.IsRefundable = IsRefundable

-- Gear that can be disenchanted at all: Uncommon to Epic weapons and armor,
-- but not cosmetic items, shirts, tabards or fishing poles. Binding and
-- your quality settings are checked by the caller.
function ns:IsDisenchantableItem(info)
    local quality = GetQuality(info)
    if not quality or not DISENCHANT_QUALITIES[quality] then
        return false
    end
    local _, _, _, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(info.itemID)
    if classID ~= CLASS_WEAPON and classID ~= CLASS_ARMOR then
        return false
    end
    if not equipLoc or SKIP_EQUIP_LOC[equipLoc] then
        return false
    end
    if classID == CLASS_ARMOR and subClassID == ARMOR_COSMETIC then
        return false
    end
    if classID == CLASS_WEAPON and subClassID == WEAPON_FISHING_POLE then
        return false
    end
    if C_Item.IsCosmeticItem and info.hyperlink and C_Item.IsCosmeticItem(info.hyperlink) then
        return false
    end
    return true
end

-- Returns every candidate in bag order (excluded ones flagged), plus how
-- many of them will actually be sent.
function ns:ScanBags()
    local items, sendable = {}, 0
    if not self.db then
        return items, 0
    end
    for bag = FIRST_BAG, LAST_BAG do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and not info.isLocked and self:IsCandidate(bag, slot, info) then
                local excluded = self.db.excluded[info.itemID] and true or false
                items[#items + 1] = {
                    bag = bag,
                    slot = slot,
                    itemID = info.itemID,
                    link = info.hyperlink,
                    icon = info.iconFileID,
                    quality = GetQuality(info),
                    excluded = excluded,
                }
                if not excluded then
                    sendable = sendable + 1
                end
            end
        end
    end
    return items, sendable
end

function ns:CountSendable()
    local _, sendable = self:ScanBags()
    return sendable
end

-------------------------------------------------------------------------------
-- Sending
-------------------------------------------------------------------------------

function ns:IsMailOpen()
    return self.mailOpen and MailFrame and MailFrame:IsShown() and true or false
end

-- Returns true plus the number of items to send, or false plus the reason.
function ns:CanStart()
    if not self:IsMailOpen() then
        return false, L.NEED_MAILBOX
    end
    if GameLimitedMode_IsActive and GameLimitedMode_IsActive() then
        return false, L.TRIAL
    end
    local recipient = self:GetRecipient()
    if recipient == "" then
        return false, L.NEED_RECIPIENT
    end
    if self:IsSelf(recipient) then
        return false, L.IS_SELF
    end
    local sendable = self:CountSendable()
    if sendable == 0 then
        return false, L.NOTHING
    end
    if CountAttachments() > 0 then
        return false, L.HAS_ATTACHMENTS
    end
    if HasPendingMoney() then
        return false, L.HAS_MONEY
    end
    return true, sendable
end

-- trigger is "click", "slash" or "auto". fromClick says whether we are
-- running inside a mouse click or key press, which some game actions need.
function ns:Start(trigger, fromClick)
    local run = self.run
    if run then
        if run.state == "paused" then
            self:SendNextLetter(fromClick)
            return true
        end
        return false
    end

    local ok, result = self:CanStart()
    if not ok then
        return false, result
    end
    if CursorHasItem() then
        self:SetMessage(L.CURSOR, "bad")
        self:Notify()
        return false, L.CURSOR
    end

    self:SetMessage(nil)
    self.run = {
        trigger = trigger,
        recipient = self:GetRecipient(),
        letters = 0,
        items = 0,
        attached = 0,
        token = 0,
        state = "starting",
    }
    self:SendNextLetter(fromClick)
    return true
end

function ns:Stop()
    local run = self.run
    if not run then
        return
    end
    if run.state == "sending" then
        -- The current letter is already on its way; stop after it.
        run.stopRequested = true
        self:Notify()
    else
        self:ReturnAttachments()
        self:Finish("stopped")
    end
end

function ns:SendNextLetter(fromClick)
    local run = self.run
    if not run then
        return
    end
    if not self:IsMailOpen() then
        return self:Finish("closed")
    end
    if run.stopRequested then
        return self:Finish("stopped")
    end

    -- Let an inbox action (like Open All) finish first.
    if C_Mail and C_Mail.IsCommandPending and C_Mail.IsCommandPending() then
        run.state = "waiting"
        self:Notify()
        C_Timer.After(0.5, function()
            if self.run == run and run.state == "waiting" then
                self:SendNextLetter(false)
            end
        end)
        return
    end

    -- Never touch a letter you started yourself on the Send Mail tab.
    if CountAttachments() > 0 then
        return self:Finish("attachments")
    end
    if CursorHasItem() then
        return self:Finish("cursor")
    end

    local items, sendable = self:ScanBags()
    if sendable == 0 then
        return self:Finish("done")
    end

    run.state = "attaching"
    SetSendMailShowing(true)

    -- Fill the letter, skipping anything the mailbox refuses.
    local attached = 0
    for _, item in ipairs(items) do
        local slotIndex = FirstFreeAttachmentSlot()
        if attached >= MAX_ATTACHMENTS or not slotIndex then
            break
        end
        if not item.excluded then
            C_Container.PickupContainerItem(item.bag, item.slot)
            if CursorHasItem() then
                ClickSendMailItemButton(slotIndex)
                if CursorHasItem() then
                    -- The mailbox wouldn't take it; put it back and skip it.
                    ClearCursor()
                    self.unmailable[item.itemID] = true
                    run.skipped = true
                else
                    attached = attached + 1
                end
            else
                self.unmailable[item.itemID] = true
                run.skipped = true
            end
        end
    end

    if attached == 0 then
        -- Everything left was refused (and is now skipped).
        return self:Finish("done")
    end

    if CountAttachments() >= attached then
        self:DoSend(fromClick)
    else
        -- Give the client a moment to register the attachments.
        local started = GetTime()
        local function check()
            if self.run ~= run or run.state ~= "attaching" then
                return
            end
            if CountAttachments() >= attached or GetTime() - started > 2 then
                self:DoSend(false)
            else
                C_Timer.After(0.1, check)
            end
        end
        C_Timer.After(0.1, check)
        self:Notify()
    end
end

function ns:DoSend(fromClick)
    local run = self.run
    if not run then
        return
    end
    local count = CountAttachments()
    if count == 0 then
        return self:Finish("failed", L.NOTHING_ATTACHED)
    end
    run.attached = count
    run.state = "sending"
    run.fromClick = fromClick and true or false
    run.lastError = nil
    run.token = run.token + 1
    local token = run.token
    self:Notify()

    SendMail(run.recipient, L.SUBJECT, "")

    C_Timer.After(SEND_TIMEOUT, function()
        if self.run == run and run.state == "sending" and run.token == token then
            self:OnSendTimeout()
        end
    end)
end

function ns:OnSendTimeout()
    local run = self.run
    if not run then
        return
    end
    self:ReturnAttachments()
    if not run.fromClick and not self.needsClick then
        -- Nothing happened without a click; assume the game wants one.
        self:PauseForClick()
    else
        self:Finish("timeout")
    end
end

-- Some game versions only allow one letter per mouse click. When that
-- happens we wait for the player to press the button for each letter.
function ns:PauseForClick(afterLetter)
    local run = self.run
    if not run then
        return
    end
    self.needsClick = true
    if afterLetter and self:CountSendable() == 0 then
        return self:Finish("done")
    end
    run.state = "paused"
    if run.trigger == "auto" and run.letters == 0 then
        Print(L.AUTO_NEEDS_CLICK:format(self:CountSendable()))
    end
    self:Notify()
end

function ns:ReturnAttachments()
    if not self:IsMailOpen() then
        return
    end
    for i = 1, MAX_ATTACHMENTS do
        if HasSendMailItem(i) then
            ClickSendMailItemButton(i, true)
        end
    end
end

function ns:Finish(result, detail)
    local run = self.run
    if not run then
        return
    end
    self.run = nil

    if self:IsMailOpen() and not (SendMailFrame and SendMailFrame:IsShown()) then
        SetSendMailShowing(false)
    end

    local who = run.recipient
    local msg, kind
    if result == "done" then
        if run.items > 0 then
            msg, kind = L.DONE:format(run.items, who, run.letters), "good"
        elseif run.skipped then
            msg, kind = L.SKIPPED_ALL, "bad"
        else
            msg, kind = L.NOTHING, nil
        end
    elseif result == "stopped" then
        msg, kind = L.STOPPED:format(run.items, who), nil
    elseif result == "failed" then
        msg, kind = L.FAILED:format(detail or L.UNKNOWN_ERROR), "bad"
    elseif result == "timeout" then
        msg, kind = L.TIMEOUT, "bad"
    elseif result == "forbidden" then
        msg, kind = L.FORBIDDEN, "bad"
    elseif result == "cursor" then
        msg, kind = L.CURSOR, "bad"
    elseif result == "refund" then
        msg, kind = L.REFUND, "bad"
    elseif result == "attachments" then
        msg, kind = L.HAS_ATTACHMENTS, "bad"
    end
    if run.skipped and result == "done" and run.items > 0 then
        msg = msg .. " " .. L.SKIPPED
    end

    if result == "closed" then
        if run.items > 0 then
            Print(L.STOPPED:format(run.items, who))
        end
        self:SetMessage(nil)
    else
        self:SetMessage(msg, kind, result ~= "cursor" and result ~= "attachments")
        -- Keep a record in chat of what went out, and of problems with
        -- automatic sends (the Disenchant tab may not be open).
        if msg and (run.items > 0 or (run.trigger == "auto" and kind == "bad")) then
            Print(msg)
        end
    end
    self:Notify()
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    local handler = ns[event]
    if handler then
        handler(ns, ...)
    end
end)
for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_LOGIN",
    "MAIL_SHOW", "MAIL_CLOSED", "MAIL_SEND_SUCCESS", "MAIL_FAILED", "MAIL_LOCK_SEND_ITEMS",
    "UI_ERROR_MESSAGE", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN",
    "BAG_UPDATE_DELAYED",
}) do
    events:RegisterEvent(event)
end

function ns:InitUI()
    if self.db and self.UI and not self.UI.created and MailFrame then
        self.UI:Create()
    end
end

function ns:InitExtras()
    if not self.db then
        return
    end
    if self.Options and not self.Options.created then
        self.Options:Create()
    end
    if self.Minimap and not self.Minimap.created then
        self.Minimap:Create()
    end
end

function ns:ADDON_LOADED(name)
    if name == ADDON_NAME then
        DEMailerDB = type(DEMailerDB) == "table" and DEMailerDB or {}
        CopyDefaults(DEFAULTS, DEMailerDB)
        self.db = DEMailerDB
        DEMailerCharDB = type(DEMailerCharDB) == "table" and DEMailerCharDB or {}
        DEMailerCharDB.recorded = type(DEMailerCharDB.recorded) == "table" and DEMailerCharDB.recorded or {}
        self.charDB = DEMailerCharDB
        self:InitUI()
        self:InitExtras()
    elseif name == "Blizzard_MailFrame" then
        self:InitUI()
    end
end

function ns:PLAYER_LOGIN()
    self:InitUI()
    self:InitExtras()
end

function ns:MAIL_SHOW()
    self.mailOpen = true
    self:SetMessage(nil)
    self:InitUI()
    if self.UI and self.UI.OnMailShow then
        self.UI:OnMailShow()
    end
    if self.db and self.db.autoSend and not IsShiftKeyDown() then
        C_Timer.After(AUTO_SEND_DELAY, function()
            self:TryAutoSend()
        end)
    end
    self:Notify()
end

function ns:TryAutoSend()
    if self.run or not self:IsMailOpen() then
        return
    end
    local ok, sendable = self:CanStart()
    if not ok then
        return
    end
    if self.needsClick then
        Print(L.AUTO_NEEDS_CLICK:format(sendable))
        return
    end
    self:Start("auto", false)
end

function ns:MAIL_CLOSED()
    self.mailOpen = false
    if self.run then
        self:Finish("closed")
    end
    self:SetMessage(nil)
end

function ns:MAIL_SEND_SUCCESS()
    local run = self.run
    if not run or run.state ~= "sending" then
        return
    end
    run.letters = run.letters + 1
    run.items = run.items + run.attached
    run.attached = 0
    self:ReleaseHiddenFocusSoon()

    if run.stopRequested then
        return self:Finish("stopped")
    end
    if self.needsClick then
        return self:PauseForClick(true)
    end
    run.state = "between"
    self:Notify()
    C_Timer.After(LETTER_DELAY, function()
        if self.run == run and run.state == "between" then
            self:SendNextLetter(false)
        end
    end)
end

function ns:MAIL_FAILED()
    local run = self.run
    if run and (run.state == "sending" or run.state == "attaching") then
        local reason = run.lastError
        self:ReturnAttachments()
        self:Finish("failed", reason)
    end
end

function ns:MAIL_LOCK_SEND_ITEMS()
    if self.run then
        self:Finish("refund")
    end
end

function ns:UI_ERROR_MESSAGE(_, message)
    local run = self.run
    if run and (run.state == "sending" or run.state == "attaching")
        and type(message) == "string" and not IsSecret(message) then
        run.lastError = message
    end
end

function ns:ADDON_ACTION_BLOCKED(addon)
    local run = self.run
    if addon ~= ADDON_NAME or not run then
        return
    end
    self:ReturnAttachments()
    if run.state == "sending" and not run.fromClick then
        self:PauseForClick()
    else
        self:Finish("forbidden")
    end
end

function ns:ADDON_ACTION_FORBIDDEN(addon)
    if addon == ADDON_NAME and self.run then
        self:ReturnAttachments()
        self:Finish("forbidden")
    end
end

function ns:BAG_UPDATE_DELAYED()
    if self.mailOpen then
        if self.message and not self.messageSticky then
            self:SetMessage(nil)
        end
        self:Notify()
    end
end

-- After a letter goes out, the game puts the keyboard cursor in the
-- Send Mail "To:" box. If that tab isn't showing, give the keyboard back.
function ns:ReleaseHiddenFocusSoon()
    C_Timer.After(0, function()
        local box = SendMailNameEditBox
        if box and box:HasFocus() and not box:IsVisible() then
            box:ClearFocus()
        end
    end)
end

-------------------------------------------------------------------------------
-- Slash command: /demailer (or /dem)
-------------------------------------------------------------------------------

local function PrintHelp()
    Print("commands:")
    Print("  /dem to <name> - set your enchanter for this realm")
    Print("  /dem send - send now (at a mailbox)")
    Print("  /dem auto - turn automatic sending on or off")
    Print("  /dem reset - send every item you chose to keep again")
    Print("  /dem options - open DE Mailer in the game's Options")
    Print("  /dem minimap - show or hide the minimap button")
    Print("  /dem de - open or close the Disenchanting window")
    local recipient = ns:GetRecipient()
    Print(("enchanter: %s, automatic sending: %s"):format(
        recipient ~= "" and recipient or "not set", ns.db.autoSend and "on" or "off"))
end

SLASH_DEMAILER1 = "/demailer"
SLASH_DEMAILER2 = "/dem"
SlashCmdList.DEMAILER = function(input)
    if not ns.db then
        return
    end
    local command, rest = Trim(input):match("^(%S*)%s*(.-)$")
    command = (command or ""):lower()
    if command == "to" then
        ns:SetRecipient(rest)
        local recipient = ns:GetRecipient()
        Print(recipient ~= "" and ("your enchanter is now " .. recipient .. ".") or "enchanter cleared.")
    elseif command == "send" then
        local ok, reason = ns:Start("slash", true)
        if not ok and reason then
            Print(reason)
        end
    elseif command == "auto" then
        local value = rest:lower()
        local enabled
        if value == "on" then
            enabled = true
        elseif value == "off" then
            enabled = false
        else
            enabled = not ns.db.autoSend
        end
        ns:SetAutoSend(enabled)
        Print("automatic sending is " .. (enabled and "on" or "off") .. ".")
    elseif command == "reset" then
        ns:ResetExcluded()
        Print("every item you chose to keep will be sent again.")
    elseif command == "options" or command == "config" then
        if ns.Options then
            ns.Options:Open()
        end
    elseif command == "de" or command == "disenchant" then
        if ns.DE then
            ns.DE:ToggleWindow()
        end
    elseif command == "minimap" then
        local shown = ns.db.minimap.hide
        ns:SetMinimapShown(shown)
        Print("minimap button " .. (shown and "shown" or "hidden") .. ".")
    else
        PrintHelp()
    end
end
