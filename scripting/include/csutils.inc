#if defined _csutils_included
#endinput
#endif
#define _csutils_included

enum GrenadeType {
  GrenadeType_None = 0,
  GrenadeType_Smoke = 1,
  GrenadeType_Flash = 2,
  GrenadeType_HE = 3,
  GrenadeType_Molotov = 4,
  GrenadeType_Decoy = 5,
  GrenadeType_Incendiary = 6,
};

// Core grenade functions.
// client is currently unused.
native int CSU_ThrowGrenade(int client, GrenadeType grenadeType, const float origin[3],
                            const float velocity[3]);

// Removes any grenades in the throw queue and any nade bot connected.
native bool CSU_ClearGrenades();

// When a client throws a grenade.
// This is *not* called when the grenade came from the CSU_ThrowGrenade native.
forward void CSU_OnThrowGrenade(int client, GrenadeType grenadeType, const float origin[3],
                                const float velocity[3]);

stock bool IsGrenade(GrenadeType g) {
  return g != GrenadeType_None;
}

stock GrenadeType GrenadeFromProjectileName(const char[] projectileName) {
  if (StrEqual(projectileName, "smokegrenade_projectile")) {
    return GrenadeType_Smoke;
  } else if (StrEqual(projectileName, "flashbang_projectile")) {
    return GrenadeType_Flash;
  } else if (StrEqual(projectileName, "hegrenade_projectile")) {
    return GrenadeType_HE;
  } else if (StrEqual(projectileName, "molotov_projectile")) {
    return GrenadeType_Molotov;
  } else if (StrEqual(projectileName, "decoy_projectile")) {
    return GrenadeType_Decoy;
  } else if (StrEqual(projectileName, "molotov_projectile")) {
    return GrenadeType_Incendiary;
  } else {
    return GrenadeType_None;
  }
}

stock void GetGrenadeWeapon(GrenadeType type, char[] buffer, int length) {
  switch (type) {
    case GrenadeType_Smoke:
      Format(buffer, length, "weapon_smokegrenade");
    case GrenadeType_Flash:
      Format(buffer, length, "weapon_flashbang");
    case GrenadeType_HE:
      Format(buffer, length, "weapon_hegrenade");
    case GrenadeType_Molotov:
      Format(buffer, length, "weapon_molotov");
    case GrenadeType_Decoy:
      Format(buffer, length, "weapon_decoy");
    case GrenadeType_Incendiary:
      Format(buffer, length, "weapon_incgrenade");
    default:
      LogError("Unknown grenade type: %d", type);
  }
}

stock GrenadeType GrenadeTypeFromString(const char[] name) {
  if (StrEqual(name, "smoke")) {
    return GrenadeType_Smoke;
  } else if (StrEqual(name, "flash")) {
    return GrenadeType_Flash;
  } else if (StrEqual(name, "he")) {
    return GrenadeType_HE;
  } else if (StrEqual(name, "molotov")) {
    return GrenadeType_Molotov;
  } else if (StrEqual(name, "decoy")) {
    return GrenadeType_Decoy;
  } else if (StrEqual(name, "incendiary")) {
    return GrenadeType_Incendiary;
  } else {
    return GrenadeType_None;
  }
}

stock void GrenadeTypeString(GrenadeType type, char[] buffer, int length) {
  switch (type) {
    case GrenadeType_Smoke:
      Format(buffer, length, "smoke");
    case GrenadeType_Flash:
      Format(buffer, length, "flash");
    case GrenadeType_HE:
      Format(buffer, length, "he");
    case GrenadeType_Molotov:
      Format(buffer, length, "molotov");
    case GrenadeType_Decoy:
      Format(buffer, length, "decoy");
    case GrenadeType_Incendiary:
      Format(buffer, length, "incendiary");
    default:
      LogError("Unknown grenade type: %d", type);
  }
}

public SharedPlugin __pl_csutils = {
    name = "csutils", file = "csutils.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_csutils_SetNTVOptional() {
  MarkNativeAsOptional("CSU_ThrowGrenade");
}
#endif
