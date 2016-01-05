#include <cstrike>
#include <sdktools>

#tryinclude "manual_version.sp"
#if !defined PLUGIN_VERSION
#define PLUGIN_VERSION "0.0.1-dev"
#endif

#define MAX_INTEGER_STRING_LENGTH 16
#define MAX_FLOAT_STRING_LENGTH 32

static char _colorNames[][] = {"{NORMAL}", "{DARK_RED}", "{PINK}", "{GREEN}", "{YELLOW}", "{LIGHT_GREEN}", "{LIGHT_RED}", "{GRAY}", "{ORANGE}", "{LIGHT_BLUE}", "{DARK_BLUE}", "{PURPLE}"};
static char _colorCodes[][] = {"\x01",     "\x02",      "\x03",   "\x04",         "\x05",     "\x06",          "\x07",        "\x08",   "\x09",     "\x0B",         "\x0C",        "\x0E"};

/**
 * Switches and respawns a player onto a new team.
 */
stock void SwitchPlayerTeam(int client, int team) {
    if (GetClientTeam(client) == team)
        return;

    if (team > CS_TEAM_SPECTATOR) {
        CS_SwitchTeam(client, team);
        CS_UpdateClientModel(client);
        CS_RespawnPlayer(client);
    } else {
        ChangeClientTeam(client, team);
    }
}

/**
 * Returns if a client is valid.
 */
stock bool IsValidClient(int client) {
    return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client);
}

stock bool IsPlayer(int client) {
    return IsValidClient(client) && !IsFakeClient(client);
}

stock void Colorize(char[] msg, int size, bool stripColor=false) {
    for (int i = 0; i < sizeof(_colorNames); i ++) {
        if (stripColor)
            ReplaceString(msg, size, _colorNames[i], "\x01"); // replace with white
        else
            ReplaceString(msg, size, _colorNames[i], _colorCodes[i]);
    }
}

stock void SetConVarStringSafe(const char[] name, const char[] value) {
    Handle cvar = FindConVar(name);
    if (cvar == INVALID_HANDLE) {
        LogError("Failed to find cvar: \"%s\"", name);
    } else {
        SetConVarString(cvar, value);
    }
}

/**
 * Closes a nested adt-array.
 */
stock void CloseNestedArray(Handle array, bool closeOuterArray=true) {
    int n = GetArraySize(array);
    for (int i = 0; i < n; i++) {
        Handle h = GetArrayCell(array, i);
        CloseHandle(h);
    }

    if (closeOuterArray)
        CloseHandle(array);
}

stock void ClearNestedArray(Handle array) {
    int n = GetArraySize(array);
    for (int i = 0; i < n; i++) {
        Handle h = GetArrayCell(array, i);
        CloseHandle(h);
    }

    ClearArray(array);
}

stock void GetEnabledString(char[] buffer, int length, bool variable, int client=LANG_SERVER) {
    if (variable)
        Format(buffer, length, "enabled");
        // Format(buffer, length, "%T", "Enabled", client);
    else
        Format(buffer, length, "disabled");
        // Format(buffer, length, "%T", "Disabled", client);
}

stock void GetTrueString(char[] buffer, int length, bool variable, int client=LANG_SERVER) {
    if (variable)
        Format(buffer, length, "true");
    else
        Format(buffer, length, "false");
}

stock int GetCvarIntSafe(const char[] cvarName) {
    Handle cvar = FindConVar(cvarName);
    if (cvar == INVALID_HANDLE) {
        LogError("Failed to find cvar \"%s\"", cvar);
        return 0;
    } else {
        return GetConVarInt(cvar);
    }
}

stock int FindStringInArray2(const char[][] array, int len, const char[] string, bool caseSensitive=true) {
    for (int i = 0; i < len; i++) {
        if (StrEqual(string, array[i], caseSensitive)) {
            return i;
        }
    }

    return -1;
}

stock void GetCleanMapName(char[] buffer, int size) {
    char mapName[PLATFORM_MAX_PATH];
    GetCurrentMap(mapName, sizeof(mapName));
    int last_slash = 0;
    int len = strlen(mapName);
    for (int i = 0;  i < len; i++) {
        if (mapName[i] == '/' || mapName[i] == '\\')
            last_slash = i + 1;
    }
    strcopy(buffer, size, mapName[last_slash]);
}

stock void RemoveCvarFlag(Handle cvar, int flag) {
    SetConVarFlags(cvar, GetConVarFlags(cvar) & ~flag);
}

stock int min(int x, int y) {
    return (x < y) ? x : y;
}

stock bool SplitOnSpaceFirstPart(const char[] str, char[] buf1, int len1) {
    for (int i = 0; i < strlen(str); i++){
        if (str[i] == ' ') {
            strcopy(buf1, min(len1, i + 1), str);
            return true;
        }
    }
    return false;
}

stock bool SplitOnSpace(const char[] str, char[] buf1, int len1, char[] buf2, int len2) {
    for (int i = 0; i < strlen(str); i++){
        if (str[i] == ' ') {
            strcopy(buf1, min(len1, i + 1), str);
            strcopy(buf2, len2, str[i+1]);
            return true;
        }
    }
    return false;
}
