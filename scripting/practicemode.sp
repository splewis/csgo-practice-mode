#include <cstrike>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <pugsetup>

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
ArrayList g_BinaryOptionCvarRestore;

/** Chat aliases loaded **/
#define ALIAS_LENGTH 64
#define COMMAND_LENGTH 64
ArrayList g_ChatAliases;
ArrayList g_ChatAliasesCommands;

// Plugin cvars
ConVar g_AutostartCvar;
ConVar g_MaxHistorySizeCvar;
ConVar g_MaxGrenadesSavedCvar;

// Infinite money data
ConVar g_InfiniteMoneyCvar;
bool g_InfiniteMoney = false;

// Grenade trajectory fix data
int g_BeamSprite = -1;
int g_ClientColors[MAXPLAYERS+1][4];
ConVar g_GrenadeTrajectoryClientColorCvar;
bool g_GrenadeTrajectoryClientColor = true;

ConVar g_AllowNoclipCvar;
bool g_AllowNoclip = false;

ConVar g_GrenadeTrajectoryCvar;
ConVar g_GrenadeThicknessCvar;
ConVar g_GrenadeTimeCvar;
ConVar g_GrenadeSpecTimeCvar;
bool g_GrenadeTrajectory = false;
float g_GrenadeThickness = 0.2;
float g_GrenadeTime = 20.0;
float g_GrenadeSpecTime = 4.0;

// Saved grenade locations data
#define GRENADE_DESCRIPTION_LENGTH 256
#define GRENADE_NAME_LENGTH 64
#define GRENADE_ID_LENGTH 16
#define AUTH_LENGTH 64
char g_GrenadeLocationsFile[PLATFORM_MAX_PATH];
KeyValues g_GrenadeLocationsKv;
int g_CurrentSavedGrenadeId[MAXPLAYERS+1];
bool g_UpdatedGrenadeKv = false; // whether there has been any changed the kv structure this map

// Grenade history data
int g_GrenadeHistoryIndex[MAXPLAYERS+1];
ArrayList g_GrenadeHistoryPositions[MAXPLAYERS+1];
ArrayList g_GrenadeHistoryAngles[MAXPLAYERS+1];

// These must match the values used by cl_color.
enum ClientColor {
    ClientColor_Yellow = 0,
    ClientColor_Purple = 1,
    ClientColor_Green = 2,
    ClientColor_Blue = 3,
    ClientColor_Orange = 4,
};

int g_LastNoclipCommand[MAXPLAYERS+1];

// Forwards
Handle g_OnGrenadeSaved = INVALID_HANDLE;
Handle g_OnPracticeModeDisabled = INVALID_HANDLE;
Handle g_OnPracticeModeEnabled = INVALID_HANDLE;
Handle g_OnPracticeModeSettingChanged = INVALID_HANDLE;
Handle g_OnPracticeModeSettingsRead = INVALID_HANDLE;

#include "practicemode/pugsetup_integration.sp"
#include "practicemode/grenadeutils.sp"
#include "practicemode/natives.sp"
#include "practicemode/commands.sp"
#include "practicemode/grenademenus.sp"


public Plugin myinfo = {
    name = "CS:GO PracticeMode",
    author = "splewis",
    description = "A practice mode that can be launched through the .setup menu",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-practice-mode"
};

public void OnPluginStart() {
    // LoadTranslations("pugsetup.phrases");
    g_InPracticeMode = false;
    AddCommandListener(Command_TeamJoin, "jointeam");
    AddCommandListener(Command_Noclip, "noclip");

    // Forwards
    g_OnGrenadeSaved = CreateGlobalForward("PM_OnPracticeModeEnabled", ET_Event, Param_Cell, Param_Array, Param_Array, Param_String);
    g_OnPracticeModeDisabled = CreateGlobalForward("PM_OnPracticeModeEnabled", ET_Ignore);
    g_OnPracticeModeEnabled = CreateGlobalForward("PM_OnPracticeModeEnabled", ET_Ignore);
    g_OnPracticeModeSettingChanged = CreateGlobalForward("PM_OnPracticeModeEnabled", ET_Ignore, Param_Cell, Param_String, Param_String, Param_Cell);
    g_OnPracticeModeSettingsRead = CreateGlobalForward("PM_OnPracticeModeEnabled", ET_Ignore);

    // Init data structures to be read from the config file
    g_BinaryOptionIds = new ArrayList(OPTION_NAME_LENGTH);
    g_BinaryOptionNames = new ArrayList(OPTION_NAME_LENGTH);
    g_BinaryOptionEnabled = new ArrayList();
    g_BinaryOptionChangeable = new ArrayList();
    g_BinaryOptionEnabledCvars = new ArrayList();
    g_BinaryOptionEnabledValues = new ArrayList();
    g_BinaryOptionCvarRestore = new ArrayList();
    ReadPracticeSettings();

    // Setup stuff for grenade history
    HookEvent("weapon_fire", Event_WeaponFired);
    for (int i = 0; i <= MAXPLAYERS; i++) {
        g_GrenadeHistoryPositions[i] = new ArrayList(3);
        g_GrenadeHistoryAngles[i] = new ArrayList(3);
    }

    RegAdminCmd("sm_launchpractice", Command_LaunchPracticeMode, ADMFLAG_CHANGEMAP, "Launches practice mode");
    RegAdminCmd("sm_practice", Command_LaunchPracticeMode, ADMFLAG_CHANGEMAP, "Launches practice mode");
    RegAdminCmd("sm_exitpractice", Command_ExitPracticeMode, ADMFLAG_CHANGEMAP, "Exits practice mode");

    // Grenade history commands
    RegConsoleCmd("sm_grenadeback", Command_GrenadeBack);
    RegConsoleCmd("sm_grenadeforward", Command_GrenadeForward);
    RegConsoleCmd("sm_clearnades", Command_ClearNades);
    RegConsoleCmd("sm_gotogrenade", Command_GotoNade);
    PM_AddChatAlias(".back", "sm_grenadeback");
    PM_AddChatAlias(".forward", "sm_grenadeforward");
    PM_AddChatAlias(".clearnades", "sm_clearnades");
    PM_AddChatAlias(".goto", "sm_gotogrenade");

    // Saved grenade location commands
    RegConsoleCmd("sm_grenades", Command_Grenades);
    RegConsoleCmd("sm_savegrenade", Command_SaveGrenade);
    RegConsoleCmd("sm_adddescription", Command_GrenadeDescription);
    RegConsoleCmd("sm_deletegrenade", Command_DeleteGrenade);
    PM_AddChatAlias(".nades", "sm_grenades");
    PM_AddChatAlias(".grenades", "sm_grenades");
    PM_AddChatAlias(".addnade", "sm_savegrenade");
    PM_AddChatAlias(".savenade", "sm_savegrenade");
    PM_AddChatAlias(".save", "sm_savegrenade");
    PM_AddChatAlias(".desc", "sm_adddescription");
    PM_AddChatAlias(".delete", "sm_deletegrenade");

    // New Plugin cvars
    g_AutostartCvar = CreateConVar("sm_practicemode_autostart", "0", "Whether the plugin is automatically started on mapstart");
    g_MaxHistorySizeCvar = CreateConVar("sm_practicemode_max_grenade_history_size", "1000", "Maximum number of grenades throws saved in history per-client");
    g_MaxGrenadesSavedCvar = CreateConVar("sm_practicemode_max_grenades_saved", "256", "Maximum number of grenades saved per-map per-client");
    AutoExecConfig(true, "practicemode");

    // New cvars we don't want saved in the autoexec'd file
    g_InfiniteMoneyCvar = CreateConVar("sm_infinite_money", "0", "Whether clients recieve infinite money");
    g_InfiniteMoneyCvar.AddChangeHook(OnInfiniteMoneyChanged);
    g_AllowNoclipCvar = CreateConVar("sm_allow_noclip", "0", "Whether players may use .noclip in chat to toggle noclip");
    g_AllowNoclipCvar.AddChangeHook(OnAllowNoclipChanged);

    g_GrenadeTrajectoryClientColorCvar = CreateConVar("sm_grenade_trajectory_use_player_color", "0", "Whether to use client colors when drawing grenade trajectories");
    g_GrenadeTrajectoryClientColorCvar.AddChangeHook(OnGrenadeTrajectoryClientColorChanged);

    // Patched builtin cvars
    g_GrenadeTrajectoryCvar = GetCvar("sv_grenade_trajectory");
    g_GrenadeThicknessCvar = GetCvar("sv_grenade_trajectory_thickness");
    g_GrenadeTimeCvar = GetCvar("sv_grenade_trajectory_time");
    g_GrenadeSpecTimeCvar = GetCvar("sv_grenade_trajectory_time_spectator");
    g_GrenadeTrajectoryCvar.AddChangeHook(OnGrenadeTrajectoryChanged);
    g_GrenadeThicknessCvar.AddChangeHook(OnGrenadeThicknessChanged);
    g_GrenadeTimeCvar.AddChangeHook(OnGrenadeTimeChanged);
    g_GrenadeSpecTimeCvar.AddChangeHook(OnGrenadeSpecTimeChanged);

    // set default colors to green
    for (int i = 0; i <= MAXPLAYERS; i++) {
        g_ClientColors[0][0] = 0;
        g_ClientColors[0][1] = 255;
        g_ClientColors[0][2] = 0;
        g_ClientColors[0][3] = 255;
    }

    // Remove cheats so sv_cheats isn't required for this:
    RemoveCvarFlag(g_GrenadeTrajectoryCvar, FCVAR_CHEAT);

    HookEvent("server_cvar", Event_CvarChanged, EventHookMode_Pre);

    g_PugsetupLoaded = LibraryExists("pugsetup");
}

public void OnLibraryAdded(const char[] name) {
    g_PugsetupLoaded = LibraryExists("pugsetup");
}

public void OnLibraryRemoved(const char[] name) {
    g_PugsetupLoaded = LibraryExists("pugsetup");
}

public int OnInfiniteMoneyChanged(Handle cvar, const char[] oldValue, const char[] newValue) {
    bool previousValue = g_InfiniteMoney;
    g_InfiniteMoney = !StrEqual(newValue, "0");
    if (!previousValue && g_InfiniteMoney) {
        CreateTimer(1.0, Timer_GivePlayersMoney, _, TIMER_REPEAT);
    }
}

public int OnGrenadeTrajectoryChanged(Handle cvar, const char[] oldValue, const char[] newValue) {
    g_GrenadeTrajectory = !StrEqual(newValue, "0");
}

public int OnGrenadeTrajectoryClientColorChanged(Handle cvar, const char[] oldValue, const char[] newValue) {
    g_GrenadeTrajectoryClientColor = !StrEqual(newValue, "0");
}

public int OnGrenadeThicknessChanged(Handle cvar, const char[] oldValue, const char[] newValue) {
    g_GrenadeThickness = StringToFloat(newValue);
}

public int OnGrenadeTimeChanged(Handle cvar, const char[] oldValue, const char[] newValue) {
    g_GrenadeTime = StringToFloat(newValue);
}

public int OnGrenadeSpecTimeChanged(Handle cvar, const char[] oldValue, const char[] newValue) {
    g_GrenadeSpecTime = StringToFloat(newValue);
}

public int OnAllowNoclipChanged(Handle cvar, const char[] oldValue, const char[] newValue) {
    g_AllowNoclip = !StrEqual(newValue, "0");
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

public void OnClientConnected(int client) {
    g_GrenadeHistoryIndex[client] = -1;
    g_CurrentSavedGrenadeId[client] = -1;
    ClearArray(g_GrenadeHistoryPositions[client]);
    ClearArray(g_GrenadeHistoryAngles[client]);
}

public void OnMapStart() {
    ReadPracticeSettings();
    g_BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");

    // Init map-based saved grenade spots
    char dir[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, dir, sizeof(dir), "data/practicemode_grenades");
    if (!DirExists(dir)) {
        CreateDirectory(dir, 511);
    }

    char map[PLATFORM_MAX_PATH];
    GetCleanMapName(map, sizeof(map));
    Format(g_GrenadeLocationsFile, sizeof(g_GrenadeLocationsFile), "%s/%s.cfg", dir, map);
    g_GrenadeLocationsKv = new KeyValues("Grenades");
    g_GrenadeLocationsKv.ImportFromFile(g_GrenadeLocationsFile);
    g_UpdatedGrenadeKv = false;
}

public void OnConfigsExecuted() {
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
}

public void OnMapEnd() {
    if (g_UpdatedGrenadeKv) {
        g_GrenadeLocationsKv.ExportToFile(g_GrenadeLocationsFile);
        g_UpdatedGrenadeKv = false;
    }

    if (g_InPracticeMode)
        ExitPracticeMode();

    delete g_GrenadeLocationsKv;
}

public void OnClientPutInServer(int client) {
    UpdatePlayerColor(client);
}

public void UpdatePlayerColor(int client) {
    QueryClientConVar(client, "cl_color", QueryClientColor, client);
}

public void QueryClientColor(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue) {
    int color = StringToInt(cvarValue);
    GetColor(view_as<ClientColor>(color), g_ClientColors[client]);
}

public void GetColor(ClientColor c, int array[4]) {
    int r, g, b;
    switch(c) {
        case ClientColor_Green:  { r = 0;   g = 255; b = 0; }
        case ClientColor_Purple: { r = 128; g = 0;   b = 128; }
        case ClientColor_Blue:   { r = 0;   g = 0;   b = 255; }
        case ClientColor_Orange: { r = 255; g = 128; b = 0; }
        case ClientColor_Yellow: { r = 255; g = 255; b = 0; }
    }
    array[0] = r;
    array[1] = g;
    array[2] = b;
    array[3] = 255;
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
    if (g_AllowNoclip && StrEqual(text, ".noclip") && IsPlayer(client)) {
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
    if (g_LastNoclipCommand[client] == GetGameTickCount() || (!g_AllowNoclip && GetCvarIntSafe("sv_cheats") == 0)) {
        return;
    }

    g_LastNoclipCommand[client] = GetGameTickCount();
    MoveType t = GetEntityMoveType(client);
    MoveType next = (t == MOVETYPE_WALK) ? MOVETYPE_NOCLIP : MOVETYPE_WALK;
    SetEntityMoveType(client, next);
}

public void ReadPracticeSettings() {
    ClearArray(g_BinaryOptionNames);
    ClearArray(g_BinaryOptionEnabled);
    ClearArray(g_BinaryOptionChangeable);
    ClearNestedArray(g_BinaryOptionEnabledCvars);
    ClearNestedArray(g_BinaryOptionEnabledValues);
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

                char cvarName[CVAR_NAME_LENGTH];
                char cvarValue[CVAR_VALUE_LENGTH];

                // read the enabled cvar list
                ArrayList enabledCvars = new ArrayList(CVAR_NAME_LENGTH);
                ArrayList enabledValues = new ArrayList(CVAR_VALUE_LENGTH);
                if (kv.JumpToKey("enabled")) {
                    if (kv.GotoFirstSubKey(false)) {
                        do {
                            kv.GetSectionName(cvarName, sizeof(cvarName));
                            enabledCvars.PushString(cvarName);
                            kv.GetString(NULL_STRING, cvarValue, sizeof(cvarValue));
                            enabledValues.PushString(cvarValue);
                        } while (kv.GotoNextKey(false));
                        kv.GoBack();
                    }
                    kv.GoBack();
                }

                PM_AddSetting(id, name, enabledCvars, enabledValues, enabled, changeable);

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

stock void ChangeSetting(int index, bool enabled, bool print=true) {
    if (enabled) {
        ArrayList cvars = g_BinaryOptionEnabledCvars.Get(index);
        ArrayList values = g_BinaryOptionEnabledValues.Get(index);
        g_BinaryOptionCvarRestore.Set(index, SaveCvars(cvars));

        char cvar[CVAR_NAME_LENGTH];
        char value[CVAR_VALUE_LENGTH];

        for (int i = 0; i < cvars.Length; i++) {
            cvars.GetString(i, cvar, sizeof(cvar));
            values.GetString(i, value, sizeof(value));
            ServerCommand("%s %s", cvar, value);
        }

    } else {
        Handle cvarRestore = g_BinaryOptionCvarRestore.Get(index);
        if (cvarRestore != INVALID_HANDLE) {
            RestoreCvars(cvarRestore, true);
            g_BinaryOptionCvarRestore.Set(index, INVALID_HANDLE);
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
        if (!StrEqual(name, ""))
            PM_MessageToAll("%s is now %s.", name, enabledString);
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

    for (int i = 0; i < g_BinaryOptionNames.Length; i++) {
        ChangeSetting(i, false, false);
    }

    g_InPracticeMode = false;

    // force turn noclip off for everyone
    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i))
            SetEntityMoveType(i, MOVETYPE_WALK);
    }

    ServerCommand("exec sourcemod/practicemode_end.cfg");
    PM_MessageToAll("Practice mode is now disabled.");
}

public void SetCvar(const char[] name, int value) {
    Handle cvar = FindConVar(name);
    if (cvar == INVALID_HANDLE) {
        LogError("cvar \"%s\" could not be found", name);
    } else {
        SetConVarInt(cvar, value);
    }
}

public Action Timer_GivePlayersMoney(Handle timer) {
    if (!g_InfiniteMoney) {
        return Plugin_Handled;
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i) && !IsFakeClient(i)) {
            SetEntProp(i, Prop_Send, "m_iAccount", 16000);
        }
    }

    return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] className) {
    if (!g_GrenadeTrajectory || !IsValidEntity(entity) || !IsGrenadeProjectile(className))
        return;

    SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawned);
}

public int OnEntitySpawned(int entity) {
    if (!g_GrenadeTrajectory || !IsValidEdict(entity))
        return;

    char className[64];
    GetEdictClassname(entity, className, sizeof(className));

    if (!IsGrenadeProjectile(className))
        return;

    int client = 0; // will use the default color (green)
    if (g_GrenadeTrajectoryClientColor) {
        int owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
        if (IsPlayer(owner)) {
            client = owner;
            UpdatePlayerColor(client);
        }
    }

    if (IsValidEntity(entity)) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientConnected(i) || !IsClientInGame(i)) {
                continue;
            }

            // Note: the technique using temporary entities is taken from InternetBully's NadeTails plugin
            // which you can find at https://forums.alliedmods.net/showthread.php?t=240668
            float time = (GetClientTeam(i) == CS_TEAM_SPECTATOR) ? g_GrenadeSpecTime : g_GrenadeTime;
            TE_SetupBeamFollow(entity, g_BeamSprite, 0, time, g_GrenadeThickness * 5, g_GrenadeThickness * 5, 1, g_ClientColors[client]);
            TE_SendToClient(i);
        }
    }
}

public Action Event_WeaponFired(Event event, const char[] name, bool dontBroadcast) {
    if (!g_InPracticeMode) {
        return;
    }

    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);
    char weapon[64];
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

static bool CheckChatAlias(const char[] alias, const char[] command, const char[] chatCommand, const char[] chatArgs, int client) {
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
            GetArrayString(g_ChatAliases, i, alias, sizeof(alias));
            GetArrayString(g_ChatAliasesCommands, i, cmd, sizeof(cmd));

            if (CheckChatAlias(alias, cmd, chatCommand, chatArgs, client)) {
                break;
            }
        }
    }

    if (!g_PugsetupLoaded) {
        if (StrEqual(chatCommand, ".setup"))
            GivePracticeMenu(client);
        if (StrEqual(chatCommand, ".help"))
            PrintHelpInfo(client);
    }
}

public void PrintHelpInfo(int client) {
    PM_Message(client, "{LIGHT_GREEN}.setup {NORMAL}to change/view practicemode settings");
    if (g_AllowNoclip)
        PM_Message(client, "{LIGHT_GREEN}.noclip {NORMAL}to enter/exit noclip mode");
    PM_Message(client, "{LIGHT_GREEN}.back {NORMAL}to go to your last grenade position");
    PM_Message(client, "{LIGHT_GREEN}.forward {NORMAL}to go to your next grenade position");
    PM_Message(client, "{LIGHT_GREEN}.save <name> {NORMAL}to save a grenade position");
    PM_Message(client, "{LIGHT_GREEN}.nades [player] {NORMAL}to view all saved grenades");
    PM_Message(client, "{LIGHT_GREEN}.desc <description> {NORMAL}to add a nade description");
    PM_Message(client, "{LIGHT_GREEN}.delete {NORMAL}to delete your current grenade position");
    PM_Message(client, "{LIGHT_GREEN}.goto [player] <id> {NORMAL}to go to a grenadeid");
}
