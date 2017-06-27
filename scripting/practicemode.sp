#define UPDATE_URL "https://dl.whiffcity.com/plugins/practicemode/practicemode.txt"

#include <clientprefs>
#include <cstrike>
#include <sdkhooks>
#include <sdktools>
#include <smlib>
#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <pugsetup>
#include <updater>

#include "include/practicemode.inc"
#include "include/restorecvars.inc"
#include "practicemode/generic.sp"

#pragma semicolon 1
#pragma newdecls required

bool g_InPracticeMode = false;
bool g_PugsetupLoaded = false;

// These data structures maintain a list of settings for a toggle-able option:
// the name, the cvar/value for the enabled option, and the cvar/value for the disabled option.
// Note: the first set of values for these data structures is the overall-practice mode cvars,
// which aren't toggle-able or named.
ArrayList g_BinaryOptionIds;
ArrayList g_BinaryOptionNames;
ArrayList g_BinaryOptionEnabled;
ArrayList g_BinaryOptionChangeable;
ArrayList g_BinaryOptionEnabledCvars;
ArrayList g_BinaryOptionEnabledValues;
ArrayList g_BinaryOptionDisabledCvars;
ArrayList g_BinaryOptionDisabledValues;
ArrayList g_BinaryOptionCvarRestore;

/** Chat aliases loaded **/
#define ALIAS_LENGTH 64
#define COMMAND_LENGTH 64
ArrayList g_ChatAliases;
ArrayList g_ChatAliasesCommands;

// Plugin cvars
ConVar g_AutostartCvar;
ConVar g_MaxGrenadesSavedCvar;
ConVar g_MaxHistorySizeCvar;
ConVar g_PracModeCanBeStartedCvar;

// Infinite money data
ConVar g_InfiniteMoneyCvar;

// Grenade trajectory fix data
int g_BeamSprite = -1;
int g_ClientColors[MAXPLAYERS + 1][4];
ConVar g_PatchGrenadeTrajectoryCvar;
ConVar g_GrenadeTrajectoryClientColorCvar;

ConVar g_AllowNoclipCvar;
ConVar g_GrenadeTrajectoryCvar;
ConVar g_GrenadeThicknessCvar;
ConVar g_GrenadeTimeCvar;
ConVar g_GrenadeSpecTimeCvar;

// Saved grenade locations data
#define GRENADE_DESCRIPTION_LENGTH 256
#define GRENADE_NAME_LENGTH 64
#define GRENADE_ID_LENGTH 16
#define GRENADE_CATEGORY_LENGTH 128
#define AUTH_LENGTH 64
#define AUTH_METHOD AuthId_Steam2
char g_GrenadeLocationsFile[PLATFORM_MAX_PATH];
KeyValues
    g_GrenadeLocationsKv;  // Inside any global function, we expect this to be at the root level.
int g_CurrentSavedGrenadeId[MAXPLAYERS + 1];
bool g_UpdatedGrenadeKv = false;  // whether there has been any changed the kv structure this map

// Grenade history data
int g_GrenadeHistoryIndex[MAXPLAYERS + 1];
ArrayList g_GrenadeHistoryPositions[MAXPLAYERS + 1];
ArrayList g_GrenadeHistoryAngles[MAXPLAYERS + 1];

ArrayList g_ClientGrenadeThrowTimes[MAXPLAYERS + 1];  // ArrayList of <int:entity, float:throw time>
                                                      // pairs of live grenades
bool g_TestingFlash[MAXPLAYERS + 1];
float g_TestingFlashOrigins[MAXPLAYERS + 1][3];
float g_TestingFlashAngles[MAXPLAYERS + 1][3];

// Respawn values set by clients in the current session
bool g_SavedRespawnActive[MAXPLAYERS + 1];
float g_SavedRespawnOrigin[MAXPLAYERS + 1][3];
float g_SavedRespawnAngles[MAXPLAYERS + 1][3];

ArrayList g_KnownNadeCategories = null;

ArrayList g_ClientBots[MAXPLAYERS + 1];  // Bots owned by each client.
// int g_BotOwned[MAXPLAYERS + 1];
bool g_IsPMBot[MAXPLAYERS + 1];
float g_BotSpawnOrigin[MAXPLAYERS + 1][3];
float g_BotSpawnAngles[MAXPLAYERS + 1][3];
char g_BotSpawnWeapon[MAXPLAYERS + 1][64];
bool g_BotCrouching[MAXPLAYERS + 1];

#define PLAYER_HEIGHT 72.0
#define CLASS_LENGTH 64

// These must match the values used by cl_color.
enum ClientColor {
  ClientColor_Yellow = 0,
  ClientColor_Purple = 1,
  ClientColor_Green = 2,
  ClientColor_Blue = 3,
  ClientColor_Orange = 4,
};

int g_LastNoclipCommand[MAXPLAYERS + 1];

enum TimerType {
  TimerType_Movement = 0,
  TimerType_Manual = 1,
}

bool g_RunningTimeCommand[MAXPLAYERS + 1];
bool g_RunningLiveTimeCommand[MAXPLAYERS + 1];
TimerType g_TimerType[MAXPLAYERS + 1];
float g_LastTimeCommand[MAXPLAYERS + 1];

MoveType g_PreFastForwardMoveTypes[MAXPLAYERS + 1];

// Data storing spawn priorities.
ArrayList g_CTSpawns = null;
ArrayList g_TSpawns = null;
KeyValues g_NamedSpawnsKv = null;

#define SHOW_AIRTIME_DEFAULT true
Handle g_ShowGrenadeAirtimeCookie = INVALID_HANDLE;

#define FLASH_EFFECTIVE_THRESHOLD_DEFAULT 2.0
Handle g_FlashEffectiveThresholdCookie = INVALID_HANDLE;

#define TEST_FLASH_TELEPORT_DELAY_DEFAULT 0.3
Handle g_TestFlashTeleportDelayCookie = INVALID_HANDLE;

// Forwards
Handle g_OnGrenadeSaved = INVALID_HANDLE;
Handle g_OnPracticeModeDisabled = INVALID_HANDLE;
Handle g_OnPracticeModeEnabled = INVALID_HANDLE;
Handle g_OnPracticeModeSettingChanged = INVALID_HANDLE;
Handle g_OnPracticeModeSettingsRead = INVALID_HANDLE;

#include "practicemode/bots.sp"
#include "practicemode/commands.sp"
#include "practicemode/grenadeiterators.sp"
#include "practicemode/grenademenus.sp"
#include "practicemode/grenadeutils.sp"
#include "practicemode/natives.sp"
#include "practicemode/pugsetup_integration.sp"
#include "practicemode/spawns.sp"

// clang-format off
public Plugin myinfo = {
  name = "CS:GO PracticeMode",
  author = "splewis",
  description = "A practice mode that can be launched through the .setup menu",
  version = PLUGIN_VERSION,
  url = "https://github.com/splewis/csgo-practice-mode"
};
// clang-format on

public void OnPluginStart() {
  g_InPracticeMode = false;
  AddCommandListener(Command_TeamJoin, "jointeam");
  AddCommandListener(Command_Noclip, "noclip");

  // Forwards
  g_OnGrenadeSaved = CreateGlobalForward("PM_OnPracticeModeEnabled", ET_Event, Param_Cell,
                                         Param_Array, Param_Array, Param_String);
  g_OnPracticeModeDisabled = CreateGlobalForward("PM_OnPracticeModeEnabled", ET_Ignore);
  g_OnPracticeModeEnabled = CreateGlobalForward("PM_OnPracticeModeEnabled", ET_Ignore);
  g_OnPracticeModeSettingChanged = CreateGlobalForward(
      "PM_OnPracticeModeEnabled", ET_Ignore, Param_Cell, Param_String, Param_String, Param_Cell);
  g_OnPracticeModeSettingsRead = CreateGlobalForward("PM_OnPracticeModeEnabled", ET_Ignore);

  // Init data structures to be read from the config file
  g_BinaryOptionIds = new ArrayList(OPTION_NAME_LENGTH);
  g_BinaryOptionNames = new ArrayList(OPTION_NAME_LENGTH);
  g_BinaryOptionEnabled = new ArrayList();
  g_BinaryOptionChangeable = new ArrayList();
  g_BinaryOptionEnabledCvars = new ArrayList();
  g_BinaryOptionEnabledValues = new ArrayList();
  g_BinaryOptionDisabledCvars = new ArrayList();
  g_BinaryOptionDisabledValues = new ArrayList();
  g_BinaryOptionCvarRestore = new ArrayList();
  ReadPracticeSettings();

  // Setup stuff for grenade history
  HookEvent("weapon_fire", Event_WeaponFired);
  HookEvent("flashbang_detonate", Event_FlashDetonate);
  HookEvent("smokegrenade_detonate", Event_SmokeDetonate);

  for (int i = 0; i <= MAXPLAYERS; i++) {
    g_GrenadeHistoryPositions[i] = new ArrayList(3);
    g_GrenadeHistoryAngles[i] = new ArrayList(3);
    g_ClientGrenadeThrowTimes[i] = new ArrayList(2);
    g_ClientBots[i] = new ArrayList();
  }

  RegAdminCmd("sm_prac", Command_LaunchPracticeMode, ADMFLAG_CHANGEMAP, "Launches practice mode");
  RegAdminCmd("sm_launchpractice", Command_LaunchPracticeMode, ADMFLAG_CHANGEMAP,
              "Launches practice mode");
  RegAdminCmd("sm_practice", Command_LaunchPracticeMode, ADMFLAG_CHANGEMAP,
              "Launches practice mode");

  RegAdminCmd("sm_exitpractice", Command_ExitPracticeMode, ADMFLAG_CHANGEMAP,
              "Exits practice mode");
  RegAdminCmd("sm_translategrenades", Command_TranslateGrenades, ADMFLAG_CHANGEMAP,
              "Translates all grenades on this map");

  // Grenade history commands
  RegConsoleCmd("sm_grenadeback", Command_GrenadeBack);
  RegConsoleCmd("sm_grenadeforward", Command_GrenadeForward);
  RegConsoleCmd("sm_lastgrenade", Command_LastGrenade);
  RegConsoleCmd("sm_nextgrenade", Command_NextGrenade);
  RegConsoleCmd("sm_clearnades", Command_ClearNades);

  // Spawn commands
  RegConsoleCmd("sm_gotospawn", Command_GotoSpawn);
  RegConsoleCmd("sm_worstspawn", Command_GotoWorstSpawn);
  RegConsoleCmd("sm_namespawn", Command_SaveSpawn);

  // Other commands
  RegConsoleCmd("sm_testflash", Command_TestFlash);
  RegConsoleCmd("sm_stopflash", Command_StopFlash);
  RegConsoleCmd("sm_time", Command_Time);
  RegConsoleCmd("sm_time2", Command_Time2);
  RegConsoleCmd("sm_fastforward", Command_FastForward);

  // Bot commands
  RegConsoleCmd("sm_bot", Command_Bot);
  RegConsoleCmd("sm_movebot", Command_MoveBot);
  RegConsoleCmd("sm_crouchbot", Command_CrouchBot);
  RegConsoleCmd("sm_botplace", Command_BotPlace);
  RegConsoleCmd("sm_boost", Command_Boost);
  RegConsoleCmd("sm_crouchboost", Command_CrouchBoost);
  RegConsoleCmd("sm_removebot", Command_RemoveBot);
  RegConsoleCmd("sm_removebots", Command_RemoveBots);

  PM_AddChatAlias(".back", "sm_grenadeback");
  PM_AddChatAlias(".last", "sm_lastgrenade");
  PM_AddChatAlias(".forward", "sm_grenadeforward");
  PM_AddChatAlias(".clearnades", "sm_clearnades");
  PM_AddChatAlias(".goto", "sm_gotogrenade");
  PM_AddChatAlias(".next", "sm_nextgrenade");
  PM_AddChatAlias(".nextid", "sm_nextgrenade");

  PM_AddChatAlias(".spawn", "sm_gotospawn");
  PM_AddChatAlias(".bestspawn", "sm_gotospawn");
  PM_AddChatAlias(".worstspawn", "sm_worstspawn");
  PM_AddChatAlias(".namespawn", "sm_namespawn");

  PM_AddChatAlias(".flash", "sm_testflash");
  PM_AddChatAlias(".testflash", "sm_testflash");
  PM_AddChatAlias(".startflash", "sm_testflash");
  PM_AddChatAlias(".endflash", "sm_stopflash");
  PM_AddChatAlias(".stopflash", "sm_stopflash");

  PM_AddChatAlias(".timer", "sm_time");
  PM_AddChatAlias(".time", "sm_time");
  PM_AddChatAlias(".timer2", "sm_time2");

  PM_AddChatAlias(".bot", "sm_bot");
  PM_AddChatAlias(".addbot", "sm_bot");
  PM_AddChatAlias(".movebot", "sm_movebot");
  PM_AddChatAlias(".crouchbot", "sm_crouchbot");
  PM_AddChatAlias(".cbot", "sm_crouchbot");
  PM_AddChatAlias(".botplace", "sm_botplace");
  PM_AddChatAlias(".bot2", "sm_botplace");
  PM_AddChatAlias(".boost", "sm_boost");
  PM_AddChatAlias(".crouchboost", "sm_crouchboost");
  PM_AddChatAlias(".cboost", "sm_crouchboost");

  PM_AddChatAlias(".removebot", "sm_removebot");
  PM_AddChatAlias(".kickbot", "sm_removebot");
  PM_AddChatAlias(".clearbot", "sm_removebot");
  PM_AddChatAlias(".clearbots", "sm_removebots");
  PM_AddChatAlias(".nobot", "sm_removebot");

  PM_AddChatAlias(".fastforward", "sm_fastforward");
  PM_AddChatAlias(".fast", "sm_fastforward");
  PM_AddChatAlias(".ff", "sm_fastforward");

  // Saved grenade location commands
  RegConsoleCmd("sm_gotogrenade", Command_GotoNade);
  RegConsoleCmd("sm_grenades", Command_Grenades);
  RegConsoleCmd("sm_renamegrenade", Command_RenameGrenade);
  RegConsoleCmd("sm_savegrenade", Command_SaveGrenade);
  RegConsoleCmd("sm_movegrenade", Command_MoveGrenade);
  RegConsoleCmd("sm_adddescription", Command_GrenadeDescription);
  RegConsoleCmd("sm_deletegrenade", Command_DeleteGrenade);
  RegConsoleCmd("sm_categories", Command_Categories);
  RegConsoleCmd("sm_addcategory", Command_AddCategory);
  RegConsoleCmd("sm_addcategories", Command_AddCategories);
  RegConsoleCmd("sm_removecategory", Command_RemoveCategory);
  RegConsoleCmd("sm_deletecategory", Command_DeleteCategory);
  RegConsoleCmd("sm_clearcategories", Command_ClearGrenadeCategories);
  RegConsoleCmd("sm_copygrenade", Command_CopyGrenade);
  RegConsoleCmd("sm_respawn", Command_Respawn);
  RegConsoleCmd("sm_stoprespawn", Command_Respawn);
  RegConsoleCmd("sm_stopall", Command_StopAll);
  PM_AddChatAlias(".nades", "sm_grenades");
  PM_AddChatAlias(".grenades", "sm_grenades");
  PM_AddChatAlias(".addnade", "sm_savegrenade");
  PM_AddChatAlias(".savenade", "sm_savegrenade");
  PM_AddChatAlias(".save", "sm_savegrenade");
  PM_AddChatAlias(".resave", "sm_movegrenade");
  PM_AddChatAlias(".update", "sm_movegrenade");
  PM_AddChatAlias(".move", "sm_movegrenade");
  PM_AddChatAlias(".desc", "sm_adddescription");
  PM_AddChatAlias(".rename", "sm_renamegrenade");
  PM_AddChatAlias(".delete", "sm_deletegrenade");
  PM_AddChatAlias(".category", "sm_addcategory");
  PM_AddChatAlias(".cat", "sm_addcategory");
  PM_AddChatAlias(".cats", "sm_categories");
  PM_AddChatAlias(".addcategory", "sm_addcategory");
  PM_AddChatAlias(".addcat", "sm_addcategory");
  PM_AddChatAlias(".addcats", "sm_addcategories");
  PM_AddChatAlias(".removecategory", "sm_removecategory");
  PM_AddChatAlias(".removecat", "sm_removecategory");
  PM_AddChatAlias(".deletecat", "sm_deletecategory");
  PM_AddChatAlias(".clearcats", "sm_clearcategories");
  PM_AddChatAlias(".copy", "sm_copygrenade");
  PM_AddChatAlias(".respawn", "sm_respawn");
  PM_AddChatAlias(".stoprespawn", "sm_stoprespawn");
  PM_AddChatAlias(".stop", "sm_stopall");

  // New Plugin cvars
  g_AutostartCvar = CreateConVar("sm_practicemode_autostart", "0",
                                 "Whether the plugin is automatically started on mapstart");
  g_MaxHistorySizeCvar =
      CreateConVar("sm_practicemode_max_grenade_history_size", "1000",
                   "Maximum number of grenades throws saved in history per-client");
  g_MaxGrenadesSavedCvar = CreateConVar("sm_practicemode_max_grenades_saved", "256",
                                        "Maximum number of grenades saved per-map per-client");
  g_PracModeCanBeStartedCvar =
      CreateConVar("sm_practicemode_can_be_started", "1", "Whether practicemode may be started");
  AutoExecConfig(true, "practicemode");

  // New cvars we don't want saved in the autoexec'd file
  g_InfiniteMoneyCvar = CreateConVar("sm_infinite_money", "0",
                                     "Whether clients recieve infinite money", FCVAR_DONTRECORD);
  g_AllowNoclipCvar =
      CreateConVar("sm_allow_noclip", "0",
                   "Whether players may use .noclip in chat to toggle noclip", FCVAR_DONTRECORD);

  g_PatchGrenadeTrajectoryCvar =
      CreateConVar("sm_patch_grenade_trajectory_cvar", "1",
                   "Whether the plugin patches sv_grenade_trajectory with its own grenade trails");
  g_GrenadeTrajectoryClientColorCvar =
      CreateConVar("sm_grenade_trajectory_use_player_color", "0",
                   "Whether to use client colors when drawing grenade trajectories");

  // Patched builtin cvars
  g_GrenadeTrajectoryCvar = GetCvar("sv_grenade_trajectory");
  g_GrenadeThicknessCvar = GetCvar("sv_grenade_trajectory_thickness");
  g_GrenadeTimeCvar = GetCvar("sv_grenade_trajectory_time");
  g_GrenadeSpecTimeCvar = GetCvar("sv_grenade_trajectory_time_spectator");

  // set default colors to green
  for (int i = 0; i <= MAXPLAYERS; i++) {
    g_ClientColors[0][0] = 0;
    g_ClientColors[0][1] = 255;
    g_ClientColors[0][2] = 0;
    g_ClientColors[0][3] = 255;
  }

  g_CTSpawns = new ArrayList();
  g_TSpawns = new ArrayList();
  g_KnownNadeCategories = new ArrayList(GRENADE_CATEGORY_LENGTH);

  // Create client cookies.
  g_ShowGrenadeAirtimeCookie =
      RegClientCookie("practicemode_grenade_airtime",
                      "Whether to display airtime of grenades in chat", CookieAccess_Public);
  g_FlashEffectiveThresholdCookie =
      RegClientCookie("practicemode_flash_threshold",
                      "Number of seconds a flash must last to be effective", CookieAccess_Public);
  g_TestFlashTeleportDelayCookie = RegClientCookie(
      "practicemode_testflash_delay",
      "Seconds (as a float) waited before teleporting after throwing a flash using .flash",
      CookieAccess_Public);

  // Remove cheats so sv_cheats isn't required for this:
  RemoveCvarFlag(g_GrenadeTrajectoryCvar, FCVAR_CHEAT);

  HookEvent("server_cvar", Event_CvarChanged, EventHookMode_Pre);
  HookEvent("player_spawn", Event_PlayerSpawn);
  HookEvent("player_hurt", Event_DamageDealtEvent, EventHookMode_Pre);

  g_PugsetupLoaded = LibraryExists("pugsetup");

  CreateTimer(1.0, Timer_GivePlayersMoney, _, TIMER_REPEAT);
}

public void OnPluginEnd() {
  if (g_InPracticeMode) {
    ExitPracticeMode();
  }
}

public void OnLibraryAdded(const char[] name) {
  g_PugsetupLoaded = LibraryExists("pugsetup");
  if (LibraryExists("updater")) {
    Updater_AddPlugin(UPDATE_URL);
  }
}

public void OnLibraryRemoved(const char[] name) {
  g_PugsetupLoaded = LibraryExists("pugsetup");
}

/**
 * Silences all cvar changes in practice mode.
 */
public Action Event_CvarChanged(Event event, const char[] name, bool dontBroadcast) {
  if (g_InPracticeMode) {
    event.BroadcastDisabled = true;
  }
  return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InPracticeMode) {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(event.GetInt("userid"));
  if (IsPlayer(client) && g_SavedRespawnActive[client]) {
    TeleportEntity(client, g_SavedRespawnOrigin[client], g_SavedRespawnAngles[client], NULL_VECTOR);
  }
  if (IsPMBot(client)) {
    GiveBotParams(client);
  }
  return Plugin_Continue;
}

public void OnClientConnected(int client) {
  g_CurrentSavedGrenadeId[client] = -1;
  g_GrenadeHistoryIndex[client] = -1;
  ClearArray(g_GrenadeHistoryPositions[client]);
  ClearArray(g_GrenadeHistoryAngles[client]);
  ClearArray(g_ClientGrenadeThrowTimes[client]);
  g_TestingFlash[client] = false;
  g_RunningTimeCommand[client] = false;
  g_RunningLiveTimeCommand[client] = false;
  g_SavedRespawnActive[client] = false;
}

public void OnMapStart() {
  ReadPracticeSettings();
  g_BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
  g_KnownNadeCategories.Clear();

  EnforceDirectoryExists("data/practicemode");
  EnforceDirectoryExists("data/practicemode/grenades");
  EnforceDirectoryExists("data/practicemode/spawns");

  // This supports backwards compatability for grenades saved in the old location
  // data/practicemode_grenades. The data is transferred to the new
  // location if they are read from the legacy location.
  char legacyDir[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, legacyDir, sizeof(legacyDir), "data/practicemode_grenades");

  char map[PLATFORM_MAX_PATH];
  GetCleanMapName(map, sizeof(map));

  char legacyFile[PLATFORM_MAX_PATH];
  Format(legacyFile, sizeof(legacyFile), "%s/%s.cfg", legacyDir, map);

  BuildPath(Path_SM, g_GrenadeLocationsFile, sizeof(g_GrenadeLocationsFile),
            "data/practicemode/grenades/%s.cfg", map);

  if (!FileExists(g_GrenadeLocationsFile) && FileExists(legacyFile)) {
    LogMessage("Moving legacy grenade data from %s to %s", legacyFile, g_GrenadeLocationsFile);
    g_GrenadeLocationsKv = new KeyValues("Grenades");
    g_GrenadeLocationsKv.ImportFromFile(legacyFile);
    g_UpdatedGrenadeKv = true;
  } else {
    g_GrenadeLocationsKv = new KeyValues("Grenades");
    g_GrenadeLocationsKv.ImportFromFile(g_GrenadeLocationsFile);
    g_UpdatedGrenadeKv = false;
  }

  FindGrenadeCategories();
  Spawns_MapStart();
}

public void OnConfigsExecuted() {
  // Disable legacy plugin if found.
  char legacyPluginFile[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, legacyPluginFile, sizeof(legacyPluginFile),
            "plugins/pugsetup_practicemode.smx");
  if (FileExists(legacyPluginFile)) {
    char disabledLegacyPluginName[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, disabledLegacyPluginName, sizeof(disabledLegacyPluginName),
              "plugins/disabled/pugsetup_practicemode.smx");
    ServerCommand("sm plugins unload pugsetup_practicemode");
    if (FileExists(disabledLegacyPluginName))
      DeleteFile(disabledLegacyPluginName);
    RenameFile(disabledLegacyPluginName, legacyPluginFile);
    LogMessage("%s was unloaded and moved to %s", legacyPluginFile, disabledLegacyPluginName);
  }

  // Autostart practicemode if enabled.
  if (g_AutostartCvar.IntValue != 0) {
    if (g_PugsetupLoaded && PugSetup_GetGameState() != GameState_None) {
      return;
    }
    LaunchPracticeMode();
  }
}

public void OnClientDisconnect(int client) {
  // always update the grenades file so user's saved grenades are never lost
  if (g_UpdatedGrenadeKv) {
    g_GrenadeLocationsKv.ExportToFile(g_GrenadeLocationsFile);
    g_UpdatedGrenadeKv = false;
  }

  if (g_InPracticeMode) {
    KickAllClientBots(client);
  }

  g_IsPMBot[client] = false;
}

public void OnMapEnd() {
  if (g_UpdatedGrenadeKv) {
    g_GrenadeLocationsKv.ExportToFile(g_GrenadeLocationsFile);
    g_UpdatedGrenadeKv = false;
  }

  if (g_InPracticeMode)
    ExitPracticeMode();

  Spawns_MapEnd();
  delete g_GrenadeLocationsKv;
}

public void OnClientSettingsChanged(int client) {
  UpdatePlayerColor(client);
}

public void OnClientPutInServer(int client) {
  UpdatePlayerColor(client);
}

public void UpdatePlayerColor(int client) {
  QueryClientConVar(client, "cl_color", QueryClientColor, client);
}

public void QueryClientColor(QueryCookie cookie, int client, ConVarQueryResult result,
                      const char[] cvarName, const char[] cvarValue) {
  int color = StringToInt(cvarValue);
  GetColor(view_as<ClientColor>(color), g_ClientColors[client]);
}

public void GetColor(ClientColor c, int array[4]) {
  int r, g, b;
  switch (c) {
    case ClientColor_Yellow: {
      r = 229;
      g = 224;
      b = 44;
    }
    case ClientColor_Purple: {
      r = 150;
      g = 45;
      b = 225;
    }
    case ClientColor_Green: {
      r = 23;
      g = 255;
      b = 102;
    }
    case ClientColor_Blue: {
      r = 112;
      g = 191;
      b = 255;
    }
    case ClientColor_Orange: {
      r = 227;
      g = 152;
      b = 33;
    }
    default: {
      r = 23;
      g = 255;
      b = 102;
    }
  }
  array[0] = r;
  array[1] = g;
  array[2] = b;
  array[3] = 255;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3],
                      int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed,
                      int mouse[2]) {
  if (!g_InPracticeMode) {
    return Plugin_Continue;
  }

  if (IsPMBot(client)) {
    if (g_BotCrouching[client]) {
      buttons |= IN_DUCK;
    } else {
      buttons &= ~IN_DUCK;
    }
    return Plugin_Continue;
  }

  if (!IsPlayer(client)) {
    return Plugin_Continue;
  }

  bool moving = MovingButtons(buttons);
  if (g_RunningTimeCommand[client] && g_TimerType[client] == TimerType_Movement) {
    if (g_RunningLiveTimeCommand[client]) {
      // The movement timer is already running; stop it.
      if (!moving && GetEntityFlags(client) & FL_ONGROUND) {
        g_RunningTimeCommand[client] = false;
        g_RunningLiveTimeCommand[client] = false;
        StopClientTimer(client);
      }
    } else {
      //  We're pending a movement timer start.
      if (moving) {
        g_RunningLiveTimeCommand[client] = true;
        StartClientTimer(client);
      }
    }
  }

  return Plugin_Continue;
}

static bool MovingButtons(int buttons) {
  return buttons & IN_FORWARD != 0 || buttons & IN_MOVELEFT != 0 || buttons & IN_MOVERIGHT != 0 ||
         buttons & IN_BACK != 0;
}

public Action Command_TeamJoin(int client, const char[] command, int argc) {
  if (!IsValidClient(client) || argc < 1)
    return Plugin_Handled;

  if (g_InPracticeMode) {
    char arg[4];
    GetCmdArg(1, arg, sizeof(arg));
    int team = StringToInt(arg);
    SwitchPlayerTeam(client, team);
    return Plugin_Handled;
  }

  return Plugin_Continue;
}

public Action Command_Noclip(int client, const char[] command, int argc) {
  PerformNoclipAction(client);
  return Plugin_Handled;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] text) {
  if (g_AllowNoclipCvar.IntValue != 0 && StrEqual(text, ".noclip") && IsPlayer(client)) {
    PerformNoclipAction(client);
  }
}

public void PerformNoclipAction(int client) {
  // The move type is also set on the next frame. This is a dirty trick to deal
  // with clients that have a double-bind of "noclip; say .noclip" to work on both
  // ESEA-practice and local sv_cheats servers. Since this plugin can have both enabled
  // (sv_cheats and allow noclip), this double bind would cause the noclip type to be toggled twice.
  // Therefore the fix is to only perform 1 noclip action per-frame per-client at most, implemented
  // by saving the frame count of each use in g_LastNoclipCommand.
  if (g_LastNoclipCommand[client] == GetGameTickCount() ||
      (g_AllowNoclipCvar.IntValue == 0 && GetCvarIntSafe("sv_cheats") == 0)) {
    return;
  }

  g_LastNoclipCommand[client] = GetGameTickCount();
  MoveType t = GetEntityMoveType(client);
  MoveType next = (t == MOVETYPE_WALK) ? MOVETYPE_NOCLIP : MOVETYPE_WALK;
  SetEntityMoveType(client, next);

  if (next == MOVETYPE_WALK) {
    SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
  } else {
    SetEntProp(client, Prop_Data, "m_CollisionGroup", 0);
  }
}

public void ReadPracticeSettings() {
  ClearArray(g_BinaryOptionNames);
  ClearArray(g_BinaryOptionEnabled);
  ClearArray(g_BinaryOptionChangeable);
  ClearNestedArray(g_BinaryOptionEnabledCvars);
  ClearNestedArray(g_BinaryOptionEnabledValues);
  ClearNestedArray(g_BinaryOptionDisabledCvars);
  ClearNestedArray(g_BinaryOptionDisabledValues);
  ClearArray(g_BinaryOptionCvarRestore);

  char filePath[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, filePath, sizeof(filePath), "configs/practicemode.cfg");

  KeyValues kv = new KeyValues("practice_settings");
  if (!kv.ImportFromFile(filePath)) {
    LogError("Failed to import keyvalue from practice config file \"%s\"", filePath);
    delete kv;
    return;
  }

  // Read in the binary options
  if (kv.JumpToKey("binary_options")) {
    if (kv.GotoFirstSubKey()) {
      // read each option
      do {
        char id[128];
        kv.GetSectionName(id, sizeof(id));

        char name[OPTION_NAME_LENGTH];
        kv.GetString("name", name, sizeof(name));

        char enabledString[64];
        kv.GetString("default", enabledString, sizeof(enabledString), "enabled");
        bool enabled = StrEqual(enabledString, "enabled", false);

        bool changeable = (kv.GetNum("changeable", 1) != 0);

        // read the enabled cvar list
        ArrayList enabledCvars = new ArrayList(CVAR_NAME_LENGTH);
        ArrayList enabledValues = new ArrayList(CVAR_VALUE_LENGTH);
        if (kv.JumpToKey("enabled")) {
          ReadCvarKv(kv, enabledCvars, enabledValues);
          kv.GoBack();
        }

        ArrayList disabledCvars = new ArrayList(CVAR_NAME_LENGTH);
        ArrayList disabledValues = new ArrayList(CVAR_VALUE_LENGTH);
        if (kv.JumpToKey("disabled")) {
          ReadCvarKv(kv, disabledCvars, disabledValues);
          kv.GoBack();
        }

        PM_AddSetting(id, name, enabledCvars, enabledValues, enabled, changeable, disabledCvars,
                      disabledValues);

      } while (kv.GotoNextKey());
    }
  }
  kv.Rewind();

  Call_StartForward(g_OnPracticeModeSettingsRead);
  Call_Finish();

  delete kv;
}

public void LaunchPracticeMode() {
  ServerCommand("exec sourcemod/practicemode_start.cfg");

  g_InPracticeMode = true;
  for (int i = 0; i < g_BinaryOptionNames.Length; i++) {
    ChangeSetting(i, PM_IsSettingEnabled(i), false);
  }

  PM_MessageToAll("Practice mode is now enabled.");
  Call_StartForward(g_OnPracticeModeEnabled);
  Call_Finish();
}

stock void ChangeSetting(int index, bool enabled, bool print = true) {
  if (enabled) {
    ArrayList cvars = g_BinaryOptionEnabledCvars.Get(index);
    ArrayList values = g_BinaryOptionEnabledValues.Get(index);
    g_BinaryOptionCvarRestore.Set(index, SaveCvars(cvars));
    ExecuteCvarLists(cvars, values);
  } else {
    ArrayList cvars = g_BinaryOptionDisabledCvars.Get(index);
    ArrayList values = g_BinaryOptionDisabledValues.Get(index);

    if (cvars != null && cvars.Length > 0 && values != null && values.Length == cvars.Length) {
      // If there are are disabled cvars explicity set.
      ExecuteCvarLists(cvars, values);
    } else {
      // If there are no "disabled" cvars explicity set, we'll just restore to the cvar
      // values before the option was enabled.
      Handle cvarRestore = g_BinaryOptionCvarRestore.Get(index);
      if (cvarRestore != INVALID_HANDLE) {
        RestoreCvars(cvarRestore, true);
        g_BinaryOptionCvarRestore.Set(index, INVALID_HANDLE);
      }
    }
  }

  char id[OPTION_NAME_LENGTH];
  char name[OPTION_NAME_LENGTH];
  g_BinaryOptionIds.GetString(index, id, sizeof(id));
  g_BinaryOptionNames.GetString(index, name, sizeof(name));

  if (print) {
    char enabledString[32];
    GetEnabledString(enabledString, sizeof(enabledString), enabled);

    // don't display empty names
    if (!StrEqual(name, "")) {
      PM_MessageToAll("%s is now %s.", name, enabledString);
    }
  }

  Call_StartForward(g_OnPracticeModeSettingChanged);
  Call_PushCell(index);
  Call_PushString(id);
  Call_PushString(name);
  Call_PushCell(enabled);
  Call_Finish();
}

public void ExitPracticeMode() {
  Call_StartForward(g_OnPracticeModeDisabled);
  Call_Finish();

  for (int i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i) && IsFakeClient(i) && g_IsPMBot[i]) {
      KickClient(i);
      g_IsPMBot[i] = false;
    }
  }

  for (int i = 0; i < g_BinaryOptionNames.Length; i++) {
    ChangeSetting(i, false, false);

    // Restore the cvar values if they haven't already been.
    Handle cvarRestore = g_BinaryOptionCvarRestore.Get(i);
    if (cvarRestore != INVALID_HANDLE) {
      RestoreCvars(cvarRestore, true);
      g_BinaryOptionCvarRestore.Set(i, INVALID_HANDLE);
    }
  }

  g_InPracticeMode = false;

  // force turn noclip off for everyone
  for (int i = 1; i <= MaxClients; i++) {
    g_TestingFlash[i] = false;
    if (IsValidClient(i)) {
      SetEntityMoveType(i, MOVETYPE_WALK);
    }
  }

  ServerCommand("exec sourcemod/practicemode_end.cfg");
  PM_MessageToAll("Practice mode is now disabled.");
}

public Action Timer_GivePlayersMoney(Handle timer) {
  if (g_InfiniteMoneyCvar.IntValue != 0) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPlayer(i)) {
        SetEntProp(i, Prop_Send, "m_iAccount", 16000);
      }
    }
  }

  return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] className) {
  if (!IsValidEntity(entity)) {
    return;
  }

  SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawned);
}

public int OnEntitySpawned(int entity) {
  if (!IsValidEdict(entity)) {
    return;
  }

  char className[CLASS_LENGTH];
  GetEdictClassname(entity, className, sizeof(className));

  if (IsGrenadeProjectile(className)) {
    // Get the cl_color value for the client that threw this grenade.
    int client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
    if (IsPlayer(client) && g_InPracticeMode && StrEqual(className, "smokegrenade_projectile")) {
      int index = g_ClientGrenadeThrowTimes[client].Push(entity);
      g_ClientGrenadeThrowTimes[client].Set(index, view_as<int>(GetEngineTime()), 1);
    }

    if (IsValidEntity(entity)) {
      if (g_GrenadeTrajectoryCvar.IntValue != 0 && g_PatchGrenadeTrajectoryCvar.IntValue != 0) {
        // Send a temp ent beam that follows the grenade entity to all other clients.
        for (int i = 1; i <= MaxClients; i++) {
          if (!IsClientConnected(i) || !IsClientInGame(i)) {
            continue;
          }

          // Note: the technique using temporary entities is taken from InternetBully's NadeTails
          // plugin
          // which you can find at https://forums.alliedmods.net/showthread.php?t=240668
          float time = (GetClientTeam(i) == CS_TEAM_SPECTATOR) ? g_GrenadeSpecTimeCvar.FloatValue
                                                               : g_GrenadeTimeCvar.FloatValue;

          int coloringClient = client;
          if (g_GrenadeTrajectoryClientColorCvar.IntValue == 0 || !IsPlayer(client)) {
            coloringClient = 0;
          }

          TE_SetupBeamFollow(entity, g_BeamSprite, 0, time, g_GrenadeThicknessCvar.FloatValue * 5,
                             g_GrenadeThicknessCvar.FloatValue * 5, 1,
                             g_ClientColors[coloringClient]);
          TE_SendToClient(i);
        }
      }

      // If the user recently indicated they are testing a flash (.flash),
      // teleport to that spot.
      if (StrEqual(className, "flashbang_projectile") && g_TestingFlash[client]) {
        float delay = GetCookieFloat(client, g_TestFlashTeleportDelayCookie,
                                     TEST_FLASH_TELEPORT_DELAY_DEFAULT);

        if (delay <= 0.0)
          delay = 0.1;

        CreateTimer(delay, Timer_TeleportClient, GetClientSerial(client));
      }
    }
  }
}

public Action Timer_TeleportClient(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  if (g_InPracticeMode && IsPlayer(client) && g_TestingFlash[client]) {
    float velocity[3];
    TeleportEntity(client, g_TestingFlashOrigins[client], g_TestingFlashAngles[client], velocity);
    SetEntityMoveType(client, MOVETYPE_NONE);
  }
}

public Action Timer_FakeGrenadeBack(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  if (g_InPracticeMode && IsPlayer(client)) {
    FakeClientCommand(client, "sm_lastgrenade");
  }
}

public Action Event_WeaponFired(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InPracticeMode) {
    return;
  }

  int userid = event.GetInt("userid");
  int client = GetClientOfUserId(userid);
  char weapon[CLASS_LENGTH];
  event.GetString("weapon", weapon, sizeof(weapon));

  if (IsGrenadeWeapon(weapon) && IsPlayer(client)) {
    if (GetArraySize(g_GrenadeHistoryPositions[client]) >= g_MaxHistorySizeCvar.IntValue) {
      RemoveFromArray(g_GrenadeHistoryPositions[client], 0);
      RemoveFromArray(g_GrenadeHistoryAngles[client], 0);
    }

    float position[3];
    float angles[3];
    GetClientAbsOrigin(client, position);
    GetClientEyeAngles(client, angles);
    PushArrayArray(g_GrenadeHistoryPositions[client], position, sizeof(position));
    PushArrayArray(g_GrenadeHistoryAngles[client], angles, sizeof(angles));
    g_GrenadeHistoryIndex[client] = g_GrenadeHistoryPositions[client].Length;
  }
}

public Action Event_SmokeDetonate(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InPracticeMode) {
    return;
  }
  GrenadeDetonateTimerHelper(event, "smoke grenade");
}

public void GrenadeDetonateTimerHelper(Event event, const char[] grenadeName) {
  int userid = event.GetInt("userid");
  int client = GetClientOfUserId(userid);
  int entity = event.GetInt("entityid");

  if (IsPlayer(client)) {
    for (int i = 0; i < g_ClientGrenadeThrowTimes[client].Length; i++) {
      if (g_ClientGrenadeThrowTimes[client].Get(i, 0) == entity) {
        float dt = GetEngineTime() - view_as<float>(g_ClientGrenadeThrowTimes[client].Get(i, 1));
        g_ClientGrenadeThrowTimes[client].Erase(i);
        if (GetCookieBool(client, g_ShowGrenadeAirtimeCookie, SHOW_AIRTIME_DEFAULT)) {
          PM_Message(client, "Airtime of %s: %.1f seconds", grenadeName, dt);
        }
        break;
      }
    }
  }
}

public Action Event_FlashDetonate(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InPracticeMode) {
    return;
  }

  int userid = event.GetInt("userid");
  int client = GetClientOfUserId(userid);
  if (IsPlayer(client) && g_TestingFlash[client]) {
    // Get the impact of the flash next frame, since doing it in
    // this frame doesn't work.
    RequestFrame(GetFlashInfo, GetClientSerial(client));
  }
}

public void GetFlashInfo(int serial) {
  int client = GetClientFromSerial(serial);
  if (IsPlayer(client) && g_TestingFlash[client]) {
    float flashDuration =
        GetEntDataFloat(client, FindSendPropInfo("CCSPlayer", "m_flFlashDuration"));
    PM_Message(client, "Flash duration: %.1f seconds", flashDuration);

    if (flashDuration < GetCookieFloat(client, g_FlashEffectiveThresholdCookie,
                                       FLASH_EFFECTIVE_THRESHOLD_DEFAULT)) {
      PM_Message(client, "Ineffective flash");
      CreateTimer(1.0, Timer_FakeGrenadeBack, GetClientSerial(client));
    } else {
      float delay = flashDuration - 1.0;
      if (delay <= 0.0)
        delay = 0.1;

      CreateTimer(delay, Timer_FakeGrenadeBack, GetClientSerial(client));
    }
  }
}

static bool CheckChatAlias(const char[] alias, const char[] command, const char[] chatCommand,
                           const char[] chatArgs, int client) {
  if (StrEqual(chatCommand, alias, false)) {
    // Get the original cmd reply source so it can be restored after the fake client command.
    // This means and ReplyToCommand will go into the chat area, rather than console, since
    // *chat* aliases are for *chat* commands.
    ReplySource replySource = GetCmdReplySource();
    SetCmdReplySource(SM_REPLY_TO_CHAT);
    char fakeCommand[256];
    Format(fakeCommand, sizeof(fakeCommand), "%s %s", command, chatArgs);
    FakeClientCommand(client, fakeCommand);
    SetCmdReplySource(replySource);
    return true;
  }
  return false;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs) {
  if (!IsPlayer(client))
    return;

  // splits to find the first word to do a chat alias command check
  char chatCommand[COMMAND_LENGTH];
  char chatArgs[255];
  int index = SplitString(sArgs, " ", chatCommand, sizeof(chatCommand));

  if (index == -1) {
    strcopy(chatCommand, sizeof(chatCommand), sArgs);
  } else if (index < strlen(sArgs)) {
    strcopy(chatArgs, sizeof(chatArgs), sArgs[index]);
  }

  if (chatCommand[0]) {
    char alias[ALIAS_LENGTH];
    char cmd[COMMAND_LENGTH];
    for (int i = 0; i < GetArraySize(g_ChatAliases); i++) {
      g_ChatAliases.GetString(i, alias, sizeof(alias));
      g_ChatAliasesCommands.GetString(i, cmd, sizeof(cmd));

      if (CheckChatAlias(alias, cmd, chatCommand, chatArgs, client)) {
        break;
      }
    }
  }

  if (!g_PugsetupLoaded) {
    if (StrEqual(chatCommand, ".setup")) {
      if (CanStartPracticeMode(client)) {
        GivePracticeMenu(client);
      } else {
        if (!CheckCommandAccess(client, "sm_prac", ADMFLAG_CHANGEMAP)) {
          PM_Message(client, "You don't have permission to start practicemode.");
        } else {
          PM_Message(client, "You cannot use .setup right now.");
        }
      }
    } else if (StrEqual(chatCommand, ".help")) {
      ShowHelpInfo(client);
    }
  }
}

public void ShowHelpInfo(int client) {
  ShowMOTDPanel(client, "Practicemode Help", "http://csgo.splewis.net/redirect_practicemode_help",
                MOTDPANEL_TYPE_URL);
  QueryClientConVar(client, "cl_disablehtmlmotd", CheckMOTDAllowed, client);
}

public void CheckMOTDAllowed(QueryCookie cookie, int client, ConVarQueryResult result,
                      const char[] cvarName, const char[] cvarValue) {
  if (!StrEqual(cvarValue, "0")) {
    PrintToChat(client, "You must have \x04cl_disablehtmlmotd 0 \x01to use that command.");
  }
}

bool CanStartPracticeMode(int client) {
  if (g_PracModeCanBeStartedCvar.IntValue == 0) {
    return false;
  }
  return CheckCommandAccess(client, "sm_prac", ADMFLAG_CHANGEMAP);
}
