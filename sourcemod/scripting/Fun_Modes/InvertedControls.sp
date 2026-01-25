/*
    (). FunModes V2:
        
    @file           InvertedControls.sp
    @Usage          Functions for the IC mode.
*/

#pragma semicolon 1
#pragma newdecls required

ModeInfo g_ICInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_ICInfo

#define IC_CONVAR_TOGGLE 0

/* CALLED ON PLUGIN START */
stock void OnPluginStart_IC()
{
	THIS_MODE_INFO.name = "IC";
	THIS_MODE_INFO.tag = "{gold}[FunModes-InvertedControls]{lightgreen}";

	/* Admin Commands */
	static const char commands[][] =
	{
		"sm_invertedcon",
		"sm_invertcon",
		"sm_invertedcontrols",
		"sm_fm_ic"
	};
	
	for(int i = 0; i < sizeof(commands); i++)
	{
		RegAdminCmd(commands[i], Cmd_ICToggle, ADMFLAG_CONVARS, "Enable/Disable Inverted controls");
	}
	
	RegAdminCmd("sm_ic_settings", Cmd_ICSettings, ADMFLAG_CONVARS, "Open IC Settings Menu");
	
	/* CONVARS */
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, IC_CONVAR_TOGGLE,
		"sm_ic_enable", "1", "Enable/Disable Inverted Controls mode.",
		("0,1"), "bool"
	);

	THIS_MODE_INFO.enableIndex = IC_CONVAR_TOGGLE;

	THIS_MODE_INFO.index = g_iLastModeIndex++;
	g_ModesInfo[THIS_MODE_INFO.index] = THIS_MODE_INFO;

	THIS_MODE_INFO.cvarInfo[IC_CONVAR_TOGGLE].cvar.AddChangeHook(OnICModeToggle);
}

void OnICModeToggle(ConVar cvar, const char[] newValue, const char[] oldValue)
{
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, cvar.BoolValue, THIS_MODE_INFO.index);
}

stock void OnMapStart_IC() {}
stock void OnMapEnd_IC()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
}

stock void OnClientPutInServer_IC(int client)
{
	#pragma unused client
}

stock void OnClientDisconnect_IC(int client)
{
	#pragma unused client
}

stock void ZR_OnClientInfected_IC(int client)
{
	#pragma unused client
}

stock void Event_RoundStart_IC() {}
stock void Event_RoundEnd_IC() {}
stock void Event_PlayerSpawn_IC(int client)
{
	#pragma unused client
}

stock void Event_PlayerTeam_IC(Event event)
{
	#pragma unused event
}

stock void Event_PlayerDeath_IC(int client)
{
	#pragma unused client
}

public Action Cmd_ICToggle(int client, int args)
{
	if (!THIS_MODE_INFO.cvarInfo[THIS_MODE_INFO.enableIndex].cvar.BoolValue)
	{
		CReplyToCommand(client, "%s Inverted Controls is currently Disabled", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	ConVar cvar = FindConVar("sv_accelerate");
	if(cvar == null)
	{
		// it should never happen though
		return Plugin_Handled;
	}
	
	if(cvar.IntValue == -5)
	{
		CPrintToChatAll("%s Inverted Controls is now {olive}Off!", THIS_MODE_INFO.tag);
		cvar.IntValue = 5;
		delete cvar;
		return Plugin_Handled;
	}
	
	CPrintToChatAll("%s Inverted Controls is now {olive}On!", THIS_MODE_INFO.tag);
	cvar.IntValue = -5;
	delete cvar;
	return Plugin_Handled;
}

/* IC Settings */
public Action Cmd_ICSettings(int client, int args)
{
	if (!client)
		return Plugin_Handled;
		
	Menu menu = new Menu(Menu_ICSettings);

	menu.SetTitle("%s - Settings", THIS_MODE_INFO.name);

	menu.AddItem(NULL_STRING, "Show Cvars\n");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

int Menu_ICSettings(Menu menu, MenuAction action, int param1, int param2)
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