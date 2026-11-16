# FAQ and troubleshooting

## Questions

**Is it really free?**
Yes. The code is open: read it, change it, use it on your server.

**Do I need ox_lib or a framework?**
No. Qbox, QBCore, ESX and ox_inventory are detected only for the `groups`
and `items` checks. Without them, those checks always pass.

**Can I change the key?**
Yes: `Config.Target.key = 'G'` (any letter from `Config.Keys`).

**Can I change the colours or the language?**
Yes: `Config.Theme` and `Config.Locale`. See
[configuration.md](configuration.md).

**Will my players still be able to use ox_inventory, garages, jobs…?**
Yes. With the bridge every script that used ox_target works the same way,
only the controls change (look + wheel + E instead of ALT + click).

**Does it cost performance?**
Far from anything with options it sleeps. Near things, it does light maths
every frame only for what is close. Many zones far away cost almost nothing.

## Problems

**`No such export addBoxZone in resource ox_target`**
The bridge is not running. Check that its folder is named exactly
`ox_target`, contains `fxmanifest.lua` and `client.lua`, and that
`server.cfg` has `ensure ox_target`.

**`No such export ... in resource vault-interact`**
vault-interact is not running or the folder was renamed. The folder must be
named `vault-interact` and `server.cfg` must have `ensure vault-interact`
before the scripts that use it.

**The console says `ox_target` is duplicated.**
The original ox_target is still somewhere inside `resources/`. Move it out
(see [ox_target.md](ox_target.md)).

**Vehicle doors appear twice, or not at all.**
Twice: the original ox_target is running too. Not at all: check
`Config.Target.vehicleDoors` and the convar `ox_target:defaults`.

**An option does not show.**
1. Get closer: the option's `distance`, or 2.5 m by default.
2. Check you have the job (`groups`) or the item (`items`).
3. Is there a wall in between? Try `Config.Target.throughWalls = true` to
   find out.
4. Set `Config.Debug = true` and look at F8 for failing `canInteract`.

**ox_inventory says `ox_target is not loaded`.**
The bridge started after ox_inventory. Put `ensure ox_target` before
`ensure [ox]` in `server.cfg`.

**Nothing appears while a menu or the phone is open.**
That is intended (`Config.HideInNui`). Set it to `false` if you prefer.

**A warning `Config.X should be a ...` appears.**
That setting in your `config.lua` has the wrong type, so the default is used.
Fix the value or delete the line.

**Icons do not show.**
Icons load from a CDN. Check the client can reach `cdn.jsdelivr.net`, and
that the icon name is a Font Awesome 6 Free name like `'fa-solid fa-car'`.
