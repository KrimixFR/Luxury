fx_version 'cerulean'
game 'gta5'

name        'qb-core'
description 'QBCore Framework — Los Santos 1987 (version intégrée)'
version     '1.0.0'
author      'ls1987_server'

shared_scripts {
    'shared/locale.lua',
    'shared/items.lua',
    'shared/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/functions.lua',
    'server/player.lua',
    'server/main.lua',
    'server/commands.lua',
}

client_scripts {
    'client/functions.lua',
    'client/main.lua',
}
