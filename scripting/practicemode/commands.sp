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

public Action Command_LastGrenade(int client, int args) {
    int index = g_GrenadeHistoryPositions[client].Length - 1;
    if (g_InPracticeMode && index >= 0) {
        TeleportToGrenadeHistoryPosition(client, index);
        PM_Message(client, "Teleporting back to position %d in grenade history.", index + 1);
    }

    return Plugin_Handled;
}

public Action Command_NextGrenade(int client, int args) {
    int nadeId = g_CurrentSavedGrenadeId[client];
    if (nadeId < 0 || !g_InPracticeMode) {
        return Plugin_Handled;
    }

    int nextId = FindNextGrenadeId(client, nadeId);
    if (nextId != -1) {
        char auth[AUTH_LENGTH];
        GetClientAuthId(client, AUTH_METHOD, auth, sizeof(auth));

        char idBuffer[GRENADE_ID_LENGTH];
        IntToString(nextId, idBuffer, sizeof(idBuffer));
        TeleportToSavedGrenadePosition(client, auth, idBuffer);
    }

    return Plugin_Handled;
}

public Action Command_GrenadeBack(int client, int args) {
    if (g_InPracticeMode && g_GrenadeHistoryPositions[client].Length > 0) {
        g_GrenadeHistoryIndex[client]--;
        if (g_GrenadeHistoryIndex[client] < 0)
            g_GrenadeHistoryIndex[client] = 0;

        TeleportToGrenadeHistoryPosition(client, g_GrenadeHistoryIndex[client]);
        PM_Message(client, "Teleporting back to position %d in grenade history.", g_GrenadeHistoryIndex[client] + 1);
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
        PM_Message(client, "Teleporting forward to position %d in grenade history.", g_GrenadeHistoryIndex[client] + 1);
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
            GetClientAuthId(client, AUTH_METHOD, auth, sizeof(auth));
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

    if (args >= 1 && GetCmdArgString(arg, sizeof(arg))) {
        // Get a lower case version of the arg for a category search.
        char matchingCategory[GRENADE_CATEGORY_LENGTH];
        FindMatchingCategory(arg, matchingCategory, sizeof(matchingCategory));

        if (FindGrenadeTarget(arg, name, sizeof(name), auth, sizeof(auth))) {
            GiveGrenadesForPlayer(client, name, auth);
            return Plugin_Handled;
        } else if (FindStringInList(g_KnownNadeCategories, GRENADE_CATEGORY_LENGTH, matchingCategory, false) >= 0) {
            GiveCategoryGrenades(client, matchingCategory);
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

public Action Command_RenameGrenade(int client, int args) {
    int nadeId = g_CurrentSavedGrenadeId[client];
    if (nadeId < 0 || !g_InPracticeMode) {
        return Plugin_Handled;
    }

    char name[GRENADE_NAME_LENGTH];
    GetCmdArgString(name, sizeof(name));

    UpdateGrenadeName(client, nadeId, name);
    PM_Message(client, "Updated grenade name.");
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
    GetClientAuthId(client, AUTH_METHOD, auth, sizeof(auth));
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

public Action Command_SaveSpawn(int client, int args) {
    if (!g_InPracticeMode) {
        return Plugin_Handled;
    }

    char arg[64];
    if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
        int team = GetClientTeam(client);
        SaveNamedSpawn(client, team, arg);
        PM_Message(client, "Saved spawn \"%s\"", arg);
        TeleportToNamedSpawn(client, team, arg);
        SetEntityMoveType(client, MOVETYPE_WALK);
    } else {
        PM_Message(client, "Usage: .namespawn <name>");
    }

    return Plugin_Handled;
}

public Action Command_GotoSpawn(int client, int args) {
    if (!g_InPracticeMode) {
        return Plugin_Handled;
    }

    if (IsPlayer(client)) {
        ArrayList spawnList = null;
        if (GetClientTeam(client) == CS_TEAM_CT) {
            spawnList = g_CTSpawns;
        } else {
            spawnList = g_TSpawns;
        }

        char arg[32];
        int spawnIndex = -1;
        // Note: the spawn_number argumment in .spawn <spawn_number> is 1-indexed for users.
        if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
            // If 0, then we use the arg as the user setting or going to a named location
            int argInt = StringToInt(arg);
            if (argInt == 0 && !StrEqual(arg, "0")) {
                int team = GetClientTeam(client);
                if (DoesNamedSpawnExist(team, arg)) {
                    TeleportToNamedSpawn(client, team, arg);
                    PM_Message(client, "Moved to spawn \"%s\"", arg);
                } else {
                    PM_Message(client, "There is no spawn for \"%s\", use .namespawn <name> to add a name for your nearest spawn point", arg);
                }
                return Plugin_Handled;

            } else {
                spawnIndex = argInt - 1;
            }
        } else {
            spawnIndex = FindNearestSpawnIndex(client, spawnList);
        }

        if (spawnIndex < 0 || spawnIndex >= spawnList.Length) {
            PM_Message(client, "Spawn number out of range. (%d max)", spawnList.Length);
            return Plugin_Handled;
        }

        int ent = spawnList.Get(spawnIndex);
        TeleportToSpawnEnt(client, ent);
        SetEntityMoveType(client, MOVETYPE_WALK);
        PM_Message(client, "Moved to spawn %d (of %d).", spawnIndex + 1, spawnList.Length);
    }
    return Plugin_Handled;
}

public Action Command_GotoWorstSpawn(int client, int args) {
    if (!g_InPracticeMode) {
        return Plugin_Handled;
    }

    if (IsPlayer(client)) {
        ArrayList spawnList = null;
        if (GetClientTeam(client) == CS_TEAM_CT) {
            spawnList = g_CTSpawns;
        } else {
            spawnList = g_TSpawns;
        }

        char arg[32];
        int spawnIndex = -1;
        if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
            spawnIndex = StringToInt(arg) - 1; // One-indexed for users.
        } else {
            spawnIndex = FindFurthestSpawnIndex(client, spawnList);
        }

        if (spawnIndex < 0 || spawnIndex >= spawnList.Length) {
            PM_Message(client, "Spawn number out of range. (%d max)", spawnList.Length);
            return Plugin_Handled;
        }

        int ent = spawnList.Get(spawnIndex);
        TeleportToSpawnEnt(client, ent);
        SetEntityMoveType(client, MOVETYPE_WALK);
        PM_Message(client, "Moved to spawn %d (of %d).", spawnIndex + 1, spawnList.Length);
    }
    return Plugin_Handled;
}

public Action Command_TestFlash(int client, int args) {
    if (!g_InPracticeMode) {
        return Plugin_Handled;
    }

    g_TestingFlash[client] = true;
    PM_Message(client, "Saved your position. Throw a flashbang and you will be teleported back here to see the flashbang's effect.");
    GetClientAbsOrigin(client, g_TestingFlashOrigins[client]);
    GetClientEyeAngles(client, g_TestingFlashAngles[client]);
    return Plugin_Handled;
}


public Action Command_StopFlash(int client, int args) {
    if (!g_InPracticeMode) {
        return Plugin_Handled;
    }

    g_TestingFlash[client] = false;
    PM_Message(client, "Disabled flash testing.");
    return Plugin_Handled;
}

public Action Command_Categories(int client, int args) {
    if (!g_InPracticeMode) {
        return Plugin_Handled;
    }
    GiveGrenadesMenu(client, true);
    return Plugin_Handled;
}

public Action Command_AddCategory(int client, int args) {
    int nadeId = g_CurrentSavedGrenadeId[client];
    if (nadeId < 0 || !g_InPracticeMode || args < 1) {
        return Plugin_Handled;
    }

    char category[GRENADE_CATEGORY_LENGTH];
    GetCmdArgString(category, sizeof(category));
    AddGrenadeCategory(client, nadeId, category);

    PM_Message(client, "Added grenade category.");
    return Plugin_Handled;
}

public Action Command_AddCategories(int client, int args) {
    int nadeId = g_CurrentSavedGrenadeId[client];
    if (nadeId < 0 || !g_InPracticeMode || args < 1) {
        return Plugin_Handled;
    }

    char category[GRENADE_CATEGORY_LENGTH];

    for (int i = 1; i <= args; i++) {
        GetCmdArg(i, category, sizeof(category));
        AddGrenadeCategory(client, nadeId, category);
    }

    PM_Message(client, "Added grenade category.");
    return Plugin_Handled;
}

public Action Command_RemoveCategory(int client, int args) {
    int nadeId = g_CurrentSavedGrenadeId[client];
    if (nadeId < 0 || !g_InPracticeMode) {
        return Plugin_Handled;
    }

    char category[GRENADE_CATEGORY_LENGTH];
    GetCmdArgString(category, sizeof(category));

    if (RemoveGrenadeCategory(client, nadeId, category))
        PM_Message(client, "Removed grenade category.");
    else
        PM_Message(client, "Category not found.");

    return Plugin_Handled;
}

public Action Command_DeleteCategory(int client, int args) {
    char category[GRENADE_CATEGORY_LENGTH];
    GetCmdArgString(category, sizeof(category));

    DeleteGrenadeCategory(client, category);
    PM_Message(client, "Removed grenade category.");
    return Plugin_Handled;
}

public Action Command_ClearGrenadeCategories(int client, int args) {
    int nadeId = g_CurrentSavedGrenadeId[client];
    if (nadeId < 0 || !g_InPracticeMode) {
        return Plugin_Handled;
    }

    SetClientGrenadeData(client, nadeId, "categories", "");
    PM_Message(client, "Cleared grenade categories for id %d.", nadeId);

    return Plugin_Handled;
}

public Action Command_TranslateGrenades(int client, int args) {
    if (args != 3) {
        ReplyToCommand(client, "Usage: sm_translategrenades <dx> <dy> <dz>");
        return Plugin_Handled;
    }

    char buffer[32];
    GetCmdArg(1, buffer, sizeof(buffer));
    float dx = StringToFloat(buffer);

    GetCmdArg(2, buffer, sizeof(buffer));
    float dy = StringToFloat(buffer);

    GetCmdArg(3, buffer, sizeof(buffer));
    float dz = StringToFloat(buffer);

    TranslateGrenades(dx, dy, dz);

    return Plugin_Handled;
}

public Action Command_Time(int client, int args) {
    if (!g_InPracticeMode) {
        return Plugin_Handled;
    }

    if (!g_RunningTimeCommand[client]) {
        // Start command.
        PM_Message(client, "When you start moving a timer will run until you stop.");
        g_RunningTimeCommand[client] = true;
        g_RunningLiveTimeCommand[client] = false;
    } else {
        // Early stop command.
        g_RunningTimeCommand[client] = false;
        g_RunningLiveTimeCommand[client] = false;
        StopClientTimer(client);
    }

    return Plugin_Handled;
}

public void StartClientTimer(int client) {
    g_LastTimeCommand[client] = GetEngineTime();
    CreateTimer(0.1, Timer_DisplayClientTimer, GetClientSerial(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void StopClientTimer(int client) {
    float dt = GetEngineTime() - g_LastTimeCommand[client];
    PM_Message(client, "Timer result: %.2f seconds", dt);
    PrintHintText(client, "<b>Time: %.2f</b> seconds", dt);
}

public Action Timer_DisplayClientTimer(Handle timer, int serial) {
    int client = GetClientFromSerial(serial);
    if (IsPlayer(client) && g_RunningTimeCommand[client]) {
        if (g_RunningTimeCommand[client]) {
            float dt = GetEngineTime() - g_LastTimeCommand[client];
            PrintHintText(client, "<b>Time: %.1f</b> seconds", dt);
            return Plugin_Continue;
        } else {
            return Plugin_Stop;
        }
    }
    return Plugin_Stop;
}

public Action Command_CopyGrenade(int client, int args) {
    if (!IsPlayer(client) || args != 2) {
        PM_Message(client, "Usage: .copy <name> <id>");
        return Plugin_Handled;
    }

    char name[MAX_NAME_LENGTH];
    char id[GRENADE_ID_LENGTH];
    GetCmdArg(1, name, sizeof(name));
    GetCmdArg(2, id, sizeof(id));

    char targetName[MAX_NAME_LENGTH];
    char targetAuth[AUTH_LENGTH];
    if (FindGrenadeTarget(name, targetName, sizeof(targetName), targetAuth, sizeof(targetAuth))) {
        int newid = CopyGrenade(targetAuth, id, client);
        if (newid != -1) {
            PM_Message(client, "Copied nade to new id %d", newid);
        } else {
            PM_Message(client, "Could not find grenade %s from %s", newid, name);
        }
    } else {
        PM_Message(client, "Could not find user %s", name);
    }

    return Plugin_Handled;
}
