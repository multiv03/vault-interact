# Configuration

Everything is in `config.lua`. Every setting is optional: if you delete a
line, the default value is used. If a value has the wrong type (text where a
number is expected, for example) the default is used and a warning shows in
the F8 console. Restart the server after any change.

## 1. Language

| Setting | Default | What it does |
|---|---|---|
| `Config.Locale` | `'en'` | Language of the texts players see. Included: `'en'`, `'es'`. |

### Adding a language

1. Copy `locales/en.lua` to a new file, for example `locales/fr.lua`.
2. Inside, change `Locales.en` to `Locales.fr` and translate the texts on the
   right side of each `=`.
3. Set `Config.Locale = 'fr'`.

Any text you leave out falls back to English. `number_format` and
`price_format` control how prices look (`'$1,250'` or `'1.250 $'`).

## 2. Interactions (`Config.Target`)

| Setting | Default | What it does |
|---|---|---|
| `enabled` | `true` | `false` turns off every interaction menu (custom providers keep working). |
| `key` | `'E'` | Key that uses the selected option. Must be one of `Config.Keys`. |
| `distance` | `2.5` | Reach in metres for options that do not set their own `distance`. |
| `maxDistance` | `nil` | Hard cap for all options, even those asking for more. `nil` = no cap. |
| `throughWalls` | `false` | `true` offers options behind walls too. |
| `inVehicle` | `true` | Zones work from inside a vehicle (car wash, drive-thru). |
| `entitiesInVehicle` | `false` | From inside a vehicle, also show options on other vehicles, peds and objects. |
| `sounds` | `true` | A soft click when scrolling and selecting. |
| `vehicleDoors` | `true` | Built-in open/close door, hood and trunk on every vehicle. |
| `outline` | object only | White outline on what you look at: `{ object = true, vehicle = false, ped = false }`. |
| `scanRadius` | `10.0` | Advanced. Metres around the player where entities are searched. |
| `maxPoints` | `32` | Advanced. Nearby points considered at once (closest first). |
| `threshold` | `0.45` | Advanced. How far (m) from your view a bone or point still counts as looked at. |
| `selectDelay` | `400` | Advanced. Milliseconds between one selection and the next. |
| `scrollUp` / `scrollDown` | wheel + arrows | Advanced. GTA control ids that move the selection. |

The built-in vehicle doors also respect ox_target's convar: `setr
ox_target:defaults 0` in your `server.cfg` removes them.

## 3. Indicators (`Config.Indicators`)

The small dots that show something is nearby.

| Setting | Default | What it does |
|---|---|---|
| `enabled` | `true` | Show the dots. |
| `distance` | `5.0` | Maximum distance (m) at which dots appear. |
| `margin` | `2.0` | Dots appear this many metres before the option is in reach. |
| `max` | `24` | Maximum dots on screen. |

## 4. When interactions are hidden

| Setting | Default | What it does |
|---|---|---|
| `Config.HideInNui` | `true` | Hide while a screen has focus (inventory, menus, phone). |
| `Config.HideWhenDead` | `true` | Hide while the player is dead. |
| `Config.ShouldHide` | busy or dead | Your own check: a function that returns `true` to hide. `false` disables it. |

The default `ShouldHide` hides while the player state bag has `invBusy`
(ox_inventory and ox_lib progress bars), `isDead` or `dead`.

## 5. Jobs, gangs and items (`Config.Bridge`)

Used by the `groups` and `items` fields of options.

| Setting | Default | Values |
|---|---|---|
| `framework` | `'auto'` | `'auto'`, `'qbx'`, `'qb'`, `'esx'`, `'none'` |
| `inventory` | `'auto'` | `'auto'`, `'ox'`, `'qb'`, `'esx'`, `'none'` |

With `'none'`, every `groups` or `items` check passes. If you run another
framework, write your own checks:

```lua
Config.HasGroup = function(filter)
    -- filter is 'police', { 'police', 'ems' } or { police = 2 } (minimum grade)
    return true
end

Config.HasItems = function(filter, anyItem)
    -- filter is 'lockpick', { 'lockpick', 'drill' } or { lockpick = 2 }
    return true
end
```

## 6. Look and feel

`Config.Theme` takes any CSS colour:

| Key | Used for |
|---|---|
| `accent` | The dot, the price, the keys and the selected option. |
| `accentShadow` | The 3D edge under the keys. |
| `ink` | Text on top of the accent colour. |
| `background` | Label background. |
| `text` / `muted` / `warning` | Main text, secondary text, warning text. |

`Config.Outline` sets the outline colour (`{ r, g, b, a }`) used for entities
listed by custom providers.

## 7. Keys and timing (advanced)

| Setting | Default | What it does |
|---|---|---|
| `Config.Keys` | E, G, Q, H, F, R, X | Letter shown on screen = GTA control id. |
| `Config.ScanInterval` | `250` | Milliseconds between asking for nearby points. |
| `Config.HoldRepeat` | `100` | Milliseconds between `onHold` calls of custom providers. |
| `Config.LookThreshold` | `0.3` | Default look distance (m) for custom provider points. |

## 8. Debug

`Config.Debug = true` prints extra warnings in F8: options replaced because
they share a name, `canInteract` functions that throw errors, zones that do
not exist. Leave it `false` on a live server.
