fx_version 'cerulean'
game 'gta5'

name        'eightys_payphone'
description 'Los Santos 1987 — Cabines téléphoniques (pas de portable en 1987)'
version     '1.0.0'
author      'eightys_server'

shared_scripts {
    '@ox_lib/init.lua',
    '@eightys_core/config.lua',
}

client_scripts {
    'client/cl_main.lua',
}

server_scripts {
    'server/sv_main.lua',
}

dependencies {
    'ox_lib',
    'qb-core',
    'eightys_core',
}
