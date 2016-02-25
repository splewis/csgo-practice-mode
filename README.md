csgo-practice-mode
===========================

[![Build Status](https://travis-ci.org/splewis/csgo-practice-mode.svg?branch=master)](https://travis-ci.org/splewis/csgo-practice-mode)

Practice Mode is a sourcemod plugin for helping players/teams run practices. It was formerly a part of [PugSetup](https://github.com/splewis/csgo-pug-setup) but has since been made into a separate project. It still contains integrations with pugsetup to make it available on it's ``.setup`` menu. It is also still distributed in pugsetup's releases.

### Download

Download from [the releases section](https://github.com/splewis/csgo-practice-mode/releases).

You may also download the [latest development build](http://ci.splewis.net/job/csgo-practice-mode/lastSuccessfulBuild/) if you wish. If you report any bugs from these, make sure to include the build number (when typing ``sm plugins list`` into the server console, the build number will be displayed with the plugin version).

### Installation

Extract the files in the release archive to the ``csgo`` server directory.

You must have [SourceMod](http://www.sourcemod.net/downloads.php) and [MetaMod:Source](http://www.sourcemm.net/downloads) installed to use this plugin.

### Features
- Draws working grenade trajectories if ``sv_grenade_trajectory`` is on (since it doesn't work on dedicated servers)
- Adds new cvars to give extra practice settings (infinite money, noclip without needing sv_cheats enabled)
- Can save users' grenade locations/eye-angles with a name and description for them
- Users can goto any players' saved grenades to learn or revisit them
- Displays a menu with toggle settings to set practice cvars defined in [addons/sourcemod/configs/practicemode.cfg](configs/practicemode.cfg)
- Maintains your grenade history on the current map so you can use ``.back`` and ``.forward`` to see all spots you threw grenades from in the current session

### Commands
- ``.setup`` displays the practicemode menu
- ``.help``: displays chat commands
- ``.nades [player]``: displays users with grenades saved in a menu (or your own nades if no player is given)
- ``.save <name>``: saves your current position as a grenade spot with the given name
- ``.desc``: adds a grenade description to the last grenade you saved/used .goto on
- ``.goto [playername] <grenadeid>``: teleports you to a player's saved grenade (or your own if no player is named)
- ``.last``: teleports you back to where you threw your last grenade from
- ``.back``: teleports you back a position in your grenade history
- ``.forward``: teleports you forward a position in your grenade history
- ``.spawn <number>``: teleports you to a spawn # for the maps's spawns, if no number is given the nearest map spawn is used (uses your current CT/T team to decide which team's spawns to use)
- ``.flash``:  saves you position to test flashbangs against it. Use this command in a spot you want to try to blind, then move and throw the flashbang; you will be teleported back to the position and see how effective the flashbang is
- ``.stopflash``: stops flash testing

### ConVars
- ``sm_practicemode_autostart``
- ``sm_practicemode_max_grenade_history_size``
- ``sm_practicemode_max_grenades_saved``
- ``sm_infinite_money``
- ``sm_allow_noclip``
- ``sm_grenade_trajectory_use_player_color``
