// Much of the work for this plugin is credited to Deathknife,
// whose help in getting nades thrown in a working manner wouldn't be possible without.

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
ArrayList g_NadeList;
ArrayList g_SmokeList;

// clang-format off
public Plugin myinfo = {
  name = "csutils",
  author = "splewis/Deathknife",
  description = "Grenade throwing natives/forwards",
  version = PLUGIN_VERSION,
  url = "https://github.com/splewis"
};
// clang-format off

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
  CreateNative("CSU_ThrowGrenade", Native_ThrowGrenade);
  CreateNative("CSU_ClearGrenades", Native_ClearGrenades);
  RegPluginLibrary("csutils");
  return APLRes_Success;
}

public void OnPluginStart() {
  g_OnGrenadeThrownForward = CreateGlobalForward(
      "CSU_OnThrowGrenade", ET_Ignore, Param_Cell, Param_Cell, Param_Cell,
      Param_Array, Param_Array, Param_Array,Param_Array);
}

public void OnMapStart() {
  delete g_NadeList;
  g_NadeList = new ArrayList(8);

  delete g_SmokeList;
  g_SmokeList = new ArrayList();
}

public void AddNade(
  int entRef, GrenadeType type,
  const float[3] origin, const float[3] velocity) {
  int index = g_NadeList.Push(entRef);
  g_NadeList.Set(index, type, 1);
  for (int i = 0; i < 3; i++) {
    g_NadeList.Set(index, view_as<int>(origin[i]), 2 + i);
    g_NadeList.Set(index, view_as<int>(velocity[i]), 2 + 3 + i);
  }
}

public void GetNade(int index, int& entRef, GrenadeType& type,
  float origin[3], float velocity[3]) {
  entRef = g_NadeList.Get(index, 0);
  type = g_NadeList.Get(index, 1);
  for (int i = 0; i < 3; i++) {
    origin[i] =  g_NadeList.Get(index, 2 + i);
    velocity[i] =  g_NadeList.Get(index, 2 + 3 + i);
  }
}

public int Native_ThrowGrenade(Handle plugin, int numParams) {
  int client = GetNativeCell(1);

  GrenadeType grenadeType = view_as<GrenadeType>(GetNativeCell(2));
  CheckGrenadeType(grenadeType);

  float origin[3];
  GetNativeArray(3, origin, sizeof(origin));

  float velocity[3];
  GetNativeArray(4, velocity, sizeof(velocity));

  char classname[64];
  GetProjectileName(grenadeType, classname, sizeof(classname));

  int entity = CreateEntityByName(classname);
  if (entity == -1) {
    LogError("Could not create nade %s", classname);
    return -1;
  }

  AddNade(EntIndexToEntRef(entity), grenadeType, origin, velocity);
  TeleportEntity(entity, origin, NULL_VECTOR, velocity);

  DispatchSpawn(entity);
  DispatchKeyValue(entity, "globalname", "custom");

  SetEntPropEnt(entity, Prop_Data, "m_hThrower", client);
  if (IsValidClient(client)) {
    SetEntProp(entity, Prop_Data, "m_iTeamNum", GetClientTeam(client));
  }
  AcceptEntityInput(entity, "InitializeSpawnFromWorld");
  AcceptEntityInput(entity, "FireUser1", client, client);
  SetEntPropFloat(entity, Prop_Data, "m_flElasticity", 0.45);
  SetEntPropFloat(entity, Prop_Data, "m_flGravity", 0.4);
  SetEntPropFloat(entity, Prop_Data, "m_flFriction", 0.2);
  Entity_SetOwner(entity, client);
  SetEntPropEnt(entity, Prop_Send, "m_hThrower", client);

  return entity;
}

public void OnGameFrame() {
  for (int i = 0; i < g_SmokeList.Length; i++) {
    int ref = g_SmokeList.Get(i);
    int ent = EntRefToEntIndex(ref);

    if (ent == INVALID_ENT_REFERENCE) {
      g_SmokeList.Erase(i);
      i--;
      continue;
    }

    float vel[3];
    GetEntPropVector(ent, Prop_Data, "m_vecVelocity", vel);
    if (GetVectorLength(vel) <= 0.1) {
      SetEntProp(ent, Prop_Send, "m_nSmokeEffectTickBegin", GetGameTickCount() + 1);
      EmitSoundToAll("weapons/smokegrenade/smoke_emit.wav", ent, 6);
      CreateTimer(15.0, KillNade, ref);
      g_SmokeList.Erase(i);
      i--;
    }
  }
}

public bool HandleNativeRequestedNade(int entity) {
  int ref = EntIndexToEntRef(entity);

  for (int i = 0; i < g_NadeList.Length; i++) {
    if (g_NadeList.Get(i, 0) == ref) {
      int entRef;
      GrenadeType type;
      float origin[3];
      float velocity[3];
      GetNade(i, entRef, type, origin, velocity);

      float angVelocity[3];
      angVelocity[0] = GetRandomFloat(-1000.0, 1000.0);
      angVelocity[1] = 0.0;
      angVelocity[2] = 600.0;

      SetEntPropFloat(entity, Prop_Data, "m_flElasticity", 0.45);
      SetEntPropFloat(entity, Prop_Data, "m_flGravity", 0.4);
      SetEntPropFloat(entity, Prop_Data, "m_flFriction", 0.2);

      SetEntPropVector(entity, Prop_Data, "m_vecOrigin", origin);
      SetEntPropVector(entity, Prop_Data, "m_vecVelocity", velocity);
      // This would be nice to set, but causes crashes?
      // SetEntPropVector(entity, Prop_Send, "m_vInitialVelocity", velocity);
      SetEntPropVector(entity, Prop_Data, "m_vecAngVelocity", angVelocity);
      TeleportEntity(entity, origin, NULL_VECTOR, velocity);
      g_NadeList.Erase(i);
      if (type == GrenadeType_Smoke) {
        g_SmokeList.Push(ref);
      }
      return true;
    }
  }
  return false;
}

public Action KillNade(Handle timer, int ref) {
  int ent = EntRefToEntIndex(ref);
  if (ent != INVALID_ENT_REFERENCE) {
    AcceptEntityInput(ent, "kill");
  }
}

public void OnEntityCreated(int entity, const char[] className) {
  if (GrenadeFromProjectileName(className) != GrenadeType_None) {
    SDKHook(entity, SDKHook_SpawnPost, OnGrenadeProjectileSpawned);
  }
}

public void OnGrenadeProjectileSpawned(int entity) {
  RequestFrame(GetGrenadeParameters, entity);
}

public void GetGrenadeParameters(int entity) {
  if (HandleNativeRequestedNade(entity)) {
    return;
  }

  char className[128];
  GetEntityClassname(entity, className, sizeof(className));
  GrenadeType grenadeType = GrenadeFromProjectileName(className);
  // TODO: try checking m_bIsIncGrenade

  int client = Entity_GetOwner(entity);
  float origin[3];
  float velocity[3];
  GetEntPropVector(entity, Prop_Data, "m_vecOrigin", origin);
  GetEntPropVector(entity, Prop_Data, "m_vecVelocity", velocity);

  Call_StartForward(g_OnGrenadeThrownForward);
  Call_PushCell(client);
  Call_PushCell(entity);
  Call_PushCell(grenadeType);
  Call_PushArray(origin, 3);
  Call_PushArray(velocity, 3);
  Call_Finish();
}

public void CheckGrenadeType(GrenadeType type) {
  if (view_as<int>(type) < 0 || type == GrenadeType_None) {
    ThrowNativeError(SP_ERROR_PARAM, "Invalid grenade type %d", type);
  }
}

public int Native_ClearGrenades(Handle plugin, int numParams) {
  return 0;
}
