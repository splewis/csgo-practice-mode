stock int CreateBot(int client, bool forceCrouch=false) {
  int bot = GetClientBot(client);
  if (bot <= 0) {
    char name[64];
    GetClientName(client, name, sizeof(name));
    StrCat(name, sizeof(name), " ");
    bot = CreateFakeClient(name);
    g_BotOwned[client] = bot;
    g_IsPMBot[bot] = true;
    PM_Message(client, "Created bot, use .nobot to remove it.");
  }
  if (bot <= 0) {
    PM_Message(client, "Failed to create bot :(");
    return -1;
  }

  int botTeam = GetClientTeam(client) == CS_TEAM_CT ? CS_TEAM_T : CS_TEAM_CT;
  ChangeClientTeam(bot, botTeam);

  bool clientCrouching = (GetEntityFlags(client) & FL_DUCKING != 0);
  g_BotCrouching[bot] = forceCrouch || clientCrouching;

  CS_RespawnPlayer(bot);
  return bot;
}

bool IsPMBot(int client) {
  return client > 0 && g_IsPMBot[client] && IsClientInGame(client) && IsFakeClient(client);
}

public int GetClientBot(int client) {
  int bot = g_BotOwned[client];
  if (IsPMBot(bot)) {
    return bot;
  }
  return -1;
}

void KickClientBot(int client) {
  int bot = GetClientBot(client);
  if (bot > 0) {
    KickClient(bot);
    g_BotOwned[client] = -1;
    g_IsPMBot[bot] = false;
  }
}

void GiveBotParams(int bot) {
  Client_RemoveAllWeapons(bot);
  GivePlayerItem(bot, g_BotSpawnWeapon[bot]);
  TeleportEntity(bot, g_BotSpawnOrigin[bot], g_BotSpawnAngles[bot], NULL_VECTOR);
}

// Commands.

public Action Command_Bot(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int bot = CreateBot(client);
  if (bot <= 0) {
    return Plugin_Handled;
  }

  GetClientAbsOrigin(client, g_BotSpawnOrigin[bot]);
  GetClientEyeAngles(client, g_BotSpawnAngles[bot]);
  GetClientWeapon(client, g_BotSpawnWeapon[bot], CLASS_LENGTH);
  GiveBotParams(bot);

  SetEntityMoveType(client, MOVETYPE_NOCLIP);
  return Plugin_Handled;
}

public Action Command_CrouchBot(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int bot = CreateBot(client, true);
  if (bot <= 0) {
    return Plugin_Handled;
  }

  GetClientAbsOrigin(client, g_BotSpawnOrigin[bot]);
  GetClientEyeAngles(client, g_BotSpawnAngles[bot]);
  GetClientWeapon(client, g_BotSpawnWeapon[bot], CLASS_LENGTH);
  GiveBotParams(bot);

  SetEntityMoveType(client, MOVETYPE_NOCLIP);
  return Plugin_Handled;
}

public Action Command_BotPlace(int client, int args) {
  // Based on Franc1sco's bot_spawner plugin:
  // https://github.com/Franc1sco/BotSpawner/blob/master/bot_spawner.sp
  int bot = CreateBot(client);
  if (bot <= 0) {
    return Plugin_Handled;
  }

  float start[3], angle[3], end[3], normal[3];
  GetClientEyePosition(client, start);
  GetClientEyeAngles(client, angle);

  TR_TraceRayFilter(start, angle, MASK_SOLID, RayType_Infinite, RayDontHitSelf, client);
  if (TR_DidHit(INVALID_HANDLE)) {
    TR_GetEndPosition(end, INVALID_HANDLE);
    TR_GetPlaneNormal(INVALID_HANDLE, normal);
    GetVectorAngles(normal, normal);
    normal[0] += 90.0;

    g_BotSpawnOrigin[bot] = end;
    g_BotSpawnAngles[bot] = normal;
    GetClientWeapon(client, g_BotSpawnWeapon[bot], CLASS_LENGTH);
    GiveBotParams(bot);
  }

  return Plugin_Handled;
}

public Action Command_Boost(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int bot = CreateBot(client);
  if (bot <= 0) {
    return Plugin_Handled;
  }

  float origin[3];
  GetClientAbsOrigin(client, origin);
  g_BotSpawnOrigin[bot] = origin;

  GetClientEyeAngles(client, g_BotSpawnAngles[bot]);
  GetClientWeapon(client, g_BotSpawnWeapon[bot], CLASS_LENGTH);
  GiveBotParams(bot);

  origin[2] += PLAYER_HEIGHT + 4.0;
  TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
  return Plugin_Handled;
}

public Action Command_CrouchBoost(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int bot = CreateBot(client, true);
  if (bot <= 0) {
    return Plugin_Handled;
  }

  float origin[3];
  GetClientAbsOrigin(client, origin);
  g_BotSpawnOrigin[bot] = origin;

  GetClientEyeAngles(client, g_BotSpawnAngles[bot]);
  GetClientWeapon(client, g_BotSpawnWeapon[bot], CLASS_LENGTH);
  GiveBotParams(bot);

  origin[2] += PLAYER_HEIGHT + 4.0;
  TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
  return Plugin_Handled;
}

public bool RayDontHitSelf(int entity, int contentsMask, any data) {
  return entity != data;
}

public Action Command_RemoveBot(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  KickClientBot(client);
  return Plugin_Handled;
}
