-- DE Mailer: Groups.lua
-- Mail groups: your own named groups of items, arranged in a tree (Herbs >
-- Northrend), each with a recipient and simple "keep" and "send at most"
-- rules. This file holds the group data, the slash commands for it, and works
-- out what a send would mail to whom. The Groups tab on the mailbox and the
-- group editor window are drawn elsewhere.

local ADDON_NAME, ns = ...
local L = ns.L

local Groups = {}
ns.Groups = Groups

-------------------------------------------------------------------------------
-- Text
-------------------------------------------------------------------------------

L.G_TAG             = "Groups"
L.G_NONE            = "You have no mail groups yet. Make one with /dem groups new <name>."
L.G_HEADER          = "Mail groups (%s):"
L.G_LINE            = "%s%s  |cff999999->|r %s  keep %s, %s, %d |4item:items;%s"
L.G_CAP             = "at most %d"
L.G_NO_CAP          = "no limit"
L.G_INHERITED       = "|cff999999(same as above)|r"
L.G_NOBODY          = "|cffff6060nobody|r"
L.G_OFF_MARK        = " |cffff6060[off]|r"
L.G_CHECKED         = "|cff20ff20[x]|r "
L.G_UNCHECKED       = "|cff999999[ ]|r "

L.G_CREATED         = "made group %s."
L.G_RENAMED         = "renamed to %s."
L.G_MOVED           = "moved %s."
L.G_DELETED         = "deleted %s. Its items and subgroups moved up a level."
L.G_DELETED_TOP     = "deleted %s. Its subgroups are now top-level groups and its items are in no group."
L.G_RECIPIENT_SET   = "%s now goes to %s."
L.G_RECIPIENT_SAME  = "%s now goes to the same character as the group above it."
L.G_KEEP_SET        = "%s keeps %s of each item."
L.G_CAP_SET         = "%s sends %s of each item."
L.G_TURNED          = "%s is now %s."
L.G_CHECKED_MSG     = "%s is %s for sending from the Groups tab."
L.G_ADDED           = "added %d |4item:items; to %s."
L.G_MOVED_ITEMS     = "%d of them moved there from another group."
L.G_REMOVED         = "took %d |4item:items; out of their groups."
L.G_SAME_AS_ABOVE   = "same as above"

L.G_ERR_NAME        = "Give the group a name."
L.G_ERR_NAME_CHARS  = "Group names can't contain \">\" or \"=\"."
L.G_ERR_NAME_TAKEN  = "There's already a group called %s there."
L.G_ERR_DEPTH       = "Groups can only go %d levels deep."
L.G_ERR_NOT_FOUND   = "No group called \"%s\"."
L.G_ERR_AMBIGUOUS   = "More than one group is called \"%s\". Use the full path, like Herbs > Northrend."
L.G_ERR_INTO_ITSELF = "A group can't go inside itself or one of its own subgroups."
L.G_ERR_NO_ITEMS    = "Shift-click items into the command, or give item IDs."
L.G_ERR_NUMBER      = "Use a number, or \"same\" to use the group above's setting."
L.G_ERR_TOP_SAME    = "%s is a top-level group, so there's no group above it to copy."
L.G_ERR_USAGE       = "Use: %s"

L.G_PLAN_TITLE_SEL  = "Dry run for your checked groups (nothing is sent):"
L.G_PLAN_TITLE_ALL  = "Dry run for all groups (nothing is sent):"
L.G_PLAN_EMPTY      = "Nothing to send."
L.G_PLAN_RECIPIENT  = "-> %s: %d |4item:items; in %d |4letter:letters;"
L.G_PLAN_SPLITS     = "%d |4stack:stacks; will be split first, so keep %d bag |4slot:slots; free."
L.G_PLAN_SKIP_NOBODY = "Skipped %s: no recipient set."
L.G_PLAN_SKIP_SELF  = "Skipped %s: it goes to the character you're on."
L.G_PLAN_KEPT       = "%s: keeping all %d."

-------------------------------------------------------------------------------
-- Constants and helpers
-------------------------------------------------------------------------------

Groups.MAX_DEPTH = 5
local MAX_NAME   = 40
local MAX_COUNT  = 100000
local TOP        = 0 -- the "parent" key for top-level groups

local function Trim(text)
    return (tostring(text or ""):match("^%s*(.-)%s*$"))
end

local function Print(msg)
    ns.Print(msg)
end

local function ItemLink(itemID, known)
    if known then
        return known
    end
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local link = getInfo and select(2, getInfo(itemID))
    return link or ("item:" .. itemID)
end

-- Splits "Herbs > Northrend" into { "Herbs", "Northrend" }.
local function SplitPath(text)
    local parts = {}
    for part in (tostring(text or "") .. ">"):gmatch("([^>]*)>") do
        part = Trim(part)
        if part ~= "" then
            parts[#parts + 1] = part
        end
    end
    return parts
end

local function CountKeys(t)
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

-------------------------------------------------------------------------------
-- Loading and the lookup tables
-------------------------------------------------------------------------------

-- Called once the saved settings are loaded. Repairs anything odd in the
-- saved groups (a missing parent, a loop of parents, an item in two groups)
-- so the rest of the code can trust the data.
function Groups:Init()
    local db = ns.db
    self.db = db
    local groups = db.groups

    for id, group in pairs(groups) do
        if type(id) ~= "number" or type(group) ~= "table" then
            groups[id] = nil
        else
            if type(group.name) ~= "string" or Trim(group.name) == "" then
                group.name = "Group " .. id
            end
            if type(group.items) ~= "table" then
                group.items = {}
            end
            if group.enabled == nil then
                group.enabled = true
            end
            if type(group.order) ~= "number" then
                group.order = id
            end
            if group.keep ~= nil and type(group.keep) ~= "number" then
                group.keep = nil
            end
            if group.cap ~= nil and group.cap ~= false and type(group.cap) ~= "number" then
                group.cap = nil
            end
            if id >= db.nextGroupId then
                db.nextGroupId = id + 1
            end
        end
    end

    for id, group in pairs(groups) do
        if group.parent ~= nil and (group.parent == id or not groups[group.parent]) then
            group.parent = nil
        end
    end

    -- Break any loop of parents (A inside B inside A).
    for id, group in pairs(groups) do
        local seen, current = { [id] = true }, group.parent
        while current do
            if seen[current] then
                group.parent = nil
                break
            end
            seen[current] = true
            current = groups[current].parent
        end
    end

    self:Rebuild()
end

local function SiblingOrder(a, b)
    local groups = Groups.db.groups
    local ga, gb = groups[a], groups[b]
    if ga.order ~= gb.order then
        return ga.order < gb.order
    end
    local na, nb = ga.name:lower(), gb.name:lower()
    if na ~= nb then
        return na < nb
    end
    return a < b
end

-- Rebuilds the item -> group lookup and each group's list of subgroups.
-- Neither is saved; both come from the groups themselves.
function Groups:Rebuild()
    local groups = self.db.groups
    local ids = {}
    for id in pairs(groups) do
        ids[#ids + 1] = id
    end
    table.sort(ids)

    local itemIndex, children = {}, { [TOP] = {} }
    for _, id in ipairs(ids) do
        local group = groups[id]
        for itemID in pairs(group.items) do
            if type(itemID) ~= "number" or itemIndex[itemID] then
                group.items[itemID] = nil -- only one group per item
            else
                itemIndex[itemID] = id
            end
        end
        local key = group.parent or TOP
        children[key] = children[key] or {}
        table.insert(children[key], id)
    end
    for _, list in pairs(children) do
        table.sort(list, SiblingOrder)
    end
    self.itemIndex = itemIndex
    self.children = children
end

-- Something about the groups changed: refresh the lookups and every window.
function Groups:Changed(structural)
    if structural ~= false then
        self:Rebuild()
    end
    ns:OnSettingsChanged()
end

-------------------------------------------------------------------------------
-- Reading the tree
-------------------------------------------------------------------------------

function Groups:Get(id)
    return id and self.db.groups[id]
end

function Groups:GetChildren(id)
    return self.children[id or TOP] or {}
end

function Groups:GetGroupOfItem(itemID)
    return itemID and self.itemIndex[itemID]
end

function Groups:CountItems(id)
    local group = self:Get(id)
    return group and CountKeys(group.items) or 0
end

-- How deep a group sits: 1 for top-level groups.
function Groups:GetDepth(id)
    local depth = 0
    while id do
        depth = depth + 1
        id = self.db.groups[id].parent
    end
    return depth
end

-- How many levels a group and its subgroups take up: 1 with no subgroups.
function Groups:GetHeight(id)
    local tallest = 0
    for _, child in ipairs(self:GetChildren(id)) do
        tallest = math.max(tallest, self:GetHeight(child))
    end
    return tallest + 1
end

function Groups:IsInside(id, ancestor)
    while id do
        if id == ancestor then
            return true
        end
        id = self.db.groups[id].parent
    end
    return false
end

-- Calls fn(id, depth) for every group, parents before their subgroups,
-- in the order they're listed.
function Groups:Walk(fn, from, depth)
    depth = depth or 1
    for _, id in ipairs(self:GetChildren(from)) do
        fn(id, depth)
        self:Walk(fn, id, depth + 1)
    end
end

-- "Herbs > Northrend"
function Groups:GetPath(id)
    local names = {}
    while id do
        local group = self.db.groups[id]
        table.insert(names, 1, group.name)
        id = group.parent
    end
    return table.concat(names, " > ")
end

function Groups:FindChild(parent, name)
    name = name:lower()
    for _, id in ipairs(self:GetChildren(parent)) do
        if self.db.groups[id].name:lower() == name then
            return id
        end
    end
end

-- Finds a group from text typed by the player: a full path like
-- "Herbs > Northrend", or just a name if only one group has it.
-- Returns the group ID, or nil and a message.
function Groups:Find(text)
    local parts = SplitPath(text)
    if #parts == 0 then
        return nil, L.G_ERR_NAME
    end
    local id
    for _, part in ipairs(parts) do
        id = self:FindChild(id, part)
        if not id then
            break
        end
    end
    if id then
        return id
    end
    if #parts == 1 then
        local wanted, found, count = parts[1]:lower(), nil, 0
        for gid, group in pairs(self.db.groups) do
            if group.name:lower() == wanted then
                found, count = gid, count + 1
            end
        end
        if count == 1 then
            return found
        elseif count > 1 then
            return nil, L.G_ERR_AMBIGUOUS:format(parts[1])
        end
    end
    return nil, L.G_ERR_NOT_FOUND:format(Trim(text))
end

-------------------------------------------------------------------------------
-- Settings that pass down from a group to its subgroups
-------------------------------------------------------------------------------

function Groups:GetRecipients(create)
    local key = ns.RealmKey()
    local list = self.db.groupRecipients[key]
    if not list and create then
        list = {}
        self.db.groupRecipients[key] = list
    end
    return list
end

-- The recipient set on this group itself (nil means "same as above").
function Groups:GetOwnRecipient(id)
    local list = self:GetRecipients(false)
    return list and list[id]
end

-- The recipient, keep and cap that actually apply to a group, after looking
-- up through its parents for anything it doesn't set itself. Also returns
-- whether each one came from a group above.
function Groups:Resolve(id)
    local list = self:GetRecipients(false) or {}
    local recipient, keep, cap
    local recipientFound, keepFound, capFound = false, false, false
    local inherited = { recipient = false, keep = false, cap = false }
    local current, first = id, true
    while current and not (recipientFound and keepFound and capFound) do
        local group = self.db.groups[current]
        if not recipientFound and list[current] then
            recipient, recipientFound = list[current], true
            inherited.recipient = not first
        end
        if not keepFound and group.keep ~= nil then
            keep, keepFound = group.keep, true
            inherited.keep = not first
        end
        if not capFound and group.cap ~= nil then
            cap, capFound = group.cap, true
            inherited.cap = not first
        end
        current, first = group.parent, false
    end
    return recipient or "", keep or 0, (cap ~= false) and cap or nil, inherited
end

-- A group sends only if it and every group above it are switched on.
function Groups:IsActive(id)
    while id do
        local group = self.db.groups[id]
        if not group.enabled then
            return false
        end
        id = group.parent
    end
    return true
end

-- Checked on the Groups tab, directly or through a group above it.
function Groups:IsChecked(id)
    while id do
        if self.db.groupsSelected[id] then
            return true
        end
        id = self.db.groups[id].parent
    end
    return false
end

-------------------------------------------------------------------------------
-- Changing the tree
-------------------------------------------------------------------------------

local function CheckName(name)
    name = Trim(name)
    if name == "" then
        return nil, L.G_ERR_NAME
    end
    if name:find("[>=]") then
        return nil, L.G_ERR_NAME_CHARS
    end
    if #name > MAX_NAME then
        name = name:sub(1, MAX_NAME)
    end
    return name
end

local function NextOrder(parent)
    local highest = 0
    for _, id in ipairs(Groups:GetChildren(parent)) do
        highest = math.max(highest, Groups.db.groups[id].order)
    end
    return highest + 1
end

-- A name that isn't taken under parent yet: "Herbs", "Herbs (2)", ...
local function FreeName(parent, name, except)
    local candidate, n = name, 1
    while true do
        local taken = Groups:FindChild(parent, candidate)
        if not taken or taken == except then
            return candidate
        end
        n = n + 1
        candidate = ("%s (%d)"):format(name, n)
    end
end

function Groups:Create(name, parent)
    local err
    name, err = CheckName(name)
    if not name then
        return nil, err
    end
    if parent and not self:Get(parent) then
        return nil, L.G_ERR_NOT_FOUND:format(tostring(parent))
    end
    if (parent and self:GetDepth(parent) or 0) + 1 > self.MAX_DEPTH then
        return nil, L.G_ERR_DEPTH:format(self.MAX_DEPTH)
    end
    if self:FindChild(parent, name) then
        return nil, L.G_ERR_NAME_TAKEN:format(name)
    end
    local id = self.db.nextGroupId
    self.db.nextGroupId = id + 1
    self.db.groups[id] = {
        name = name,
        parent = parent,
        order = NextOrder(parent),
        enabled = true,
        items = {},
    }
    if not parent then
        self.db.groupsSelected[id] = true -- new top-level groups start checked
    end
    self:Changed()
    return id
end

function Groups:Rename(id, name)
    local group = self:Get(id)
    local err
    name, err = CheckName(name)
    if not name then
        return nil, err
    end
    local taken = self:FindChild(group.parent, name)
    if taken and taken ~= id then
        return nil, L.G_ERR_NAME_TAKEN:format(name)
    end
    group.name = name
    self:Changed()
    return true
end

-- Moves a group (with its subgroups and items) under newParent, or to the
-- top level when newParent is nil.
function Groups:Move(id, newParent)
    local group = self:Get(id)
    if newParent and self:IsInside(newParent, id) then
        return nil, L.G_ERR_INTO_ITSELF
    end
    if (newParent and self:GetDepth(newParent) or 0) + self:GetHeight(id) > self.MAX_DEPTH then
        return nil, L.G_ERR_DEPTH:format(self.MAX_DEPTH)
    end
    if newParent == group.parent then
        return true
    end
    local taken = self:FindChild(newParent, group.name)
    if taken then
        return nil, L.G_ERR_NAME_TAKEN:format(group.name)
    end
    group.order = NextOrder(newParent)
    group.parent = newParent
    self:Changed()
    return true
end

-- Deletes a group. With keepContents, its items go to the group above it
-- (or out of every group, for a top-level group) and its subgroups move up
-- a level. Without it, the subgroups and their items go too.
function Groups:Delete(id, keepContents)
    local groups = self.db.groups
    local group = groups[id]
    if not group then
        return
    end
    local parent = group.parent
    local removed = { id }
    if keepContents then
        for _, child in ipairs(self:GetChildren(id)) do
            local childGroup = groups[child]
            childGroup.name = FreeName(parent, childGroup.name, child)
            childGroup.parent = parent
            childGroup.order = NextOrder(parent)
            self:Rebuild() -- so FreeName sees the groups already moved
        end
        if parent then
            for itemID in pairs(group.items) do
                groups[parent].items[itemID] = true
            end
        end
    else
        self:Walk(function(child)
            removed[#removed + 1] = child
        end, id)
    end
    for _, gone in ipairs(removed) do
        groups[gone] = nil
        self.db.groupsSelected[gone] = nil
        self.db.groupsCollapsed[gone] = nil
        for _, list in pairs(self.db.groupRecipients) do
            list[gone] = nil
        end
    end
    self:Changed()
end

-- name: a character name, or nil for "same as above".
function Groups:SetRecipient(id, name)
    name = name and Trim(name) or nil
    if name == "" then
        name = nil
    end
    local list = self:GetRecipients(true)
    list[id] = name
    self:Changed(false)
end

-- value: a number, or nil for "same as above".
function Groups:SetKeep(id, value)
    self:Get(id).keep = value and math.max(0, math.min(MAX_COUNT, math.floor(value))) or nil
    self:Changed(false)
end

-- value: a number, false for "no limit", or nil for "same as above".
function Groups:SetCap(id, value)
    if type(value) == "number" then
        value = math.max(1, math.min(MAX_COUNT, math.floor(value)))
    end
    self:Get(id).cap = value
    self:Changed(false)
end

function Groups:SetEnabled(id, enabled)
    self:Get(id).enabled = enabled and true or false
    self:Changed(false)
end

function Groups:SetChecked(id, checked)
    self.db.groupsSelected[id] = checked and true or nil
    self:Changed(false)
end

-- Puts items into a group, taking them out of any other group first.
-- Returns how many were added and how many came from another group.
function Groups:AddItems(id, itemIDs)
    local group = self:Get(id)
    local added, moved = 0, 0
    for _, itemID in ipairs(itemIDs) do
        local current = self.itemIndex[itemID]
        if current ~= id then
            if current then
                self.db.groups[current].items[itemID] = nil
                moved = moved + 1
            end
            group.items[itemID] = true
            self.itemIndex[itemID] = id
            added = added + 1
        end
    end
    self:Changed()
    return added, moved
end

function Groups:RemoveItems(itemIDs)
    local removed = 0
    for _, itemID in ipairs(itemIDs) do
        local current = self.itemIndex[itemID]
        if current then
            self.db.groups[current].items[itemID] = nil
            removed = removed + 1
        end
    end
    self:Changed()
    return removed
end

-------------------------------------------------------------------------------
-- Working out what to send
-------------------------------------------------------------------------------

-- The groups a send covers: every switched-on group that is checked (or sits
-- under a checked group), or every switched-on group when all is true.
function Groups:GetSendSet(all)
    local set = {}
    for id in pairs(self.db.groups) do
        if self:IsActive(id) and (all or self:IsChecked(id)) then
            set[id] = true
        end
    end
    return set
end

-- Every mailable stack in your bags of an item that's in a group:
-- [itemID] = { { bag, slot, count, link, icon, quality }, ... }
function Groups:ScanBags()
    local stacks = {}
    for bag = ns.FIRST_BAG, ns.LAST_BAG do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local itemID = info and info.itemID
            if itemID and self.itemIndex[itemID] and not info.isBound and not info.isLocked
                and not ns.unmailable[itemID] and not ns.IsRefundable(bag, slot) then
                local list = stacks[itemID]
                if not list then
                    list = {}
                    stacks[itemID] = list
                end
                list[#list + 1] = {
                    bag = bag,
                    slot = slot,
                    count = info.stackCount or 1,
                    link = info.hyperlink,
                    icon = info.iconFileID,
                    quality = ns.GetQuality(info),
                }
            end
        end
    end
    return stacks
end

-- Picks which stacks to send so that exactly `amount` goes out. Whole stacks
-- first, biggest first. If some is still missing, the smallest stack left
-- gets split, so only one stack per item ever needs splitting.
local function PickStacks(stacks, amount)
    local sorted = {}
    for i, stack in ipairs(stacks) do
        sorted[i] = stack
    end
    table.sort(sorted, function(a, b)
        if a.count ~= b.count then
            return a.count > b.count
        end
        if a.bag ~= b.bag then
            return a.bag < b.bag
        end
        return a.slot < b.slot
    end)

    local picked, left, unused = {}, amount, {}
    for _, stack in ipairs(sorted) do
        if left > 0 and stack.count <= left then
            picked[#picked + 1] = { stack = stack, count = stack.count }
            left = left - stack.count
        else
            unused[#unused + 1] = stack
        end
    end
    if left > 0 then
        -- Every unused stack is bigger than what's left; split the smallest.
        local smallest = unused[#unused]
        if smallest then
            picked[#picked + 1] = { stack = smallest, count = left, split = true }
        end
    end
    return picked
end

-- Works out a send without doing anything. Returns:
-- {
--   recipients = { { name, items = n, letters = n, attachments = { ... } }, ... },
--   skipped    = { { id, reason }, ... },   groups with items that won't go
--   kept       = { { itemID, link, count }, ... }, items held back by "keep"
--   items, letters, splits = totals
-- }
-- Each attachment is { bag, slot, itemID, link, icon, quality, count, split }.
function Groups:BuildPlan(all)
    local plan = { recipients = {}, skipped = {}, kept = {}, items = 0, letters = 0, splits = 0 }
    if not self.db then
        return plan
    end
    local sendSet = self:GetSendSet(all)
    local stacks = self:ScanBags()

    local itemIDs = {}
    for itemID in pairs(stacks) do
        if sendSet[self.itemIndex[itemID]] then
            itemIDs[#itemIDs + 1] = itemID
        end
    end
    table.sort(itemIDs)

    local byName, skippedGroups = {}, {}
    for _, itemID in ipairs(itemIDs) do
        local id = self.itemIndex[itemID]
        local recipient, keep, cap = self:Resolve(id)
        local list = stacks[itemID]
        local have = 0
        for _, stack in ipairs(list) do
            have = have + stack.count
        end
        local amount = have - keep
        if cap then
            amount = math.min(amount, cap)
        end

        if recipient == "" or ns:IsSelf(recipient) then
            if not skippedGroups[id] then
                skippedGroups[id] = true
                plan.skipped[#plan.skipped + 1] = { id = id, reason = (recipient == "") and "nobody" or "self" }
            end
        elseif amount <= 0 then
            plan.kept[#plan.kept + 1] = { itemID = itemID, link = list[1].link, count = have }
        else
            local key = recipient:lower()
            local entry = byName[key]
            if not entry then
                entry = { name = recipient, items = 0, attachments = {} }
                byName[key] = entry
                plan.recipients[#plan.recipients + 1] = entry
            end
            for _, pick in ipairs(PickStacks(list, amount)) do
                local stack = pick.stack
                entry.attachments[#entry.attachments + 1] = {
                    bag = stack.bag,
                    slot = stack.slot,
                    itemID = itemID,
                    link = stack.link,
                    icon = stack.icon,
                    quality = stack.quality,
                    count = pick.count,
                    split = pick.split or false,
                }
                entry.items = entry.items + pick.count
                if pick.split then
                    plan.splits = plan.splits + 1
                end
            end
        end
    end

    table.sort(plan.recipients, function(a, b)
        return a.name:lower() < b.name:lower()
    end)
    for _, entry in ipairs(plan.recipients) do
        entry.letters = math.ceil(#entry.attachments / ns.MAX_ATTACHMENTS)
        plan.items = plan.items + entry.items
        plan.letters = plan.letters + entry.letters
    end
    return plan
end

-------------------------------------------------------------------------------
-- Chat output
-------------------------------------------------------------------------------

function Groups:PrintTree()
    if not next(self.db.groups) then
        Print(L.G_NONE)
        return
    end
    local realm, faction = ns:GetRealmAndFaction()
    Print(L.G_HEADER:format(realm .. ", " .. faction))
    self:Walk(function(id, depth)
        local group = self.db.groups[id]
        local recipient, keep, cap, inherited = self:Resolve(id)
        local who = (recipient ~= "") and recipient or L.G_NOBODY
        if inherited.recipient then
            who = who .. " " .. L.G_INHERITED
        end
        local check = self.db.groupsSelected[id] and L.G_CHECKED or L.G_UNCHECKED
        Print(L.G_LINE:format(
            string.rep("    ", depth - 1) .. check,
            group.name,
            who,
            tostring(keep),
            cap and L.G_CAP:format(cap) or L.G_NO_CAP,
            self:CountItems(id),
            group.enabled and "" or L.G_OFF_MARK))
    end)
end

-- Prints what a send would do. Chat lines are kept short by listing
-- each recipient's items on lines of their own.
function Groups:PrintPlan(all)
    local plan = self:BuildPlan(all)
    Print(all and L.G_PLAN_TITLE_ALL or L.G_PLAN_TITLE_SEL)
    if #plan.recipients == 0 then
        Print(L.G_PLAN_EMPTY)
    end
    for _, entry in ipairs(plan.recipients) do
        Print(L.G_PLAN_RECIPIENT:format(entry.name, entry.items, entry.letters))
        -- Add up the stacks of each item for a shorter list.
        local totals, order, links = {}, {}, {}
        for _, attachment in ipairs(entry.attachments) do
            if not totals[attachment.itemID] then
                totals[attachment.itemID] = 0
                order[#order + 1] = attachment.itemID
                links[attachment.itemID] = attachment.link
            end
            totals[attachment.itemID] = totals[attachment.itemID] + attachment.count
        end
        local line = {}
        for _, itemID in ipairs(order) do
            line[#line + 1] = ItemLink(itemID, links[itemID]) .. " x" .. totals[itemID]
            if #line == 4 then
                Print("    " .. table.concat(line, ", "))
                wipe(line)
            end
        end
        if #line > 0 then
            Print("    " .. table.concat(line, ", "))
        end
    end
    for _, kept in ipairs(plan.kept) do
        Print(L.G_PLAN_KEPT:format(ItemLink(kept.itemID, kept.link), kept.count))
    end
    for _, skip in ipairs(plan.skipped) do
        local text = (skip.reason == "self") and L.G_PLAN_SKIP_SELF or L.G_PLAN_SKIP_NOBODY
        Print(text:format(self:GetPath(skip.id)))
    end
    if plan.splits > 0 then
        Print(L.G_PLAN_SPLITS:format(plan.splits, plan.splits))
    end
end

-------------------------------------------------------------------------------
-- Slash commands: /dem groups ..., /dem add, /dem remove
-------------------------------------------------------------------------------

-- Item IDs from shift-clicked links, or from plain numbers if there are none.
local function ParseItems(text)
    local ids, seen = {}, {}
    for id in tostring(text or ""):gmatch("item:(%d+)") do
        id = tonumber(id)
        if id and not seen[id] then
            ids[#ids + 1], seen[id] = id, true
        end
    end
    if #ids == 0 then
        for id in tostring(text or ""):gmatch("%d+") do
            id = tonumber(id)
            if id and not seen[id] then
                ids[#ids + 1], seen[id] = id, true
            end
        end
    end
    return ids
end

-- "Herbs > Northrend = Alchemistalt" -> "Herbs > Northrend", "Alchemistalt"
local function SplitAssign(text)
    local left, right = tostring(text or ""):match("^(.-)=(.*)$")
    if not left then
        return Trim(text), nil
    end
    return Trim(left), Trim(right)
end

local function IsSame(value)
    value = (value or ""):lower()
    return value == "same" or value == "inherit" or value == "parent"
end

local function Usage(text)
    Print(L.G_ERR_USAGE:format(text))
end

-- Finds a group or prints why not.
local function FindOrSay(text)
    local id, err = Groups:Find(text)
    if not id then
        Print(err)
    end
    return id
end

-- Makes every group along a path that doesn't exist yet. Returns the last one.
function Groups:CreatePath(text)
    local parts = SplitPath(text)
    if #parts == 0 then
        return nil, L.G_ERR_NAME
    end
    local parent, made
    for _, part in ipairs(parts) do
        local existing = self:FindChild(parent, part)
        if existing then
            parent = existing
        else
            local id, err = self:Create(part, parent)
            if not id then
                return nil, err
            end
            parent, made = id, id
        end
    end
    if not made then
        return nil, L.G_ERR_NAME_TAKEN:format(self:GetPath(parent))
    end
    return made
end

local SUBCOMMANDS = {}

SUBCOMMANDS.new = function(rest)
    if Trim(rest) == "" then
        return Usage("/dem groups new Herbs > Northrend")
    end
    local id, err = Groups:CreatePath(rest)
    Print(id and L.G_CREATED:format(Groups:GetPath(id)) or err)
end

SUBCOMMANDS.rename = function(rest)
    local path, name = SplitAssign(rest)
    if not name then
        return Usage("/dem groups rename Herbs = Plants")
    end
    local id = FindOrSay(path)
    if id then
        local ok, err = Groups:Rename(id, name)
        Print(ok and L.G_RENAMED:format(Groups:GetPath(id)) or err)
    end
end

SUBCOMMANDS.move = function(rest)
    local path, target = SplitAssign(rest)
    if not target then
        return Usage("/dem groups move Northrend = Herbs   (or = top)")
    end
    local id = FindOrSay(path)
    if not id then
        return
    end
    local parent
    if target:lower() ~= "top" and target ~= "" then
        parent = FindOrSay(target)
        if not parent then
            return
        end
    end
    local ok, err = Groups:Move(id, parent)
    Print(ok and L.G_MOVED:format(Groups:GetPath(id)) or err)
end

SUBCOMMANDS.delete = function(rest)
    local id = FindOrSay(rest)
    if id then
        local path = Groups:GetPath(id)
        local topLevel = not Groups:Get(id).parent
        Groups:Delete(id, true)
        Print((topLevel and L.G_DELETED_TOP or L.G_DELETED):format(path))
    end
end

SUBCOMMANDS.to = function(rest)
    local path, name = SplitAssign(rest)
    if not name then
        return Usage("/dem groups to Herbs = Alchemistalt   (or = same)")
    end
    local id = FindOrSay(path)
    if not id then
        return
    end
    if IsSame(name) or name == "" then
        Groups:SetRecipient(id, nil)
        if Groups:Get(id).parent then
            Print(L.G_RECIPIENT_SAME:format(Groups:GetPath(id)))
        else
            Print(L.G_RECIPIENT_SET:format(Groups:GetPath(id), L.G_NOBODY))
        end
    else
        Groups:SetRecipient(id, name)
        Print(L.G_RECIPIENT_SET:format(Groups:GetPath(id), name))
    end
end

local function SetNumber(rest, usage, setter, message, allowOff)
    local path, value = SplitAssign(rest)
    if not value then
        return Usage(usage)
    end
    local id = FindOrSay(path)
    if not id then
        return
    end
    local lower = value:lower()
    if IsSame(lower) then
        if not Groups:Get(id).parent then
            return Print(L.G_ERR_TOP_SAME:format(Groups:GetPath(id)))
        end
        setter(id, nil)
        Print(message:format(Groups:GetPath(id), L.G_SAME_AS_ABOVE))
    elseif allowOff and (lower == "off" or lower == "none" or lower == "no") then
        setter(id, false)
        Print(message:format(Groups:GetPath(id), L.G_NO_CAP))
    else
        local number = tonumber(value)
        if not number then
            return Print(L.G_ERR_NUMBER)
        end
        setter(id, number)
        Print(message:format(Groups:GetPath(id), tostring(math.floor(number))))
    end
end

SUBCOMMANDS.keep = function(rest)
    SetNumber(rest, "/dem groups keep Herbs = 20   (or = same)", function(id, value)
        Groups:SetKeep(id, value)
    end, L.G_KEEP_SET, false)
end

SUBCOMMANDS.cap = function(rest)
    SetNumber(rest, "/dem groups cap Herbs = 100   (or = off, = same)", function(id, value)
        Groups:SetCap(id, value)
    end, L.G_CAP_SET, true)
end

local function SetSwitch(rest, enabled)
    local id = FindOrSay(rest)
    if id then
        Groups:SetEnabled(id, enabled)
        Print(L.G_TURNED:format(Groups:GetPath(id), enabled and L.ON or L.OFF))
    end
end

SUBCOMMANDS.on = function(rest)
    SetSwitch(rest, true)
end

SUBCOMMANDS.off = function(rest)
    SetSwitch(rest, false)
end

local function SetCheck(rest, checked)
    local id = FindOrSay(rest)
    if id then
        Groups:SetChecked(id, checked)
        Print(L.G_CHECKED_MSG:format(Groups:GetPath(id), checked and "checked" or "unchecked"))
    end
end

SUBCOMMANDS.check = function(rest)
    SetCheck(rest, true)
end

SUBCOMMANDS.uncheck = function(rest)
    SetCheck(rest, false)
end

SUBCOMMANDS.dry = function(rest)
    Groups:PrintPlan(Trim(rest):lower() == "all")
end

SUBCOMMANDS.list = function()
    Groups:PrintTree()
end
SUBCOMMANDS.dump = SUBCOMMANDS.list

local function PrintGroupsHelp()
    Print("group commands:")
    Print("  /dem groups - list your groups")
    Print("  /dem groups new Herbs > Northrend - make a group (and any missing groups above it)")
    Print("  /dem groups to Herbs = Name - who gets this group (= same: like the group above)")
    Print("  /dem groups keep Herbs = 20 - how many of each item stays in your bags")
    Print("  /dem groups cap Herbs = 100 - send at most this many of each item (= off)")
    Print("  /dem groups rename Herbs = Plants, move Northrend = Herbs (or = top), delete Herbs")
    Print("  /dem groups on|off Herbs - switch a group (and its subgroups) on or off")
    Print("  /dem groups check|uncheck Herbs - include it when sending from the Groups tab")
    Print("  /dem groups dry - show what would be sent (dry all: every group)")
    Print("  /dem add Herbs <shift-click items> - put items in a group")
    Print("  /dem remove <shift-click items> - take items out of their group")
end

function Groups:HandleSlash(input)
    local command, rest = Trim(input):match("^(%S*)%s*(.-)$")
    command = (command or ""):lower()
    if command == "" then
        return self:PrintTree()
    end
    local handler = SUBCOMMANDS[command]
    if handler then
        handler(rest or "")
    else
        PrintGroupsHelp()
    end
end

-- /dem add Herbs > Northrend [Peacebloom] [Silverleaf]
function Groups:HandleAdd(input)
    input = Trim(input)
    local cut = input:find("|", 1, true)
    local path, itemText
    if cut then
        path, itemText = Trim(input:sub(1, cut - 1)), input:sub(cut)
    else
        -- No links: trailing numbers are item IDs.
        path, itemText = input:match("^(.-)%s+([%d%s]+)$")
        path = path and Trim(path)
    end
    if not path or path == "" then
        return Usage("/dem add Herbs <shift-click items>")
    end
    local ids = ParseItems(itemText)
    if #ids == 0 then
        return Print(L.G_ERR_NO_ITEMS)
    end
    local id = FindOrSay(path)
    if not id then
        return
    end
    local added, moved = self:AddItems(id, ids)
    local msg = L.G_ADDED:format(added, self:GetPath(id))
    if moved > 0 then
        msg = msg .. " " .. L.G_MOVED_ITEMS:format(moved)
    end
    Print(msg)
end

-- /dem remove [Peacebloom]
function Groups:HandleRemove(input)
    local ids = ParseItems(input)
    if #ids == 0 then
        return Print(L.G_ERR_NO_ITEMS)
    end
    Print(L.G_REMOVED:format(self:RemoveItems(ids)))
end
