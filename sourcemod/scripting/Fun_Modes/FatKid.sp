/*
    (). FunModes V2:
        
    @file           FatKid.sp
    @Usage         	Functions for the FatKid Mode.
    				
*/

#pragma semicolon 1
#pragma newdecls required

ModeInfo g_FatKidInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_FatKidInfo

#define FATKID_CONVAR_TOGGLE 0

stock void OnPluginStart_FatKid()
{
	THIS_MODE_INFO.name = "FatKid";
	THIS_MODE_INFO.tag = "{gold}[FunModes-FatKid]{lightgreen}";
	
	/* COMMANDS */
	/* THESE ARE THE STANDARD COMMANDS THAT ALL MODES SHOULD HAVE */
	RegAdminCmd("sm_fm_fatkid", Cmd_FatKidToggle, ADMFLAG_CONVARS, "Turn FatKid Mode On/Off");
	RegAdminCmd("sm_fatkid_settings", Cmd_FatKidSettings, ADMFLAG_CONVARS, "Open FatKid Sttings Menu");
	
	/* CONVARS */
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, FATKID_CONVAR_TOGGLE,
		"sm_fatkid_enable", "1", "Enable/Disable FatKid Mode (This differs from turning it on/off)",
		("0,1"), "bool"
	);
	
	THIS_MODE_INFO.enableIndex = FATKID_CONVAR_TOGGLE;
	
	THIS_MODE_INFO.index = g_iLastModeIndex++;
	g_ModesInfo[THIS_MODE_INFO.index] = THIS_MODE_INFO;
	
	THIS_MODE_INFO.cvarInfo[FATKID_CONVAR_TOGGLE].cvar.AddChangeHook(OnFatKidModeToggle);
}

void OnFatKidModeToggle(ConVar cvar, const char[] newValue, const char[] oldValue)
{
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, cvar.BoolValue, THIS_MODE_INFO.index);
}

stock void OnMapStart_FatKid() {}
stock void OnMapEnd_FatKid()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
}

stock void OnClientPutInServer_FatKid(int client)
{
	#pragma unused client
}

stock void OnClientDisconnect_FatKid(int client)
{
	#pragma unused client
}

stock void ZR_OnClientInfected_FatKid(int client)
{
	#pragma unused client
}

stock void Event_RoundStart_FatKid() {}
stock void Event_RoundEnd_FatKid() {}
stock void Event_PlayerSpawn_FatKid(int client)
{
	#pragma unused client
}

stock void Event_PlayerTeam_FatKid(Event event)
{
	#pragma unused event
}

stock void Event_PlayerDeath_FatKid(int client)
{
	#pragma unused client
}

public Action Cmd_FatKidToggle(int client, int args)
{
	if (!THIS_MODE_INFO.cvarInfo[THIS_MODE_INFO.enableIndex].cvar.BoolValue)
	{
		CReplyToCommand(client, "%s FatKid Mode is currently Disabled", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	/* You can change whatever you want here */
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);
	
	CPrintToChatAll("%s FatKid Mode is now %s!", THIS_MODE_INFO.tag, THIS_MODE_INFO.isOn ? "On" : "Off");
	
	if (THIS_MODE_INFO.isOn)
	{
		
	}
	return Plugin_Handled;
}

/* FatKid Settings */
public Action Cmd_FatKidSettings(int client, int args)
{
	if (!client)
		return Plugin_Handled;
		
	Menu menu = new Menu(Menu_FatKidSettings);

	menu.SetTitle("%s - Settings", THIS_MODE_INFO.name);

	menu.AddItem(NULL_STRING, "Show Cvars\n");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

int Menu_FatKidSettings(Menu menu, MenuAction action, int param1, int param2)
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