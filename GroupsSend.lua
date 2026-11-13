-- DE Mailer: GroupsSend.lua
-- Sends mail groups: works out the whole send once (Groups:BuildPlan), then
-- goes through the recipients one after another, 12 attachments per letter.
-- Core.lua's send loop does the rest (sending, waiting, errors, "one letter
-- per click") exactly as it does for the Disenchant tab.

local ADDON_NAME, ns = ...
local L = ns.L
local Groups = ns.Groups

L.G_SUBJECT         = "Items from DE Mailer"
L.G_SEND_NOTHING    = "Nothing to send from your checked groups."
L.G_SEND_NOTHING_ALL = "Nothing to send from your groups."
L.G_NO_SPACE        = "Some partial stacks stayed behind (splitting needs a free slot in an ordinary bag)."
L.G_SPLIT_FAILED    = "a stack couldn't be split"

local SPLIT_TIMEOUT = 3 -- seconds to wait for a split stack to show up

local function Remaining(entry)
    local total = 0
    for _, count in pairs(entry.remaining) do
        total = total + count
    end
    return total
end

-- An empty slot in an ordinary bag (not a herb or mining bag).
local function FindEmptySlot(exceptBag, exceptSlot)
    for bag = ns.FIRST_BAG, ns.LAST_BAG do
        local free, family = C_Container.GetContainerNumFreeSlots(bag)
        if (free or 0) > 0 and (family == nil or family == 0) then
            for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
                if not C_Container.GetContainerItemInfo(bag, slot)
                    and not (bag == exceptBag and slot == exceptSlot) then
                    return bag, slot
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Starting
-------------------------------------------------------------------------------

-- Sends the checked groups (or every group when all is true). Returns true,
-- or false and the reason it can't start.
function ns:StartGroups(trigger, fromClick, all)
    local run = self.run
    if run then
        if run.state == "paused" then
            self:SendNextLetter(fromClick)
            return true
        end
        return false
    end
    if not self:IsMailOpen() then
        return false, L.NEED_MAILBOX
    end
    if GameLimitedMode_IsActive and GameLimitedMode_IsActive() then
        return false, L.TRIAL
    end
    if ns.CountAttachments() > 0 then
        return false, L.HAS_ATTACHMENTS
    end
    if ns.HasPendingMoney() then
        return false, L.HAS_MONEY
    end
    if CursorHasItem() then
        return false, L.CURSOR
    end

    local plan = Groups:BuildPlan(all)
    if plan.items == 0 then
        return false, all and L.G_SEND_NOTHING_ALL or L.G_SEND_NOTHING
    end

    -- How much of each item goes to each recipient, decided now so that
    -- "send at most" counts once per send, not once per letter.
    local queue = {}
    for _, entry in ipairs(plan.recipients) do
        local item = { name = entry.name, remaining = {}, order = {} }
        for _, attachment in ipairs(entry.attachments) do
            if not item.remaining[attachment.itemID] then
                item.remaining[attachment.itemID] = 0
                item.order[#item.order + 1] = attachment.itemID
            end
            item.remaining[attachment.itemID] = item.remaining[attachment.itemID] + attachment.count
        end
        queue[#queue + 1] = item
    end

    self:SetMessage(nil)
    self.run = {
        trigger = trigger,
        groups = {
            queue = queue,
            index = 1,
            split = {},    -- [itemID] = { bag, slot, count, fromBag, fromSlot } once split
            letter = {},   -- what the letter on its way holds: [itemID] = count
            sentTo = {},   -- recipients that got something, in order
        },
        recipient = queue[1].name,
        subject = L.G_SUBJECT,
        totalLetters = plan.letters,
        letters = 0,
        items = 0,
        attached = 0,
        token = 0,
        state = "starting",
    }
    self:SendNextLetter(fromClick)
    return true
end

function ns:CountGroupItemsLeft()
    local run = self.run
    if not (run and run.groups) then
        return 0
    end
    local total = 0
    for _, entry in ipairs(run.groups.queue) do
        total = total + Remaining(entry)
    end
    return total
end

-- "Alchy and Smith", for the messages at the end.
function ns:GroupRecipientsText(run)
    local names = run.groups.sentTo
    if #names == 0 then
        return run.recipient or ""
    elseif #names == 1 then
        return names[1]
    end
    return table.concat(names, ", ", 1, #names - 1) .. " " .. L.DE_AND .. " " .. names[#names]
end

-------------------------------------------------------------------------------
-- Choosing stacks for a letter
-------------------------------------------------------------------------------

-- Stacks for one item: the stack split off for it (if any) first, then whole
-- stacks biggest first. The stack the split came from is left alone, so this
-- picks the same stacks the plan did. Returns the picks and what's still
-- missing (which needs a split).
local function PickForItem(stacks, need, split, room)
    local picks = {}
    local sorted = {}
    for _, stack in ipairs(stacks) do
        local isSplit = split and stack.bag == split.bag and stack.slot == split.slot
        local isSource = split and stack.bag == split.fromBag and stack.slot == split.fromSlot
        if isSplit then
            if #picks < room and stack.count <= need then
                picks[#picks + 1] = stack
                need = need - stack.count
            end
        elseif not isSource then
            sorted[#sorted + 1] = stack
        end
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
    local unused = {}
    for _, stack in ipairs(sorted) do
        if #picks < room and need > 0 and stack.count <= need then
            picks[#picks + 1] = stack
            need = need - stack.count
        else
            unused[#unused + 1] = stack
        end
    end
    -- If something's still missing, the smallest stack bigger than it gets split.
    local splitFrom
    if need > 0 then
        for i = #unused, 1, -1 do
            if unused[i].count > need then
                splitFrom = unused[i]
                break
            end
        end
    end
    return picks, need, splitFrom
end

-- Splits `amount` off a stack into an empty bag slot, then carries on with
-- the letter once the new stack has appeared.
function ns:SplitForGroups(itemID, stack, amount)
    local run = self.run
    local g = run.groups
    local bag, slot = FindEmptySlot(stack.bag, stack.slot)
    if not bag then
        return false
    end
    run.state = "splitting"
    self:Notify()
    C_Container.SplitContainerItem(stack.bag, stack.slot, amount)
    if not CursorHasItem() then
        return false
    end
    C_Container.PickupContainerItem(bag, slot)
    if CursorHasItem() then
        ClearCursor()
        return false
    end
    g.split[itemID] = { bag = bag, slot = slot, count = amount, fromBag = stack.bag, fromSlot = stack.slot }

    local started = GetTime()
    local function check()
        if self.run ~= run or run.state ~= "splitting" then
            return
        end
        local info = C_Container.GetContainerItemInfo(bag, slot)
        local source = C_Container.GetContainerItemInfo(stack.bag, stack.slot)
        if info and info.itemID == itemID and info.stackCount == amount and not info.isLocked
            and not (source and source.isLocked) then
            self:SendNextLetter(false)
        elseif GetTime() - started > SPLIT_TIMEOUT then
            self:Finish("failed", L.G_SPLIT_FAILED)
        else
            C_Timer.After(0.1, check)
        end
    end
    C_Timer.After(0.1, check)
    return true
end

-------------------------------------------------------------------------------
-- One letter
-------------------------------------------------------------------------------

-- Called by Core.lua's SendNextLetter after its safety checks.
function ns:SendNextGroupLetter(fromClick)
    local run = self.run
    local g = run.groups
    local max = ns.MAX_ATTACHMENTS

    -- Move on past recipients who have everything.
    while g.queue[g.index] and Remaining(g.queue[g.index]) == 0 do
        g.index = g.index + 1
    end
    local entry = g.queue[g.index]
    if not entry then
        return self:Finish("done")
    end
    run.recipient = entry.name

    -- Fill a letter from what's in the bags right now.
    local stacks = Groups:ScanBags()
    local picks = {}
    for _, itemID in ipairs(entry.order) do
        local need = entry.remaining[itemID]
        if need > 0 and #picks < max then
            local list = stacks[itemID]
            if not list then
                entry.remaining[itemID] = 0 -- gone from the bags since the plan
            else
                local split = g.split[itemID]
                if split and split.used then
                    split = nil -- already sent; plan the rest from whole stacks
                end
                local chosen, missing, splitFrom = PickForItem(list, need, split, max - #picks)
                if missing > 0 and #picks + #chosen < max then
                    if splitFrom and not g.split[itemID] then
                        -- Split first, then plan this letter again.
                        if self:SplitForGroups(itemID, splitFrom, missing) then
                            return
                        end
                        if self.run ~= run then
                            return
                        end
                        run.state = "attaching"
                    end
                    -- Can't split (no room, or it already was): send what fits.
                    entry.remaining[itemID] = need - missing
                    g.noSpace = true
                end
                for _, stack in ipairs(chosen) do
                    picks[#picks + 1] = { itemID = itemID, stack = stack }
                end
            end
        end
    end

    if #picks == 0 then
        -- Nothing could be found for this recipient; move on.
        for itemID in pairs(entry.remaining) do
            entry.remaining[itemID] = 0
        end
        return self:SendNextGroupLetter(fromClick)
    end

    run.state = "attaching"
    SetSendMailShowing(true)
    wipe(g.letter)
    local attached = 0
    for _, pick in ipairs(picks) do
        local slotIndex = ns.FirstFreeAttachmentSlot()
        if not slotIndex then
            break
        end
        local stack, itemID = pick.stack, pick.itemID
        C_Container.PickupContainerItem(stack.bag, stack.slot)
        local ok = CursorHasItem()
        if ok then
            ClickSendMailItemButton(slotIndex)
            if CursorHasItem() then
                ClearCursor()
                ok = false
            end
        end
        if ok then
            attached = attached + 1
            g.letter[itemID] = (g.letter[itemID] or 0) + stack.count
            local split = g.split[itemID]
            if split and split.bag == stack.bag and split.slot == stack.slot then
                split.used = true
            end
        else
            -- The mailbox won't take it: skip this item from now on.
            self.unmailable[itemID] = true
            entry.remaining[itemID] = 0
            run.skipped = true
        end
    end

    if attached == 0 then
        return self:SendNextGroupLetter(fromClick)
    end

    if ns.CountAttachments() >= attached then
        self:DoSend(fromClick)
    else
        local started = GetTime()
        local function check()
            if self.run ~= run or run.state ~= "attaching" then
                return
            end
            if ns.CountAttachments() >= attached or GetTime() - started > 2 then
                self:DoSend(false)
            else
                C_Timer.After(0.1, check)
            end
        end
        C_Timer.After(0.1, check)
        self:Notify()
    end
end

-- A letter arrived: take its items off what's left. Returns how many items it held.
function ns:OnGroupLetterSent()
    local g = self.run.groups
    local entry = g.queue[g.index]
    local total = 0
    for itemID, count in pairs(g.letter) do
        entry.remaining[itemID] = math.max(0, (entry.remaining[itemID] or 0) - count)
        total = total + count
    end
    wipe(g.letter)
    local seen = false
    for _, name in ipairs(g.sentTo) do
        if name == entry.name then
            seen = true
        end
    end
    if not seen and total > 0 then
        g.sentTo[#g.sentTo + 1] = entry.name
    end
    return total
end
