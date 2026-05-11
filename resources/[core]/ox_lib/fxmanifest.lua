fx_version 'cerulean'
game 'gta5'

name        'ox_lib'
description 'Bibliothèque ox_lib — Notifications, Menus, Progress Bar, Input'
version     '1.0.0'
author      'ls1987_server'

-- Les scripts l'incluent via : shared_scripts { '@ox_lib/init.lua' }

shared_scripts {
    'init.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}
