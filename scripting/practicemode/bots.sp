public int CreateBot(int client) {
  int bot = GetClientBot(client);
  if (bot <= 0) {
    char name[64];
    GetClientName(client, name, sizeof(name));
    StrCat(name, sizeof(name), " ");
    bot = CreateFakeClient(name);
    g_BotOwned[client] = bot;
    g_IsPMBot[bot] = true;
  }
  if (bot <= 0) {
    PM_Message(client, "Failed to create bot :(");
    return -1;
  }

  int botTeam = GetClientTeam(client) == CS_TEAM_CT ? CS_TEAM_T : CS_TEAM_CT;
  ChangeClientTeam(bot, botTeam);
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
