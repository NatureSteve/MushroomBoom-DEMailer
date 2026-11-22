# DE Mailer

Mails the disenchantable gear in your bags to your enchanter, right from the mailbox, and gives your enchanter a Disenchanting window to work through it. **Mail groups** send everything else to the right character too: herbs to your alchemist, cloth to your tailor, ore to your smith. Made for World of Warcraft: Forever.

## Install

1. Close the game.
2. Copy the `DEMailer` folder into `World of Warcraft\_forever_\Interface\AddOns\`.
   You should end up with `...\AddOns\DEMailer\DEMailer.toc`.
3. Start the game. On the character screen, click **AddOns** and make sure **DE Mailer** is checked.

## Use

1. Open any mailbox. There's a new **Disenchant** tab next to Inbox and Send Mail.
   It shows how many items are ready, for example "Disenchant (14)".
2. Type your enchanter's name in **Send to:**. It's remembered for each realm and faction.
3. Press **Send**. Items go out 12 per letter, one letter after another.

Other options on the tab:

- **Include:** choose Uncommon, Rare and/or Epic. Epic is off by default.
- **Click an item** to keep it. It stays in your bags and is greyed out with a red X. Click it again to send it after all.
- **Send automatically when I open a mailbox:** sends without a click. Hold **Shift** while opening the mailbox to skip it once.

## Mail groups

Put items into your own groups, choose who gets each group, and send them all from the mailbox with one press.

**Make groups** in the **Mail Groups** editor. To open it, use **Edit Groups** on the Groups tab, **Open Mail Groups** in the minimap button's menu, the button in the options, or `/dem groups edit`.

- **New Group** and **New Subgroup** make groups. Groups can sit inside each other, up to five levels (for example Herbs > Northrend).
- **Send to**, **Keep** and **Send at most** are set per group:
  - **Keep** is how many of each item stays in your bags.
  - **Send at most** limits each item per send (0 means no limit).
  - Leave a box empty to use the group above; a grey line shows what that is.
- **Add items** by dragging them onto a group or into its item area, or by Alt-clicking them in your bags while the editor is open. An item can be in only one group.
- **Right-click a group** to rename it, move it (with everything inside it), switch it off, or delete it. When deleting, choose whether its items and subgroups move up a level or go too.
- **Right-click an item** in the editor to take it out of the group.
- Item tooltips show which group an item is in and who gets it.

**Send them** from the new **Groups** tab on the mailbox, next to Disenchant:

- Tick the groups to send. A ticked group includes the groups inside it, and a switched-off group is never sent.
- The tab shows who gets each group, how much is ready, and the items going out. Press **Send**.
- Each recipient gets their own letters, 12 attachments each. When only part of a stack should go, DE Mailer splits it into a free bag slot first, which needs one empty slot in an ordinary bag.
- **Send checked groups when I open a mailbox** sends without a click, right after the Disenchant tab's automatic send. Hold **Shift** while opening the mailbox to skip it once.
- Recipients are remembered separately for each realm and faction.

Group commands: `/dem groups help` lists them all. The most useful:

- `/dem groups`: list your groups
- `/dem groups dry`: show what would be sent, without sending (`dry all` for every group)
- `/dem groups send`: send your checked groups now, at a mailbox (`send all` for every group)
- `/dem add Herbs [item]`: put shift-clicked items in a group

## Options and minimap

The same settings are also available away from the mailbox:

- **Options window:** press Esc, choose **Options**, open the **AddOns** tab and pick **DE Mailer**.
  - **Enchanter:** click the button to type a name.
  - **Item Qualities:** Uncommon, Rare and Epic, for both mailing and disenchanting.
  - **Send Automatically**.
  - **Items You Keep:** reset to send kept items again.
  - **Send Groups Automatically** and a button to open the **Group Editor**.
  - **Disenchanting Window**, **Open When You Pick Up Gear** and **Show Materials in Tooltips** and **Price Source** (see below).
  - **Show Minimap Button**.
- **Minimap button:**
  - Left-click opens the options.
  - Right-click shows quick settings: enchanter, qualities, automatic sending and the button itself.
  - Drag it to move it around the edge of the minimap.
- **The minimap's AddOns menu** also lists DE Mailer and works the same way, even if you hide the minimap button.

## Disenchanting window

On characters that know Disenchant, DE Mailer records disenchantable gear as you pick it up: looting, taking it out of the mailbox, or trades. It lists that gear in its own **Disenchanting** window.

- **To open it**, use any of these:
  - Shift-click the minimap button.
  - Choose **Open Disenchanting** in the minimap button's right-click menu.
  - Type `/dem de`.
  - Set a key in Esc > Options > Keybindings > AddOns.
- **The next item** is shown at the top. Press **Disenchant** once for each item. For a key instead, bind **Disenchant next item** in Keybindings.
- **Possible materials** under the next item shows what it usually gives: the chance, the material and how many. Hover a line to see the material.
- **Tooltips:** every disenchantable item's tooltip lists the same possible materials under "Disenchants into:". Turn this off with **Show Materials in Tooltips** in the options.
- **Disenchant value:** pick an auction addon under **Price Source** in the options (Auctionator, or TradeSkillMaster's Market Value, Min Buyout or Recent Value). The window then shows the next item's value beside Possible materials and each item's value in the list, and tooltips add a "Disenchant value:" line. It's the average a disenchant is worth: each material's price, weighted by its chance and count. DE Mailer keeps no prices itself, so the auction addon must be installed and have scanned the Auction House. **None** (the default) hides values.
- **This session** shows the materials you've got and how many items you've disenchanted.
- **In the list**, click an item to keep it (it's greyed out and is never mailed or disenchanted). Right-click an item to take it off the list.
- **Add from Bags** adds disenchantable gear that was already in your bags before recording started.
- If an item can't be disenchanted (for example, your Enchanting skill is too low), the reason is shown. After two tries the item is skipped for this session.
- The window closes during combat and comes back afterwards.
- To turn it off, or have it open when you pick up gear, go to Options > AddOns > DE Mailer > Disenchanting.

What's listed: the same weapons and armor as for mailing, in the qualities you chose. Soulbound gear is included, since it can be disenchanted. It never lists:

- gear in one of your equipment sets
- items you can still refund at a vendor
- gear you already had before recording started, or took out of your bank, unless you add it with **Add from Bags**

## What gets sent

Weapons and armor (including rings, necks, trinkets and off-hands) of the qualities you chose that aren't soulbound. It never sends:

- soulbound or account-bound items
- cosmetic items, shirts, tabards or fishing poles
- items you can still sell back to a vendor for a refund
- items you chose to keep

Possible materials come from WoW Forever's disenchanting table: green armor gives mostly dust, green weapons mostly essence, blue items a shard, and purple items shards or a Nexus Crystal. The chances are typical values from WoW-Professions' WoW Forever guide, as compiled by forevermastery.com. Each disenchant varies.

## Slash commands

- `/dem to Name`: set your enchanter
- `/dem send`: send now (at a mailbox)
- `/dem auto`: turn automatic sending on or off
- `/dem reset`: send every item you chose to keep again
- `/dem options`: open DE Mailer in the Options window
- `/dem minimap`: show or hide the minimap button
- `/dem de`: open or close the Disenchanting window
- `/dem groups ...`: mail groups (see above)

## Good to know

- Normal postage applies.
- DE Mailer won't touch a letter you've started yourself. If your Send Mail tab already has items attached, send it or take them off first.
- If the game only allows one letter per click, the button changes to **Send Next Letter**. Press it once for each letter.
