fx_version 'cerulean'
game 'gta5'

name        'qb-vehicleshop'
description 'QBCore VehicleShop — Concession (stub, remplacé par AutoLuxe)'
version     '1.0.0'
author      'ls1987_server'

shared_scripts {
    '@ox_lib/init.lua',
    '@qb-core/shared/main.lua',
}

client_scripts { 'client/cl_main.lua' }
server_scripts { 'server/sv_main.lua' }

dependencies { 'qb-core', 'ox_lib' }
