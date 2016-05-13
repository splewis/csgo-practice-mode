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

stock void GiveGrenadesMenu(int client, bool categoriesOnly=false) {
    Menu menu = new Menu(GrenadeMenu_Handler);
    menu.ExitButton = true;

    if (categoriesOnly)
        menu.SetTitle("Select a category:");
    else
        menu.SetTitle("Select a player/category:");

    if (!categoriesOnly && g_GrenadeLocationsKv.GotoFirstSubKey()) {
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
            }

        } while (g_GrenadeLocationsKv.GotoNextKey());
        g_GrenadeLocationsKv.GoBack();
    }

    for (int i = 0; i < g_KnownNadeCategories.Length; i++) {
        char cat[64];
        g_KnownNadeCategories.GetString(i, cat, sizeof(cat));
        int count = CountCategoryNades(cat);

        char info[256];
        Format(info, sizeof(info), "cat %s", cat);
        char display[256];
        Format(display, sizeof(display), "Category: %s (%d saved)", cat, count);

        if (count > 0)
            menu.AddItem(info, display);
    }

    if (menu.ItemCount == 0) {
        if (categoriesOnly)
            PM_Message(client, "No categories have been set yet.");
        else
            PM_Message(client, "No players have grenade positions saved.");
        delete menu;
    } else {
        menu.Display(client, MENU_TIME_FOREVER);
    }
}

public int GrenadeMenu_Handler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select && g_InPracticeMode) {
        int client = param1;
        char buffer[MAX_NAME_LENGTH+AUTH_LENGTH+1];
        menu.GetItem(param2, buffer, sizeof(buffer));

        // split buffer from "auth name" (seperated by whitespace)
        char arg1[AUTH_LENGTH]; // 'cat' or ownerAuth
        char arg2[MAX_NAME_LENGTH]; // categoryName or ownerName
        SplitOnSpace(buffer, arg1, sizeof(arg1), arg2, sizeof(arg2));

        if (StrEqual(arg1, "cat")) {
            GiveCategoryGrenades(client, arg2);
        } else {
            GiveGrenadesForPlayer(client, arg2, arg1);
        }
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

stock void GiveGrenadesForPlayer(int client, const char[] ownerName, const char[] ownerAuth, int menuPosition=0) {
    Menu menu = new Menu(GrenadeHandler_GrenadeSelection);
    menu.SetTitle("Grenades for %s", ownerName);
    menu.ExitButton = true;
    menu.ExitBackButton = true;

    if (g_GrenadeLocationsKv.JumpToKey(ownerAuth)) {
        if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
            do {
                AddKvGrenadeToMenu(menu, g_GrenadeLocationsKv, ownerAuth, ownerAuth);
            } while (g_GrenadeLocationsKv.GotoNextKey());
            g_GrenadeLocationsKv.GoBack();
        }
        g_GrenadeLocationsKv.GoBack();
    }

    if (menu.ItemCount == 0) {
        PM_Message(client, "No grenades found.");
        delete menu;
    } else {
        menu.DisplayAt(client, menuPosition, MENU_TIME_FOREVER);
    }
}

stock void GiveCategoryGrenades(int client, const char[] category, int menuPosition=0) {
    Menu menu = new Menu(GrenadeHandler_GrenadeSelection);
    menu.SetTitle("Category: %s", category);
    menu.ExitButton = true;
    menu.ExitBackButton = true;
    AddCategoryToMenu(menu, category);
    menu.DisplayAt(client, menuPosition, MENU_TIME_FOREVER);
}

public int GrenadeHandler_GrenadeSelection(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select && g_InPracticeMode) {
        int client = param1;
        HandleGrenadeSelected(client, menu, param2);
    } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        int client = param1;
        GiveGrenadesMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

stock void AddGrenadeToMenu(Menu menu, const char[] ownerAuth, const char[] ownerName,
    const char[] strId, const char[] name, bool showPlayerName=false) {
    char info[128];
    Format(info, sizeof(info), "%s %s", ownerAuth, strId);

    char display[128];
    if (showPlayerName) {
        Format(display, sizeof(display), "%s (%s-%s)", name, ownerName, strId);
    } else {
        Format(display, sizeof(display), "%s (id %s)", name, strId);
    }

    menu.AddItem(info, display);
}

public void AddKvGrenadeToMenu(Menu menu, KeyValues kv, const char[] ownerAuth, const char[] ownerName) {
    float origin[3];
    float angles[3];
    char description[GRENADE_DESCRIPTION_LENGTH];
    char name[GRENADE_NAME_LENGTH];
    char strId[32];

    kv.GetSectionName(strId, sizeof(strId));
    kv.GetVector("origin", origin);
    kv.GetVector("angles", angles);
    kv.GetString("description", description, sizeof(description));
    kv.GetString("name", name, sizeof(name));
    AddGrenadeToMenu(menu, ownerAuth, ownerName, strId, name);
}

public void HandleGrenadeSelected(int client, Menu menu, int param2) {
    char buffer[128];
    menu.GetItem(param2, buffer, sizeof(buffer));
    char auth[AUTH_LENGTH];
    char idStr[GRENADE_ID_LENGTH];
    // split buffer from form "<auth> <id>" (seperated by a space)
    SplitOnSpace(buffer, auth, sizeof(auth), idStr, sizeof(idStr));
    TeleportToSavedGrenadePosition(client, auth, idStr);
}

public void AddCategoryToMenu(Menu menu, const char[] category) {
    DataPack p = CreateDataPack();
    p.WriteCell(menu);
    p.WriteString(category);
    IterateGrenades(_AddCategoryToMenu_Helper, p);
    delete p;
}

public Action _AddCategoryToMenu_Helper(const char[] ownerName,
    const char[] ownerAuth, const char[] name,
    const char[] description, ArrayList categories,
    const char[] grenadeId,
    const float origin[3], const float angles[3],
    any data) {
    DataPack p = view_as<DataPack>(data);
    char cat[64];
    p.Reset();
    Menu menu = view_as<Menu>(p.ReadCell());
    p.ReadString(cat, sizeof(cat));

    if (FindStringInList(categories, GRENADE_CATEGORY_LENGTH, cat, false) >= 0) {
        AddGrenadeToMenu(menu, ownerAuth, ownerName, grenadeId, name, true);
    }
}

public int CountCategoryNades(const char[] category) {
    DataPack p = CreateDataPack();
    p.WriteCell(0);
    p.WriteString(category);
    IterateGrenades(_CountCategoryNades_Helper, p);
    p.Reset();
    int count = p.ReadCell();
    delete p;
    return count;
}

public Action _CountCategoryNades_Helper(const char[] ownerName,
    const char[] ownerAuth, const char[] name,
    const char[] description, ArrayList categories,
    const char[] grenadeId,
    const float origin[3], const float angles[3],
    any data) {
    DataPack p = view_as<DataPack>(data);
    ResetPack(p, false);
    int count = p.ReadCell();
    char cat[64];
    p.ReadString(cat, sizeof(cat));

    if (FindStringInList(categories, GRENADE_CATEGORY_LENGTH, cat, false) >= 0) {
        count++;
        ResetPack(p, true);
        p.WriteCell(count);
        p.WriteString(cat);
    }
}
