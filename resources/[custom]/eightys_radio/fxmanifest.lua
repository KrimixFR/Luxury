fx_version 'cerulean'
game 'gta5'

name        'eightys_radio'
description 'Los Santos 1987 — Lecteur cassette & disquaire Ray\'s Records'
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
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'ox_lib',
    'qb-core',
    'oxmysql',
    'eightys_core',
}
