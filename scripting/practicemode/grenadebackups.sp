public void BackupGrenadeData(KeyValues kv) {
  char map[PLATFORM_MAX_PATH + 1];
  GetCleanMapName(map, sizeof(map));

  // Delete backups/de_dust2.30.cfg
  // Backup backups/de_dust.29.cfg -> backups/de_dust.30.cfg
  // Backup backups/de_dust.28.cfg -> backups/de_dust.29.cfg
  // ...
  // Backup backups/de_dust.1.cfg -> backups/de_dust.2.cfg
  // Backup de_dust.cfg -> backups/de_dust.1.cfg
  for (int version = kMaxBackupsPerMap; version >= 1; version--) {
    char olderPath[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, olderPath, sizeof(olderPath), "data/practicemode/grenades/backups/%s.%d.cfg",
              map, version);

    char newerPath[PLATFORM_MAX_PATH + 1];
    if (version == 1) {
      BuildPath(Path_SM, newerPath, sizeof(newerPath), "data/practicemode/grenades/%s.cfg", map);

    } else {
      BuildPath(Path_SM, newerPath, sizeof(newerPath),
                "data/practicemode/grenades/backups/%s.%d.cfg", map, version - 1);
    }

    if (version == kMaxBackupsPerMap && FileExists(olderPath)) {
      if (!DeleteFile(olderPath)) {
        LogError("Failed to delete old grenade file %s", olderPath);
      }
    }

    if (FileExists(newerPath)) {
      if (!RenameFile(olderPath, newerPath)) {
        LogError("Failed to rename %s to %s", newerPath, olderPath);
      }
    }
  }
}
