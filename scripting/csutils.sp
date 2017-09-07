#include <cstrike>
#include <sdkhooks>
#include <sdktools>
#include <smlib>
#include <sourcemod>

#include "include/csutils.inc"

#include "practicemode/util.sp"

#pragma semicolon 1
#pragma newdecls required

Handle g_OnGrenadeThrownForward = INVALID_HANDLE;

// The idea for grenade throwing / hooking is from ofir's executes plugin at
// https://forums.alliedmods.net/showthread.php?t=287710
int g_NadeBot;
int g_NadeBotStage = -1;
int g_iNextAttackOffset = -1;

ArrayList g_GrenadeQueue = null;

// Current grenade parameters being used.
GrenadeType g_ActiveGrenadeType;
float g_ActiveGrenadeOrigin[3];
float g_ActiveGrenadeVelocity[3];

float g_BotSpawnPoint[3];
int g_ConnectedOffset;

// clang-format off
public Plugin myinfo = {
  name = "csutils",
  author = "splewis",
  description = "",
  version = PLUGIN_VERSION,
  url = "https://github.com/splewis"
};
// clang-format off

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
  CreateNative("CSU_ThrowGrenade", Native_ThrowGrenade);
  RegPluginLibrary("csutils");
  return APLRes_Success;
}

public void OnPluginStart() {
  g_OnGrenadeThrownForward = CreateGlobalForward(
      "CSU_OnThrowGrenade", ET_Ignore, Param_Cell, Param_Cell, Param_Array,
      Param_Array);
  HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
  HookEvent("player_spawn", Event_PlayerSpawn);

  g_iNextAttackOffset = FindSendPropInfo("CCSPlayer", "m_flNextAttack");
  g_ConnectedOffset = FindSendPropInfo("CCSPlayerResource", "m_bConnected");
  CreateTimer(0.1, Timer_Test, _, TIMER_REPEAT);
}

public bool KeepBotDead() {
  ConVar cvar = FindConVar("mp_respawn_on_death_t");
  return !cvar.BoolValue;
}

public void CleanupBot() {
  if (KeepBotDead() && GrenadeQueueLength() == 0 && IsCandidateNadeBot(g_NadeBot) && IsPlayerAlive(g_NadeBot)) {
    ForcePlayerSuicide(g_NadeBot);
  }
}

public Action Timer_Test(Handle timer) {
  CleanupBot();
  return Plugin_Continue;
}

public void OnPluginEnd() {
  if (IsNadeBot(g_NadeBot)) {
    KickClient(g_NadeBot);
  }
}

public void OnMapStart() {
  InitGrenadeQueue();
  g_NadeBotStage = -1;
  GetBotSpawnPoint();
}

public void OnConfigsExecuted() {
  SDKHookEx(GetPlayerResourceEntity(), SDKHook_ThinkPost, OnResourceThink);
}

public void OnClientPutInServer(int client) {
  if (client != g_NadeBot) {
    SetEntData(GetPlayerResourceEntity(), g_ConnectedOffset + (g_NadeBot * 4), false, 1);
  }
}

public void OnResourceThink(int entity) {
  if (g_NadeBot == -1) {
    return;
  }

  // Make players think g_NadeBot is not connected.
  SetEntData(entity, g_ConnectedOffset + (g_NadeBot * 4), false, 1);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (IsNadeBot(client)) {
    g_NadeBotStage = -1;
    TeleportNadeBot(client);
    CleanupBot();
  }
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
  int victim = GetClientOfUserId(event.GetInt("userid"));
  if (IsNadeBot(victim)) {
    event.BroadcastDisabled = true;
    return Plugin_Stop;
  }

  return Plugin_Continue;
}

static void TeleportNadeBot(int client) {
  TeleportEntity(client, g_BotSpawnPoint, NULL_VECTOR, NULL_VECTOR);
}

static void CheckGrenadeType(GrenadeType type) {
  if (view_as<int>(type) < 0 || type == GrenadeType_None) {
    ThrowNativeError(SP_ERROR_PARAM, "Invalid grenade type %d", type);
  }
}

public int Native_ThrowGrenade(Handle plugin, int numParams) {
  GrenadeType grenadeType = view_as<GrenadeType>(GetNativeCell(2));
  CheckGrenadeType(grenadeType);

  float origin[3];
  GetNativeArray(3, origin, sizeof(origin));

  float velocity[3];
  GetNativeArray(4, velocity, sizeof(velocity));

  AddGrenadeToQueue(grenadeType, origin, velocity);
  MaybeStartGrenadeThrow();
  return 0;
}

bool IsCandidateNadeBot(int client) {
  return client > 0 && IsClientInGame(client) && IsFakeClient(client) && !IsClientSourceTV(client);
}

bool IsNadeBot(int client) {
  return IsCandidateNadeBot(client) && client == g_NadeBot;
}

static void GetBotName(char[] name, int len) {
  ArrayList choices = new ArrayList(len);
  choices.PushString("BOT splewis");
  choices.PushString("BOT Eley");
  choices.PushString("BOT Drone");
  choices.PushString("BOT iannn");
  int index = GetRandomInt(0, choices.Length - 1);
  choices.GetString(index, name, len);
  delete choices;
}

int GetOrCreateNadeBot() {
  if (!IsCandidateNadeBot(g_NadeBot)) {
    char name[MAX_NAME_LENGTH + 1];
    GetBotName(name, sizeof(name));
    g_NadeBot = CreateFakeClient(name);
    SDKHook(g_NadeBot, SDKHook_SetTransmit, Hook_SetTransmit);
  }

  CS_SwitchTeam(g_NadeBot, CS_TEAM_T);
  if (!IsPlayerAlive(g_NadeBot)) {
    CS_RespawnPlayer(g_NadeBot);
  }
  TeleportNadeBot(g_NadeBot);

  return g_NadeBot;
}

 public Action Hook_SetTransmit(int entity, int client) {
     return entity == g_NadeBot ? Plugin_Handled : Plugin_Continue;
 }

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3],
                      float angles[3], int &weapon, int &subtype, int &cmdnum,
                      int &tickcount, int &seed, int mouse[2]) {
  if (g_NadeBotStage >= 1 && IsFakeClient(client) && g_NadeBot == client && g_NadeBotStage > 0 && IsPlayerAlive(g_NadeBot)) {
    switch (g_NadeBotStage) {
      case 1: {
        Client_RemoveAllWeapons(client);
        g_NadeBotStage++;
      }
      case 2: {
        char weaponName[128];
        GetGrenadeWeapon(g_ActiveGrenadeType, weaponName, sizeof(weaponName));
        GivePlayerItem(client, weaponName);
        g_NadeBotStage++;
      }
      case 3: {
        SetEntData(client, g_iNextAttackOffset, GetGameTime());
        g_NadeBotStage++;
      }
      case 4: {
        SetEntData(client, g_iNextAttackOffset, GetGameTime());
        g_NadeBotStage++;
      }
      case 5: {
        float origin[3];
        Entity_GetAbsOrigin(client, origin);
        float velocity[3];
        float grenadeAngles[3];
        TeleportEntity(client, origin, grenadeAngles, velocity);
        buttons = IN_ATTACK;
        g_NadeBotStage++;
      }
      case 6: {
        float origin[3];
        Entity_GetAbsOrigin(client, origin);
        float velocity[3];
        float grenadeAngles[3];
        TeleportEntity(client, origin, grenadeAngles, velocity);
        buttons = 0;
        g_NadeBotStage++;
      }
      case 7: {
        g_NadeBotStage = -1;
      }
    }
  }
}

public void OnEntityCreated(int entity, const char[] className) {
  if (GrenadeFromProjectileName(className) != GrenadeType_None) {
    RequestFrame(OnGrenadeProjectileCreated, entity);
  }
}

public void OnGrenadeProjectileCreated(int entity) {
  char className[128];
  GetEntityClassname(entity, className, sizeof(className));
  GrenadeType grenadeType = GrenadeFromProjectileName(className);
  // TODO: try checking  m_bIsIncGrenade

  int client = Entity_GetOwner(entity);
  if (client > 0 && IsClientInGame(client)) {
    if (IsNadeBot(client)) {
      TeleportEntity(entity, g_ActiveGrenadeOrigin, NULL_VECTOR, g_ActiveGrenadeVelocity);
      RemoveGrenadeFromQueue();
      if (!MaybeStartGrenadeThrow()) {
        CleanupBot();
      }
    } else {
      float origin[3];
      float velocity[3];
      Entity_GetAbsOrigin(entity, origin);
      Entity_GetLocalVelocity(entity, velocity);

      Call_StartForward(g_OnGrenadeThrownForward);
      Call_PushCell(client);
      Call_PushCell(grenadeType);
      Call_PushArray(origin, 3);
      Call_PushArray(velocity, 3);
      Call_Finish();
    }
  }
}

public bool MaybeStartGrenadeThrow() {
  if (GrenadeQueueLength() == 0) {
    return false;
  }
  if (g_NadeBotStage != -1) {
    return false;
  }
  if (!GetActiveGrenade(g_ActiveGrenadeType, g_ActiveGrenadeOrigin, g_ActiveGrenadeVelocity)) {
    return false;
  }

  // Yay! we can start now!
  if (!IsNadeBot(g_NadeBot)) {
    GetOrCreateNadeBot();
  }
  if (!IsPlayerAlive(g_NadeBot)) {
    CS_RespawnPlayer(g_NadeBot);
  }

  g_NadeBotStage = 1;
  return true;
}

public void GetBotSpawnPoint() {
  // A reasonable default.
  g_BotSpawnPoint[0] = 0.0;
  g_BotSpawnPoint[1] = 0.0;
  g_BotSpawnPoint[2] = -7000.0;

  char path[PLATFORM_MAX_PATH + 1];
  BuildPath(Path_SM, path, sizeof(path), "configs/csutils.cfg");

  KeyValues kv = new KeyValues("csutils");
  if (kv.ImportFromFile(path)) {
    char mapName[PLATFORM_MAX_PATH];
    GetCurrentMap(mapName, sizeof(mapName));
    kv.GetVector(mapName, g_BotSpawnPoint);
  }
  delete kv;
}

// Grenade queue functionality.

void InitGrenadeQueue() {
  if (g_GrenadeQueue == null) {
    g_GrenadeQueue = new ArrayList(7);
  }
  g_GrenadeQueue.Clear();
}

// Returns number of entires in the queue.
int AddGrenadeToQueue(GrenadeType grenadeType, float origin[3], float velocity[3]) {
  int index = g_GrenadeQueue.Push(grenadeType);
  g_GrenadeQueue.Set(index, origin[0], 1);
  g_GrenadeQueue.Set(index, origin[1], 2);
  g_GrenadeQueue.Set(index, origin[2], 3);
  g_GrenadeQueue.Set(index, velocity[0], 4);
  g_GrenadeQueue.Set(index, velocity[1], 5);
  g_GrenadeQueue.Set(index, velocity[2], 6);
  return index + 1;
}

bool GetActiveGrenade(GrenadeType& grenadeType, float origin[3], float velocity[3]) {
  if (g_GrenadeQueue.Length == 0) {
    return false;
  }
  grenadeType = g_GrenadeQueue.Get(0, 0);
  origin[0] = view_as<float>(g_GrenadeQueue.Get(0, 1));
  origin[1] = view_as<float>(g_GrenadeQueue.Get(0, 2));
  origin[2] = view_as<float>(g_GrenadeQueue.Get(0, 3));
  velocity[0] = view_as<float>(g_GrenadeQueue.Get(0, 4));
  velocity[1] = view_as<float>(g_GrenadeQueue.Get(0, 5));
  velocity[2] = view_as<float>(g_GrenadeQueue.Get(0, 6));

  return true;
}

int GrenadeQueueLength() {
  return g_GrenadeQueue.Length;
}

void RemoveGrenadeFromQueue() {
  if (g_GrenadeQueue.Length == 0) {
    LogError("Can't remove a grenade from queue when it's empty");
    return;
  }
  g_GrenadeQueue.Erase(0);
}
