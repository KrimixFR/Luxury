fx_version 'cerulean'
game 'gta5'

name        'eightys_economy'
description 'Los Santos 1987 — Économie dynamique des drogues (offre/demande)'
version     '1.0.0'
author      'eightys_server'

shared_scripts {
    '@eightys_core/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua',
}

dependencies { 'qb-core', 'oxmysql', 'eightys_core' }
