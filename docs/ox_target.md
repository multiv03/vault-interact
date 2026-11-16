# ox_target: replace it or run both

You have two choices.

| | Run both | Replace ox_target |
|---|---|---|
| Your other scripts | Keep using ox_target (ALT + click). | Use vault-interact, without editing them. |
| Your own scripts | Can call `exports['vault-interact']`. | Can call either name. |
| Effort | None. | Five minutes, fully reversible. |

## Option A: run both

Install vault-interact ([installation.md](installation.md)) and keep
ox_target. Each script uses the system it calls:

- `exports.ox_target:...` → ox_target, as before.
- `exports['vault-interact']:...` → vault-interact.

While the original ox_target is running, vault-interact does **not** add its
built-in vehicle doors, so they never appear twice.

## Option B: replace ox_target

vault-interact ships a small resource in `bridge/ox_target`. It is **named
`ox_target`** and forwards every `exports.ox_target` and `exports.qtarget`
call to vault-interact. ox_inventory, Qbox, ox_doorlock and every other
script keep working without changes.

> The original and the bridge cannot both be inside `resources/`, not even in
> a folder you do not start: FiveM reads every folder and two resources with
> the same name clash. Move the original **out** of `resources/`.

### Steps

1. **Stop the server.**
2. **Move the original ox_target out of `resources/`.** Do not delete it:
   it is your way back. For example, move `resources/[ox]/ox_target` to a
   folder named `backup_ox_target` next to `resources/`.
   *Windows PowerShell tip:* folders with `[ ]` need `-LiteralPath`:
   `Move-Item -LiteralPath "resources\[ox]\ox_target" -Destination "backup_ox_target"`.
3. **Copy the bridge** `vault-interact/bridge/ox_target` into `resources/`,
   in any folder. The folder must be named exactly `ox_target`.
4. **`server.cfg`:** if you already had `ensure ox_target`, leave it. That
   line now starts the bridge, and the bridge starts vault-interact first
   (it is its dependency). Keep it **before** ox_inventory:

   ```cfg
   ensure ox_lib
   ensure qbx_core
   ensure ox_target      # now the bridge, starts vault-interact
   ensure [ox]
   ```

5. **Start the server** and check F8: no red errors and no
   `No such export ... in resource ox_target`.
6. **Test in game:** an ox_inventory shop or stash, an ATM, a car door, a
   locked door with ox_doorlock, the options of your job.

### Going back

1. Stop the server.
2. Delete `resources/.../ox_target` (the bridge).
3. Move your original ox_target back into `resources/`.
4. Start. vault-interact can stay installed.

## What is covered

Every ox_target 1.18 export: `addBoxZone`, `addSphereZone`, `addPolyZone`,
`removeZone`, `zoneExists`, `addGlobalPed`, `addGlobalVehicle`,
`addGlobalObject`, `addGlobalPlayer`, `addGlobalOption` (and their
`remove...`), `addModel`, `removeModel`, `addEntity`, `removeEntity`,
`addLocalEntity`, `removeLocalEntity`, `getTargetOptions`,
`disableTargeting` and `isActive`.

Every option field: `label`, `name`, `icon`, `iconColor`, `distance`,
`groups`, `items`, `anyItem`, `bones`, `offset`, `absoluteOffset`,
`offsetSize`, `canInteract`, `onSelect`, `export`, `event`, `serverEvent`,
`command`, `openMenu` and `menuName`.

From qtarget: `AddBoxZone`, `AddPolyZone`, `AddCircleZone`, `RemoveZone`,
`AddTargetBone`, `AddTargetEntity`, `RemoveTargetEntity`, `AddTargetModel`,
`RemoveTargetModel`, `Ped`, `Vehicle`, `Object`, `Player` and their
`Remove...`.

## What is different

- **No ALT, no mouse.** Look, scroll, press E. The ox_target convars
  `defaultHotkey`, `toggleHotkey`, `leftClick`, `drawSprite` and `debug` do
  nothing. `ox_target:defaults 0` is respected (removes the vehicle doors).
- **Default reach 2.5 m** instead of 7 (`Config.Target.distance`). Options
  that set their own `distance` keep it.
- **Walls block** options behind them (`Config.Target.throughWalls`).
- **Inside a vehicle** you see zones but not options on other entities
  (`Config.Target.entitiesInVehicle`).
- **Hides itself** while a screen has focus, while busy and while dead
  ([configuration.md](configuration.md#4-when-interactions-are-hidden)).
- In `canInteract`, `coords` is the option's point (bone, offset or zone
  centre), not where the aim hit. For zones, `entity` is `0`.
- `onEnter`, `onExit` and `inside` inside zone data are ignored. Use
  `lib.zones` from ox_lib for those.
- If you restart vault-interact while the server runs, also restart the
  resources that add options. ox_target behaves the same.
