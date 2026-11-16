fx_version 'cerulean'
game 'gta5'
lua54 'yes'

-- Bridge: this resource is named ox_target so that every script using
-- exports.ox_target (and exports.qtarget) works with vault-interact unchanged.
-- It replaces the original ox_target: never run both (see docs/ox_target.md).
name 'ox_target'
author 'Vault Store (vault-interact bridge)'
description 'Bridge: ox_target -> vault-interact'
-- The ox_target API version it covers (some resources check it).
version '1.18.1'

vault_interact_bridge 'yes'

provide 'qtarget'
dependency 'vault-interact'

client_script 'client.lua'
