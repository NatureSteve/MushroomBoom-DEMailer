-- DE Mailer: Disenchant.lua
-- Records disenchantable gear as you pick it up (loot, mail, trades) and
-- works out what the Disenchanting window shows next. The window itself is
-- in DisenchantFrame.lua.

local ADDON_NAME, ns = ...
local L = ns.L

local DE = {}
ns.DE = DE

local DISENCHANT_SPELL_ID = 13262
local MAX_FAILURES = 2  -- after this many failed tries an item is skipped for the session
local LOOT_WINDOW = 3   -- seconds after a disenchant in which its loot counts as the result
local CAST_LOOT_WINDOW = 15 -- while casting, loot may show up before the cast reports success
local EQUIPPED_FIRST = INVSLOT_FIRST_EQUIPPED or 1
local EQUIPPED_LAST = INVSLOT_LAST_EQUIPPED or 19

-- Items taken out of these windows weren't "picked up", so they aren't recorded.
local PAUSING_WINDOWS = {}
for _, key in ipairs({ "Banker", "GuildBanker", "VoidStorageBanker", "AccountBanker", "CharacterBanker" }) do
    local value = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType[key]
    if value then
        PAUSING_WINDOWS[value] = true
    end
end

-- Failures that say nothing about the item itself (try again, don't skip).
local TEMPORARY_ERRORS = {}
for _, key in ipairs({ "SPELL_FAILED_MOVING", "SPELL_FAILED_NOT_READY", "SPELL_FAILED_SPELL_IN_PROGRESS",
    "ERR_SPELL_COOLDOWN", "SPELL_FAILED_AFFECTING_COMBAT", "SPELL_FAILED_STUNNED", "SPELL_FAILED_CASTER_DEAD",
    "ERR_GENERIC_THROTTLE", "SPELL_FAILED_INTERRUPTED", "SPELL_FAILED_NOT_STANDING", "ERR_NOT_WHILE_MOUNTED" }) do
    local text = _G[key]
    if type(text) == "string" then
        TEMPORARY_ERRORS[text] = true
    end
end

DE.known = {}      -- item GUIDs seen this session (in your bags or worn)
DE.failures = {}   -- [guid] = failed tries this session
DE.skipped = {}    -- [guid] = why it couldn't be disenchanted
DE.pausedBy = {}   -- bank windows that are open
DE.session = { count = 0, materials = {}, order = {} }

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

local function GetBagItemGUID(bag, slot)
    local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if location and C_Item.DoesItemExist(location) then
        return C_Item.GetItemGUID(location)
    end
end
DE.GetBagItemGUID = GetBagItemGUID

local function ForEachBagItem(callback)
    for bag = ns.FIRST_BAG, ns.LAST_BAG do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info then
                callback(bag, slot, info)
            end
        end
    end
end

local function ItemText(item)
    return ns.ColorByQuality(item.name or "?", item.quality)
end
DE.ItemText = ItemText

local function JoinList(parts)
    if #parts <= 1 then
        return parts[1] or ""
    end
    return table.concat(parts, ", ", 1, #parts - 1) .. " " .. L.DE_AND .. " " .. parts[#parts]
end

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

function DE:GetSpellName()
    return (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(DISENCHANT_SPELL_ID)) or "Disenchant"
end

function DE:IsDisenchantSpell(spellID)
    if not spellID or IsSecret(spellID) then
        return false
    end
    if spellID == DISENCHANT_SPELL_ID then
        return true
    end
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    return name ~= nil and name == self:GetSpellName()
end

function DE:CanDisenchant()
    if C_SpellBook and C_SpellBook.ContainsAnyDisenchantSpell then
        return C_SpellBook.ContainsAnyDisenchantSpell() and true or false
    end
    return false
end

function DE:IsEnabled()
    return (ns.db and ns.db.disenchant.enabled) and true or false
end

-- Recording and the list only happen on characters that know Disenchant.
function DE:IsActive()
    return self:IsEnabled() and self:CanDisenchant()
end

function DE:SetStatus(text, kind)
    self.status, self.statusKind = text, kind
end

function DE:Refresh()
    if ns.DEFrame then
        ns.DEFrame:Refresh()
    end
end

function DE:OnSettingsChanged()
    self:Refresh()
end

-------------------------------------------------------------------------------
-- Recording what you pick up
-------------------------------------------------------------------------------

function DE:RememberEquipped()
    for slot = EQUIPPED_FIRST, EQUIPPED_LAST do
        local location = ItemLocation:CreateFromEquipmentSlot(slot)
        if location and C_Item.DoesItemExist(location) then
            local guid = C_Item.GetItemGUID(location)
            if guid then
                self.known[guid] = true
            end
        end
    end
end

-- Everything you have when you log in counts as yours already; only gear
-- that arrives afterwards is recorded.
function DE:Start()
    if self.ready then
        return
    end
    ForEachBagItem(function(bag, slot)
        local guid = GetBagItemGUID(bag, slot)
        if guid then
            self.known[guid] = true
        end
    end)
    self:RememberEquipped()
    self.ready = true
    self:Prune()
    self:Refresh()
end

-- Records gear that just arrived. Returns true if any of it is on the list.
function DE:CheckNewItems()
    if not self.ready then
        return false
    end
    local record = self:IsActive() and next(self.pausedBy) == nil
    local recorded = ns.charDB.recorded
    local listedNew = false
    ForEachBagItem(function(bag, slot, info)
        local guid = GetBagItemGUID(bag, slot)
        if guid and not self.known[guid] then
            self.known[guid] = true
            if record and ns:IsDisenchantableItem(info) then
                recorded[guid] = info.itemID
                if self:IsListable(bag, slot, info) and not ns.db.excluded[info.itemID] then
                    listedNew = true
                end
            end
        end
    end)
    return listedNew
end

-- Forgets recorded gear that has left your bags (disenchanted, sold, mailed).
function DE:Prune()
    if not self.ready then
        return
    end
    local present, count = {}, 0
    ForEachBagItem(function(bag, slot)
        local guid = GetBagItemGUID(bag, slot)
        if guid then
            present[guid] = true
            count = count + 1
        end
    end)
    if count == 0 then
        return -- bags not loaded yet
    end
    for guid in pairs(ns.charDB.recorded) do
        if not present[guid] then
            ns.charDB.recorded[guid] = nil
            self.failures[guid], self.skipped[guid] = nil, nil
        end
    end
end

-- Gear that can go on the list: disenchantable, a quality you chose, not a
-- vendor purchase you can still refund, and not part of an equipment set.
function DE:IsListable(bag, slot, info)
    if not ns:IsDisenchantableItem(info) or not ns:IsQualityEnabled(info) then
        return false
    end
    if ns.IsRefundable(bag, slot) then
        return false
    end
    if C_Container.GetContainerItemEquipmentSetInfo then
        local inSet = C_Container.GetContainerItemEquipmentSetInfo(bag, slot)
        if inSet then
            return false
        end
    end
    return true
end

-- The list in bag order, including gear you keep or that couldn't be
-- disenchanted (shown greyed out). Also returns how many are to disenchant.
function DE:GetList()
    local items, readyCount = {}, 0
    if not self:IsActive() then
        return items, 0
    end
    local recorded = ns.charDB.recorded
    ForEachBagItem(function(bag, slot, info)
        local guid = GetBagItemGUID(bag, slot)
        if guid and recorded[guid] and self:IsListable(bag, slot, info) then
            local item = {
                guid = guid,
                bag = bag,
                slot = slot,
                itemID = info.itemID,
                link = info.hyperlink,
                icon = info.iconFileID,
                quality = ns.GetQuality(info),
                name = info.itemName,
                locked = info.isLocked,
                kept = ns.db.excluded[info.itemID] and true or false,
                skipped = self.skipped[guid],
            }
            item.ready = not (item.kept or item.skipped)
            if item.ready then
                readyCount = readyCount + 1
            end
            items[#items + 1] = item
        end
    end)
    return items, readyCount
end

-- The next item the Disenchant button will use.
function DE:GetNext()
    local items, readyCount = self:GetList()
    for _, item in ipairs(items) do
        if item.ready and not item.locked then
            return item, items, readyCount
        end
    end
    return nil, items, readyCount
end

-- Disenchantable gear in your bags that was there before recording started.
function DE:CountUnrecorded()
    local count = 0
    if not self:IsActive() then
        return 0
    end
    local recorded = ns.charDB.recorded
    ForEachBagItem(function(bag, slot, info)
        local guid = GetBagItemGUID(bag, slot)
        if guid and not recorded[guid] and self:IsListable(bag, slot, info) and not ns.db.excluded[info.itemID] then
            count = count + 1
        end
    end)
    return count
end

function DE:AddFromBags()
    if not self:IsActive() then
        return
    end
    local recorded = ns.charDB.recorded
    ForEachBagItem(function(bag, slot, info)
        local guid = GetBagItemGUID(bag, slot)
        if guid and not recorded[guid] and self:IsListable(bag, slot, info) and not ns.db.excluded[info.itemID] then
            recorded[guid] = info.itemID
        end
    end)
    self:SetStatus(nil)
    self:Refresh()
end

-- Takes one item off the list without keeping it forever.
function DE:Forget(guid)
    ns.charDB.recorded[guid] = nil
    self.skipped[guid] = nil
    self:Refresh()
end

-------------------------------------------------------------------------------
-- Disenchanting and its results
-------------------------------------------------------------------------------

-- Called right before the Disenchant button acts on an item.
function DE:BeginCast(item)
    self.pending = {
        guid = item.guid,
        itemID = item.itemID,
        name = item.name,
        quality = item.quality,
    }
    self.lastError = nil
    self:SetStatus(nil)
end

function DE:AddResults(results)
    local session = self.session
    local parts = {}
    for _, result in ipairs(results) do
        local key = result.itemID or result.name
        local entry = session.materials[key]
        if not entry then
            entry = { itemID = result.itemID, link = result.link, name = result.name, icon = result.icon,
                quality = result.quality, count = 0 }
            session.materials[key] = entry
            session.order[#session.order + 1] = key
        end
        entry.count = entry.count + result.count
        -- Icons keep the line short; with a single material, add its name.
        local icon = result.icon and ("|T%s:0|t"):format(result.icon)
        local label = icon or ItemText(result)
        if #results == 1 and icon then
            label = icon .. " " .. ItemText(result)
        end
        parts[#parts + 1] = ("%d %s"):format(result.count, label)
    end
    self:SetStatus(L.DE_STATUS_GOT:format(JoinList(parts)), "good")
    self:Refresh()
end

function DE:CaptureLoot()
    if not self.lootDeadline or GetTime() > self.lootDeadline then
        return
    end
    local results = {}
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local icon, name, quantity, _, quality = GetLootSlotInfo(slot)
        if link and name and quantity and not IsSecret(link) and not IsSecret(quantity) and quantity > 0 then
            results[#results + 1] = {
                itemID = tonumber(link:match("item:(%d+)")),
                link = link,
                name = name,
                icon = icon,
                quality = quality,
                count = quantity,
            }
        end
    end
    if #results > 0 then
        self.lootDeadline = nil
        self:AddResults(results)
    end
end

-------------------------------------------------------------------------------
-- Opening the window
-------------------------------------------------------------------------------

function DE:OpenWindow()
    if not self:IsEnabled() then
        ns.Print(L.DE_OFF)
        return
    end
    if InCombatLockdown() then
        ns.Print(L.DE_NO_COMBAT_OPEN)
        return
    end
    ns.DEFrame:Open()
end

function DE:ToggleWindow()
    if ns.DEFrame:IsOpen() then
        ns.DEFrame:Close()
    else
        self:OpenWindow()
    end
end

-- Named in Bindings.xml.
function DEMailer_ToggleDisenchantWindow()
    DE:ToggleWindow()
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    local handler = DE[event]
    if handler and ns.db then
        handler(DE, ...)
    end
end)
for _, event in ipairs({
    "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "SPELLS_CHANGED",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
    "LOOT_READY", "LOOT_OPENED", "UI_ERROR_MESSAGE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}) do
    events:RegisterEvent(event)
end
for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED" }) do
    events:RegisterUnitEvent(event, "player")
end

function DE:PLAYER_ENTERING_WORLD()
    if not self.ready then
        -- Give the bags a moment to load before taking stock.
        C_Timer.After(1, function()
            self:Start()
        end)
    end
end

function DE:BAG_UPDATE_DELAYED()
    if not self.ready then
        return
    end
    local listedNew = self:CheckNewItems()
    self:Prune()
    self:Refresh()
    if listedNew and ns.db.disenchant.autoOpen and not InCombatLockdown() and not ns.DEFrame:IsOpen() then
        self:OpenWindow()
    end
end

function DE:PLAYER_EQUIPMENT_CHANGED()
    self:RememberEquipped()
end

function DE:SPELLS_CHANGED()
    self:Refresh()
end

function DE:PLAYER_INTERACTION_MANAGER_FRAME_SHOW(interactionType)
    if PAUSING_WINDOWS[interactionType] then
        self.pausedBy[interactionType] = true
    end
end

function DE:PLAYER_INTERACTION_MANAGER_FRAME_HIDE(interactionType)
    if PAUSING_WINDOWS[interactionType] then
        -- Let the last bag updates from the bank arrive before recording again.
        C_Timer.After(0.5, function()
            self.pausedBy[interactionType] = nil
        end)
    end
end

function DE:UNIT_SPELLCAST_START(_, _, spellID)
    if self:IsDisenchantSpell(spellID) then
        self.casting = true
        self.lootDeadline = GetTime() + CAST_LOOT_WINDOW
        self:Refresh()
    end
end

function DE:UNIT_SPELLCAST_SUCCEEDED(_, _, spellID)
    if not self:IsDisenchantSpell(spellID) then
        return
    end
    self.casting = false
    self.lootDeadline = GetTime() + LOOT_WINDOW
    if self.pending then
        self.failures[self.pending.guid] = nil
    end
    self.pending = nil
    self.session.count = self.session.count + 1
    self:Refresh()
end

function DE:UNIT_SPELLCAST_INTERRUPTED(_, _, spellID)
    if not self:IsDisenchantSpell(spellID) then
        return
    end
    self.casting = false
    self.lootDeadline = nil
    if self.pending then
        self:SetStatus(L.DE_STATUS_INTERRUPTED, nil)
    end
    self.pending = nil
    self:Refresh()
end

function DE:UNIT_SPELLCAST_FAILED(_, _, spellID)
    if not self:IsDisenchantSpell(spellID) then
        return
    end
    self.casting = false
    self.lootDeadline = nil
    local pending = self.pending
    self.pending = nil
    if not pending then
        self:Refresh()
        return
    end
    -- The game's error message can arrive just after this event.
    C_Timer.After(0.1, function()
        local reason = self.lastError
        if reason and TEMPORARY_ERRORS[reason] then
            self:SetStatus(L.DE_STATUS_FAILED:format(ItemText(pending), reason), "bad")
        else
            reason = reason or L.DE_UNKNOWN_REASON
            local failures = (self.failures[pending.guid] or 0) + 1
            self.failures[pending.guid] = failures
            if failures >= MAX_FAILURES then
                self.skipped[pending.guid] = reason
                self:SetStatus(L.DE_STATUS_SKIPPED:format(ItemText(pending), reason), "bad")
            else
                self:SetStatus(L.DE_STATUS_FAILED:format(ItemText(pending), reason), "bad")
            end
        end
        self:Refresh()
    end)
end

function DE:UI_ERROR_MESSAGE(_, message)
    if type(message) == "string" and not IsSecret(message) then
        self.lastError = message
    end
end

function DE:LOOT_READY()
    self:CaptureLoot()
end

function DE:LOOT_OPENED()
    self:CaptureLoot()
end

function DE:PLAYER_REGEN_DISABLED()
    if ns.DEFrame then
        ns.DEFrame:OnCombatStart()
    end
end

function DE:PLAYER_REGEN_ENABLED()
    if ns.DEFrame then
        ns.DEFrame:OnCombatEnd()
    end
end
