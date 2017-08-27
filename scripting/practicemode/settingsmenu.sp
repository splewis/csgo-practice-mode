public Action Command_Settings(int client, int args) {
  GiveSettingsMenu(client);
  return Plugin_Handled;
}

public void GiveSettingsMenu(int client) {
  Menu menu = new Menu(SettingsMenuHandler);
  menu.SetTitle("User settings:");

  bool showingAirtime = GetCookieBool(client, g_ShowGrenadeAirtimeCookie, SHOW_AIRTIME_DEFAULT);
  bool leaveNadeMenuOpen =
      GetCookieBool(client, g_LeaveNadeMenuOpenCookie, LEAVE_NADE_MENU_OPEN_SELECT_DEFAULT);

  float flashThreshold =
      GetCookieFloat(client, g_FlashEffectiveThresholdCookie, FLASH_EFFECTIVE_THRESHOLD_DEFAULT);
  float flashTeleportDelay =
      GetCookieFloat(client, g_TestFlashTeleportDelayCookie, TEST_FLASH_TELEPORT_DELAY_DEFAULT);

  char buffer[128];
  Format(buffer, sizeof(buffer), "Show grenade airtime: %s",
         showingAirtime ? "enabled" : "disabled");
  menu.AddItem("airtime", buffer);

  Format(buffer, sizeof(buffer), "Leave .nade menu open after selection: %s",
         leaveNadeMenuOpen ? "enabled" : "disabled");
  menu.AddItem("leave_menu_open", buffer);

  Format(buffer, sizeof(buffer), "Flash blind threshold: %.1f sec", flashThreshold);
  menu.AddItem("flash_blind_threshold", buffer);

  Format(buffer, sizeof(buffer), "Flash teleport delay: %.1f sec", flashTeleportDelay);
  menu.AddItem("flash_teleport_delay", buffer);

  menu.Display(client, MENU_TIME_FOREVER);
}

public int SettingsMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select && g_InPracticeMode) {
    int client = param1;
    char buffer[128];
    menu.GetItem(param2, buffer, sizeof(buffer));
    if (StrEqual(buffer, "airtime")) {
      SetCookieBool(client, g_ShowGrenadeAirtimeCookie,
                    !GetCookieBool(client, g_ShowGrenadeAirtimeCookie, SHOW_AIRTIME_DEFAULT));

    } else if (StrEqual(buffer, "leave_menu_open")) {
      SetCookieBool(
          client, g_LeaveNadeMenuOpenCookie,
          !GetCookieBool(client, g_LeaveNadeMenuOpenCookie, LEAVE_NADE_MENU_OPEN_SELECT_DEFAULT));

    } else if (StrEqual(buffer, "flash_blind_threshold")) {
      PM_Message(client, "Open console and use this command to set the value (replacing 2.0 with the value you want:");
      PM_Message(client, "sm_cookies practicemode_flash_threshold 2.0");

    } else if (StrEqual(buffer, "practicemode_testflash_delay")) {
      PM_Message(client, "Open console and use this command to set the value (replacing 0.3 with the value you want:");
      PM_Message(client, "sm_cookies practicemode_flash_threshold 0.3");

    } else {
      LogError("SettingsMenuHandler uknown option: %s", buffer);
    }

    GiveSettingsMenu(client);

  } else if (action == MenuAction_End) {
    delete menu;
  }
}
