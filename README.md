csgo-practice-mode
===========================

[![Build status](http://ci.splewis.net/job/csgo-practice-mode/badge/icon)](http://ci.splewis.net/job/csgo-practice-mode/)
[![GitHub Downloads](https://img.shields.io/github/downloads/splewis/csgo-practice-mode/total.svg?style=flat-square&label=Downloads)](https://github.com/splewis/csgo-practice-mode/releases/latest)
[![Discord Chat](https://img.shields.io/discord/926309849673895966.svg)](https://discord.gg/zmqEa4keCk)

**Status: Supported, actively developed.**

Practice Mode is a sourcemod plugin for helping players/teams run practices. See this [YouTube video](https://www.youtube.com/watch?v=ua_I30DTggQ) for a demonstration. Check out the features and command list below for a better understanding of all the tools practicemode provides.

## Download

Download from [the releases section](https://github.com/splewis/csgo-practice-mode/releases).

You may also download the [latest development build](http://ci.splewis.net/job/csgo-practice-mode/lastSuccessfulBuild/) if you wish. If you report any bugs from these, make sure to include the build number (when typing ``sm plugins list`` into the server console, the build number will be displayed with the plugin version).

### Installation

1. Confirm you have [SourceMod](https://www.sourcemod.net/downloads.php) and [MetaMod:Source](https://metamodsource.net/downloads.php). You must have a 1.9+ build of sourcemod.

2. Extract **all** files in the release zip from above to the ``csgo`` server directory. You should see a ``practicemode.smx`` file in ``addons/sourcemod/plugins``.

3. To start practicemode via the ``.setup`` command, either [add yourself as a sourcemod admin](https://github.com/splewis/csgo-practice-mode/wiki/Command-access#adding-admins-in-sourcemod) or [remove the admin requirement](https://github.com/splewis/csgo-practice-mode/wiki/Command-access#launching-practicemode).

**Note**: access to the .setup requires having the sourcemod admin changemap flag ("g") by default. See [the wiki](https://github.com/splewis/csgo-practice-mode/wiki/Command-access) for more information on changing how admin access works.

### Download and installation for dummies

For a more thorough guide for users new to configuring servers, please see [this wiki page](https://github.com/splewis/csgo-practice-mode/wiki/Step-by-step-installation-guide).

## Features
- Draws working grenade trajectories if ``sv_grenade_trajectory`` is on (since it doesn't work on dedicated servers)
- Adds new cvars to give extra practice settings (infinite money, noclip without needing sv_cheats enabled)
- Can save users' grenade locations/eye-angles with a name and description for them (grenade data is saved to a file on the server in the ``addons/sourcemod/data/practicemode/grenades`` directory)
- Users can goto any players' saved grenades to learn or revisit them
- Displays a menu with toggle settings to set practice cvars defined in [addons/sourcemod/configs/practicemode.cfg](configs/practicemode.cfg)
- Maintains your grenade history on the current map so you can use ``.back`` and ``.forward`` to see all spots you threw grenades from in the current session
- Can replay grenade throws for testing, either in isolation or in the context of a full timed-execute

## Commands

### General commands

- ``.setup`` displays the practicemode menu
- ``.prac`` launches practice mode and displays the ``.setup`` menu
- ``.help``: displays this page
- ``.settings``: opens the client settings menu
- ``.exitprac``: exits practicemode

### Saving grenade positions
- ``.nades [filter]``: displays a menu to select saved grenade positions. ``.nades`` with no argument shows all nades. ``filter`` can be any of: nade ids, category name, player name, or part of a grenade name
- ``.cats ``: displays a menu of all saved grenades by category
- ``.save <name>``: saves your current position as a grenade spot with the given name
- ``.goto <grenadeid>``: teleports you to a player's saved grenade (or your own if no player is named)
- ``.delete``: deletes the last grenade of yours that you used .goto (or .nades) to teleport to
- ``.find <text>``: searches all grenade names for a text match

### Modifying a saved grenade
All of the following commands can only be used on _your_ grenades. They will apply to the last saved grenade you went to, whether by ``.save``, ``.nades``, or ``.goto``.
- ``.desc <description>``: adds a grenade description to your last grenade
- ``.rename <new name>``: renames your last grenade
- ``.addcat <category> ...``: adds a category to your last grenade
- ``.removecat <category>``: removes a category from your last grenade
- ``.clearcats``: removes all categories on your last grenade
- ``.deletecat <category>``: removes a category from **all** of your saved grenades
- ``.copy <username> <grenadeid>``: copies another user's grenade and saves it for you
- ``.setdelay <delay>``: sets a delay on your last grenade. This is only used when using .throw against a category

### Testing grenades
- ``.last``: teleports you back to where you threw your last grenade from
- ``.back``: teleports you back a position in your grenade history (you can also do ``.back 5`` to go to the 5th grenade you threw, for example)
- ``.forward``: teleports you forward a position in your grenade history
- ``.flash``:  saves you position to test flashbangs against it. Use this command in a spot you want to try to blind, then move and throw the flashbang; you will be teleported back to the position and see how effective the flashbang is. Use ``.stop`` to cancel.
- ``.throw [filter]``: automatically throws all grenades matching the filter. With no filter, throws the last grenade you threw.
- ``.noflash``: makes it so no flashbangs will blind you (they still blind others)

### Spawn commands
- ``.respawn``: makes you respawn at the spot you are standing (``.stop`` to cancel)
- ``.spawn <number>``: teleports you to a spawn #, using your team's spawns (CT or T). Closest spawn is used if no argument is given
- ``.ctspawn <number>``: same as .spawn, but using CT only regardless of what team you are on
- ``.tspawn <number>``: same as .spawn, but using T only regardless of what team you are on
- ``.namespawn <name>``: saves the closest spawn to you under a name, which can then be gone to via ``.spawn <name>``
- ``.bestspawn``: teleports you to your team's closest spawn from your current position
- ``.worstspawn``: teleports you to your team's furthest spawn from your current position

### Bot commands
- ``.bots``: opens the bot menu for easier access to most of the below commands
- ``.bot``: adds a bot where you're standing (or crouching!); ``.crouchbot`` to force a crouching bot
- ``.ctbot``, ``.tbot``: same as ``.bot``, but forces the bot's team to CT or T
- ``.botplace``: adds a bot at the point you're looking at (similar to the ``bot_place`` command)
- ``.boost``: spawns a bot boosting you (crouch-boosting if you're crouching); ``.crouchboost`` to force a crouching bot
- ``.swapbot``: swaps your position with the nearest bot (temporarily, the bot will respawn in the original spot still)
- ``.movebot``: moves the last bot you placed to your current position
- ``.nobot``: removes the bot you're aiming at (can also use ``.kickbot`` or ``.removebot``)
- ``.nobots``: clears all bots (``.clearbots``, ``.removebots``, ``.kickbots`` also work)
- ``.savebots``: saves all current bots to a file
- ``.loadbots``: loads bots from the file (written by the last ``.savebots``)

### Miscellaneous commands
- ``.timer``: starts a timer when you start moving in any direction, and stops it when you stop moving, telling you the duration of time between starting/stopping
- ``.timer2``: starts a timer immediately and stops it when you type .timer2 again, telling you the duration of time
- ``.countdown <duration>``: starts a countdown timer for the duration specified (in seconds), defaulting to the round duration (the `mp_roundtime` cvar).
- ``.fastfoward`` (or ``.ff``): speeds up the server clock briefly so smokes dissipate quickly
- ``.repeat <interval> <command>``: give a number of seconds and a chat command, the command will automatically repeat at the given interval. For example: ``.repeat 3 .throw`` repeats .throw every 3 seconds
- ``.delay <duration> <command>``: runs the given chat command after a given duration (in seconds)
- ``.map``: changes map (you can use a map name like ``.map de_dust2`` or just ``.map`` to get a menu)
- ``.dryrun``: disables most practicemode settings (leaving infinte money on), restarts the round, and sets freezetime to ``sm_practicemode_dry_run_freeze_time`` (default 6) - you can also use ``.dry``
- ``.enable <arg>``: enables a partially-named setting, or "all" settings.
- ``.disable <arg>``: disables a partially-named setting, or "all" settings.
- ``.savepos``: temporarily saves a position so you can ``.back`` to it (this adds the position to the list of grenade positions you've thrown)
- ``.god``: toggles god mode (alias for the ``god`` command in console; requires sv_cheats to be on)
- ``.endround``: ends the round (alias for the ``endround`` command in console; requires sv_cheats to be on)
- ``.break``: breaks all func_breakable entities (most windows)
- ``.stop``: cancels a current action (this can stop many things: the .flash command, the .repeat command, and the .timer command)
- ``.spec``, ``.t``, ``.ct``: joins a team

### Bot replay commands
**Note:** bot replay support is currently a work in progress. It's not ready for general use yet. Installing the [dhooks extension](http://users.alliedmods.net/~drifter/builds/dhooks/2.2/) is also a good idea if you plan using these commands. Expect random crashes if you use these.

- ``.replays``: opens replay mode menu
- ``.replay``: opens the replay mode menu, or the last replay/role menu you had open
- ``.namereplay``: names the replay you're currently working on
- ``.namerole``: names the role you're currently working on
- ``.finish``: finishes and saves current recording
- ``.cancel``: cancels current replay/recording
- ``.play <id> [role]``: plays a replay id (all the roles), or a single role from a replay


Also see the [notes for power users](https://github.com/splewis/csgo-practice-mode/wiki/Notes-for-power-users) for more detail on using these commands effectively.


## ConVars
You can edit these in the file ``cfg/sourcemod/practicemode.cfg``, which is autogenerated when the plugin first starts.

Note that this is not necessarily an exhaustive list; check ``cfg/sourcemod/practicemode.cfg`` for more cvars, or even consider checking the source code for a more up-to-date listing.

- ``sm_practicemode_alphabetize_nades``: displays grenades in alphabetical order instead of id order
- ``sm_practicemode_share_all_nades``: lets all users edit all nades, and hides who created them
- ``sm_practicemode_autostart``: whether to automatically start practicemode
- ``sm_practicemode_max_grenades_saved``: max # of grenades a user can save via ``.save``
- ``sm_infinite_money``: whether to give infinite money
- ``sm_allow_noclip``: whether the .noclip command is enabled
- ``sm_grenade_trajectory_use_player_color``: whether to use cl_color to get nade trajectory color
- ``sm_practicemode_can_be_started``: whether practicemode can be started

### Discord Chat

A [Discord](https://discord.gg/zmqEa4keCk) channel is available for general discussion.

### Contributions

Pull requests are welcome. Please follow the general coding formatting style as much as possible. If you're concerned about a pull request not being merged, please feel free to make an [issue](https://github.com/splewis/csgo-practice-mode/issues) and inquire if the feature is worth adding. I greatly appreciate anyone trying to contribute!
