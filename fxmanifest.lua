fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vault-interact'
author 'Vault Store'
description 'Look-and-press proximity interactions with a floating label. Drop-in replacement for ox_target.'
version '2.1.0'

-- No dependencies: Qbox, QBCore, ESX and ox_inventory are detected if present.
-- Documentation: docs/README.md
shared_scripts {
    'config.lua',
    'locales/*.lua',
}

client_scripts {
    'client/util.lua',
    'client/puente.lua',
    'client/zonas.lua',
    'client/main.lua',
    'client/target.lua',
    'client/defaults.lua',
    'client/compat.lua',
}

server_script 'server/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/etiqueta.css',
    'html/etiqueta.js',
    'html/fuentes/*.woff2',
}
