fx_version 'cerulean'
game 'gta5'

lua54 'yes'

name 'esx_org_hub'
author 'cursor-agent'
description 'Sistema de organizaciones para ESX Legacy'
version '1.0.0'

ui_page 'html/index.html'

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

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    'es_extended',
    'oxmysql',
    'ox_inventory'
}
