fx_version 'cerulean'
game 'gta5'
--<<>>
author 'RoyaleWind'
name 'MW BUCKET'
description 'MW BUCKET'
version '2.1.0'
lua54 'on'
contact 'https://discord.gg/T8b8q7ZN8b'
------------------------------
-- <<<<<<<<<<<<<<<<<<
------------------------------
dependencies 'ox_lib'
--<<>>
shared_script '@ox_lib/init.lua'
-- <<<<<<<<<<<<<<<<<<
------------------------------
--<<>>
files {
    'data/**/*',
}
client_script "client/**/*"
server_script "server/**/*"
