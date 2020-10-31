#define GRENADE_ACCURACY_MESSAGE_GOOD "{GREEN}perfectly landed{NORMAL}"
#define GRENADE_ACCURACY_MESSAGE_CLOSE "{LIGHT_GREEN}closely landed{NORMAL}"
#define GRENADE_ACCURACY_MESSAGE_FAR "{LIGHT_RED}missed{NORMAL}"
#define GRENADE_ACCURACY_MESSAGE_MISSING_DATA "{LIGHT_RED}Warning:{NORMAL} detonation data missing for grenade %i. Try running the console command \"sm_fixdetonations\"."
#define GRENADE_ACCURACY_SCORING_DETONATION 10.0, 50.0, 400.0
#define GRENADE_ACCURACY_SCORING_ANGLES 5.0, 30.0, 200.0
#define GRENADE_ACCURACY_SCORING_ORIGIN 0.3, 3.0, 100.0

enum GrenadeAccuracyIteratorProp {
  GrenadeAccuracyIteratorProp_Detonation, 
  GrenadeAccuracyIteratorProp_Origin
}

enum GrenadeAccuracyScore {
  GrenadeAccuracyScore_GOOD,
  GrenadeAccuracyScore_CLOSE,
  GrenadeAccuracyScore_FAR,
  GrenadeAccuracyScore_IGNORE
}

StringMap g_GrenadeAccuracyQueue;
int g_GrenadeAccuracyIntent[MAXPLAYERS];
int g_GrenadeAccuracyAllowReport[MAXPLAYERS];

public void GrenadeAccuracy_PluginStart() {
  g_GrenadeAccuracyQueue = new StringMap();
}

public void GrenadeAccuracy_MapStart() {
  g_GrenadeAccuracyQueue.Clear();
  for (int i = 1; i <= MaxClients; i++) {
    g_GrenadeAccuracyIntent[i] = -1;
    g_GrenadeAccuracyAllowReport[i] = true;
  }
}

public void GrenadeAccuracy_OnThrowGrenade(const int client, const int entity) {
  // We want the player coordinates, not the grenade coordinates, so we should get those ourselves.
  // Improbably possibility for a race condition here, if the grenade event is slow to fire somehow. 
  int i = g_GrenadeHistoryIndex[client] - 1;
  float angles[3]; 
  g_GrenadeHistoryAngles[client].GetArray(i, angles, sizeof(angles));
  float origin[3];
  g_GrenadeHistoryPositions[client].GetArray(i, origin, sizeof(origin));

  DataPack p = new DataPack();
  p.WriteFloat(origin[0]);
  p.WriteFloat(origin[1]);
  p.WriteFloat(origin[2]);
  p.WriteFloat(angles[0]);
  p.WriteFloat(angles[1]);
  p.WriteFloat(angles[2]);
  char key[32];
  IntToString(entity, key, sizeof(key));
  // replacing shouldn't be possible -- 1 nade throw = 1 entity -- so let's allow exceptions.
  g_GrenadeAccuracyQueue.SetValue(key, p, /*replace*/ false); 
}

public void GrenadeAccuracy_OnGrenadeExplode(
  const int client, 
  const int entity, 
  GrenadeType type,
  const float detonation[3]
) {
  if (!g_GrenadeAccuracyAllowReport[client]) {
    return;
  }

  Handle p;
  char key[32];
  IntToString(entity, key, sizeof(key));
  if (!g_GrenadeAccuracyQueue.GetValue(key, p)) {
    return;
  }

  ResetPack(p);
  float origin[3];
  origin[0] = ReadPackFloat(p);
  origin[1] = ReadPackFloat(p);
  origin[2] = ReadPackFloat(p);
  float angles[3];
  angles[0] = ReadPackFloat(p);
  angles[1] = ReadPackFloat(p);
  angles[2] = ReadPackFloat(p);
  CloseHandle(p);
  g_GrenadeAccuracyQueue.Remove(key);

  int grenadeID_nearOrigin = g_GrenadeAccuracyIntent[client] != -1 
    ? g_GrenadeAccuracyIntent[client]
    : GrenadeAccuracyFindNearestIdToVectorProp(
      origin, 
      type,
      GrenadeAccuracyIteratorProp_Origin
    );
  int grenadeID_nearDetonation = g_GrenadeAccuracyIntent[client] != -1 
    ? g_GrenadeAccuracyIntent[client]
    : GrenadeAccuracyFindNearestIdToVectorProp(
      detonation, 
      type, 
      GrenadeAccuracyIteratorProp_Detonation
    );

  float detonation_nearOrigin[3];
  float origin_nearOrigin[3];
  float angles_nearOrigin[3];
  char name_nearOrigin[GRENADE_NAME_LENGTH];
  GrenadeAccuracyScore scoreDetonation_nearOrigin;
  GrenadeAccuracyScore scoreOrigin_nearOrigin;
  GrenadeAccuracyScore scoreAngles_nearOrigin;
  if (grenadeID_nearOrigin != -1) {
    GetClientGrenadeVector(grenadeID_nearOrigin, "grenadeDetonationOrigin", detonation_nearOrigin);
    GetClientGrenadeVector(grenadeID_nearOrigin, "origin", origin_nearOrigin);
    GetClientGrenadeVector(grenadeID_nearOrigin, "angles", angles_nearOrigin);
    GetClientGrenadeData(grenadeID_nearOrigin, "name", name_nearOrigin, sizeof(name_nearOrigin));
    scoreDetonation_nearOrigin = GetGrenadeAccuracyScore(detonation, detonation_nearOrigin, GRENADE_ACCURACY_SCORING_DETONATION);
    scoreOrigin_nearOrigin = GetGrenadeAccuracyScore(origin, origin_nearOrigin, GRENADE_ACCURACY_SCORING_ANGLES);
    scoreAngles_nearOrigin = GetGrenadeAccuracyScore(angles, angles_nearOrigin, GRENADE_ACCURACY_SCORING_ORIGIN);
    GrenadeAccuracyPrintWarningIfMissing(client, detonation_nearOrigin, grenadeID_nearOrigin);
  }

  float detonation_nearDetonation[3];
  float origin_nearDetonation[3];
  float angles_nearDetonation[3];
  char name_nearDetonation[GRENADE_NAME_LENGTH];
  GrenadeAccuracyScore scoreDetonation_nearDetonation;
  GrenadeAccuracyScore scoreOrigin_nearDetonation;
  GrenadeAccuracyScore scoreAngles_nearDetonation;
  if (grenadeID_nearDetonation != -1) {
    GetClientGrenadeVector(grenadeID_nearDetonation, "grenadeDetonationOrigin", detonation_nearDetonation);
    GetClientGrenadeVector(grenadeID_nearDetonation, "origin", origin_nearDetonation);
    GetClientGrenadeVector(grenadeID_nearDetonation, "angles", angles_nearDetonation);
    GetClientGrenadeData(grenadeID_nearDetonation, "name", name_nearDetonation, sizeof(name_nearDetonation));
    scoreDetonation_nearDetonation = GetGrenadeAccuracyScore(detonation, detonation_nearDetonation, GRENADE_ACCURACY_SCORING_DETONATION);
    scoreOrigin_nearDetonation = GetGrenadeAccuracyScore(origin, origin_nearDetonation, GRENADE_ACCURACY_SCORING_ANGLES);
    scoreAngles_nearDetonation = GetGrenadeAccuracyScore(angles, angles_nearDetonation, GRENADE_ACCURACY_SCORING_ORIGIN);
    GrenadeAccuracyPrintWarningIfMissing(client, detonation_nearDetonation, grenadeID_nearDetonation);
  }

  // TODO for potential scoring improvement: especially penalize deltas in z-axis.
  if (
    grenadeID_nearDetonation != -1
    && scoreDetonation_nearOrigin > GrenadeAccuracyScore_CLOSE 
    && GrenadeAccuracyGetCloserVector(detonation, detonation_nearDetonation, detonation_nearOrigin) == -1
    && grenadeID_nearDetonation != grenadeID_nearOrigin
  ) {
    // The player exploded for a nade that they weren't standing closest to.
    // Let's infer that the user is trying to throw that other nade from a different position.
    GrenadeAccuracyPrint(
      client, 
      grenadeID_nearDetonation, 
      name_nearDetonation,
      scoreDetonation_nearDetonation,
      scoreOrigin_nearDetonation,
      scoreAngles_nearDetonation,
      grenadeID_nearOrigin, 
      name_nearOrigin,
      scoreDetonation_nearOrigin,
      scoreOrigin_nearOrigin
    );
  } else if (grenadeID_nearOrigin != -1) {
    GrenadeAccuracyPrint(
      client, 
      grenadeID_nearOrigin, 
      name_nearOrigin,
      scoreDetonation_nearOrigin,
      scoreOrigin_nearOrigin,
      scoreAngles_nearOrigin,
      grenadeID_nearDetonation, 
      name_nearDetonation,
      scoreDetonation_nearDetonation,
      scoreOrigin_nearDetonation
    );
  }
}

// -1 is a arg, 1 is b arg, 0 is equal
public int GrenadeAccuracyGetCloserVector(const float test[3], const float a[3], const float b[3]) {
  float distA = GetVectorDistance(test, a);
  float distB = GetVectorDistance(test, b);
  if (distA == distB) {
    return 0;
  }
  return distA < distB ? -1 : 1;
}

public GrenadeAccuracyScore GetGrenadeAccuracyScore(const float a[3], const float b[3], float good, float close, float far) {
  float distance = GetVectorDistance(a, b);
  if (distance < good) {
    return GrenadeAccuracyScore_GOOD;
  }
  if (distance < close) {
    return GrenadeAccuracyScore_CLOSE;
  }
  if (distance < far) {
    return GrenadeAccuracyScore_FAR;
  }
  return GrenadeAccuracyScore_IGNORE;
}

public void GrenadeAccuracyPrint(
  const int client, 
  const int grenadeID, 
  const char[] grenadeName, 
  const GrenadeAccuracyScore detonation, 
  const GrenadeAccuracyScore origin, 
  const GrenadeAccuracyScore angles,
  const int altGrenadeID, 
  const char[] altGrenadeName, 
  const GrenadeAccuracyScore altDetonation, 
  const GrenadeAccuracyScore altOrigin
) {
  if (detonation == GrenadeAccuracyScore_IGNORE && altDetonation >= GrenadeAccuracyScore_FAR) {
    // Not significant enough to message the user.
    return;
  }
  if (detonation == GrenadeAccuracyScore_GOOD) {
    if (origin <= GrenadeAccuracyScore_CLOSE) { // should this be stricter?
      PM_Message(
        client, 
        "You " ... GRENADE_ACCURACY_MESSAGE_GOOD ... " grenade %i, \"%s\".", 
        grenadeID, 
        grenadeName
      );
    } else {
      PM_Message(
        client, 
        "You " ... GRENADE_ACCURACY_MESSAGE_GOOD ... " grenade %i, \"%s\", from a \x07different position\x01.", 
        grenadeID, 
        grenadeName
      );
    }
  } else {
    char prefix[256];
    if (detonation == GrenadeAccuracyScore_CLOSE) {
      Format(
        prefix, 
        sizeof(prefix),
        "You " ... GRENADE_ACCURACY_MESSAGE_CLOSE ... " grenade %i, \"%s\".", 
        grenadeID, 
        grenadeName
      );
    } else {
      Format(
        prefix, 
        sizeof(prefix),
        "You " ... GRENADE_ACCURACY_MESSAGE_FAR ... " grenade %i, \"%s\".", 
        grenadeID, 
        grenadeName
      );
    }
    if (origin == GrenadeAccuracyScore_GOOD) {
      if (angles == GrenadeAccuracyScore_GOOD) {
        PM_Message(
          client, 
          "%s Your lineup was nearly perfect. This grenade might be inconsistent.",
          prefix
        );
      } else {
        PM_Message(
          client, 
          "%s Try aiming closer to the center of the target.",
          prefix
        );
      }
    } else {
      if (origin == GrenadeAccuracyScore_CLOSE) {
        PM_Message(
          client, 
          "%s You were slightly away from the intended position. Try moving closer to the lineup, or say \".goto %i\" to teleport.",
          prefix,
          grenadeID
        );
      } else {
        // This message might be unnecessary noise; the player could be trying to find a new lineup.
        PM_Message(
          client, 
          "%s You were \x07not near the intended position\x01. Say \".goto %i\" to teleport.",
          prefix,
          grenadeID
        );
      }
    }
  }
  // Also mention the alt nade if it was landed.
  if (altGrenadeID != grenadeID && altDetonation <= GrenadeAccuracyScore_CLOSE) {
    if (altDetonation == GrenadeAccuracyScore_GOOD) {
    PM_Message(
        client, 
        altOrigin <= GrenadeAccuracyScore_CLOSE 
          ? "You also " ... GRENADE_ACCURACY_MESSAGE_GOOD ... " grenade %i, \"%s\"."
          : "You also " ... GRENADE_ACCURACY_MESSAGE_GOOD ... " grenade %i, \"%s\", from a \x07different position\x01.", 
        altGrenadeID, 
        altGrenadeName
      );
    } else if (altDetonation == GrenadeAccuracyScore_CLOSE) {
      PM_Message(
        client, 
        altOrigin <= GrenadeAccuracyScore_CLOSE 
          ? "You also " ... GRENADE_ACCURACY_MESSAGE_CLOSE ... " grenade %i, \"%s\"."
          : "You also " ... GRENADE_ACCURACY_MESSAGE_CLOSE ... " grenade %i, \"%s\", from a \x07different position\x01.", 
        altGrenadeID, 
        altGrenadeName
      );
    }
  }
}

public void GrenadeAccuracyPrintWarningIfMissing(const int client, const float vec[3], const int grenadeID) {
  if (vec[0] == 0.0 && vec[1] == 0.0  && vec[2] == 0.0 ) {
    PM_Message(client, GRENADE_ACCURACY_MESSAGE_MISSING_DATA, grenadeID);
  }

}

// return id of -1 means that no grenade was found for the given type.
public int GrenadeAccuracyFindNearestIdToVectorProp(const float vec[3], GrenadeType type, GrenadeAccuracyIteratorProp prop) {
  ArrayList nades = new ArrayList();

  // Hack: reuse the array to push additional arguments to the iterator.
  nades.Push(vec[0]);
  nades.Push(vec[1]);
  nades.Push(vec[2]);
  nades.Push(type);
  nades.Push(prop);

  IterateGrenades(_FindNearestGrenadeToVector_Iterator, nades);

  // Hack: remove the arguments so we can safely sort.
  nades.Erase(0);
  nades.Erase(0);
  nades.Erase(0);
  nades.Erase(0);
  nades.Erase(0);

  int result = -1;
  if (nades.Length > 0) {
    SortADTArrayCustom(nades, _FindNearestGrenadeToVector_Sort);
    Handle pResult = nades.Get(0);
    ResetPack(pResult);
    ReadPackFloat(pResult); // skip distance.
    char idStr[GRENADE_ID_LENGTH];
    ReadPackString(pResult, idStr, sizeof(idStr));
    
    result = StringToInt(idStr, 10);
    
    for (int i = 0; i < nades.Length; i++) {
      CloseHandle(nades.Get(i));
    }
  }
  nades.Clear();
  CloseHandle(nades);
  return result;
}

public Action _FindNearestGrenadeToVector_Iterator(
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
  ArrayList nades
) {
  // Hack: first, pull out the expected, hardcoded additional arguments from the arraylist.
  int argc = 0;
  float vec[3];
  vec[0] = nades.Get(argc++);
  vec[1] = nades.Get(argc++);
  vec[2] = nades.Get(argc++);
  GrenadeType expectedType = nades.Get(argc++);
  GrenadeAccuracyIteratorProp prop = nades.Get(argc++);
  
  if (expectedType == GrenadeTypeFromString(grenadeType)) {
    float dist = prop == GrenadeAccuracyIteratorProp_Origin 
      ? GetVectorDistance(grenadeOrigin, vec) 
      : GetVectorDistance(grenadeDetonationOrigin, vec);
    
    DataPack p = new DataPack();
    p.WriteFloat(dist);
    p.WriteString(grenadeId);
    p.WriteFloat(grenadeDetonationOrigin[0]);
    p.WriteFloat(grenadeDetonationOrigin[1]);
    p.WriteFloat(grenadeDetonationOrigin[2]);
    ResetPack(p);
    PushArrayCell(nades, p);
  }
}

public int _FindNearestGrenadeToVector_Sort(int a, int b, Handle arr, Handle hndl) {
  Handle pA = GetArrayCell(arr, a);
  Handle pB = GetArrayCell(arr, b);
  ResetPack(pA);
  float distA = ReadPackFloat(pA);
  ResetPack(pB);
  float distB = ReadPackFloat(pB);
  // We want the smallest distance at the top.
  if (distA <= distB) {
    return -1;
  } 
  return 1;
}

public void GrenadeAccuracySetIntent(const int client, const int grenadeID) {
  g_GrenadeAccuracyIntent[client] = grenadeID;
}

public void GrenadeAccuracyClearIntent(const int client) {
  GrenadeAccuracySetIntent(client, -1);
}

public void GrenadeAccuracyAllowReport(const int client) {
  g_GrenadeAccuracyAllowReport[client] = true;
}

public void GrenadeAccuracyDenyReport(const int client) {
  g_GrenadeAccuracyAllowReport[client] = false;
}