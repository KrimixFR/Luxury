fx_version 'cerulean'
game 'gta5'
name 'eightys_addiction'
description 'Los Santos 1987 — Système d\'addiction et sevrage'
version '1.0.0'
author 'eightys_server'

shared_scripts {
    '@ox_lib/init.lua',
    '@eightys_core/config.lua',
}
client_scripts { 'client/cl_main.lua' }
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua',
}
dependencies { 'ox_lib', 'qb-core', 'oxmysql', 'eightys_core' }
