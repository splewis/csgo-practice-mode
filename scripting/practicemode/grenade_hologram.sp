#define ASSET_RING "materials/practicemode/ring.vmt"
#define ASSET_RING_VTF "materials/practicemode/ring.vtf"
#define ASSET_DISC "materials/practicemode/disc.vmt"
#define ASSET_DISC_VTF "materials/practicemode/disc.vtf"
#define ASSET_PLACEHOLDER_MDL "materials/models/shells/shell_9mm.mdl"
#define MAX_HINT_SIZE 225
#define ENT_NADEID_PREFIX "sm_grenadeid_"
#define ENT_RING_BOUNDS_MAX view_as<float>({8.0, 8.0, 8.0})
#define ENT_RING_BOUNDS_MIN view_as<float>({-8.0, -8.0, -8.0})
// height is 64, crouch is 46: https://developer.valvesoftware.com/wiki/Dimensions#Eyelevel
#define EYE_HEIGHT 64.0
#define RETICULE_DISTANCE 50.0
#define GRENADE_COLOR_SMOKE "55 235 19"
#define GRENADE_COLOR_FLASH "87 234 247"
#define GRENADE_COLOR_MOLOTOV "255 161 46"
#define GRENADE_COLOR_HE "250 7 7"
#define GRENADE_COLOR_DEFAULT "180 180 180"

ArrayList /*int*/ g_grenadeHologramEntities;
int g_grenadeHologramClientTargetGrenadeIDs[MAXPLAYERS]; 
bool g_grenadeHologramClientInUse[MAXPLAYERS];
bool g_grenadeHologramClientEnabled[MAXPLAYERS];
bool g_grenadeHologramClientAllowed[MAXPLAYERS];
int g_grenadeHologramClientWhitelist[MAXPLAYERS];

public void GrenadeHologram_PluginStart() {
  g_grenadeHologramEntities = new ArrayList();
  for (int client = 1; client <= MaxClients; client++) {
    InitGrenadeHologramClientSettings(client);
  }
  HookEvent("round_start", GrenadeHologram_OnRoundStart, EventHookMode_PostNoCopy);
}

public void GrenadeHologram_OnRoundStart(Event event, const char[] name, bool dontBroadcast) {
  // Round restart will kill some of our hologram entities, so let's recreate our state.
  UpdateGrenadeHologramEntities();
}

public void GrenadeHologram_GameFrame() {
  if (!g_InPracticeMode) {
    return;
  }
  int ent = -1;
  int grenadeID = 0;
  for(int client = 1; client <= MaxClients; client++) {
    grenadeID = 0;
    if (IsClientInGame(client)) {
      ent = GetClientVisibleAimTarget(client);
      grenadeID = ent != -1 
        ? GetHologramEntityGrenadeID(ent) 
        : 0;
      if (GrenadeHologramShouldShow(client, grenadeID)) {
        ShowGrenadeHUDInfo(client, grenadeID);
      }
    } 
    g_grenadeHologramClientTargetGrenadeIDs[client] = grenadeID;
  }
}

public void GrenadeHologram_MapStart() {
  PrecacheModel(ASSET_RING, true);
  AddFileToDownloadsTable(ASSET_RING);
  AddFileToDownloadsTable(ASSET_RING_VTF);
  PrecacheModel(ASSET_DISC, true);
  AddFileToDownloadsTable(ASSET_DISC);
  AddFileToDownloadsTable(ASSET_DISC_VTF);
  PrecacheModel(ASSET_PLACEHOLDER_MDL, true);
}

public void GrenadeHologram_MapEnd() {
  RemoveGrenadeHologramEntites();
}

public void GrenadeHologram_ClientPutInServer(int client) {
  InitGrenadeHologramClientSettings(client);
  InitGrenadeHologramEntities();
}

public void GrenadeHologram_ClientDisconnect(int client) {
  InitGrenadeHologramClientSettings(client);
}

public void GrenadeHologram_LaunchPracticeMode() {
  // This gate is a workaround to prevent unexpected destruction of our entities during server initialization.
  // (The workaround is to wait until after initialization to make our entities.)
  if (!IsServerEmpty()) {
    InitGrenadeHologramEntities();
  }
}

public void GrenadeHologram_ExitPracticeMode() {
  RemoveGrenadeHologramEntites();
}

public void GrenadeHologram_GrenadeKvMutate() {
  UpdateGrenadeHologramEntities();
}

public void GrenadeHologram_EntityDestroyed(int entity) {
  if (entity == -1) {
    // Not sure what the cause is for this, but it does happen sometimes, and it's not valid for us.
    // No evident reason to log it though.
    return;
  }
  char classname[128];
  GetEntityClassname(entity, classname, sizeof(classname));
  if (!strcmp(classname, "env_sprite_oriented") || !strcmp(classname, "info_target")) {
    int i = g_grenadeHologramEntities.FindValue(entity);
    if (i != -1) {
      LogMessage("CSGO is destroying hologram entity %i but we are retaining it. Expecting to fix at next round_start.", entity);
      g_grenadeHologramEntities.Erase(i);
    }
  }
}

public Action GrenadeHologram_PlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) {	
  if (buttons & IN_USE) {
    // Debounce the use button switch.
    if (!g_grenadeHologramClientInUse[client]) {
      g_grenadeHologramClientInUse[client] = true;
      // Is the client aiming at a grenade?
      if (g_grenadeHologramClientTargetGrenadeIDs[client]) {
        char strGrenadeID[128];
        IntToString(g_grenadeHologramClientTargetGrenadeIDs[client], strGrenadeID, sizeof(strGrenadeID));
        if (!TeleportToSavedGrenadePosition(client, strGrenadeID)) {
          PM_Message(client, "Could not teleport to grenade id %s.", strGrenadeID);
        }
      }
    }
  } else {
    g_grenadeHologramClientInUse[client] = false;
  }
}

public void InitGrenadeHologramClientSettings(int client) {
  g_grenadeHologramClientTargetGrenadeIDs[client] = -1;
  g_grenadeHologramClientInUse[client] = false;
  g_grenadeHologramClientEnabled[client] = true;
  g_grenadeHologramClientAllowed[client] = true;
  g_grenadeHologramClientWhitelist[client] = -1;
}

public void InitGrenadeHologramEntities() {
  if (g_InPracticeMode && !g_grenadeHologramEntities.Length) {
    UpdateGrenadeHologramEntities();
  }
}

public void UpdateGrenadeHologramEntities() {
  RemoveGrenadeHologramEntites();
  IterateGrenades(_UpdateGrenadeHologramEntities_Iterator);
  SetupGrenadeHologramEntitiesHooks();
}

public Action _UpdateGrenadeHologramEntities_Iterator(
  const char[] ownerName, 
  const char[] ownerAuth, 
  const char[] name, 
  const char[] description, 
  ArrayList categories,
  const char[] grenadeId, 
  const float origin[3], 
  const float angles[3], 
  const char[] grenadeType, 
  const float grenadeOrigin[3],
  const float grenadeVelocity[3], 
  const float grenadeDetonationOrigin[3], 
  any data
) {
  GrenadeType type = GrenadeTypeFromString(grenadeType);

  float projectedOrigin[3];
  GetGrenadeHologramReticulePosition(origin, angles, projectedOrigin);

  char parentName[128];
  int button = CreateGrenadeHologramInteractiveEntity(projectedOrigin, angles, grenadeId, parentName, sizeof(parentName));
  if (button != -1) {
    g_grenadeHologramEntities.Push(button);
  }

  int reticule = CreateGrenadeHologramReticule(projectedOrigin, angles, type, grenadeId, parentName);
  if (reticule != -1) {
    g_grenadeHologramEntities.Push(reticule);
  }

  int disc = CreateGrenadeHologramFloor(origin, angles, type, grenadeId, parentName);
  if (disc != -1) {
    g_grenadeHologramEntities.Push(disc);
  }
}

public void RemoveGrenadeHologramEntites() {
  for (int i = g_grenadeHologramEntities.Length - 1; i >= 0; i--) {
    int ent = g_grenadeHologramEntities.Get(i);
    g_grenadeHologramEntities.Erase(i);
    if (IsValidEntity(ent)) {
      SDKUnhook(ent, SDKHook_SetTransmit, GrenadeHologramHook_OnTransmit);
      AcceptEntityInput(ent, "Kill");
    }
  }
}

public void SetupGrenadeHologramEntitiesHooks() {
  for(int i = 0; i < g_grenadeHologramEntities.Length; i++) {
    SDKHook(g_grenadeHologramEntities.Get(i), SDKHook_SetTransmit, GrenadeHologramHook_OnTransmit); 
  }
}

public Action GrenadeHologramHook_OnTransmit(int entity, int client) {
  return IsGrenadeHologramEnabled(client) || IsGrenadeHologramEntityWhitelisted(client, entity) 
    ? Plugin_Continue 
    : Plugin_Handled;
}

// creates an invisible entity for player interaction with the reticule.
// brush creation method adapted from:
// https://forums.alliedmods.net/showthread.php?t=129597
public int CreateGrenadeHologramInteractiveEntity(
  const float origin[3], 
  const float angles[3], 
  const char[] grenadeID,
  char[] targetname, 
  const int targetnameLength
) {
  int ent = CreateEntityByName("info_target");
  if (ent == -1) {
    return -1;
  }

  EncodeEntityGrenadeIDString(targetname, targetnameLength, grenadeID);
  DispatchKeyValue(ent, "targetname", targetname);
  // Hack: reuse this prop for storing grenade ID.
  SetEntProp(ent, Prop_Send, "m_iTeamNum", StringToInt(grenadeID, 10));

  DispatchKeyValue(ent, "spawnflags", "1");
  DispatchSpawn(ent);

  TeleportEntity(ent, origin, angles, NULL_VECTOR);
  // This causes logspew because info_target is a brush but this is not a brush model.
  // Not sure how to fix; we need to set a model for this technique to work.
  SetEntityModel(ent, ASSET_PLACEHOLDER_MDL); 
  
  SetEntPropVector(ent, Prop_Send, "m_vecMins", ENT_RING_BOUNDS_MIN);
  SetEntPropVector(ent, Prop_Send, "m_vecMaxs", ENT_RING_BOUNDS_MAX);

  // Gives the model bbox for raycasting, but does not block the player.
  SetEntProp(ent, Prop_Send, "m_nSolidType", SOLID_BBOX);    
  SetEntProp(ent, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS);

  // We need to set a model to activate the bounding rendering. 
  // But it will cause a warning if the engine attempts to draw the model, 
  // because this entity is not meant to draw a model. So we disable drawing here.
  int effects = GetEntProp(ent, Prop_Send, "m_fEffects");
  effects |= 32; // Sets EF_NODRAW.
  SetEntProp(ent, Prop_Send, "m_fEffects", effects);

  return ent;
}

// thing you stand on.
public int CreateGrenadeHologramFloor(
  const float origin[3], 
  const float angles[3], 
  const GrenadeType type,
  const char[] grenadeID,
  const char[] interactivityParent
) {
  char color[16];
  GetGrenadeHologramColorFromType(type, color);

  float rotation[3];
  rotation[0] = 90.0;
  rotation[1] = angles[1];
  rotation[2] = 0.0;

  // Prevent clipping in some maps from overlapping with floor brushes.
  float raisedOrigin[3];
  raisedOrigin[0] = origin[0];
  raisedOrigin[1] = origin[1];
  raisedOrigin[2] = origin[2] + 2.0; 

  int ent = CreateEntityByName("env_sprite_oriented");
  if (ent != -1) {
    DispatchKeyValue(ent, "classname", "env_sprite_oriented");
    DispatchKeyValue(ent, "spawnflags", "1"); 
    DispatchKeyValue(ent, "renderamt", "255");
    DispatchKeyValue(ent, "rendermode", "1"); 
    DispatchKeyValue(ent, "rendercolor", color);
    DispatchKeyValue(ent, "targetname", "grenade_hologram_disc");
    DispatchKeyValue(ent, "model", ASSET_DISC);
    if (!DispatchSpawn(ent)) {
      return -1;
    } 
    TeleportEntity(ent, raisedOrigin, rotation, NULL_VECTOR);
    // Hack: reuse this prop for storing grenade ID.
    SetEntProp(ent, Prop_Send, "m_iTeamNum", StringToInt(grenadeID, 10));
    // Needed for transmit hooks.
    SetVariantString(interactivityParent);
    AcceptEntityInput(ent, "SetParent"); 
  }
  return ent;
}

// thing you aim at.
public int CreateGrenadeHologramReticule(
  const float origin[3], 
  const float angles[3], 
  const GrenadeType type,
  const char[] grenadeID,
  const char[] interactivityParent
) {
  char color[16];
  GetGrenadeHologramColorFromType(type, color);

  int ent = CreateEntityByName("env_sprite_oriented");
  if (ent != -1) {
    DispatchKeyValue(ent, "classname", "env_sprite_oriented");
    DispatchKeyValue(ent, "spawnflags", "1"); 
    DispatchKeyValue(ent, "renderamt", "255");
    DispatchKeyValue(ent, "rendermode", "1"); 
    DispatchKeyValue(ent, "rendercolor", color);
    DispatchKeyValue(ent, "targetname", "grenade_hologram_reticule");
    DispatchKeyValue(ent, "model", ASSET_RING);
    if (!DispatchSpawn(ent)) {
      return -1;
    } 
    TeleportEntity(ent, origin, angles, NULL_VECTOR);
    // Hack: reuse this prop for storing grenade ID.
    SetEntProp(ent, Prop_Send, "m_iTeamNum", StringToInt(grenadeID, 10));
    // Needed for transmit hooks.
    SetVariantString(interactivityParent);
    AcceptEntityInput(ent, "SetParent"); 
  }
  return ent;
}

// moves origin up and out, to a point in front of player's face.
public void GetGrenadeHologramReticulePosition(const float origin[3], const float angles[3], float projectedOrigin[3]) {
  float eyeOrigin[3];
  float direction[3];
  AddVectors(origin, view_as<float>({0.0, 0.0, EYE_HEIGHT}), eyeOrigin);
  Math_RotateVector(view_as<float>({1.0, 0.0, 0.0}), angles, direction);
  ScaleVector(direction, RETICULE_DISTANCE);
  AddVectors(eyeOrigin, direction, projectedOrigin);
}

public int GetGrenadeHologramColorFromType(const GrenadeType type, char[] buffer) {
  switch (type) {
    case GrenadeType_Molotov:
      return strcopy(buffer, 16, GRENADE_COLOR_MOLOTOV);
    case GrenadeType_Incendiary:
      return strcopy(buffer, 16, GRENADE_COLOR_MOLOTOV);
    case GrenadeType_Smoke:
      return strcopy(buffer, 16, GRENADE_COLOR_SMOKE);
    case GrenadeType_Flash:
      return strcopy(buffer, 16,  GRENADE_COLOR_FLASH);
    case GrenadeType_HE:
      return strcopy(buffer, 16, GRENADE_COLOR_HE);
  }
  return strcopy(buffer, 16, GRENADE_COLOR_DEFAULT);
}

public void EncodeEntityGrenadeIDString(char[] buffer, const int length, const char[] grenadeID) {
  strcopy(buffer, length, ENT_NADEID_PREFIX);
  StrCat(buffer, length, grenadeID);
}

public int GetHologramEntityGrenadeID(const int ent) {
  // Hack: reuse this prop for storing grenade ID.
  return GetEntProp(ent, Prop_Send, "m_iTeamNum");
}

public int GetClientVisibleAimTarget(int client) {
  float origin[3];
  float angles[3];
  GetClientEyePosition(client, origin);
  GetClientEyeAngles(client, angles);
  Handle tr = TR_TraceRayFilterEx(origin, angles, MASK_VISIBLE, RayType_Infinite, TR_DontHitSelf, client);
  int result = -1;
  if (TR_DidHit(tr)) {
    result = TR_GetEntityIndex(tr);
  }
  CloseHandle(tr);
  return result;
}

public bool TR_DontHitSelf(int entity, int mask, any data_client) {
 if (entity == data_client) {
   return false;
 }
 return true;
}

public void ShowGrenadeHUDInfo(const int client, const int grenadeID) {
  if (!GrenadeHologramShouldShow(client, grenadeID)) {
    return;
  }
  if (!grenadeID) {
    PrintHintText(client, "Aim at a target for nade info.");
  } else {
    char name[256];
    GetClientGrenadeData(grenadeID, "name", name, sizeof(name));
    char desc[256];
    GetClientGrenadeData(grenadeID, "description", desc, sizeof(desc));
    char type[256];
    GetClientGrenadeData(grenadeID, "grenadeType", type, sizeof(type));

    char message[] = "%s [%s]\n"
      ..."—\n"
      ..."PRESS 'use' TO WARP";

    char messageWithDescription[] = "%s [%s]\n"
      ..."—\n"
      ..."%s\n"
      ..."—\n"
      ..."PRESS 'use' TO WARP";

    PrintHintText(client, desc[0] ? messageWithDescription : message, name, type, desc);
  }
}

public void GrenadeHologramToggle(int client) {
  g_grenadeHologramClientEnabled[client] = !g_grenadeHologramClientEnabled[client];
}

public void GrenadeHologramEnable(int client) {
  GrenadeHologramClearWhitelist(client);
  g_grenadeHologramClientEnabled[client] = true;
}

public void GrenadeHologramDisable(int client) {
  g_grenadeHologramClientEnabled[client] = false;
}

public void GrenadeHologramDeny(int client) {
  GrenadeHologramDisable(client);
  g_grenadeHologramClientAllowed[client] = false;
}

public void GrenadeHologramAllow(int client) {
  GrenadeHologramEnable(client);
  g_grenadeHologramClientAllowed[client] = true;
}

public bool IsGrenadeHologramAllowed(int client) {
  return g_grenadeHologramClientAllowed[client];
}

public bool IsGrenadeHologramEnabled(int client) {
  return g_grenadeHologramClientEnabled[client];
}

public bool IsGrenadeHologramEntityWhitelisted(const int client, const int entity) {
  int id = GetHologramEntityGrenadeID(entity);
  return id == g_grenadeHologramClientWhitelist[client];
}

public void GrenadeHologramWhitelistGrenadeID(const int client, const int id) {
  g_grenadeHologramClientWhitelist[client] = id;
}

public void GrenadeHologramClearWhitelist(const int client) {
  GrenadeHologramWhitelistGrenadeID(client, -1);
}

public bool GrenadeHologramShouldShow(const int client, const int grenadeID) {
  if (IsGrenadeHologramEnabled(client)) {
    return true; 
  }
  if (g_grenadeHologramClientWhitelist[client] == grenadeID) {
    return true;
  }
  return false;
}
