/**
 * Pugsetup forwards.
 */
public Action OnSetupMenuOpen(int client, Menu menu, bool displayOnly) {
    if (!g_PugsetupLoaded)
        return Plugin_Continue;

    int leader = GetLeader(false);
    if (!IsPlayer(leader)) {
        SetLeader(client);
    }

    int style = ITEMDRAW_DEFAULT;
    if (!HasPermissions(client, Permission_Leader) || displayOnly) {
        style = ITEMDRAW_DISABLED;
    }

    if (g_InPracticeMode) {
        GivePracticeMenu(client, style);
        return Plugin_Stop;
    } else {
        AddMenuItem(menu, "launch_practice", "Launch practice mode", style);
        return Plugin_Continue;
    }
}

public void OnReadyToStart() {
    if (!g_PugsetupLoaded)
        return;

    if (g_InPracticeMode)
        ExitPracticeMode();
}

public void OnSetupMenuSelect(Menu menu, int client, const char[] selected_info, int selected_position) {
    if (!g_PugsetupLoaded)
        return;

    if (StrEqual(selected_info, "launch_practice")) {
        LaunchPracticeMode();
        GivePracticeMenu(client);
    }
}

public void OnHelpCommand(int client, ArrayList replyMessages, int maxMessageSize, bool& block) {
    if (!g_PugsetupLoaded)
        return;

    if (g_InPracticeMode) {
        block = true;
        PM_Message(client, "{LIGHT_GREEN}.setup {NORMAL}to change/view practicemode settings");
        if (g_AllowNoclip)
            PM_Message(client, "{LIGHT_GREEN}.noclip {NORMAL}to enter/exit noclip mode");
        PM_Message(client, "{LIGHT_GREEN}.back {NORMAL}to go to your last grenade position");
        PM_Message(client, "{LIGHT_GREEN}.forward {NORMAL}to go to your next grenade position");
        PM_Message(client, "{LIGHT_GREEN}.save <name> {NORMAL}to save a grenade position");
        PM_Message(client, "{LIGHT_GREEN}.nades [player] {NORMAL}to view all saved grenades");
        PM_Message(client, "{LIGHT_GREEN}.desc <description> {NORMAL}to add a nade description");
        PM_Message(client, "{LIGHT_GREEN}.delete {NORMAL}to delete your current grenade position");
        PM_Message(client, "{LIGHT_GREEN}.goto [player] <id> {NORMAL}to go to a grenadeid");
    }
}
