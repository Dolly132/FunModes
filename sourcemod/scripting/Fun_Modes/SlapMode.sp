/*
    (). FunModes V2:

    @file           SlapMode.sp
    @Usage          Functions for the SlapMode Mode.
*/

#pragma semicolon 1
#pragma newdecls required

ModeInfo g_SlapModeInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_SlapModeInfo

#define SLAPMODE_CONVAR_TIMER_INTERVAL  0
#define SLAPMODE_CONVAR_RANDOMS_COUNT   1
#define SLAPMODE_CONVAR_TOGGLE          2

Handle g_hSlapModeTimer;

float g_fSlapModeInterval;
int g_iSlapModeCount;
bool g_bSlapModeEnabled;

stock void OnPluginStart_SlapMode()
{
	THIS_MODE_INFO.name = "SlapMode";
	THIS_MODE_INFO.tag = "{gold}[FunModes-SlapMode]{lightgreen}";

	RegAdminCmd("sm_fm_slapmode", Cmd_SlapModeToggle, ADMFLAG_CONVARS, "Turn SlapMode On/Off");
	RegAdminCmd("sm_slapmode_settings", Cmd_SlapModeSettings, ADMFLAG_CONVARS, "Open SlapMode Settings Menu");

	DECLARE_FM_CVAR(
		SLAPMODE_CONVAR_TIMER_INTERVAL, "sm_slapmode_time_interval",
		"20.0", "The time interval between each slap round",
		("15.0,20.0,30.0,40.0,60.0"), CONVAR_FLOAT
	);
	THIS_MODE_INFO.cvars[SLAPMODE_CONVAR_TIMER_INTERVAL].HookChange(SlapMode_OnConVarChange);

	DECLARE_FM_CVAR(
		SLAPMODE_CONVAR_RANDOMS_COUNT, "sm_slapmode_randoms_count",
		"1", "How many random CTs should be slapped each round",
		("1,2,3,4,5"), CONVAR_INT
	);
	THIS_MODE_INFO.cvars[SLAPMODE_CONVAR_RANDOMS_COUNT].HookChange(SlapMode_OnConVarChange);

	DECLARE_FM_CVAR(
		SLAPMODE_CONVAR_TOGGLE, "sm_slapmode_enable",
		"1", "Enable/Disable SlapMode (This differs from turning it on/off)",
		("0,1"), CONVAR_BOOL
	);
	THIS_MODE_INFO.cvars[SLAPMODE_CONVAR_TOGGLE].HookChange(SlapMode_OnConVarChange);

	THIS_MODE_INFO.enableIndex = SLAPMODE_CONVAR_TOGGLE;

	FUNMODES_REGISTER_MODE();
}

void InitCvarsValues_SlapMode()
{
	int modeIndex = THIS_MODE_INFO.index;

	g_fSlapModeInterval = _FUNMODES_CVAR_GET_VALUE(modeIndex, SLAPMODE_CONVAR_TIMER_INTERVAL, Float);
	g_iSlapModeCount = _FUNMODES_CVAR_GET_VALUE(modeIndex, SLAPMODE_CONVAR_RANDOMS_COUNT, Int);
	g_bSlapModeEnabled = _FUNMODES_CVAR_GET_VALUE(modeIndex, SLAPMODE_CONVAR_TOGGLE, Bool);
}

void SlapMode_OnConVarChange(int modeIndex, int cvarIndex, const char[] oldValue, const char[] newValue)
{
	switch (cvarIndex)
	{
		case SLAPMODE_CONVAR_TIMER_INTERVAL:
			g_fSlapModeInterval = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Float);

		case SLAPMODE_CONVAR_RANDOMS_COUNT:
			g_iSlapModeCount = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Int);

		case SLAPMODE_CONVAR_TOGGLE:
		{
			bool val = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Bool);

			if (THIS_MODE_INFO.isOn)
				CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, val, THIS_MODE_INFO.index);

			g_bSlapModeEnabled = val;
		}
	}
}

stock void OnMapStart_SlapMode() {}

stock void OnMapEnd_SlapMode()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
	g_hSlapModeTimer = null;
}

stock void OnClientPutInServer_SlapMode(int client)
{
	#pragma unused client
}

stock void OnClientDisconnect_SlapMode(int client)
{
	#pragma unused client
}

stock void ZR_OnClientInfected_SlapMode(int client)
{
	#pragma unused client
}

stock void Event_RoundStart_SlapMode() {}
stock void Event_RoundEnd_SlapMode() {}

stock void Event_PlayerSpawn_SlapMode(int client)
{
	#pragma unused client
}

stock void Event_PlayerTeam_SlapMode(Event event)
{
	#pragma unused event
}

stock void Event_PlayerDeath_SlapMode(int client)
{
	#pragma unused client
}

public Action Cmd_SlapModeToggle(int client, int args)
{
	if (!g_bSlapModeEnabled)
	{
		CReplyToCommand(client, "%s SlapMode is currently Disabled", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);

	CPrintToChatAll("%s SlapMode is now %s!", THIS_MODE_INFO.tag, THIS_MODE_INFO.isOn ? "On" : "Off");

	if (THIS_MODE_INFO.isOn)
	{
		CPrintToChatAll("%s Random CTs will be slapped every %.2f seconds", THIS_MODE_INFO.tag, g_fSlapModeInterval);

		delete g_hSlapModeTimer;
		g_hSlapModeTimer = CreateTimer(
			g_fSlapModeInterval,
			Timer_SlapMode,
			_,
			TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE
		);
	}
	else
	{
		delete g_hSlapModeTimer;
	}

	return Plugin_Handled;
}

Action Timer_SlapMode(Handle timer)
{
	if (!THIS_MODE_INFO.isOn)
		return Plugin_Stop;

	int players[MAXPLAYERS + 1];
	int count;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT)
			continue;

		players[count] = i;
		count++;
	}

	if (!count)
		return Plugin_Continue;

	for (int i = 0; i < g_iSlapModeCount; i++)
	{
		int client = players[GetRandomInt(0, count - 1)];

		SlapPlayer(client);
		SlapPlayer(client);

		CPrintToChatAll("%s %N has been slapped", THIS_MODE_INFO.tag, client);
	}

	return Plugin_Continue;
}

public Action Cmd_SlapModeSettings(int client, int args)
{
	if (!client)
		return Plugin_Handled;

	Menu menu = new Menu(Menu_SlapModeSettings);

	menu.SetTitle("%s - Settings", THIS_MODE_INFO.name);
	menu.AddItem(NULL_STRING, "Show Cvars\n");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

int Menu_SlapModeSettings(Menu menu, MenuAction action, int param1, int param2)
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
