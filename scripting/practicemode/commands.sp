public Action Command_LaunchPracticeMode(int client, int args) {
    if (!g_InPracticeMode) {
        if (g_PugsetupLoaded && PugSetup_GetGameState() >= GameState_Warmup) {
            return Plugin_Continue;
        }
        LaunchPracticeMode();
        if (IsPlayer(client)) {
            GivePracticeMenu(client);
        }
    }
    return Plugin_Handled;
}

public Action Command_ExitPracticeMode(int client, int args) {
    if (g_InPracticeMode) {
        ExitPracticeMode();
    }
    return Plugin_Handled;
}

public Action Command_GrenadeBack(int client, int args) {
    if (g_InPracticeMode && g_GrenadeHistoryPositions[client].Length > 0) {
        g_GrenadeHistoryIndex[client]--;
        if (g_GrenadeHistoryIndex[client] < 0)
            g_GrenadeHistoryIndex[client] = 0;

        TeleportToGrenadeHistoryPosition(client, g_GrenadeHistoryIndex[client]);
        PM_Message(client, "Teleporting back to %d position in grenade history.", g_GrenadeHistoryIndex[client] + 1);
    }

    return Plugin_Handled;
}

public Action Command_GrenadeForward(int client, int args) {
    if (g_InPracticeMode && g_GrenadeHistoryPositions[client].Length > 0) {
        int max = g_GrenadeHistoryPositions[client].Length;
        g_GrenadeHistoryIndex[client]++;
        if (g_GrenadeHistoryIndex[client] >= max)
            g_GrenadeHistoryIndex[client] = max - 1;
        TeleportToGrenadeHistoryPosition(client, g_GrenadeHistoryIndex[client]);
        PM_Message(client, "Teleporting forward to %d position in grenade history.", g_GrenadeHistoryIndex[client] + 1);
    }

    return Plugin_Handled;
}

public Action Command_ClearNades(int client, int args) {
    if (g_InPracticeMode) {
        ClearArray(g_GrenadeHistoryPositions[client]);
        ClearArray(g_GrenadeHistoryAngles[client]);
        PM_Message(client, "Grenade history cleared.");
    }

    return Plugin_Handled;
}

public Action Command_GotoNade(int client, int args) {
    if (g_InPracticeMode) {
        char arg1[32];
        char arg2[32];
        char name[MAX_NAME_LENGTH];
        char auth[AUTH_LENGTH];

        if (args >= 2 && GetCmdArg(1, arg1, sizeof(arg1)) && GetCmdArg(2, arg2, sizeof(arg2))) {
            if (!FindGrenadeTarget(arg1, name, sizeof(name), auth, sizeof(auth))) {
                PM_Message(client, "Player not found.");
                return Plugin_Handled;
            }
            if (!TeleportToSavedGrenadePosition(client, auth, arg2)){
                PM_Message(client, "Grenade id %s not found.", arg2);
                return Plugin_Handled;
            }

        } else if (args >= 1 && GetCmdArg(1, arg1, sizeof(arg1))) {
            GetClientName(client, name, sizeof(name));
            GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
            if (!TeleportToSavedGrenadePosition(client, auth, arg1)){
                PM_Message(client, "Grenade id %s not found.", arg1);
                return Plugin_Handled;
            }

        } else {
            PM_Message(client, "Usage: .goto [player] <grenadeid>");
        }
    }

    return Plugin_Handled;
}

public Action Command_Grenades(int client, int args) {
    if (!g_InPracticeMode) {
        return Plugin_Handled;
    }

    char arg[MAX_NAME_LENGTH];
    char auth[AUTH_LENGTH];
    char name[MAX_NAME_LENGTH];

    if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
        if (FindGrenadeTarget(arg, name, sizeof(name), auth, sizeof(auth))) {
            GiveGrenadesForPlayer(client, name, auth);
            return Plugin_Handled;
        }
    } else {
        GiveGrenadesMenu(client);
    }

    return Plugin_Handled;
}

public Action Command_GrenadeDescription(int client, int args) {
    int nadeId = g_CurrentSavedGrenadeId[client];
    if (nadeId < 0 || !g_InPracticeMode) {
        return Plugin_Handled;
    }

    char description[GRENADE_DESCRIPTION_LENGTH];
    GetCmdArgString(description, sizeof(description));

    UpdateGrenadeDescription(client, nadeId, description);
    PM_Message(client, "Added grenade description.");
    return Plugin_Handled;
}

public Action Command_DeleteGrenade(int client, int args) {
    if (!g_InPracticeMode) {
        return Plugin_Handled;
    }

    // get the grenade id first
    char grenadeIdStr[32];
    if (args < 1 || !GetCmdArg(1, grenadeIdStr, sizeof(grenadeIdStr))) {
        // if this fails, use the last grenade position
        IntToString(g_CurrentSavedGrenadeId[client], grenadeIdStr, sizeof(grenadeIdStr));
    }

    DeleteGrenadeFromKv(client, grenadeIdStr);
    return Plugin_Handled;
}

public Action Command_SaveGrenade(int client, int args) {
    if (!g_InPracticeMode) {
        return Plugin_Handled;
    }

    char name[GRENADE_NAME_LENGTH];
    GetCmdArgString(name, sizeof(name));
    TrimString(name);

    if (strlen(name) == 0)  {
        PM_Message(client, "Usage: .save <name>");
        return Plugin_Handled;
    }

    char auth[AUTH_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
    char grenadeId[GRENADE_ID_LENGTH];
    if (FindGrenadeByName(auth, name, grenadeId)) {
        PM_Message(client, "You have already used that name.");
        return Plugin_Handled;
    }


    if (CountGrenadesForPlayer(auth) >= g_MaxGrenadesSavedCvar.IntValue) {
        PM_Message(client, "You have reached the maximum number of grenades you can save (%d).",
                        g_MaxGrenadesSavedCvar.IntValue);
        return Plugin_Handled;
    }

    float origin[3];
    float angles[3];
    GetClientAbsOrigin(client, origin);
    GetClientEyeAngles(client, angles);

    Action ret = Plugin_Continue;
    Call_StartForward(g_OnGrenadeSaved);
    Call_PushCell(client);
    Call_PushArray(origin, sizeof(origin));
    Call_PushArray(angles, sizeof(angles));
    Call_PushString(name);
    Call_Finish(ret);

    if (ret < Plugin_Handled) {
        int nadeId = SaveGrenadeToKv(client, origin, angles, name);
        g_CurrentSavedGrenadeId[client] = nadeId;
        PM_Message(client, "Saved grenade (id %d). Type .desc <description> to add a description or .delete to delete this position.", nadeId);
    }

    return Plugin_Handled;
}
