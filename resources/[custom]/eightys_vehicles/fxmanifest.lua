fx_version 'cerulean'
game 'gta5'

name        'eightys_vehicles'
description 'Los Santos 1987 — Restriction aux véhicules des années 80'
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
