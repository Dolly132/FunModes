/*
    (). FunModes V2:
        
    @file           Sample.sp
    @Usage         	Functions for the Sample Mode.
    				
*/

#pragma semicolon 1
#pragma newdecls required

ModeInfo g_SampleInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_SampleInfo

#define SAMPLE_CONVAR_TOGGLE 0

stock void OnPluginStart_Sample()
{
	THIS_MODE_INFO.name = "Sample";
	THIS_MODE_INFO.tag = "{gold}[FunModes-Sample]{lightgreen}";
	
	/* COMMANDS */
	/* THESE ARE THE STANDARD COMMANDS THAT ALL MODES SHOULD HAVE */
	RegAdminCmd("sm_fm_sample", Cmd_SampleToggle, ADMFLAG_CONVARS, "Turn Sample Mode On/Off");
	RegAdminCmd("sm_sample_settings", Cmd_SampleSettings, ADMFLAG_CONVARS, "Open Sample Sttings Menu");
	
	/* CONVARS */
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, SAMPLE_CONVAR_TOGGLE,
		"sm_sample_enable", "1", "Enable/Disable Sample Mode (This differs from turning it on/off)",
		("0,1"), "bool"
	);
	
	THIS_MODE_INFO.enableIndex = SAMPLE_CONVAR_TOGGLE;
	
	THIS_MODE_INFO.index = g_iLastModeIndex++;
	g_ModesInfo[THIS_MODE_INFO.index] = THIS_MODE_INFO;
	
	THIS_MODE_INFO.cvarInfo[SAMPLE_CONVAR_TOGGLE].cvar.AddChangeHook(OnSampleModeToggle);
}

void OnSampleModeToggle(ConVar cvar, const char[] newValue, const char[] oldValue)
{
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, cvar.BoolValue, THIS_MODE_INFO.index);
}

stock void OnMapStart_Sample() {}
stock void OnMapEnd_Sample()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
}

stock void OnClientPutInServer_Sample(int client)
{
	#pragma unused client
}

stock void OnClientDisconnect_Sample(int client)
{
	#pragma unused client
}

stock void ZR_OnClientInfected_Sample(int client)
{
	#pragma unused client
}

stock void Event_RoundStart_Sample() {}
stock void Event_RoundEnd_Sample() {}
stock void Event_PlayerSpawn_Sample(int client)
{
	#pragma unused client
}

stock void Event_PlayerTeam_Sample(Event event)
{
	#pragma unused event
}

stock void Event_PlayerDeath_Sample(int client)
{
	#pragma unused client
}

public Action Cmd_SampleToggle(int client, int args)
{
	if (!THIS_MODE_INFO.cvarInfo[THIS_MODE_INFO.enableIndex].cvar.BoolValue)
	{
		CReplyToCommand(client, "%s Sample Mode is currently Disabled", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	/* You can change whatever you want here */
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);
	
	CPrintToChatAll("%s Sample Mode is now %s!", THIS_MODE_INFO.tag, THIS_MODE_INFO.isOn ? "On" : "Off");
	
	return Plugin_Handled;
}

/* Sample Settings */
public Action Cmd_SampleSettings(int client, int args)
{
	if (!client)
		return Plugin_Handled;
		
	Menu menu = new Menu(Menu_SampleSettings);

	menu.SetTitle("%s - Settings", THIS_MODE_INFO.name);

	menu.AddItem(NULL_STRING, "Show Cvars\n");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

int Menu_SampleSettings(Menu menu, MenuAction action, int param1, int param2)
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