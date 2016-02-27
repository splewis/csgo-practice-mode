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
        // Get a lower case version of the arg for a category search.
        char argLower[MAX_NAME_LENGTH];
        strcopy(argLower, sizeof(argLower), arg);
        LowerString(argLower);

        if (g_KnownNadeCategories.FindString(argLower) >= 0) {
            GiveCategoryGrenades(client, argLower);
            return Plugin_Handled;
        } else if (FindGrenadeTarget(arg, name, sizeof(name), auth, sizeof(auth))) {
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
        if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
            spawnIndex = StringToInt(arg) - 1; // One-indexed for users.
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

public Action Command_Category(int client, int args) {
    int nadeId = g_CurrentSavedGrenadeId[client];
    if (nadeId < 0 || !g_InPracticeMode) {
        return Plugin_Handled;
    }

    char categoryString[GRENADE_CATEGORY_LENGTH];
    GetGrenadeData(client, nadeId, "categories", categoryString, sizeof(categoryString));

    ArrayList categories = new ArrayList(64);
    AddCategoriesToList(categoryString, categories);

    for (int i = 0; i < categories.Length; i++) {
        char cat[64];
        categories.GetString(i, cat, sizeof(cat));
        PM_Message(client, "Category %d: %s", i + 1, cat);
    }
    if (categories.Length == 0) {
        PM_Message(client, "No categories found");
    }
    delete categories;

    return Plugin_Handled;
}

public Action Command_AddCategory(int client, int args) {
    int nadeId = g_CurrentSavedGrenadeId[client];
    if (nadeId < 0 || !g_InPracticeMode) {
        return Plugin_Handled;
    }

    char category[GRENADE_CATEGORY_LENGTH];
    GetCmdArgString(category, sizeof(category));
    LowerString(category);

    AddGrenadeCategory(client, nadeId, category);
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
    LowerString(category);

    if (RemoveGrenadeCategory(client, nadeId, category))
        PM_Message(client, "Removed grenade category.");
    else
        PM_Message(client, "Category not found.");

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
