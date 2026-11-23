-- DE Mailer: EnchantConfirm.lua
-- Options > Disenchanting > Skip Replace Enchant Confirmation: when the game
-- asks "Do you want to replace X with Y?" after you enchant something that
-- already has an enchant, answer Yes for you.

local ADDON_NAME, ns = ...
local L = ns.L

L.SKIP_REPLACE        = "Skip Replace Enchant Confirmation"
L.SKIP_REPLACE_TIP    = "Don't ask before an enchant replaces one an item already has: answer Yes straight away."
L.SKIP_REPLACE_DONE   = "Replaced %s with %s."

-- The game's dialogs and what their Yes button does.
local DIALOGS = {
    REPLACE_ENCHANT            = "ReplaceEnchant",           -- your own gear
    TRADE_REPLACE_ENCHANT      = "ReplaceTradeEnchant",      -- an item in the trade window
    REPLACE_TRADESKILL_ENCHANT = "ReplaceTradeskillEnchant", -- from the profession window
}

local function Accept(which, oldEnchant, newEnchant)
    local name = DIALOGS[which]
    if not name or not (ns.db and ns.db.skipReplaceEnchant) then
        return
    end
    local accept = (C_Item and C_Item[name]) or _G[name]
    if not accept then
        return
    end
    accept()
    if StaticPopup_Hide then
        StaticPopup_Hide(which)
    end
    if type(oldEnchant) == "string" and type(newEnchant) == "string" then
        ns.Print(L.SKIP_REPLACE_DONE:format(oldEnchant, newEnchant))
    end
end

if StaticPopup_Show then
    hooksecurefunc("StaticPopup_Show", Accept)
end

function ns:SetSkipReplaceEnchant(enabled)
    self.db.skipReplaceEnchant = enabled and true or false
    self:OnSettingsChanged()
end
