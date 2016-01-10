public void FindMapSpawns() {
    FindMapSpawnsForTeam(g_CTSpawns, "info_player_counterterrorist");
    FindMapSpawnsForTeam(g_TSpawns, "info_player_terrorist");
}

static void FindMapSpawnsForTeam(ArrayList list, const char[] spawnClassName) {
    int minPriority = -1;

    int maxEnt = GetMaxEntities();
    char className[128];

    // First pass over spawns to find minPriority.
    for (int i = MaxClients; i < maxEnt; i++) {
        bool valid = IsValidEdict(i) && IsValidEntity(i);
        if (valid && GetEdictClassname(i, className, sizeof(className))) {
            if (StrEqual(className, spawnClassName)) {
                int priority = GetEntProp(i, Prop_Data, "m_iPriority");
                if (priority < minPriority || minPriority == -1) {
                    minPriority = priority;
                }
            }
        }
    }

    // Second pass only adds spawns with the lowest priority to the list.
    for (int i = MaxClients; i < maxEnt; i++) {
        bool valid = IsValidEdict(i) && IsValidEntity(i);
        if (valid && GetEdictClassname(i, className, sizeof(className))) {
            if (StrEqual(className, spawnClassName)) {
                int priority = GetEntProp(i, Prop_Data, "m_iPriority");
                if (priority == minPriority) {
                    list.Push(i);
                }
            }
        }
    }
}

public void TeleportToSpawnEnt(int client, int ent) {
    float origin[3];
    float angles[3];
    float velocity[3];
    GetEntPropVector(ent, Prop_Data, "m_vecOrigin", origin);
    GetEntPropVector(ent, Prop_Data, "m_angRotation", angles);
    TeleportEntity(client, origin, angles, velocity);
}

public int FindNearestSpawnIndex(int client, ArrayList list) {
    float clientOrigin[3];
    GetClientAbsOrigin(client, clientOrigin);

    float origin[3];
    int closest = -1;
    float minDist = 0.0;

    for (int i = 0; i < list.Length; i++) {
        int ent = list.Get(i);
        GetEntPropVector(ent, Prop_Data, "m_vecOrigin", origin);
        float dist = GetVectorDistance(clientOrigin, origin);
        if (closest < 0 || dist < minDist) {
            minDist = dist;
            closest = i;
        }
    }

    return closest;
}
