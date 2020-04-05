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

public void GrenadeHologram_PluginStart() {
  g_grenadeHologramEntities = new ArrayList();
  for (int client = 1; client <= MaxClients; client++) {
    InitGrenadeHologramClientSettings(client);
  }
}

public void GrenadeHologram_GameFrame() {
  int ent = -1;
  int grenadeID = 0;
  for(int client = 1; client <= MaxClients; client++) {
    grenadeID = 0;
    if (IsClientInGame(client)) {
      ent = GetClientVisibleAimTarget(client);
      grenadeID = ent != -1 
        ? GetEntityGrenadeID(ent) 
        : 0;
      ShowGrenadeHUDInfo(client, grenadeID);
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
  ClearArray(g_grenadeHologramEntities);
}

public void GrenadeHologram_ClientDisconnect(int client) {
  InitGrenadeHologramClientSettings(client);
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

  int reticule = CreateGrenadeHologramReticule(projectedOrigin, angles, type, parentName);
  if (reticule != -1) {
    g_grenadeHologramEntities.Push(reticule);
  }

  int disc = CreateGrenadeHologramFloor(origin, angles, type, parentName);
  if (disc != -1) {
    g_grenadeHologramEntities.Push(disc);
  }
}

public void RemoveGrenadeHologramEntites() {
  for (int i = 0; i < g_grenadeHologramEntities.Length; i++) {
    int ent = g_grenadeHologramEntities.Get(i);
    if (IsValidEntity(ent)) {
        SDKUnhook(ent, SDKHook_SetTransmit, GrenadeHologramHook_OnTransmit);
        AcceptEntityInput(ent, "Kill");
    }
  }
  ClearArray(g_grenadeHologramEntities);
}

public void SetupGrenadeHologramEntitiesHooks() {
  for(int i = 0; i < g_grenadeHologramEntities.Length; i++) {
    SDKHook(g_grenadeHologramEntities.Get(i), SDKHook_SetTransmit, GrenadeHologramHook_OnTransmit); 
  }
}

public Action GrenadeHologramHook_OnTransmit(int entity, int client) {
  return g_grenadeHologramClientEnabled[client] ? Plugin_Continue : Plugin_Handled;
}

// thing you stand on.
public int CreateGrenadeHologramFloor(
  const float origin[3], 
  const float angles[3], 
  const GrenadeType type,
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
    DispatchSpawn(ent);
    TeleportEntity(ent, raisedOrigin, rotation, NULL_VECTOR);
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

// thing you aim at.
public int CreateGrenadeHologramReticule(
  const float origin[3], 
  const float angles[3], 
  const GrenadeType type,
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
    DispatchSpawn(ent);
    TeleportEntity(ent, origin, angles, NULL_VECTOR);
    // Needed for transmit hooks.
    SetVariantString(interactivityParent);
    AcceptEntityInput(ent, "SetParent"); 
  }
  return ent;
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

public int GetEntityGrenadeID(int ent) {
  int prefixlen = strlen(ENT_NADEID_PREFIX);
  char prop[128];
  GetEntPropString(ent, Prop_Send, "m_iName", prop, sizeof(prop));
  char numeral[128];
  strcopy(numeral, sizeof(numeral), prop[prefixlen]);
  // TODO: error checking if name is formatted incorrectly?
  return StringToInt(numeral, 10);
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

public void GrenadeHologramClientToggle(int client) {
  g_grenadeHologramClientEnabled[client] = !g_grenadeHologramClientEnabled[client];
}

public bool IsGrenadeHologramEnabled(int client) {
  return g_grenadeHologramClientEnabled[client];
}