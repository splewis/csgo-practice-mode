#define ASSET_RING "materials/practicemode/ring.vmt"
#define ASSET_RING_VTF "materials/practicemode/ring.vtf"
#define ASSET_DISC "materials/practicemode/disc.vmt"
#define ASSET_DISC_VTF "materials/practicemode/disc.vtf"
// height is 64, crouch is 46: https://developer.valvesoftware.com/wiki/Dimensions#Eyelevel
#define EYE_HEIGHT 64.0
#define RETICULE_DISTANCE 50.0
#define GRENADE_COLOR_SMOKE "55 235 19"
#define GRENADE_COLOR_FLASH "87 234 247"
#define GRENADE_COLOR_MOLOTOV "235 91 19"
#define GRENADE_COLOR_HE "250 7 7"
#define GRENADE_COLOR_DEFAULT "180 180 180"

bool g_grenadeHologramInitiated = false;
ArrayList /*int*/ g_grenadeHologramEntities;

public void GrenadeHologram_MapStart() {
  PrecacheModel(ASSET_RING, true);
  AddFileToDownloadsTable(ASSET_RING);
  AddFileToDownloadsTable(ASSET_RING_VTF);
  PrecacheModel(ASSET_DISC, true);
  AddFileToDownloadsTable(ASSET_DISC);
  AddFileToDownloadsTable(ASSET_DISC_VTF);
}

public void UpdateGrenadeHologramEntities() {
  if (!g_grenadeHologramInitiated) {
    g_grenadeHologramEntities = new ArrayList();
    g_grenadeHologramInitiated = true;
  }
  RemoveGrenadeHologramEntites();
  IterateGrenades(_UpdateGrenadeHologramEntities_Iterator);
}

public Action _UpdateGrenadeHologramEntities_Iterator(const char[] ownerName, const char[] ownerAuth, const char[] name,
                                  const char[] description, ArrayList categories,
                                  const char[] grenadeId, const float origin[3],
                                  const float angles[3], const char[] strGrenadeType, any data) {
  GrenadeType type = GrenadeTypeFromString(strGrenadeType);
  int reticule = CreateGrenadeHologramReticule(origin, angles, type);
  if (reticule != -1) {
    g_grenadeHologramEntities.Push(reticule);
  }
  int disc = CreateGrenadeHologramDisc(origin, angles, type);
  if (disc != -1) {
    g_grenadeHologramEntities.Push(disc);
  }
}

public void RemoveGrenadeHologramEntites() {
  for (int i = 0; i < g_grenadeHologramEntities.Length; i++) {
    int ent = g_grenadeHologramEntities.Get(i);
    if (IsValidEntity(ent)) {
      RemoveEntity(ent);
    }
  }
  ClearArray(g_grenadeHologramEntities);
}

// thing you stand on.
public int CreateGrenadeHologramDisc(const float origin[3], const float angles[3], GrenadeType type) {
    char color[16];
    GetGrenadeHologramColorFromType(type, color);

    float rotation[3];
    rotation[0] = 90.0;
    rotation[1] = angles[1];
    rotation[2] = 0.0;

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
        TeleportEntity(ent, origin, rotation, NULL_VECTOR);
    }
    return ent;
}

// thing you aim at.
public int CreateGrenadeHologramReticule(const float origin[3], const float angles[3], GrenadeType type) {
    // move sprite up and forward, in front of player's face. 
    float eyeOrigin[3];
    float direction[3];
    float projectedOrigin[3];
    AddVectors(origin, view_as<float>({0.0, 0.0, EYE_HEIGHT}), eyeOrigin);
    Math_RotateVector(view_as<float>({1.0, 0.0, 0.0}), angles, direction);
    ScaleVector(direction, RETICULE_DISTANCE);
    AddVectors(eyeOrigin, direction, projectedOrigin);
    
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
        TeleportEntity(ent, projectedOrigin, angles, NULL_VECTOR);
    }
    return ent;
}

public int GetGrenadeHologramColorFromType(GrenadeType type, char[] buffer) {
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