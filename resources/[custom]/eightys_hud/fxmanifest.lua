fx_version 'cerulean'
game 'gta5'

name        'eightys_hud'
description 'Los Santos 1987 — HUD rétro néon années 80'
version     '1.0.0'
author      'eightys_server'

shared_scripts {
    '@ox_lib/init.lua',
    '@eightys_core/config.lua',
}

client_scripts {
    'client/cl_main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}
