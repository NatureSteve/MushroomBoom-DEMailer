-- DE Mailer: Prices.lua
-- Disenchant value from MushroomBoom AHDB. DE Mailer keeps no prices of
-- its own: it asks AHDB, using the price picked in Options >
-- Disenchanting > Price Source, for each possible material and adds them up,
-- weighted by how often each one drops.

local ADDON_NAME, ns = ...
local L = ns.L

local Prices = {}
ns.Prices = Prices

L.PRICE_SOURCE         = "Price Source"
L.PRICE_SOURCE_TIP     = "Where disenchant values come from. Shown in item tooltips and the Disenchanting window. Prices come from the MushroomBoom AHDB addon, for your own auction house."
L.PRICE_NONE           = "None"
L.PRICE_NONE_TIP       = "Don't show disenchant values."
L.PRICE_MISSING        = "%s (not loaded)"
L.PRICE_VALUE          = "Disenchant value:"
L.PRICE_VALUE_SHORT    = "Value: %s"
L.PRICE_NO_DATA        = "no auction data"
L.PRICE_VALUE_TIP      = "The average a disenchant is worth at %s prices. Each disenchant varies."
L.PRICE_PARTIAL        = "Some materials have no price yet, so the real value may be higher."
L.PRICE_EACH           = "%s each at the Auction House (%s)."

-- MushroomBoom AHDB's public API (global MushroomBoomAHDB): copper per
-- unit at this character's own auction house, or nil.
local function FromAHDB(priceName)
    return function(itemID)
        local api = MushroomBoomAHDB
        if not (api and api.GetPrice) then
            return nil
        end
        local ok, price = pcall(api.GetPrice, itemID, priceName)
        return ok and price or nil
    end
end

local function HasAHDB()
    return MushroomBoomAHDB ~= nil and MushroomBoomAHDB.GetPrice ~= nil
end

local SOURCES = {
    { key = "ahdb_market", label = "AHDB: Market Value",    available = HasAHDB, price = FromAHDB("market") },
    { key = "ahdb_min",    label = "AHDB: Min Buyout",      available = HasAHDB, price = FromAHDB("min") },
    { key = "ahdb_avg3",   label = "AHDB: 3-Day Average",   available = HasAHDB, price = FromAHDB("avg3") },
    { key = "ahdb_avg14",  label = "AHDB: 14-Day Average",  available = HasAHDB, price = FromAHDB("avg14") },
}
local BY_KEY = {}
for _, source in ipairs(SOURCES) do
    BY_KEY[source.key] = source
end
Prices.SOURCES = SOURCES

-- The saved choice; one this version doesn't know (from an older build)
-- counts as the default.
function Prices.CurrentKey()
    local key = ns.db and ns.db.disenchant.priceSource
    if key == "none" or BY_KEY[key] then
        return key
    end
    return ns.DEFAULTS.disenchant.priceSource
end

-- The picked source, if it's installed right now.
function Prices.GetSource()
    local source = BY_KEY[Prices.CurrentKey()]
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
