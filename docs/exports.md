# Exports

All exports are **client-side**. Because the resource name has a dash, call
them with brackets:

```lua
exports['vault-interact']:addBoxZone({ ... })
```

If you installed the ox_target bridge ([ox_target.md](ox_target.md)), the
exact same calls also work as `exports.ox_target:addBoxZone({ ... })`.

Every option and zone you add belongs to the resource that added it and is
removed automatically when that resource stops.

## Quick examples

### A zone (box)

```lua
exports['vault-interact']:addBoxZone({
    name = 'my_shop_counter',
    coords = vec3(25.7, -1347.3, 29.5),
    size = vec3(1.2, 0.8, 1.0),
    rotation = 45,
    options = {
        {
            name = 'open_shop',
            label = 'Open shop',
            icon = 'fa-solid fa-basket-shopping',
            onSelect = function(data)
                print('zone', data.zone, 'at', data.coords)
            end,
        },
        {
            name = 'rob_register',
            label = 'Rob register',
            icon = 'fa-solid fa-mask',
            iconColor = '#ff8f8f',
            items = 'lockpick',
            holdTime = 3000,       -- hold E for 3 seconds
            cooldown = 60000,      -- then wait 1 minute
            serverEvent = 'my_shop:rob',
        },
    },
})
```

### Every ATM model

```lua
exports['vault-interact']:addModel({ 'prop_atm_01', 'prop_atm_02', 'prop_atm_03' }, {
    {
        name = 'use_atm',
        label = 'Use ATM',
        icon = 'fa-solid fa-credit-card',
        distance = 1.5,
        onSelect = function(data)
            TriggerEvent('my_bank:openAtm', data.entity)
        end,
    },
})
```

### A ped you spawned

```lua
local ped = CreatePed(4, `a_m_m_business_01`, 100.0, 200.0, 30.0, 90.0, false, true)

exports['vault-interact']:addLocalEntity(ped, {
    {
        name = 'talk',
        label = 'Talk',
        icon = 'fa-solid fa-comment',
        onSelect = function() print('Hello!') end,
    },
})
```

### A single point in the world (extra)

```lua
local id = exports['vault-interact']:addCoords(vec3(441.8, -982.0, 30.7), {
    {
        name = 'clock_in',
        label = 'Clock in',
        icon = 'fa-solid fa-clock',
        groups = 'police',
        holdTime = 1500,
        onSelect = function() TriggerServerEvent('my_job:clockIn') end,
    },
})

-- later
exports['vault-interact']:removeCoords(id)
```

### Job-only option on every vehicle

```lua
exports['vault-interact']:addGlobalVehicle({
    {
        name = 'impound',
        label = 'Impound vehicle',
        icon = 'fa-solid fa-truck-pickup',
        groups = { police = 2 },   -- police, grade 2 or higher
        bones = { 'boot' },
        onSelect = function(data) TriggerServerEvent('my_job:impound', VehToNet(data.entity)) end,
    },
})
```

### A sub-menu

```lua
exports['vault-interact']:addSphereZone({
    coords = vec3(-1196.4, -890.8, 14.0),
    radius = 1.0,
    options = {
        { name = 'menu', label = 'Order food', icon = 'fa-solid fa-burger', openMenu = 'food' },
        { name = 'burger', label = 'Burger', menuName = 'food', event = 'my_diner:order' },
        { name = 'fries', label = 'Fries', menuName = 'food', event = 'my_diner:order' },
    },
})
```

A **Back** entry is added at the top of sub-menus automatically.

## Functions

| Function | Returns | What it does |
|---|---|---|
| `addBoxZone(data)` | zone id | Box zone. `data`: `coords`, `size` (vec3), `rotation` (degrees), `name`, `debug`, `drawSprite`, `options`. |
| `addSphereZone(data)` | zone id | Sphere zone. `data`: `coords`, `radius`, `name`, `debug`, `drawSprite`, `options`. |
| `addPolyZone(data)` | zone id | Polygon zone. `data`: `points` (3 or more vec3), `thickness`, `name`, `debug`, `drawSprite`, `options`. |
| `zoneExists(idOrName)` | boolean | Whether a zone exists. |
| `removeZone(idOrName)` | — | Removes a zone (or a list of them). |
| `addCoords(coords, options)` | id or list of ids | **Extra.** Options on a single point. Pass a list of points to get a list of ids. |
| `removeCoords(id)` | — | Removes a point added with `addCoords`. |
| `addModel(models, options)` | — | Options on every entity of these models (names or hashes, one or a list). |
| `removeModel(models, names?)` | — | Removes those options (by name) or all of them. |
| `addEntity(netIds, options)` | — | Options on networked entities (by network id). |
| `removeEntity(netIds, names?)` | — | Removes them. |
| `addLocalEntity(entities, options)` | — | Options on local entities (by handle). |
| `removeLocalEntity(entities, names?)` | — | Removes them. |
| `addGlobalPed(options)` | — | Options on every ped (not players). |
| `addGlobalVehicle(options)` | — | Options on every vehicle. |
| `addGlobalObject(options)` | — | Options on every object. |
| `addGlobalPlayer(options)` | — | Options on every other player. |
| `addGlobalOption(options)` | — | Options on every entity. |
| `removeGlobalPed(names)` and the other `removeGlobal...` | — | Removes options by name. |
| `getTargetOptions(entity?, type?, model?)` | table | The options registered (for debugging). |
| `disableTargeting(state)` | — | `true` hides every interaction, `false` shows them again. |
| `isActive()` | boolean | `true` while the player is looking at something with options. |

`zone`, `coords`, `size` and `points` accept `vec3(...)`, `vector3(...)`,
`{ x = 1, y = 2, z = 3 }` or `{ 1, 2, 3 }`.

### Validation

Bad input never breaks the resource. Instead it prints a warning in F8 with
the name of the resource that made the call and ignores that call:

- `options` that are not a table.
- Zone data that is not a table, missing `coords`, or a polygon with fewer
  than 3 points (the function returns `nil`).
- `addLocalEntity` with an entity that does not exist.
- Network ids that do not exist are skipped silently.
- A `canInteract` that throws an error hides that option (with
  `Config.Debug = true` the error is printed).

## Option fields

| Field | What it is |
|---|---|
| `label` | Text shown in the menu. |
| `name` | Unique name. Used to remove it; adding an option with the same `name` from the same resource replaces the old one. |
| `icon`, `iconColor` | Font Awesome 6 icon (`'fa-solid fa-car'`) and its colour. |
| `distance` | Reach in metres. Default: `Config.Target.distance` (2.5). |
| `groups` | Job or gang: `'police'`, `{ 'police', 'ambulance' }` or `{ police = 2 }` (minimum grade). |
| `items`, `anyItem` | Required items: `'lockpick'`, `{ 'a', 'b' }` or `{ lockpick = 2 }`. With `anyItem = true`, one is enough. |
| `bones` | Entity bones to attach to (the first that exists). Each bone is its own point. |
| `offset`, `absoluteOffset`, `offsetSize` | Point relative to the model: from 0 to 1 of its size, or metres with `absoluteOffset = true`. |
| `canInteract(entity, distance, coords, name, bone)` | Return `true` to show the option. |
| `onSelect(data)` | Function to run. |
| `export` | `'exportName'`: calls `exports[yourResource][exportName](nil, data)`. |
| `event` | Client event to trigger with `data`. |
| `serverEvent` | Server event to trigger with `data` (here `data.entity` is a network id, or `0`). |
| `command` | Command to execute. |
| `openMenu`, `menuName` | Sub-menus: `openMenu = 'x'` opens menu `x`; options with `menuName = 'x'` only show there. |
| `holdTime` | **Extra.** Milliseconds the key must be held. The option fills up while holding. |
| `cooldown` | **Extra.** Milliseconds before the option can be used again. |

### What your function receives (`data`)

`onSelect`, `event`, `export` and `serverEvent` receive the option itself
(without its functions) plus:

| Field | What it is |
|---|---|
| `entity` | The entity handle (`0` for zones and points). |
| `zone` | The zone id, for zones. |
| `coords` | Where the option is (bone, offset, entity or zone centre). |
| `distance` | Distance from the player. |
| `resource` | The resource that added the option. |

## Events

vault-interact has no public events to listen to or trigger. Your options
fire your own events (`event`, `serverEvent`). Events whose names start with
`vault-interact:` are internal and may change between versions.

## Custom labels

For things that are not a menu (a shelf with several items, a register with
several keys), see [providers.md](providers.md).
