--[[
    vault-interact · configuration

    Every setting is optional: if you delete a line, the default shown here is
    used. If a value has the wrong type (for example text where a number is
    expected) the default is used and a warning appears in the F8 console.

    Sections:
      1. Language
      2. Interactions (the ox_target-compatible menu)
      3. Indicators (the small dots)
      4. When interactions are hidden
      5. Jobs, gangs and items (framework detection)
      6. Look and feel
      7. Keys and timing (advanced)
      8. Debug
]]
Config = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. LANGUAGE
-- ─────────────────────────────────────────────────────────────────────────────
-- Language of every text the player sees. Included: 'en' (English), 'es' (Spanish).
-- To add one, copy locales/en.lua to locales/xx.lua, translate it and put 'xx' here.
Config.Locale = 'es'

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. INTERACTIONS
-- ─────────────────────────────────────────────────────────────────────────────
-- Zones, models, entities and global options that other resources add with
-- exports['vault-interact']:addBoxZone(...) or, through the bridge, with
-- exports.ox_target:addBoxZone(...).
-- Players do not hold ALT: they walk up, look at the dot, scroll to pick an
-- option and press the key below.
Config.Target = {
    enabled = true,              -- false: no interaction menus at all (custom providers keep working)
    key = 'E',                   -- key that uses the selected option (must exist in Config.Keys)

    -- Distance (metres) for options that do not set their own `distance`.
    -- ox_target uses 7 because you aim with ALT; here walking up is enough.
    distance = 2.5,
    maxDistance = nil,           -- hard cap for every option, even if it asks for more (nil = no cap)

    throughWalls = false,        -- true: options behind a wall are still offered
    inVehicle = true,            -- inside a vehicle, zones still work (car wash, drive-thru)...
    entitiesInVehicle = false,   -- ...but not options on other vehicles, peds and objects

    sounds = true,               -- a soft click when scrolling and selecting
    vehicleDoors = true,         -- built-in "open/close door, hood, trunk" on every vehicle

    -- White outline on the entity you are looking at, by type.
    outline = { object = true, vehicle = false, ped = false },

    -- Advanced
    scanRadius = 10.0,           -- metres around the player where entities are searched
    maxPoints = 32,              -- how many nearby points are considered at once (closest first)
    threshold = 0.45,            -- how far (m) from the camera ray a bone/offset/point still counts as looked at
    selectDelay = 400,           -- ms between one selection and the next
    scrollUp = { 15, 241, 172 },   -- GTA controls that move up (mouse wheel up, arrow up)
    scrollDown = { 14, 242, 173 }, -- GTA controls that move down (mouse wheel down, arrow down)
}

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. INDICATORS
-- ─────────────────────────────────────────────────────────────────────────────
-- Small dots that show there is something to interact with nearby.
Config.Indicators = {
    enabled = true,
    distance = 5.0,   -- maximum distance (m) at which dots are shown
    margin = 2.0,     -- dots appear this many metres before the option is in reach
    max = 24,         -- maximum dots on screen
}

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. WHEN INTERACTIONS ARE HIDDEN
-- ─────────────────────────────────────────────────────────────────────────────
Config.HideInNui = true      -- while a screen has focus (inventory, menus, phone...)
Config.HideWhenDead = true   -- while the player is dead

-- Your own check: return true to hide. Set to false to disable.
-- Default: while busy (ox_lib progress bar, inventory) or dead by state bag.
Config.ShouldHide = function()
    local s = LocalPlayer.state
    return s.invBusy or s.isDead or s.dead
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. JOBS, GANGS AND ITEMS
-- ─────────────────────────────────────────────────────────────────────────────
-- Used by the `groups` and `items` fields of options. 'auto' detects what you run.
-- framework: 'auto' | 'qbx' | 'qb' | 'esx' | 'none'
-- inventory: 'auto' | 'ox'  | 'qb' | 'esx' | 'none'
-- With 'none', every `groups` / `items` check passes.
Config.Bridge = { framework = 'auto', inventory = 'auto' }

-- Or write your own checks (if set, they win over detection):
-- Config.HasGroup = function(filter) return true end
-- Config.HasItems = function(filter, anyItem) return true end

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. LOOK AND FEEL
-- ─────────────────────────────────────────────────────────────────────────────
-- Label colours (any CSS colour), to match your server's brand.
Config.Theme = {
    accent = '#fdd519',          -- the dot, the price, the keys and the selected option
    accentShadow = '#9c8207',    -- the 3D edge under the keys
    ink = '#0a0a0a',             -- text on top of the accent colour
    background = 'rgba(16, 16, 16, .95)',
    text = '#ffffff',
    muted = '#8e8c85',
    warning = '#ff8f8f',
}

-- White outline on entities listed by custom providers (see docs/providers.md).
Config.Outline = { enabled = true, color = { 255, 255, 255, 255 } }

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. KEYS AND TIMING (advanced)
-- ─────────────────────────────────────────────────────────────────────────────
-- Keys the label understands: the letter shown on screen = GTA control id.
-- Providers choose which of these they use (default: only E).
Config.Keys = { E = 38, G = 47, Q = 44, H = 74, F = 23, R = 45, X = 73 }

Config.ScanInterval = 250    -- ms between asking every provider for nearby points
Config.HoldRepeat = 100      -- ms between "hold" callbacks while a key stays pressed
Config.LookThreshold = 0.3   -- default distance (m) from the camera ray for provider points

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. DEBUG
-- ─────────────────────────────────────────────────────────────────────────────
-- Extra warnings in the F8 console (replaced options, failing canInteract...).
Config.Debug = false
