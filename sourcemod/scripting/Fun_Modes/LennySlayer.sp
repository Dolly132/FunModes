/*
    (). FunModes V2:
        
    @file           LennySlayer.sp
    @Usage         	Functions for the LennySlayer Mode.
    				
*/

#pragma semicolon 1
#pragma newdecls required

ModeInfo g_LennySlayerInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_LennySlayerInfo

#define LennySlayer_CONVAR_TOGGLE 0

stock void OnPluginStart_LennySlayer()
{
	THIS_MODE_INFO.name = "LennySlayer";
	THIS_MODE_INFO.tag = "{gold}[FunModes-LennySlayer]{lightgreen}";
	
	/* COMMANDS */
	/* THESE ARE THE STANDARD COMMANDS THAT ALL MODES SHOULD HAVE */
	RegAdminCmd("sm_fm_LennySlayer", Cmd_LennySlayerToggle, ADMFLAG_CONVARS, "Turn LennySlayer Mode On/Off");
	RegAdminCmd("sm_LennySlayer_settings", Cmd_LennySlayerSettings, ADMFLAG_CONVARS, "Open LennySlayer Sttings Menu");
	
	/* CONVARS */
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, LennySlayer_CONVAR_TOGGLE,
		"sm_LennySlayer_enable", "1", "Enable/Disable LennySlayer Mode (This differs from turning it on/off)",
		("0,1"), "bool"
	);
	
	THIS_MODE_INFO.enableIndex = LennySlayer_CONVAR_TOGGLE;
	
	THIS_MODE_INFO.index = g_iLastModeIndex++;
	g_ModesInfo[THIS_MODE_INFO.index] = THIS_MODE_INFO;
	
	THIS_MODE_INFO.cvarInfo[LennySlayer_CONVAR_TOGGLE].cvar.AddChangeHook(OnLennySlayerModeToggle);
}

void OnLennySlayerModeToggle(ConVar cvar, const char[] newValue, const char[] oldValue)
{
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, cvar.BoolValue, THIS_MODE_INFO.index);
}

stock void OnMapStart_LennySlayer() {}
stock void OnMapEnd_LennySlayer()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
}

stock void OnClientPutInServer_LennySlayer(int client)
{
	#pragma unused client
}

stock void OnClientDisconnect_LennySlayer(int client)
{
	#pragma unused client
}

stock void ZR_OnClientInfected_LennySlayer(int client)
{
	#pragma unused client
}

stock void Event_RoundStart_LennySlayer() {}
stock void Event_RoundEnd_LennySlayer() {}
stock void Event_PlayerSpawn_LennySlayer(int client)
{
	#pragma unused client
}

stock void Event_PlayerTeam_LennySlayer(Event event)
{
	#pragma unused event
}

stock void Event_PlayerDeath_LennySlayer(int client)
{
	#pragma unused client
}

public Action Cmd_LennySlayerToggle(int client, int args)
{
	if (!THIS_MODE_INFO.cvarInfo[THIS_MODE_INFO.enableIndex].cvar.BoolValue)
	{
		CReplyToCommand(client, "%s LennySlayer Mode is currently Disabled", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	/* You can change whatever you want here */
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);
	
	CPrintToChatAll("%s LennySlayer Mode is now %s!", THIS_MODE_INFO.tag, THIS_MODE_INFO.isOn ? "On" : "Off");
	
	return Plugin_Handled;
}

/* LennySlayer Settings */
public Action Cmd_LennySlayerSettings(int client, int args)
{
	if (!client)
		return Plugin_Handled;
		
	Menu menu = new Menu(Menu_LennySlayerSettings);

	menu.SetTitle("%s - Settings", THIS_MODE_INFO.name);

	menu.AddItem(NULL_STRING, "Show Cvars\n");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

int Menu_LennySlayerSettings(Menu menu, MenuAction action, int param1, int param2)
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

stock bool DoesContainLenny(const char[] buffer)
{
	int len = strlen(buffer);
	
	for (int i = 0; i < len; i++)
	{
		if (buffer[i] == '°' || buffer[i] == 'ʖ' || GetCharBytes(buffer[i]) >= 2)
			return true;
	}
	
	return false;
}