-- DE Mailer: Prices.lua
-- Disenchant value from an auction addon you already have installed. DE
-- Mailer keeps no prices of its own: it asks the addon picked in Options >
-- Disenchanting > Price Source for each possible material and adds them up,
-- weighted by how often each one drops.

local ADDON_NAME, ns = ...
local L = ns.L

local Prices = {}
ns.Prices = Prices

L.PRICE_SOURCE         = "Price Source"
L.PRICE_SOURCE_TIP     = "Where disenchant values come from. Shown in item tooltips and the Disenchanting window. Needs the auction addon to be installed and to have scanned the Auction House."
L.PRICE_NONE           = "None"
L.PRICE_NONE_TIP       = "Don't show disenchant values."
L.PRICE_MISSING        = "%s (not loaded)"
L.PRICE_VALUE          = "Disenchant value:"
L.PRICE_VALUE_SHORT    = "Value: %s"
L.PRICE_NO_DATA        = "no auction data"
L.PRICE_VALUE_TIP      = "The average a disenchant is worth at %s prices. Each disenchant varies."
L.PRICE_PARTIAL        = "Some materials have no price yet, so the real value may be higher."
L.PRICE_EACH           = "%s each at the Auction House (%s)."

local function FromAuctionator(itemID)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not (api and api.GetAuctionPriceByItemID) then
        return nil
    end
    local ok, price = pcall(api.GetAuctionPriceByItemID, ADDON_NAME, itemID)
    return ok and price or nil
end

-- TradeSkillMaster's public price API, with one of its own price names.
local function FromTSM(priceName)
    return function(itemID)
        if not (TSM_API and TSM_API.GetCustomPriceValue) then
            return nil
        end
        local ok, price = pcall(TSM_API.GetCustomPriceValue, priceName, "i:" .. itemID)
        return ok and price or nil
    end
end

local function HasAuctionator()
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    return api ~= nil and api.GetAuctionPriceByItemID ~= nil
end

local function HasTSM()
    return TSM_API ~= nil and TSM_API.GetCustomPriceValue ~= nil
end

local SOURCES = {
    { key = "auctionator",  label = "Auctionator",                 available = HasAuctionator, price = FromAuctionator },
    { key = "tsm_market",   label = "TradeSkillMaster: Market Value", available = HasTSM,      price = FromTSM("DBMarket") },
    { key = "tsm_minbuyout", label = "TradeSkillMaster: Min Buyout",  available = HasTSM,      price = FromTSM("DBMinBuyout") },
    { key = "tsm_recent",   label = "TradeSkillMaster: Recent Value", available = HasTSM,      price = FromTSM("DBRecent") },
}
local BY_KEY = {}
for _, source in ipairs(SOURCES) do
    BY_KEY[source.key] = source
end
Prices.SOURCES = SOURCES

-- The picked source, if it's installed right now.
function Prices.GetSource()
    local key = ns.db and ns.db.disenchant.priceSource
    local source = key and BY_KEY[key]
    if source and source.available() then
        return source
    end
end

function Prices.IsEnabled()
    return Prices.GetSource() ~= nil
end

-- For the Options dropdown: None, then every source (marked when its addon
-- isn't loaded, so a saved choice still shows up).
function Prices.Options()
    local list = { { value = "none", label = L.PRICE_NONE, tip = L.PRICE_NONE_TIP } }
    for _, source in ipairs(SOURCES) do
        local label = source.available() and source.label or L.PRICE_MISSING:format(source.label)
        list[#list + 1] = { value = source.key, label = label }
    end
    return list
end

function ns:SetPriceSource(key)
    self.db.disenchant.priceSource = BY_KEY[key] and key or "none"
    self:OnSettingsChanged()
end

-- One material's auction price in copper, or nil.
function Prices.MaterialPrice(itemID)
    local source = Prices.GetSource()
    if not source then
        return nil
    end
    local price = source.price(itemID)
    if type(price) == "number" and price > 0 then
        return price
    end
end

-- The average worth of one disenchant, from ns.PossibleMaterials' list.
-- Returns the value in copper (nil if no material has a price) and whether
-- some materials had no price.
function Prices.DisenchantValue(materials)
    if not materials or not Prices.GetSource() then
        return nil
    end
    local total, priced, missing = 0, false, false
    for _, entry in ipairs(materials) do
        local price = Prices.MaterialPrice(entry.itemID)
        if price then
            local count = entry.min and ((entry.min + (entry.max or entry.min)) / 2) or 1
            total = total + price * count * entry.chance / 100
            priced = true
        else
            missing = true
        end
    end
    if not priced then
        return nil, missing
    end
    return total, missing
end

-- "1g 23s" with coin icons; whole silver once it's over a gold.
function Prices.MoneyText(copper)
    copper = math.floor(copper + 0.5)
    if copper >= 10000 then
        copper = copper - copper % 100
    end
    if GetMoneyString then
        return GetMoneyString(copper, true)
    end
    return ("%dg %ds %dc"):format(copper / 10000, (copper / 100) % 100, copper % 100)
end

function Prices.SourceLabel()
    local source = Prices.GetSource()
    return source and source.label or ""
end
