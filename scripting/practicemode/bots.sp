stock int CreateBot(int client, bool forceCrouch = false) {
  int numBots = g_ClientBots[client].Length;
  char name[64];
  GetClientName(client, name, sizeof(name));
  StrCat(name, sizeof(name), " ");
  if (numBots >= 1) {
    char buf[16];
    Format(buf, sizeof(buf), "%d ", numBots + 1);
    StrCat(name, sizeof(name), buf);
  }

  int bot = CreateFakeClient(name);
  if (bot <= 0) {
    PM_Message(client, "Failed to create bot :(");
    return -1;
  }

  g_ClientBots[client].Push(bot);
  g_IsPMBot[bot] = true;
  PM_Message(client, "Created bot, use .nobot to remove it.");

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

// index=-1 implies the last bot added.
stock int GetClientBot(int client, int index = -1) {
  if (index == -1) {
    int len = g_ClientBots[client].Length;
    if (len == 0) {
      return -1;
    } else {
      return g_ClientBots[client].Get(len - 1);
    }
  }

  if (g_ClientBots[client].Length <= index) {
    return -1;
  }

  int bot = g_ClientBots[client].Get(index);
  if (IsPMBot(bot)) {
    return bot;
  }
  return -1;
}

stock void KickClientBot(int client, int index = -1) {
  int bot = GetClientBot(client, index);
  if (bot > 0) {
    KickClient(bot);
    g_IsPMBot[bot] = false;
    FindAndErase(g_ClientBots[client], bot);
  }
}

public void KickAllClientBots(int client) {
  for (int i = 0; i < g_ClientBots[client].Length; i++) {
    int bot = g_ClientBots[client].Get(i);
    if (IsPMBot(bot)) {
      KickClient(bot);
    }
  }
  g_ClientBots[client].Clear();
}

void GiveBotParams(int bot) {
  // If we were giving a knife, let's give them a gun. We don't want to accidently try to give a
  // knife our beloved bot doesn't own on the steam market!
  if (StrContains(g_BotSpawnWeapon[bot], "knife")) {
    if (GetClientTeam(bot) == CS_TEAM_CT) {
      g_BotSpawnWeapon[bot] = "weapon_m4a1";
    } else {
      g_BotSpawnWeapon[bot] = "weapon_ak47";
    }
  }

  Client_RemoveAllWeapons(bot);
  GivePlayerItem(bot, g_BotSpawnWeapon[bot]);
  TeleportEntity(bot, g_BotSpawnOrigin[bot], g_BotSpawnAngles[bot], NULL_VECTOR);
  Client_SetArmor(bot, 100);
  SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
}

// Commands.

// TODO: Add # arg to edit an existing bot index
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

public Action Command_MoveBot(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int bot = GetClientBot(client);
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

// TODO: Add # arg to edit an existing bot index
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

// TODO: Add # arg to edit an existing bot index
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

// TODO: Add # arg to remove an existing bot index
public Action Command_RemoveBot(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  KickClientBot(client);
  return Plugin_Handled;
}

public Action Command_RemoveBots(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  KickAllClientBots(client);
  return Plugin_Handled;
}

public Action Event_DamageDealtEvent(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InPracticeMode) {
    return Plugin_Continue;
  }

  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  int victim = GetClientOfUserId(event.GetInt("userid"));

  if (IsPMBot(victim) && IsPlayer(attacker)) {
    int damage = event.GetInt("dmg_health");
    int postDamageHealth = event.GetInt("health");
    PM_Message(attacker, "---> %d damage to BOT %N(%d health)", damage, victim, postDamageHealth);
  }

  return Plugin_Continue;
}
