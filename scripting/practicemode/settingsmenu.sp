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
  bool noGrenadeTrajectory =
      GetCookieBool(client, g_NoGrenadeTrajectoryCookie, NO_GRENADE_TRAJECTORY_DEFAULT);
  bool useNadeOnSelect = GetCookieBool(client, g_UseGrenadeOnNadeMenuSelectCookie,
                                       USE_GRENADE_ON_NADE_MENU_SELECT_DEFAULT);

  char buffer[128];
  Format(buffer, sizeof(buffer), "Show grenade airtime: %s",
         showingAirtime ? "enabled" : "disabled");
  menu.AddItem("airtime", buffer);

  Format(buffer, sizeof(buffer), "Leave .nade menu open after selection: %s",
         leaveNadeMenuOpen ? "enabled" : "disabled");
  menu.AddItem("leave_menu_open", buffer);

  Format(buffer, sizeof(buffer), "Disable grenade trajectories: %s",
         noGrenadeTrajectory ? "enabled" : "disabled");
  menu.AddItem("grenade_trajectory", buffer);

  Format(buffer, sizeof(buffer), "Switch to nade on .nades select: %s",
         useNadeOnSelect ? "enabled" : "disabled");
  menu.AddItem("use_on_nade_select", buffer);

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

    } else if (StrEqual(buffer, "grenade_trajectory")) {
      SetCookieBool(
          client, g_NoGrenadeTrajectoryCookie,
          !GetCookieBool(client, g_NoGrenadeTrajectoryCookie, NO_GRENADE_TRAJECTORY_DEFAULT));
    } else if (StrEqual(buffer, "use_on_nade_select")) {
      SetCookieBool(client, g_UseGrenadeOnNadeMenuSelectCookie,
                    !GetCookieBool(client, g_UseGrenadeOnNadeMenuSelectCookie,
                                   USE_GRENADE_ON_NADE_MENU_SELECT_DEFAULT));
    } else {
      LogError("SettingsMenuHandler uknown option: %s", buffer);
    }

    GiveSettingsMenu(client);

  } else if (action == MenuAction_End) {
    delete menu;
  }
}
