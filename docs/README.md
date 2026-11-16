# vault-interact

Free proximity interactions for FiveM, by Vault Store.

Walk up to something you can use and a small dot appears. Look at it and a
floating label shows its options. Scroll with the mouse wheel (or ↑ ↓) and
press **E**. No holding ALT, no mouse cursor, no menus covering the screen.

## What it does

- **Replaces ox_target without touching your other scripts.** It speaks the
  same API (`addBoxZone`, `addModel`, `addLocalEntity`…) and ships a small
  bridge resource called `ox_target`, so ox_inventory, Qbox jobs, ox_doorlock
  and any script that calls `exports.ox_target` keep working.
- **Or runs next to ox_target**, only for the scripts you choose.
- **Custom labels** for your own scripts: title, amount, price, a status line
  and several keys at once (E, G, Q, R…). See [providers.md](providers.md).
- **Built-in vehicle doors**: open and close doors, hood and trunk on any
  vehicle, with the dot on the handle.
- **Works with any framework**: Qbox, QBCore and ESX are detected for job and
  item checks; it also works with none.
- **Walls block**: options behind a wall are not offered.
- **Light on performance**: it sleeps when nothing is near and only does
  per-frame work for what is close to you.
- **Clean**: when a resource stops, its options and zones are removed.
- **Your brand, your language**: colours in `config.lua`, texts in `locales/`
  (English and Spanish included).

## Documentation

| Page | What you will find |
|---|---|
| [installation.md](installation.md) | Step-by-step install. |
| [configuration.md](configuration.md) | Every setting in `config.lua`, explained. |
| [exports.md](exports.md) | Zones, models, entities and option fields, with copy-paste examples. |
| [providers.md](providers.md) | Custom labels with several keys (advanced). |
| [ox_target.md](ox_target.md) | Replace ox_target, or run both. |
| [faq.md](faq.md) | Questions and common problems. |

## Requirements

- A FiveM server with a recent artifact (OneSync recommended).
- Nothing else. ox_lib is **not** required.

## Credits

- Geist and Geist Mono fonts: SIL Open Font License (`html/fuentes/OFL.txt`).
- Icons: Font Awesome 6 Free, loaded from a CDN (same names as in ox_target).
