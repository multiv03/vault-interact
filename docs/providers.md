# Custom labels (providers)

> Advanced. If you only need a menu of options, use [exports.md](exports.md).

A **provider** is for things that are not a menu: a shelf where each slot is
a different item, a register with "charge" on E and "open drawer" on G, a
point floating in the air. Your script says which points are nearby and what
each key does; vault-interact draws the label and reads the keys.

The point picked is the one closest to where the player is looking. There is
no physics raycast, so points work on props without collision and in empty
space.

## Example

```lua
local REGISTER = vec3(25.7, -1347.3, 29.5)

local function register()
    exports['vault-interact']:registerProvider('my_register', {
        -- Called every 250 ms: return the points near the player (or nil).
        candidates = function()
            local me = GetEntityCoords(PlayerPedId())
            if #(me - REGISTER) > 3.0 then return nil end
            return {
                { id = 'register1', x = REGISTER.x, y = REGISTER.y, z = REGISTER.z, threshold = 0.5, indicator = true },
            }
        end,

        -- What the label shows for a point.
        label = function(point)
            return {
                title = 'Cash register',
                subtitle = 'Open',
                price = 25,
                keys = {
                    { key = 'E', text = 'Charge' },
                    { key = 'G', text = 'Open drawer' },
                },
            }
        end,

        -- Keys this provider uses. While a point of yours is looked at, these
        -- keys do not trigger their normal GTA action.
        keys = { 'E', 'G' },

        onPress = function(point, key)
            print('pressed', key, 'on', point.id)
        end,
    })
end

register()

-- If vault-interact restarts while the server runs, register again.
AddEventHandler('onClientResourceStart', function(res)
    if res == 'vault-interact' then register() end
end)
```

## `registerProvider(name, definition)`

Registers a provider, or replaces the one with the same `name`. Returns
`true`, or `false` (with a warning in F8) if `name` is not text or
`candidates` is missing. Providers are removed automatically when the
resource that registered them stops.

| Field | What it is |
|---|---|
| `candidates()` | **Required.** Returns a list of nearby points, or `nil`. Called every `Config.ScanInterval` ms. |
| `label(point)` | Returns what the label shows (see below), or `nil` for no label. |
| `keys` | Letters used: `{ 'E', 'G' }`. Default `{ 'E' }`. Must exist in `Config.Keys`. |
| `onPress(point, key)` | When one of your keys is pressed. |
| `onHold(point, key)` | While the key stays pressed, every `Config.HoldRepeat` ms. |
| `onRelease(point, key)` | When the key is released. |
| `onLook(point)` | Every 400 ms while the point is looked at. |
| `onChange(point)` | When what the player looks at changes. `point` is `nil` when it is nothing of yours. |
| `onFrame(point)` | Every frame while the point is looked at. Keep it light. |

### Point fields

| Field | What it is |
|---|---|
| `id` | Identifies the point (text or number). Same id = same point between scans. |
| `x`, `y`, `z` | Position. The label's dot appears here. |
| `threshold` | How far (m) from the player's view still counts as looked at. Default `Config.LookThreshold`. |
| `reach` | Optional. Only selectable if the player is closer than this (m). |
| `always` | Optional. Wins over everything without being looked at (a sign on a door, for example). |
| `entities` | Optional. List of entity handles to outline while looked at. |
| `indicator` | Optional. `true` shows a dot when the point is not looked at. |
| anything else | Comes back untouched in `label`, `onPress` and the others. |

### Label fields

| Field | What it is |
|---|---|
| `title` | Main text. |
| `subtitle` | Second line. |
| `warning` | `true` paints the subtitle in the warning colour. |
| `amount` | A number (shown as `×4`) or text. |
| `price` | A number (formatted with the language's currency format) or text. |
| `keys` | `{ { key = 'E', text = 'Take' }, ... }` |

## Other functions

| Function | What it does |
|---|---|
| `removeProvider(name)` | Removes a provider. |
| `refresh()` | Rebuilds the label now and asks for points again. Call it when what the label says changes. |
| `getCurrentTarget()` | What is looked at now: `{ provider = name, id = id }`, or `nil`. |
| `pause(state)` | `true` hides the label and ignores keys (for example while your menu is open); `false` resumes. |

## Preview the label in a browser

Open `html/index.html?demo` (label with keys) or `html/index.html?demo=menu`
(option menu with indicators) in any browser.
