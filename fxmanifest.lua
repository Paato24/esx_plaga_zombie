fx_version 'cerulean'
game 'gta5'

lua54 'yes'

name 'esx_plaga_zombie'
author 'cursor-agent'
description 'Sistema de plaga zombie para ESX Legacy'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@oxmysql/lib/MySQL.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

dependencies {
    'es_extended',
    'oxmysql'
}
