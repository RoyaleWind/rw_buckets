fx_version 'cerulean'
-- use_experimental_fxv2_oal 'yes'
games { 'rdr3', 'gta5' }
lua54 'on'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
--<<>>
name 'RW BUCKET'
author 'RoyaleWind'
version '2.2.0'
description 'MW BUCKET'
contact 'discord.royalewind.com'
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
