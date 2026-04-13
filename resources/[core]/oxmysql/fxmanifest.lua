fx_version 'cerulean'
game 'gta5'

name        'oxmysql'
description 'Base de données JSON intégrée — compatible API oxmysql'
version     '1.0.0'
author      'ls1987_server'

-- Ce fichier est inclus par les scripts via @oxmysql/lib/MySQL.lua
-- Il fournit MySQL.query.await / MySQL.insert.await / MySQL.update.await
-- Les données sont stockées dans des fichiers JSON (db/*.json)
-- Aucun serveur MySQL externe requis.

server_scripts {
    'server/database.lua',
}

files {
    'lib/MySQL.lua',
}
