/*
    (). FunModes V2:
        
    @file           SlapMode.sp
    @Usage         	Functions for the Slap mode.
    				
*/

/*
	Slapmode :
	Like all 3 or 5 seconds (not sure about the time) a random ct gets slapped, i think it can make certain maps really fun
	
	By @Kamisama Kaneki
*/

#pragma semicolon 1
#pragma newdecls required

ModeInfo g_SlapModeInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_SlapModeInfo

#define SLAPMODE_CONVAR_TIMER_INTERVAL	0
#define SLAPMODE_CONVAR_RANDOMS_COUNT	1
#define SLAPMODE_CONVAR_TOGGLE 			2

Handle g_hSlapModeTimer;

stock void OnPluginStart_SlapMode()
{
	THIS_MODE_INFO.name = "SlapMode";
	THIS_MODE_INFO.tag = "{gold}[FunModes-SlapMode]{lightgreen}";
	
	/* COMMANDS */
	/* THESE ARE THE STANDARD COMMANDS THAT ALL MODES SHOULD HAVE */
	RegAdminCmd("sm_fm_slapmode", Cmd_SlapModeToggle, ADMFLAG_CONVARS, "Turn SlapMode Mode On/Off");
	RegAdminCmd("sm_slapmode_settings", Cmd_SlapModeSettings, ADMFLAG_CONVARS, "Open SlapMode Sttings Menu");
	
	/* CONVARS */
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, SLAPMODE_CONVAR_TIMER_INTERVAL,
		"sm_slapmode_time_interval", "20.0", "Every how many seconds to keep slapping a random human?",
		("15.0,20.0,30.0,40.0,60.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, SLAPMODE_CONVAR_RANDOMS_COUNT,
		"sm_slapmode_randoms_count", "1", "How many random humans to keep slapping?",
		("1,2,3,4,5"), "int"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, SLAPMODE_CONVAR_TOGGLE,
		"sm_slapmode_enable", "1", "Enable/Disable SlapMode Mode (This differs from turning it on/off)",
		("0,1"), "bool"
	);
	
	THIS_MODE_INFO.enableIndex = SLAPMODE_CONVAR_TOGGLE;
	
	THIS_MODE_INFO.index = g_iLastModeIndex++;
	g_ModesInfo[THIS_MODE_INFO.index] = THIS_MODE_INFO;
	
	THIS_MODE_INFO.cvarInfo[SLAPMODE_CONVAR_TOGGLE].cvar.AddChangeHook(OnSlapModeModeToggle);
}

void OnSlapModeModeToggle(ConVar cvar, const char[] newValue, const char[] oldValue)
{
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, cvar.BoolValue, THIS_MODE_INFO.index);
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
	if (!THIS_MODE_INFO.cvarInfo[THIS_MODE_INFO.enableIndex].cvar.BoolValue)
	{
		CReplyToCommand(client, "%s SlapMode Mode is currently Disabled", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	/* You can change whatever you want here */
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);
	
	CPrintToChatAll("%s SlapMode Mode is now %s!", THIS_MODE_INFO.tag, THIS_MODE_INFO.isOn ? "On" : "Off");
	
	if (THIS_MODE_INFO.isOn)
	{
		float interval = THIS_MODE_INFO.cvarInfo[SLAPMODE_CONVAR_TIMER_INTERVAL].cvar.FloatValue;
		
		CPrintToChatAll("%s A random human will get slapped every %.2f seconds", THIS_MODE_INFO.tag, interval);		
		g_hSlapModeTimer = CreateTimer(interval, Timer_SlapMode, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	}
	else
	{
		delete g_hSlapModeTimer;
	}
	
	return Plugin_Handled;
}

/* SlapMode Settings */
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

Action Timer_SlapMode(Handle timer)
{
	if (!THIS_MODE_INFO.isOn)
	{
		g_hBlindModeTimer = null;
		return Plugin_Stop;
	}
	
	int humansCount = 0;
	int humans[MAXPLAYERS + 1];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT)
			continue;
		
		humans[humansCount++] = i;
	}
	
	if (humansCount == 0)
		return Plugin_Handled;
		
	int neededHumans = THIS_MODE_INFO.cvarInfo[SLAPMODE_CONVAR_RANDOMS_COUNT].cvar.IntValue;
	int enough = 1;
	do 
	{
		int human = humans[GetRandomInt(0, humansCount - 1)];
		SlapPlayer(human);
		SlapPlayer(human);
		CPrintToChatAll("%s %N {olive}has been slapped for being a bad boy (Bruh, It's totally random...)", THIS_MODE_INFO.tag, human);
		enough++;
	} while (enough <= neededHumans);
	
	return Plugin_Continue;
}