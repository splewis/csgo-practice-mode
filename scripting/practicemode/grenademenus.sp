stock void GivePracticeMenu(int client, int style=ITEMDRAW_DEFAULT, int pos=-1) {
    Menu menu = new Menu(PracticeMenuHandler);
    SetMenuTitle(menu, "Practice Settings");
    SetMenuExitButton(menu, true);

    if (!g_InPracticeMode) {
        AddMenuItem(menu, "launch_practice", "Start practice mode");
        style = ITEMDRAW_DISABLED;
    } else {
        AddMenuItem(menu, "end_menu", "Exit practice mode", style);
    }


    for (int i = 0; i < g_BinaryOptionNames.Length; i++) {
        if (!g_BinaryOptionChangeable.Get(i))
            continue;

        char name[OPTION_NAME_LENGTH];
        g_BinaryOptionNames.GetString(i, name, sizeof(name));

        char enabled[32];
        GetEnabledString(enabled, sizeof(enabled), g_BinaryOptionEnabled.Get(i), client);

        char buffer[128];
        Format(buffer, sizeof(buffer), "%s: %s", name, enabled);
        AddMenuItem(menu, name, buffer, style);
    }

    if (pos == -1)
        DisplayMenu(menu, client, MENU_TIME_FOREVER);
    else
        DisplayMenuAtItem(menu, client, pos, MENU_TIME_FOREVER);
}

public int PracticeMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char buffer[OPTION_NAME_LENGTH];
        int pos = GetMenuSelectionPosition();
        menu.GetItem(param2, buffer, sizeof(buffer));

        for (int i = 0; i < g_BinaryOptionNames.Length; i++) {
            char name[OPTION_NAME_LENGTH];
            g_BinaryOptionNames.GetString(i, name, sizeof(name));
            if (StrEqual(name, buffer)) {
                bool setting = !g_BinaryOptionEnabled.Get(i);
                g_BinaryOptionEnabled.Set(i, setting);
                ChangeSetting(i, setting);
                GivePracticeMenu(client, ITEMDRAW_DEFAULT, pos);
                return 0;
            }
        }

        if (StrEqual(buffer, "launch_practice")) {
            LaunchPracticeMode();
            GivePracticeMenu(client);
        } if (StrEqual(buffer, "end_menu")) {
            ExitPracticeMode();
            if (g_PugsetupLoaded)
                PugSetup_GiveSetupMenu(client);
        }

    } else if (action == MenuAction_End) {
        delete menu;
    }

    return 0;
}

public void GiveGrenadesMenu(int client) {
    int count = 0;
    Menu menu = new Menu(GrenadeHandler_PlayerSelection);
    menu.SetTitle("Select a player:");
    menu.ExitButton = true;

    if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
        do {
            int nadeCount = 0;
            if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
                do {
                    nadeCount++;
                } while (g_GrenadeLocationsKv.GotoNextKey());
                g_GrenadeLocationsKv.GoBack();
            }

            char auth[AUTH_LENGTH];
            char name[MAX_NAME_LENGTH];
            g_GrenadeLocationsKv.GetSectionName(auth, sizeof(auth));
            g_GrenadeLocationsKv.GetString("name", name, sizeof(name));

            char info[256];
            Format(info, sizeof(info), "%s %s", auth, name);

            char display[256];
            Format(display, sizeof(display), "%s (%d saved)", name, nadeCount);

            if (nadeCount > 0) {
                menu.AddItem(info, display);
                count++;
            }

        } while (g_GrenadeLocationsKv.GotoNextKey());
    }
    g_GrenadeLocationsKv.Rewind();

    if (count == 0) {
        PM_Message(client, "No players have grenade positions saved.");
        delete menu;
    } else {
        menu.Display(client, MENU_TIME_FOREVER);
    }
}

public int GrenadeHandler_PlayerSelection(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select && g_InPracticeMode) {
        int client = param1;
        char buffer[MAX_NAME_LENGTH+AUTH_LENGTH+1];
        menu.GetItem(param2, buffer, sizeof(buffer));

        // split buffer from "auth name" (seperated by whitespace)
        char ownerAuth[AUTH_LENGTH];
        char ownerName[MAX_NAME_LENGTH];
        SplitOnSpace(buffer, ownerAuth, sizeof(ownerAuth), ownerName, sizeof(ownerName));
        GiveGrenadesForPlayer(client, ownerName, ownerAuth);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

stock void GiveGrenadesForPlayer(int client, const char[] ownerName, const char[] ownerAuth, int menuPosition=0) {
    float origin[3];
    float angles[3];
    char description[GRENADE_DESCRIPTION_LENGTH];
    char name[GRENADE_NAME_LENGTH];

    int userCount = 0;
    Menu menu = new Menu(GrenadeHandler_GrenadeSelection);
    menu.SetTitle("Grenades for %s", ownerName);
    menu.ExitButton = true;
    menu.ExitBackButton = true;

    if (g_GrenadeLocationsKv.JumpToKey(ownerAuth)) {
        if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
            do {
                char strId[32];
                g_GrenadeLocationsKv.GetSectionName(strId, sizeof(strId));
                g_GrenadeLocationsKv.GetVector("origin", origin);
                g_GrenadeLocationsKv.GetVector("angles", angles);
                g_GrenadeLocationsKv.GetString("description", description, sizeof(description));
                g_GrenadeLocationsKv.GetString("name", name, sizeof(name));

                char info[128];
                Format(info, sizeof(info), "%s %s", ownerAuth, strId);
                char display[128];
                Format(display, sizeof(display), "%s (id %s)", name, strId);

                menu.AddItem(info, display);
                userCount++;
            } while (g_GrenadeLocationsKv.GotoNextKey());
            g_GrenadeLocationsKv.GoBack();
        }
        g_GrenadeLocationsKv.GoBack();
    }

    if (userCount == 0) {
        PM_Message(client, "No grenades found.");
        delete menu;
    } else {
        menu.DisplayAt(client, menuPosition, MENU_TIME_FOREVER);
    }
}

public int GrenadeHandler_GrenadeSelection(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select && g_InPracticeMode) {
        int client = param1;
        char buffer[128];
        menu.GetItem(param2, buffer, sizeof(buffer));
        char auth[AUTH_LENGTH];
        char idStr[GRENADE_ID_LENGTH];
        // split buffer from form "<auth> <id>" (seperated by a space)
        SplitOnSpace(buffer, auth, sizeof(auth), idStr, sizeof(idStr));
        TeleportToSavedGrenadePosition(client, auth, idStr);

    } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        int client = param1;
        GiveGrenadesMenu(client);

    } else if (action == MenuAction_End) {
        delete menu;
    }
}
