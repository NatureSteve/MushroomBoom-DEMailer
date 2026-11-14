# DE Mailer: Mail Groups — plan

Status: **steps 0–5 done (2026-11-14), waiting for an in-game check.** Step 6 (README
and the 1.4.0 version bump) is left. Covered by automated tests run outside the game
(Lua 5.1 with a simulated WoW API): 26 for the existing features, 17 for group data and
sending, and 7 for the group editor and the Groups tab. This file is not loaded by the
game or included in releases.

Release name for 1.4.0: **DE Mail Groups** (the `## X-Release-Title:` line in
`DEMailer.toc`; remove or change it for the next version).

## Goal

Let you put items into named groups, give each group a recipient, and send every
group's items from the mailbox in one press. Example: "Herbs → Alchemistalt",
"Cloth → Tailoralt", "Ore and bars → Smithalt".

The existing disenchant mailing keeps working exactly as it does today, on its own
tab. Groups are a separate feature on a second tab and share only the send loop.

## Working method: independent implementation, not a port

TradeSkillMaster's code is "All Rights Reserved"; you can modify it for yourself
but not share derived work. To keep DE Mailer free of that:

1. **Ideas only.** What we take from TSM is the *behavior* a user sees: groups hold
   items, each item is in at most one group, a mail rule says who gets it, how many
   to keep, and an optional cap. Features and ideas aren't owned; code is.
2. **No TSM code, names or formats.** No Lua is copied, paraphrased line by line or
   translated. No TSM module names, settings keys, data layouts, group-path syntax
   (TSM's backtick paths) or import-string format.
3. **Written from this spec, in DE Mailer's own style.** Same `ns` namespace,
   same plain-frame UI built from the game's templates, same event handling and
   send loop already in `Core.lua`. No libraries.
4. **Much smaller design.** TSM uses a database engine, reactive state, threads and
   an operation framework (thousands of lines). DE Mailer needs a table of groups
   and a function that works out what to send.

Honest caveat: this isn't a formal "clean room" (that needs one person to write the
spec and a different one, who never saw the code, to implement it). I read TSM's
mailing code to learn its behavior. The protection here is that the result shares
no code, structure or data format with it. This is a practical precaution, not legal
advice.

## What the feature does (spec)

### Groups
- A group has: a name, an optional parent group, a recipient, an on/off switch,
  and a list of items.
- **Subgroups:** groups form a tree, e.g. Herbs > Northrend. Each group stores its
  parent's ID (not a path string), so renaming or moving a group never touches its
  children or items.
- **Inherited settings:** recipient, keep and cap each either use the parent's value
  ("Same as Herbs", the default for a new subgroup) or are set on the subgroup.
  A top-level group with nothing set has no recipient and sends nothing.
- **Items belong to exactly one group, at any level.** A parent's own items and its
  subgroups' items are separate lists. Adding an item to another group moves it.
- **Selecting a parent includes its subgroups** when sending. A subgroup that's
  switched off is skipped even if its parent is selected.
- **Moving a group** (right-click > Move to...) takes its subgroups and items along.
  A group can't be moved under itself or one of its own subgroups.
- **Deleting a group** asks whether its items and subgroups go up to its parent or
  are deleted with it.
- A depth limit (5 levels) keeps the list readable.
- Items are matched by **item ID**. Different versions of the same item (random
  enchant suffixes on gear) count as the same item.
- Recipient names are stored per realm and faction, like the enchanter is today.
  The same group can have a different recipient on another realm.

### Mail rule (per group)
- **Keep:** how many of each item to leave in your bags (default 0).
- **Send at most:** optional cap per item per send (off by default).
- Each item uses the rule of the group it's in, after inheritance is applied.
- If the recipient is the character you're on, the group is skipped.
- Soulbound, account-bound, refundable or quest items are never sent, as today.

Not in v1: "restock" (send only what the recipient is missing). It needs counts
from your other characters, which means tracking every character's bags, bank and
mail. Could come later.

### Working out what to send
For each selected, enabled group (and its enabled subgroups) whose resolved
recipient isn't empty:
1. Count each of its items across your bags.
2. Amount to send = count − keep, limited by the cap, never below 0.
3. Pick whole stacks first. If only part of a stack should go, split it into an
   empty bag slot first (needs one free slot; otherwise send what fits in whole
   stacks and say so).
4. Group the result by recipient. One recipient's items fill letters 12 at a time.

The existing send loop in `Core.lua` (attach, send, wait for `MAIL_SEND_SUCCESS`,
next letter, the "one letter per click" fallback, stop, errors) is reused. It
changes from "one recipient, a list of bag slots" to "a queue of (recipient, slots)".

### Putting items into groups
- **Alt-click an item in your bags** while the group editor is open: adds it to the
  selected group.
- **Drag an item** onto a group in the editor.
- **Type or paste a link:** `/dem add <group> <item link>`.
- **Right-click an item in the group list** to remove it.
- Tooltip line on any item that's in a group: "DE Mailer: Herbs → Alchemistalt".

### Where it shows up
- **Two mailbox tabs:** the existing **Disenchant** tab stays exactly as it is. A new
  **Groups** tab sits next to it with its own count, e.g. "Groups (37)". It shows the
  group tree (expand/collapse, checkbox, name, resolved recipient, number of items
  ready), the item grid for what will go out, its own "Send automatically" option,
  and a Send button that sends all checked groups. The two tabs never send at the
  same time; if one is sending, the other's button waits.
- **Group editor window:** a standalone window (`/dem groups`, minimap menu,
  Options button, or an "Edit Groups" button on the Groups tab) to create, rename,
  move and delete groups, set recipient/keep/cap, and add items. Works away from
  the mailbox.
- **Options panel:** a "Mail Groups" section with a button to open the editor.

### Saved data (new keys in `DEMailerDB`, existing keys unchanged)
```lua
groups = {
    -- keyed by ID; keep/cap = nil means "same as parent"
    [1] = { name = "Herbs", parent = nil, order = 1, enabled = true,
            keep = 0, cap = nil, items = { [765] = true } },
    [2] = { name = "Northrend", parent = 1, order = 1, enabled = true,
            keep = nil, cap = nil, items = { [36901] = true } },
},
-- per realm/faction; a missing entry means "same as parent"
groupRecipients = { ["Realm-Faction"] = { [1] = "Alchemistalt" } },
groupsSelected = { [1] = true },   -- checkboxes on the Groups tab
groupsCollapsed = {},              -- tree state in the list and editor
groupsAutoSend = false,
nextGroupId = 3,
```
An item → group lookup is built in memory when the addon loads and whenever groups
change. It isn't saved.
The existing settings (enchanter, qualities, kept items) stay where they are, so
nothing you've set up is lost.

## Files

| File | Change |
|---|---|
| `Groups.lua` (new) | Group tree: create, rename, move, delete, add/remove items, inheritance, item → group lookup, the "what to send" calculation |
| `GroupsFrame.lua` (new) | The group editor window, bag alt-click hook (best effort: bag buttons the game made before the addon loaded don't carry it), drag-and-drop, tooltip line |
| `GroupsTab.lua` (new) | The Groups mailbox tab |
| `GroupsSend.lua` (new) | Sending groups: plan once, then letters per recipient; splits a partial stack into a free bag slot (at most one split per item) |
| `Core.lua` | Small hooks so its send loop handles group runs; new slash commands, defaults |
| `UI.lua` | Small changes so two DE Mailer tabs sit side by side and hide each other correctly |
| `Options.lua` | "Mail Groups" section |
| `Minimap.lua` | "Open Mail Groups" in the right-click menu |
| `DEMailer.toc` | Load the three new files; version 1.4.0 |
| `README.md` | Document the feature |

## Steps

0. (done) Back up the `DEMailer` folder (it isn't in git) to `DEMailer_backup_1.3.0` outside
   `AddOns`, so the game doesn't load it twice.
1. (done) `Groups.lua`: group tree, inheritance and the send calculation, with a
   `/dem groups dump` debug print so it can be checked in game before any mail goes out.
2. (done) Send queue (`GroupsSend.lua` + hooks in `Core.lua`): several recipients per run, stack splitting. Disenchant
   sending keeps working exactly as now.
3. (done) A **dry run** (`/dem groups dry`) that prints what would go to whom without sending.
4. (done) Group editor window and ways to add items.
5. (done) Groups mailbox tab, Options and minimap changes.
6. README and version bump.

## How it'll be checked

There's no way to run WoW from here, so each step ends with you testing in game:
- `/reload` with no errors (`/console scriptErrors 1`).
- Dry run output matches what you expect for a few groups, including keep and cap.
- A real send of one small group to an alt, including a partial stack.
- Disenchant sending still behaves exactly as before.

## Decisions (settled 2026-11-12)

1. **Subgroups:** yes, with inherited recipient/keep/cap.
2. **Restock:** left out of v1.
3. **Mailbox tabs:** two. "Disenchant" stays as is; a new "Groups" tab is added.
4. **TSM import:** no. DE Mailer stays fully independent of TSM.
5. **Backup:** copy the folder before step 1 (step 0).
