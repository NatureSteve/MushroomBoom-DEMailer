-- DE Mailer: DisenchantData.lua
-- What disenchanting usually gives on WoW Forever, used for the "Possible
-- materials" lines in the Disenchanting window.
--
-- Rows follow the game's own disenchant table, which goes by item level:
-- 5-15, then steps of 5 up to 56-60, then 61 and up. Materials, counts and
-- typical chances come from WoW-Professions' WoW Forever disenchanting guide,
-- as compiled by forevermastery.com (read November 2026):
--   Green armor: 75% dust, 20% essence, 3-5% shard (5% used here).
--   Green weapons: 75% essence, 20% dust, 3-5% shard.
--   Blue: always one shard; a Nexus Crystal about 0.5% of the time at 56+.
--   Purple (item level 40+): shards up to item level 55, a Nexus Crystal above.
-- Each disenchant varies; these are averages, not promises.

local ADDON_NAME, ns = ...

local STRANGE_DUST, SOUL_DUST, VISION_DUST, DREAM_DUST, ILLUSION_DUST = 10940, 11083, 11137, 11176, 16204
local LESSER_MAGIC, GREATER_MAGIC = 10938, 10939
local LESSER_ASTRAL, GREATER_ASTRAL = 10998, 11082
local LESSER_MYSTIC, GREATER_MYSTIC = 11134, 11135
local LESSER_NETHER, GREATER_NETHER = 11174, 11175
local LESSER_ETERNAL, GREATER_ETERNAL = 16202, 16203
local SMALL_GLIMMERING, LARGE_GLIMMERING = 10978, 11084
local SMALL_GLOWING, LARGE_GLOWING = 11138, 11139
local SMALL_RADIANT, LARGE_RADIANT = 11177, 11178
local SMALL_BRILLIANT, LARGE_BRILLIANT = 14343, 14344
local NEXUS_CRYSTAL = 20725

-- English names, used until the game has the item's own (localized) name.
local NAMES = {
    [STRANGE_DUST] = "Strange Dust", [SOUL_DUST] = "Soul Dust", [VISION_DUST] = "Vision Dust",
    [DREAM_DUST] = "Dream Dust", [ILLUSION_DUST] = "Illusion Dust",
    [LESSER_MAGIC] = "Lesser Magic Essence", [GREATER_MAGIC] = "Greater Magic Essence",
    [LESSER_ASTRAL] = "Lesser Astral Essence", [GREATER_ASTRAL] = "Greater Astral Essence",
    [LESSER_MYSTIC] = "Lesser Mystic Essence", [GREATER_MYSTIC] = "Greater Mystic Essence",
    [LESSER_NETHER] = "Lesser Nether Essence", [GREATER_NETHER] = "Greater Nether Essence",
    [LESSER_ETERNAL] = "Lesser Eternal Essence", [GREATER_ETERNAL] = "Greater Eternal Essence",
    [SMALL_GLIMMERING] = "Small Glimmering Shard", [LARGE_GLIMMERING] = "Large Glimmering Shard",
    [SMALL_GLOWING] = "Small Glowing Shard", [LARGE_GLOWING] = "Large Glowing Shard",
    [SMALL_RADIANT] = "Small Radiant Shard", [LARGE_RADIANT] = "Large Radiant Shard",
    [SMALL_BRILLIANT] = "Small Brilliant Shard", [LARGE_BRILLIANT] = "Large Brilliant Shard",
    [NEXUS_CRYSTAL] = "Nexus Crystal",
}

-- Dust is common (white), essences uncommon, shards rare, the crystal epic.
local QUALITIES = {}
for _, id in ipairs({ STRANGE_DUST, SOUL_DUST, VISION_DUST, DREAM_DUST, ILLUSION_DUST }) do QUALITIES[id] = 1 end
for _, id in ipairs({ LESSER_MAGIC, GREATER_MAGIC, LESSER_ASTRAL, GREATER_ASTRAL, LESSER_MYSTIC, GREATER_MYSTIC,
    LESSER_NETHER, GREATER_NETHER, LESSER_ETERNAL, GREATER_ETERNAL }) do QUALITIES[id] = 2 end
for _, id in ipairs({ SMALL_GLIMMERING, LARGE_GLIMMERING, SMALL_GLOWING, LARGE_GLOWING, SMALL_RADIANT,
    LARGE_RADIANT, SMALL_BRILLIANT, LARGE_BRILLIANT }) do QUALITIES[id] = 3 end
QUALITIES[NEXUS_CRYSTAL] = 4

-- One row per item level band: highest item level, dust, essence, shard.
local ROWS = {
    { maxLevel = 15,        dust = { STRANGE_DUST, 1, 2 },  essence = { LESSER_MAGIC, 1, 2 },    shard = nil },
    { maxLevel = 20,        dust = { STRANGE_DUST, 2, 3 },  essence = { GREATER_MAGIC, 1, 2 },   shard = SMALL_GLIMMERING },
    { maxLevel = 25,        dust = { STRANGE_DUST, 4, 6 },  essence = { LESSER_ASTRAL, 1, 2 },   shard = SMALL_GLIMMERING },
    { maxLevel = 30,        dust = { SOUL_DUST, 1, 2 },     essence = { GREATER_ASTRAL, 1, 2 },  shard = LARGE_GLIMMERING },
    { maxLevel = 35,        dust = { SOUL_DUST, 2, 5 },     essence = { LESSER_MYSTIC, 1, 2 },   shard = SMALL_GLOWING },
    { maxLevel = 40,        dust = { VISION_DUST, 1, 2 },   essence = { GREATER_MYSTIC, 1, 2 },  shard = LARGE_GLOWING },
    { maxLevel = 45,        dust = { VISION_DUST, 2, 5 },   essence = { LESSER_NETHER, 1, 2 },   shard = SMALL_RADIANT },
    { maxLevel = 50,        dust = { DREAM_DUST, 1, 2 },    essence = { GREATER_NETHER, 1, 2 },  shard = LARGE_RADIANT },
    { maxLevel = 55,        dust = { DREAM_DUST, 2, 5 },    essence = { LESSER_ETERNAL, 1, 2 },  shard = SMALL_BRILLIANT },
    { maxLevel = 60,        dust = { ILLUSION_DUST, 1, 2 }, essence = { GREATER_ETERNAL, 1, 2 }, shard = LARGE_BRILLIANT },
    { maxLevel = math.huge, dust = { ILLUSION_DUST, 2, 5 }, essence = { GREATER_ETERNAL, 1, 3 }, shard = LARGE_BRILLIANT },
}

local SHARD_CHANCE = 5          -- green items, percent
local NEXUS_FROM_LEVEL = 56     -- blue and purple items at or above this item level
local EPIC_FROM_LEVEL = 40      -- the first purple row
local QUALITY_UNCOMMON, QUALITY_RARE, QUALITY_EPIC = 2, 3, 4
local CLASS_WEAPON = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2

local function RowFor(itemLevel)
    for _, row in ipairs(ROWS) do
        if itemLevel <= row.maxLevel then
            return row
        end
    end
    return ROWS[#ROWS]
end

local function Material(itemID, chance, minCount, maxCount)
    return { itemID = itemID, chance = chance, min = minCount, max = maxCount }
end

-- The possible materials for an item, most likely first: a list of
-- { itemID, chance (percent), min, max } (min and max are nil when the
-- count isn't known). Returns nil if there's nothing to say.
function ns.PossibleMaterials(itemID, quality, itemLevel)
    if not itemID or not quality or not itemLevel or itemLevel < 1 then
        return nil
    end
    local row = RowFor(itemLevel)
    local results
    if quality == QUALITY_UNCOMMON then
        local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
        local isWeapon = classID == CLASS_WEAPON
        local shardChance = row.shard and SHARD_CHANCE or 0
        local mainChance = 100 - 20 - shardChance -- 75%, or 80% when the row has no shard
        local dustChance = isWeapon and 20 or mainChance
        local essenceChance = isWeapon and mainChance or 20
        results = {
            Material(row.dust[1], dustChance, row.dust[2], row.dust[3]),
            Material(row.essence[1], essenceChance, row.essence[2], row.essence[3]),
        }
        if row.shard then
            results[#results + 1] = Material(row.shard, shardChance, 1, 1)
        end
    elseif quality == QUALITY_RARE then
        local shard = row.shard or SMALL_GLIMMERING
        if itemLevel >= NEXUS_FROM_LEVEL then
            results = { Material(shard, 99.5, 1, 1), Material(NEXUS_CRYSTAL, 0.5, 1, 1) }
        else
            results = { Material(shard, 100, 1, 1) }
        end
    elseif quality == QUALITY_EPIC then
        if itemLevel < EPIC_FROM_LEVEL then
            return nil
        elseif itemLevel >= NEXUS_FROM_LEVEL then
            results = { Material(NEXUS_CRYSTAL, 100) }
        else
            -- Item level 40 belongs with 41-45 for purple items.
            results = { Material(RowFor(math.max(itemLevel, 41)).shard, 100) }
        end
    else
        return nil
    end
    table.sort(results, function(a, b)
        return a.chance > b.chance
    end)
    return results
end

-- The game's name, icon and quality for a material, with fallbacks.
function ns.MaterialInfo(itemID)
    local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    if not name and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
    local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)
    local quality = C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(itemID)
    return name or NAMES[itemID] or ("item " .. itemID), icon, quality or QUALITIES[itemID]
end
