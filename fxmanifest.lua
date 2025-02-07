-- fxmanifest.lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rde_elevators'
description 'Advanced Elevator System with Admin Management'
author 'SerpentsByte'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'shared/*.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_target',
    'oxmysql'
}

files {
    'shared/*.lua'
}