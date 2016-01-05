/**
 * Some generic helpers functions.
 */

public bool IsGrenadeProjectile(const char[] className) {
    static char projectileTypes[][] = {
        "hegrenade_projectile",
        "smokegrenade_projectile",
        "decoy_projectile",
        "flashbang_projectile",
        "molotov_projectile",
    };

    return FindStringInArray2(projectileTypes, sizeof(projectileTypes), className) >= 0;
}

public bool IsGrenadeWeapon(const char[] weapon) {
    static char grenades[][] = {
        "incgrenade",
        "molotov",
        "hegrenade",
        "decoy",
        "flashbang",
        "smokegrenade",
    };

    return FindStringInArray2(grenades, sizeof(grenades), weapon) >= 0;
}

public void TeleportToGrenadeHistoryPosition(int client, int index) {
    float origin[3];
    float angles[3];
    float velocity[3];
    g_GrenadeHistoryPositions[client].GetArray(index, origin, sizeof(origin));
    g_GrenadeHistoryAngles[client].GetArray(index, angles, sizeof(angles));
    TeleportEntity(client, origin, angles, velocity);
    SetEntityMoveType(client, MOVETYPE_WALK);
}

public bool TeleportToSavedGrenadePosition(int client, const char[] targetAuth, const char[] id) {
    float origin[3];
    float angles[3];
    float velocity[3];
    char description[GRENADE_DESCRIPTION_LENGTH];
    bool success = false;

    // update the client's current grenade id, if it was their grenade
    bool myGrenade;
    char clientAuth[AUTH_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth));
    if (StrEqual(clientAuth, targetAuth)) {
        g_CurrentSavedGrenadeId[client] = StringToInt(id);
        myGrenade = true;
    } else {
        g_CurrentSavedGrenadeId[client] = -1;
        myGrenade = false;
    }

    if (g_GrenadeLocationsKv.JumpToKey(targetAuth)) {
        char targetName[MAX_NAME_LENGTH];
        char grenadeName[GRENADE_NAME_LENGTH];
        g_GrenadeLocationsKv.GetString("name", targetName, sizeof(targetName));

        if (g_GrenadeLocationsKv.JumpToKey(id)) {
            success = true;
            g_GrenadeLocationsKv.GetVector("origin", origin);
            g_GrenadeLocationsKv.GetVector("angles", angles);
            g_GrenadeLocationsKv.GetString("name", grenadeName, sizeof(grenadeName));
            g_GrenadeLocationsKv.GetString("description", description, sizeof(description));
            TeleportEntity(client, origin, angles, velocity);
            SetEntityMoveType(client, MOVETYPE_WALK);

            if (myGrenade) {
                PM_Message(client, "Teleporting to your grenade id %s, \"%s\".", id, grenadeName);
            } else {
                PM_Message(client, "Teleporting to %s's grenade id %s, \"%s\".", targetName, id, grenadeName);
            }

            if (!StrEqual(description, "")) {
                PM_Message(client, "Description: %s", description);
            }

            g_GrenadeLocationsKv.GoBack();
        }
        g_GrenadeLocationsKv.GoBack();
    }

    return success;
}

public int SaveGrenadeToKv(int client, const float origin[3], const float angles[3], const char[] name) {
    g_UpdatedGrenadeKv = true;
    char auth[AUTH_LENGTH];
    char clientName[MAX_NAME_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
    GetClientName(client, clientName, sizeof(clientName));
    g_GrenadeLocationsKv.JumpToKey(auth, true);
    g_GrenadeLocationsKv.SetString("name", clientName);
    int nadeId = g_GrenadeLocationsKv.GetNum("nextid", 1);
    g_GrenadeLocationsKv.SetNum("nextid", nadeId + 1);

    char idStr[32];
    IntToString(nadeId, idStr, sizeof(idStr));
    g_GrenadeLocationsKv.JumpToKey(idStr, true);

    g_GrenadeLocationsKv.SetString("name", name);
    g_GrenadeLocationsKv.SetVector("origin", origin);
    g_GrenadeLocationsKv.SetVector("angles", angles);

    g_GrenadeLocationsKv.GoBack();
    g_GrenadeLocationsKv.GoBack();
    return nadeId;
}

public bool DeleteGrenadeFromKv(int client, const char[] nadeIdStr) {
    g_UpdatedGrenadeKv = true;
    char auth[AUTH_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
    bool deleted = false;
    if (g_GrenadeLocationsKv.JumpToKey(auth)) {
        char name[GRENADE_NAME_LENGTH];
        if (g_GrenadeLocationsKv.JumpToKey(nadeIdStr)) {
            g_GrenadeLocationsKv.GetString("name", name, sizeof(name));
            g_GrenadeLocationsKv.GoBack();
        }

        deleted = g_GrenadeLocationsKv.DeleteKey(nadeIdStr);
        g_GrenadeLocationsKv.GoBack();
        PM_Message(client, "Deleted grenade id %s, \"%s\".", nadeIdStr, name);
    }
    return deleted;
}

public bool FindTargetNameByAuth(const char[] inputAuth, char[] name, int nameLen) {
    if (g_GrenadeLocationsKv.JumpToKey(inputAuth, false)) {
        g_GrenadeLocationsKv.GetString("name", name, nameLen);
        g_GrenadeLocationsKv.GoBack();
    }
    return false;
}

public bool FindTargetInGrenadesKvByName(const char[] inputName, char[] name, int nameLen, char[] auth, int authLen) {
    if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
        do {
            g_GrenadeLocationsKv.GetSectionName(auth, authLen);
            g_GrenadeLocationsKv.GetString("name", name, nameLen);

            if (StrContains(name, inputName, false) != -1) {
                g_GrenadeLocationsKv.GoBack();
                return true;
            }

        } while (g_GrenadeLocationsKv.GotoNextKey());
        g_GrenadeLocationsKv.GoBack();
    }
    return false;
}

public void UpdateGrenadeDescription(int client, int index, const char[] description) {
    g_UpdatedGrenadeKv = true;
    char auth[AUTH_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
    char nadeId[32];
    IntToString(index, nadeId, sizeof(nadeId));

    if (g_GrenadeLocationsKv.JumpToKey(auth)) {
        if (g_GrenadeLocationsKv.JumpToKey(nadeId)) {
            g_GrenadeLocationsKv.SetString("description", description);
            g_GrenadeLocationsKv.GoBack();
        }
        g_GrenadeLocationsKv.GoBack();
    }
}

public bool FindGrenadeTarget(const char[] nameInput, char[] name, int nameLen, char[] auth, int authLen) {
    int target = AttemptFindTarget(nameInput);
    if (IsPlayer(target) && GetClientAuthId(target, AuthId_Steam2, auth, authLen) && GetClientName(target, name, nameLen)) {
        return true;
    } else {
        return FindTargetInGrenadesKvByName(nameInput, name, nameLen, auth, authLen);
    }
}

public bool FindGrenadeByName(const char[] auth, const char[] lookupName, char grenadeId[GRENADE_ID_LENGTH]) {
    char name[GRENADE_NAME_LENGTH];
    if (g_GrenadeLocationsKv.JumpToKey(auth)) {
        if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
            do {
                g_GrenadeLocationsKv.GetSectionName(grenadeId, sizeof(grenadeId));
                g_GrenadeLocationsKv.GetString("name", name, sizeof(name));
                if (StrEqual(name, lookupName)) {
                    g_GrenadeLocationsKv.GoBack();
                    g_GrenadeLocationsKv.GoBack();
                    return true;
                }
            } while (g_GrenadeLocationsKv.GotoNextKey());

            g_GrenadeLocationsKv.GoBack();
        }
        g_GrenadeLocationsKv.GoBack();
    }
    return false;
}

public int CountGrenadesForPlayer(const char[] auth) {
    int count = 0;
    if (g_GrenadeLocationsKv.JumpToKey(auth)) {
        if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
            do {
                count++;
            } while (g_GrenadeLocationsKv.GotoNextKey());

            g_GrenadeLocationsKv.GoBack();
        }
        g_GrenadeLocationsKv.GoBack();
    }
    return count;
}
