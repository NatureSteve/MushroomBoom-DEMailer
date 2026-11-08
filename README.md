# DE Mailer

Mails the disenchantable gear in your bags to your enchanter, right from the mailbox, and gives your enchanter a Disenchanting window to work through it. Made for World of Warcraft: Forever.

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

## Options and minimap

The same settings are also available away from the mailbox:

- **Options window:** press Esc, choose **Options**, open the **AddOns** tab and pick **DE Mailer**.
  - **Enchanter:** click the button to type a name.
  - **Item Qualities:** Uncommon, Rare and Epic, for both mailing and disenchanting.
  - **Send Automatically**.
  - **Items You Keep:** reset to send kept items again.
  - **Disenchanting Window** and **Open When You Pick Up Gear** (see below).
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

## Good to know

- Normal postage applies.
- DE Mailer won't touch a letter you've started yourself. If your Send Mail tab already has items attached, send it or take them off first.
- If the game only allows one letter per click, the button changes to **Send Next Letter**. Press it once for each letter.
- After a game patch the addon may show as "out of date". To fix it, type `/dump select(4, GetBuildInfo())` in chat and put that number on the `## Interface:` line of `DEMailer.toc`.
- If something goes wrong, type `/console scriptErrors 1` so the game shows error messages.
