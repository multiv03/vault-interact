# Installation

You need access to your server files (FTP, txAdmin file manager or the
server's own disk) and to `server.cfg`.

## 1. Copy the folder

1. Download and unzip `vault-interact`.
2. Copy the `vault-interact` folder into your `resources` folder. Any
   sub-folder works, for example `resources/[vault]/vault-interact`.
3. Do **not** rename the folder. Other scripts find it by this exact name.

## 2. Start it

Open `server.cfg` and add this line **before** the scripts that use it:

```cfg
ensure vault-interact
```

## 3. Restart the server

Restart the whole server (not only the resource) and join. Open the F8
console: there should be no red errors mentioning `vault-interact`.

Walk up to any car: a small dot appears on the door handles. Look at it,
press **E** and the door opens. That means it works.

## 4. Choose how to use it

- **Only for your own scripts** (ox_target stays as it is): you are done.
  Call `exports['vault-interact']:...` from your scripts, see
  [exports.md](exports.md).
- **Instead of ox_target for every script**: follow
  [ox_target.md](ox_target.md). It takes five minutes and is fully
  reversible.

## 5. Optional: language and colours

Open `config.lua`:

```lua
Config.Locale = 'es'          -- Spanish texts
Config.Theme.accent = '#4ade80' -- green instead of yellow
```

Restart the server after editing `config.lua`. All settings are explained in
[configuration.md](configuration.md).

## Updating

1. Keep a copy of your `config.lua` (and any file you added to `locales/`).
2. Replace the folder with the new version.
3. Put your `config.lua` back. Settings that the new version added and your
   file does not have simply use their default value.
