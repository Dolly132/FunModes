/*
    (). FunModes V2:
        
    @file           SkinsMode.sp
    @Usage         	Functions for the SkinsMode Mode.
    				
*/

#pragma semicolon 1
#pragma newdecls required

ModeInfo g_SkinsModeInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_SkinsModeInfo

#define SKINSMODE_CONVAR_TOGGLE 0

stock void OnPluginStart_SkinsMode()
{
	THIS_MODE_INFO.name = "SkinsMode";
	THIS_MODE_INFO.tag = "{gold}[FunModes-SkinsMode]{lightgreen}";
	
	/* COMMANDS */
	/* THESE ARE THE STANDARD COMMANDS THAT ALL MODES SHOULD HAVE */
	RegAdminCmd("sm_fm_skinsmode", Cmd_SkinsModeToggle, ADMFLAG_CONVARS, "Turn SkinsMode Mode On/Off");
	RegAdminCmd("sm_skinsmode_settings", Cmd_SkinsModeSettings, ADMFLAG_CONVARS, "Open SkinsMode Sttings Menu");
	
	/* CONVARS */
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, SKINSMODE_CONVAR_TOGGLE,
		"sm_skinsmode_enable", "1", "Enable/Disable SkinsMode Mode (This differs from turning it on/off)",
		("0,1"), "bool"
	);
	
	THIS_MODE_INFO.enableIndex = SKINSMODE_CONVAR_TOGGLE;
	
	THIS_MODE_INFO.index = g_arModesInfo.Length;
	g_arModesInfo.PushArray(THIS_MODE_INFO);
	
	THIS_MODE_INFO.cvarInfo[SKINSMODE_CONVAR_TOGGLE].cvar.AddChangeHook(OnSkinsModeModeToggle);
}

void OnSkinsModeModeToggle(ConVar cvar, const char[] newValue, const char[] oldValue)
{
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, cvar.BoolValue, THIS_MODE_INFO.index);
}

stock void OnMapStart_SkinsMode() {}
stock void OnMapEnd_SkinsMode()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
}

stock void OnClientPutInServer_SkinsMode(int client)
{
	#pragma unused client
}

stock void OnClientDisconnect_SkinsMode(int client)
{
	#pragma unused client
}

stock void ZR_OnClientInfected_SkinsMode(int client)
{
	#pragma unused client
}

stock void Event_RoundStart_SkinsMode() {}
stock void Event_RoundEnd_SkinsMode() {}
stock void Event_PlayerSpawn_SkinsMode(int client)
{
	#pragma unused client
}

stock void Event_PlayerTeam_SkinsMode(Event event)
{
	#pragma unused event
}

stock void Event_PlayerDeath_SkinsMode(int client)
{
	#pragma unused client
}

public Action Cmd_SkinsModeToggle(int client, int args)
{
	if (!THIS_MODE_INFO.cvarInfo[THIS_MODE_INFO.enableIndex].cvar.BoolValue)
	{
		CReplyToCommand(client, "%s SkinsMode Mode is currently Disabled", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	/* You can change whatever you want here */
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);
	
	CPrintToChatAll("%s SkinsMode Mode is now %s!", THIS_MODE_INFO.tag, THIS_MODE_INFO.isOn ? "On" : "Off");
	
	return Plugin_Handled;
}

/* SkinsMode Settings */
public Action Cmd_SkinsModeSettings(int client, int args)
{
	if (!client)
		return Plugin_Handled;
		
	Menu menu = new Menu(Menu_SkinsModeSettings);

	menu.SetTitle("%s - Settings", THIS_MODE_INFO.name);

	menu.AddItem(NULL_STRING, "Show Cvars\n ");
	
	menu.AddItem(NULL_STRING, "Change Zombies Skin", THIS_MODE_INFO.isOn ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	menu.AddItem(NULL_STRING, "Change Humans Skin", THIS_MODE_INFO.isOn ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

int Menu_SkinsModeSettings(Menu menu, MenuAction action, int param1, int param2)
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
			switch (param2)
			{
				case 0: ShowCvarsInfo(param1, THIS_MODE_INFO);
				case 1: ShowTeamSkins(param1, 0);
				case 2: ShowTeamSkins(param1, 1);
			}
		}
	}

	return 0;
}

void ShowTeamSkins(int client, int team)
{
	
}