
/*
    (). FunModes V2:

    @file           RealityShift.sp
    @Usage          Functions for the RealityShift Mode.
*/

#pragma semicolon 1
#pragma newdecls required

ModeInfo g_RealityShiftInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_RealityShiftInfo

#define REALITYSHIFT_CONVAR_TIMER_INTERVAL 0
#define REALITYSHIFT_CONVAR_MODE 1
#define REALITYSHIFT_CONVAR_TOGGLE 2

Handle g_hRealityShiftTimer;

int g_iRealityShiftAssigned[MAXPLAYERS + 1];
bool g_bRealityShiftSwapped[MAXPLAYERS + 1];

float g_fRealityShift_TimerInterval;
int g_iRealityShift_Mode;
bool g_bRealityShift_Enabled;

stock void OnPluginStart_RealityShift()
{
    THIS_MODE_INFO.name = "RealityShift";
    THIS_MODE_INFO.tag = "{gold}[FunModes-RealityShift]{lightgreen}";

    RegAdminCmd("sm_fm_rs", Cmd_RealityShiftToggle, ADMFLAG_CONVARS, "Turn RealityShift Mode On/Off");
    RegAdminCmd("sm_realityshift_settings", Cmd_RealityShiftSettings, ADMFLAG_CONVARS, "Open RealityShift Sttings Menu");

    DECLARE_FM_CVAR(
        REALITYSHIFT_CONVAR_TIMER_INTERVAL, "sm_realityshift_timer_interval",
        "30.0", "After how many seconds to keep swapping positions",
        ("15.0,30.0,45.0,60.0"), CONVAR_FLOAT
    );
    THIS_MODE_INFO.cvars[REALITYSHIFT_CONVAR_TIMER_INTERVAL].HookChange(RealityShift_OnConVarChange);

    DECLARE_FM_CVAR(
        REALITYSHIFT_CONVAR_MODE, "sm_realityshift_mode",
        "0", "RealityShift Mode [0 = Random Swaps 1 = Assigned Swaps [At round start]]",
        ("0,1"), CONVAR_INT
    );
    THIS_MODE_INFO.cvars[REALITYSHIFT_CONVAR_MODE].HookChange(RealityShift_OnConVarChange);

    DECLARE_FM_CVAR(
        REALITYSHIFT_CONVAR_TOGGLE, "sm_realityshift_enable",
        "1", "Enable/Disable RealityShift Mode (This differs from turning it on/off)",
        ("0,1"), CONVAR_BOOL
    );
    THIS_MODE_INFO.cvars[REALITYSHIFT_CONVAR_TOGGLE].HookChange(RealityShift_OnConVarChange);

    THIS_MODE_INFO.enableIndex = REALITYSHIFT_CONVAR_TOGGLE;

    FUNMODES_REGISTER_MODE();
}

void InitCvarsValues_RealityShift()
{
    int modeIndex = THIS_MODE_INFO.index;

    g_fRealityShift_TimerInterval =
        _FUNMODES_CVAR_GET_VALUE(modeIndex, REALITYSHIFT_CONVAR_TIMER_INTERVAL, Float);

    g_iRealityShift_Mode =
        _FUNMODES_CVAR_GET_VALUE(modeIndex, REALITYSHIFT_CONVAR_MODE, Int);

    g_bRealityShift_Enabled =
        _FUNMODES_CVAR_GET_VALUE(modeIndex, REALITYSHIFT_CONVAR_TOGGLE, Bool);
}

void RealityShift_OnConVarChange(int modeIndex, int cvarIndex, const char[] oldValue, const char[] newValue)
{
    switch (cvarIndex)
    {
        case REALITYSHIFT_CONVAR_TIMER_INTERVAL:
        {
            g_fRealityShift_TimerInterval =
                _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Float);

            if (THIS_MODE_INFO.isOn)
                RealityShift_StartTimer(g_fRealityShift_TimerInterval);
        }

        case REALITYSHIFT_CONVAR_MODE:
        {
            g_iRealityShift_Mode =
                _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Int);

            if (THIS_MODE_INFO.isOn && g_iRealityShift_Mode == 1)
                RealityShift_AssignPlayers(true);
        }

        case REALITYSHIFT_CONVAR_TOGGLE:
        {
            bool val =
                _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Bool);

            if (THIS_MODE_INFO.isOn)
                CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, val, THIS_MODE_INFO.index);

            g_bRealityShift_Enabled = val;
        }
    }
}

stock void OnMapStart_RealityShift() {}

stock void OnMapEnd_RealityShift()
{
    CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
    g_hRealityShiftTimer = null;
}

stock void OnClientPutInServer_RealityShift(int client)
{
    g_iRealityShiftAssigned[client] = 0;
    g_bRealityShiftSwapped[client] = false;
}

stock void OnClientDisconnect_RealityShift(int client)
{
    g_iRealityShiftAssigned[client] = 0;
    g_bRealityShiftSwapped[client] = false;
}

stock void ZR_OnClientInfected_RealityShift(int client)
{
    #pragma unused client

    if (!THIS_MODE_INFO.isOn)
        return;

    if (!g_bMotherZombie && g_hRealityShiftTimer == null)
    {
        RealityShift_StartTimer(g_fRealityShift_TimerInterval);

        if (g_iRealityShift_Mode == 1)
            RealityShift_AssignPlayers(true);
    }
}

stock void Event_RoundStart_RealityShift() {}
stock void Event_RoundEnd_RealityShift() {}
stock void Event_PlayerSpawn_RealityShift(int client)
{
	#pragma unused client
}

stock void Event_PlayerTeam_RealityShift(Event event)
{
	#pragma unused event
}

stock void Event_PlayerDeath_RealityShift(int client)
{
	#pragma unused client
}

public Action Cmd_RealityShiftToggle(int client, int args)
{
    if (!g_bRealityShift_Enabled)
    {
        CReplyToCommand(client, "%s RealityShift Mode is currently Disabled", THIS_MODE_INFO.tag);
        return Plugin_Handled;
    }

    CHANGE_MODE_INFO(
        THIS_MODE_INFO,
        isOn,
        !THIS_MODE_INFO.isOn,
        THIS_MODE_INFO.index
    );

    CPrintToChatAll(
        "%s RealityShift Mode is now %s!",
        THIS_MODE_INFO.tag,
        THIS_MODE_INFO.isOn ? "On" : "Off"
    );

    if (THIS_MODE_INFO.isOn)
    {
        FunModes_HookEvent(
            g_bEvent_RoundStart,
            "round_start",
            Event_RoundStart
        );

        FunModes_HookEvent(
            g_bEvent_RoundEnd,
            "round_end",
            Event_RoundEnd
        );

        CPrintToChatAll(
            "%s Each human will be swapped with another one!",
            THIS_MODE_INFO.tag
        );

        if (g_iRealityShift_Mode == 0)
        {
            CPrintToChatAll(
                "%s The positions will be swapped randomly.",
                THIS_MODE_INFO.tag
            );
        }

        int interval = RoundToNearest(g_fRealityShift_TimerInterval);

        CPrintToChatAll(
            "%s Positions will be swapped every {olive}%d seconds!",
            THIS_MODE_INFO.tag,
            interval
        );

        FunModes_RestartRound();
    }
    else
    {
        delete g_hRealityShiftTimer;
    }

    return Plugin_Handled;
}

public Action Cmd_RealityShiftSettings(int client, int args)
{
    if (!client)
        return Plugin_Handled;

    Menu menu = new Menu(Menu_RealityShiftSettings);

    menu.SetTitle("%s - Settings", THIS_MODE_INFO.name);

    menu.AddItem(NULL_STRING, "Show Cvars\n");

    menu.ExitBackButton = true;

    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

int Menu_RealityShiftSettings(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_End:
            delete menu;

        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
                DisplayModeInfo(param1, g_iPreviousModeIndex[param1]);
        }

        case MenuAction_Select:
        {
            ShowCvarsInfo(param1, THIS_MODE_INFO);
        }
    }

    return 0;
}

void RealityShift_StartTimer(float interval)
{
    for (int i = 1; i <= MaxClients; i++)
        g_iRealityShiftAssigned[i] = 0;

    delete g_hRealityShiftTimer;

    g_hRealityShiftTimer =
        CreateTimer(
            interval,
            RealityShift_Timer,
            _,
            TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT
        );
}

Action RealityShift_Timer(Handle timer)
{
    if (g_bRoundEnd || !g_bMotherZombie)
    {
        g_hRealityShiftTimer = null;
        return Plugin_Stop;
    }

    RealityShift_AssignPlayers(_, g_iRealityShift_Mode == 0);

    return Plugin_Continue;
}

int GetRandomClientFromArray(int[] arr, int len, int &client)
{
    int count;

    int[] newArr = new int[len];

    for (int i = 0; i < len; i++)
    {
        if (arr[i] == 0)
            continue;

        if (g_bRealityShiftSwapped[arr[i]])
            continue;

        newArr[count++] = arr[i];
    }

    if (!count)
        return -1;

    int index = GetRandomInt(0, count - 1);

    client = newArr[index];

    return index;
}

void RealityShift_AssignPlayers(bool saveOnly = false, bool random = true)
{
    int clients[MAXPLAYERS + 1];

    int count;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i)
        || !IsPlayerAlive(i)
        || !ZR_IsClientHuman(i))
            continue;

        g_bRealityShiftSwapped[i] = false;

        clients[count++] = i;

        if (!random)
        {
            int assignedTo =
                GetClientOfUserId(g_iRealityShiftAssigned[i]);

            if (!assignedTo
            || !IsClientInGame(assignedTo)
            || !IsPlayerAlive(assignedTo)
            || !ZR_IsClientHuman(assignedTo))
            {
                g_bRealityShiftSwapped[i] = false;

                g_iRealityShiftAssigned[i] = 0;

                continue;
            }

            RealityShift_SwapPositions(i, assignedTo);
        }
    }

    if (!saveOnly && !random)
        return;

    int assignmentsCount = count / 2;

    if (assignmentsCount <= 1)
        return;

    for (int i = 0; i < assignmentsCount; i++)
    {
        int client, assignedTo;

        int index =
            GetRandomClientFromArray(clients, count, client);

        if (index == -1)
            continue;

        clients[index] = 0;

        index =
            GetRandomClientFromArray(clients, count, assignedTo);

        if (index == -1)
            continue;

        clients[index] = 0;

        if (saveOnly)
        {
            g_iRealityShiftAssigned[client] =
                GetClientUserId(assignedTo);

            g_iRealityShiftAssigned[assignedTo] =
                GetClientUserId(client);

            CPrintToChat(
                client,
                "%s You will swap with {olive}%N {lightgreen} all round!",
                THIS_MODE_INFO.tag,
                assignedTo
            );

            CPrintToChat(
                assignedTo,
                "%s You will swap with {olive}%N {lightgreen} all round!",
                THIS_MODE_INFO.tag,
                client
            );
        }
        else
        {
            if (!random)
                continue;

            if (g_bRealityShiftSwapped[client]
            || g_bRealityShiftSwapped[assignedTo])
                continue;

            RealityShift_SwapPositions(
                client,
                assignedTo
            );
        }
    }
}

void RealityShift_SwapPositions(int client, int assignedTo)
{
    if (client == assignedTo)
        return;

    if (g_bRealityShiftSwapped[client]
    || g_bRealityShiftSwapped[assignedTo])
        return;

    float clientOrigin[3];
    float assignedToOrigin[3];

    float clientEyeAngles[3];
    float assignedToEyeAngles[3];

    GetClientAbsOrigin(client, clientOrigin);
    GetClientAbsOrigin(assignedTo, assignedToOrigin);

    GetClientEyeAngles(client, clientEyeAngles);
    GetClientEyeAngles(assignedTo, assignedToEyeAngles);

    TeleportEntity(
        client,
        assignedToOrigin,
        assignedToEyeAngles
    );

    TeleportEntity(
        assignedTo,
        clientOrigin,
        clientEyeAngles
    );

    CPrintToChat(
        client,
        "%s You swapped positions with {olive}%N",
        THIS_MODE_INFO.tag,
        assignedTo
    );

    CPrintToChat(
        assignedTo,
        "%s You swapped positions with {olive}%N",
        THIS_MODE_INFO.tag,
        client
    );

    g_bRealityShiftSwapped[client] = true;
    g_bRealityShiftSwapped[assignedTo] = true;
}
