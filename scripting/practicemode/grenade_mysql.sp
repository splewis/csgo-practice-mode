public void GetDatabaseConnection() {
  if (!g_UseDatabaseCvar.BoolValue) {
    return;
  }

  char error[255];
  Database db = SQL_DefConnect(error, sizeof(error));
   
  if (db == null)
  {
    LogError("Could not connect to 'default' database (sourcemod/config/database.cfg): %s", error);
  } 
  else 
  {
    PrintToServer("Connected to external database...");
    g_Database = db;
  }
}

public void CloseDatabaseConnection() {
  if (!g_UseDatabaseCvar.BoolValue || g_Database == null) {
    return;
  }

  PrintToServer("Closed connection to external database...");

  g_Database = null;

}

public void ExportGrenadesToDatabase(const char[] tableName) {
  if (!g_InPracticeMode || !g_UseDatabaseCvar.BoolValue ) {
    return;
  }

  if (g_Database == null) {
    GetDatabaseConnection();
  }
  
  char steamId[255];
  char steamName[255];
  char grenadeId[12];
  char name[255];
  char origin[255];
  char angles[255];
  char grenadeType[255];
  char grenadeOrigin[255];
  char grenadeVelocity[255];
  char description[255];
  char categories[GRENADE_CATEGORY_LENGTH];

  char query[1000];
  int buffer_len = strlen(tableName) * 2 + 1;
  char[] new_map = new char[buffer_len];

  SQL_EscapeString(g_Database, tableName, new_map, buffer_len);

  Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%s` ("
    ... "`id` int(4) NOT NULL AUTO_INCREMENT,"
    ... "`steamId` varchar(128) DEFAULT NULL,"
    ... "`steamName` varchar(128) DEFAULT NULL,"
    ... "`grenadeId` int(4) NOT NULL,"
    ... "`name` varchar(128) DEFAULT NULL,"
    ... "`categories` varchar(128) DEFAULT NULL,"
    ... "`origin` varchar(128) DEFAULT NULL,"
    ... "`angles` varchar(128) DEFAULT NULL,"
    ... "`grenadeType` varchar(128) DEFAULT NULL,"
    ... "`grenadeOrigin` varchar(128) DEFAULT NULL,"
    ... "`grenadeVelocity` varchar(128) DEFAULT NULL,"
    ... "`description` varchar(256) DEFAULT NULL,"
    ... "`timestamp` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,"
    ... "PRIMARY KEY (`grenadeId`),"
    ... "KEY `id` (`id`))", tableName);

  if (!SQL_FastQuery(g_Database, query)) {
    char error[255];
    SQL_GetError(g_Database, error, sizeof(error));
    LogError("Failed to create table for %s (error: %s)", tableName, error);
  }

  //Begin massive looping
  g_GrenadeLocationsKv.Rewind();
  g_GrenadeLocationsKv.GotoFirstSubKey(false);

  int userCount = 0;
  do 
  {
    userCount += 1;
    g_GrenadeLocationsKv.GetSectionName(steamId, sizeof(steamId));
    g_GrenadeLocationsKv.GetString("name", steamName, sizeof(steamName));
    if (g_GrenadeLocationsKv.GotoFirstSubKey(false)) {
      g_GrenadeLocationsKv.GotoNextKey(false);
      int grenadeCount = 0;
      do
      {
        grenadeCount += 1;
        g_GrenadeLocationsKv.GetSectionName(grenadeId, sizeof(grenadeId));
        g_GrenadeLocationsKv.GetString("name", name, sizeof(name));
        g_GrenadeLocationsKv.GetString("categories", categories, sizeof(categories));
        g_GrenadeLocationsKv.GetString("origin", origin, sizeof(origin));
        g_GrenadeLocationsKv.GetString("angles", angles, sizeof(angles));
        g_GrenadeLocationsKv.GetString("grenadeType", grenadeType, sizeof(grenadeType));
        g_GrenadeLocationsKv.GetString("grenadeOrigin", grenadeOrigin, sizeof(grenadeOrigin));
        g_GrenadeLocationsKv.GetString("grenadeVelocity", grenadeVelocity, sizeof(grenadeVelocity));
        g_GrenadeLocationsKv.GetString("description", description, sizeof(description));
        //$$$ Big money function right here $$$
        UpsertGrenade(tableName, steamId, steamName, StringToInt(grenadeId), name, categories, origin, angles, grenadeType, grenadeOrigin, grenadeVelocity, description);
      } while (g_GrenadeLocationsKv.GotoNextKey(false));
      PrintToServer("%i grenades by %s (%s) were exported.", grenadeCount, steamName, steamId);
    }

    g_GrenadeLocationsKv.GoBack();
  } while (g_GrenadeLocationsKv.GotoNextKey(false));
  PrintToServer("%i users were iterated.", userCount);

  CloseDatabaseConnection();

}

//Upsert = atomically either insert a row, or on the basis of the row already existing, UPDATE that existing row instead
static void UpsertGrenade(const char[] tableName, const char[] steamId, const char[] steamName, int grenadeId, const char[] name, const char[] categories, const char[] origin, const char[] angles, 
  const char[] grenadeType, const char[] grenadeOrigin, const char[] grenadeVelocity, const char[] description ) {
  if (g_Database == null) {
    PrintToServer("No database connection open.");
    return;
  }

  static DBStatement exportQuery = null;
  char error[255];
  char query[5000];

  Format(query, sizeof(query), "INSERT INTO %s ("
    ... "steamId, steamName, grenadeId, name, categories, origin, angles, grenadeType, grenadeOrigin, grenadeVelocity, description"
    ... ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE steamId = ?, steamName = ?, grenadeId = ?, name = ?, categories = ?, origin = ?, angles = ?, grenadeType = ?, "
    ... "grenadeOrigin = ?, grenadeVelocity = ?, description = ?;", tableName);
  if (exportQuery == null) {
    exportQuery = SQL_PrepareQuery(g_Database, query, error, sizeof(error));
    if (exportQuery == null) {
      LogError("Failed to prepare export query (error: %s)", error);
    }
  }

  //22 params to bind starting at index 0
  //We prepare and bind everything because SQL injection isn't fun.
  SQL_BindParamString(exportQuery, 0, steamId, false);
  SQL_BindParamString(exportQuery, 1, steamName, false);
  SQL_BindParamInt(exportQuery, 2, grenadeId, false);
  SQL_BindParamString(exportQuery, 3, name, false);
  SQL_BindParamString(exportQuery, 4, categories, false);
  SQL_BindParamString(exportQuery, 5, origin, false);
  SQL_BindParamString(exportQuery, 6, angles, false);
  SQL_BindParamString(exportQuery, 7, grenadeType, false);
  SQL_BindParamString(exportQuery, 8, grenadeOrigin, false);
  SQL_BindParamString(exportQuery, 9, grenadeVelocity, false);
  SQL_BindParamString(exportQuery, 10, description, false);
  SQL_BindParamString(exportQuery, 11, steamId, false);
  SQL_BindParamString(exportQuery, 12, steamName, false);
  SQL_BindParamInt(exportQuery, 13, grenadeId, false);
  SQL_BindParamString(exportQuery, 14, name, false);
  SQL_BindParamString(exportQuery, 15, categories, false);
  SQL_BindParamString(exportQuery, 16, origin, false);
  SQL_BindParamString(exportQuery, 17, angles, false);
  SQL_BindParamString(exportQuery, 18, grenadeType, false);
  SQL_BindParamString(exportQuery, 19, grenadeOrigin, false);
  SQL_BindParamString(exportQuery, 20, grenadeVelocity, false);
  SQL_BindParamString(exportQuery, 21, description, false);

  if (!SQL_Execute(exportQuery))
  {
    SQL_GetError(g_Database, error, sizeof(error));
    LogError("Failed to execute export SQL (error: %s)", error);
  }

}

DBStatement selectUsersQuery = null;
public bool ImportGrenadesFromDatabase(const char[] tableName)
{

  if (!g_InPracticeMode || !g_UseDatabaseCvar.BoolValue ) {
    return false;
  }

  if (g_Database == null) {
    GetDatabaseConnection();
  }

  char query[255];
  Format(query, sizeof(query), "SELECT * FROM %s;", tableName);

  if (selectUsersQuery == null)
  {
    char error[255];
    if ((selectUsersQuery = SQL_PrepareQuery(g_Database, 
      query, 
      error, 
      sizeof(error))) 
         == null)
    {
      LogError("Failed to prepare export query (error: %s)", error);
      CloseDatabaseConnection();
      return false;
    }
  }
 

  if (!SQL_Execute(selectUsersQuery))
  {
    LogError("Failed to execute query.");
    CloseDatabaseConnection();
    return false;
  }
 
  char steamId[255];
  char steamName[255];
  char grenadeId[12];
  char name[255];
  char categories[GRENADE_CATEGORY_LENGTH];
  char origin[255];
  char angles[255];
  char grenadeType[255];
  char grenadeOrigin[255];
  char grenadeVelocity[255];
  char description[255];

  if (SQL_GetRowCount(selectUsersQuery) < 1) {
    PrintToServer("Nothing to import from table: %s...", tableName);
    return false;
  }

  PrintToServer("Retrieved %i grenades to import...", SQL_GetRowCount(selectUsersQuery));

  while (SQL_FetchRow(selectUsersQuery))
  {
    int dbId = SQL_FetchInt(selectUsersQuery, 0);
    SQL_FetchString(selectUsersQuery, 1, steamId, sizeof(name));
    SQL_FetchString(selectUsersQuery, 2, steamName, sizeof(steamName));
    SQL_FetchString(selectUsersQuery, 3, grenadeId, sizeof(grenadeId));
    SQL_FetchString(selectUsersQuery, 4, name, sizeof(name));
    SQL_FetchString(selectUsersQuery, 5, categories, sizeof(categories));
    SQL_FetchString(selectUsersQuery, 6, origin, sizeof(origin));
    SQL_FetchString(selectUsersQuery, 7, angles, sizeof(angles));
    SQL_FetchString(selectUsersQuery, 8, grenadeType, sizeof(grenadeType));
    SQL_FetchString(selectUsersQuery, 9, grenadeOrigin, sizeof(grenadeOrigin));
    SQL_FetchString(selectUsersQuery, 10, grenadeVelocity, sizeof(grenadeVelocity));
    SQL_FetchString(selectUsersQuery, 11, description, sizeof(description));
    SaveGrenadeFromDatabase(grenadeId, steamId, steamName, origin, angles, grenadeOrigin, grenadeVelocity, grenadeType, name, description, categories);
    PrintToServer("Imported dbId => %i, name => %s", dbId, name);
  }

  CloseDatabaseConnection();
  return true;
}


