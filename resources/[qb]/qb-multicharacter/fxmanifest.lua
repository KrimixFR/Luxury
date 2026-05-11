fx_version 'cerulean'
game 'gta5'

name        'qb-multicharacter'
description 'QBCore Multicharacter — Sélection / création de personnage'
version     '1.0.0'
author      'ls1987_server'

shared_scripts {
    '@ox_lib/init.lua',
    '@qb-core/shared/main.lua',
}

client_scripts {
    'client/cl_main.lua',
}

server_scripts {
    'server/sv_main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies { 'qb-core', 'ox_lib' }
